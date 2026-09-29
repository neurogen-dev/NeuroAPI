Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Set-NeuroAPIPrivateDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ((Get-Item -LiteralPath $Path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw 'Каталог NeuroAPI не должен быть ссылкой. Повторите установку.'
    }
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $acl = New-Object Security.AccessControl.DirectorySecurity
    $acl.SetOwner($identity)
    $acl.SetAccessRuleProtection($true, $false)
    $rule = New-Object Security.AccessControl.FileSystemAccessRule(
        $identity, 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow'
    )
    $acl.AddAccessRule($rule)
    Set-Acl -LiteralPath $Path -AclObject $acl
}

function New-NeuroAPILaunchDirectory {
    param([Parameter(Mandatory = $true)][string]$StateRoot)
    $path = Join-Path $StateRoot ('launch-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $path -ErrorAction Stop | Out-Null
    try {
        Set-NeuroAPIPrivateDirectory -Path $path
        return $path
    } catch {
        Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        throw 'Не удалось создать приватный каталог запуска NeuroAPI.'
    }
}

function Read-NeuroAPIProtectedCredential {
    param([Parameter(Mandatory = $true)][string]$SecretPath)
    $secure = $null
    $pointer = [IntPtr]::Zero
    try {
        $cipher = [IO.File]::ReadAllText($SecretPath)
        $secure = ConvertTo-SecureString -String $cipher
        $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        $value = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        if ([string]::IsNullOrWhiteSpace($value) -or $value.IndexOfAny([char[]]"`r`n") -ge 0) {
            throw 'Invalid credential'
        }
        return $value
    } catch {
        throw 'Не удалось прочитать защищенный ключ NeuroAPI. Повторите установку.'
    } finally {
        if ($pointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
        if ($null -ne $secure) { $secure.Dispose() }
        $value = $null
    }
}

function New-NeuroAPICatalogClient {
    Add-Type -AssemblyName System.Net.Http
    $handler = New-Object Net.Http.HttpClientHandler
    $handler.AllowAutoRedirect = $false
    $handler.UseCookies = $false
    $client = New-Object Net.Http.HttpClient($handler)
    $client.Timeout = [TimeSpan]::FromSeconds(30)
    return $client
}

function Get-NeuroAPICatalogJson {
    param([ValidateSet('codex', 'claude')][string]$Client, [string]$SecretPath)
    $endpoint = if ($Client -eq 'codex') {
        'https://codex.neuroapi.host/v1/models'
    } else {
        'https://claude.neuroapi.host/client-settings'
    }
    $http = $null; $request = $null; $response = $null; $stream = $null; $buffer = $null; $timeout = $null
    $credential = $null
    try {
        $http = New-NeuroAPICatalogClient
        $timeout = New-Object Threading.CancellationTokenSource
        $timeout.CancelAfter(30000)
        $request = New-Object Net.Http.HttpRequestMessage([Net.Http.HttpMethod]::Get, $endpoint)
        $credential = Read-NeuroAPIProtectedCredential -SecretPath $SecretPath
        $request.Headers.Authorization = New-Object Net.Http.Headers.AuthenticationHeaderValue('Bearer', $credential)
        $request.Headers.Accept.ParseAdd('application/json')
        $response = $http.SendAsync($request, [Net.Http.HttpCompletionOption]::ResponseHeadersRead, $timeout.Token).GetAwaiter().GetResult()
        if ([int]$response.StatusCode -ne 200) { throw 'Catalog unavailable' }
        $limit = 2 * 1024 * 1024
        if ($null -ne $response.Content.Headers.ContentLength -and $response.Content.Headers.ContentLength -gt $limit) {
            throw 'Catalog too large'
        }
        $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $buffer = New-Object IO.MemoryStream
        $chunk = New-Object byte[] 8192
        while ($true) {
            $read = $stream.ReadAsync($chunk, 0, $chunk.Length, $timeout.Token).GetAwaiter().GetResult()
            if ($read -eq 0) { break }
            if ($buffer.Length + $read -gt $limit) { throw 'Catalog too large' }
            $buffer.Write($chunk, 0, $read)
        }
        $utf8 = New-Object Text.UTF8Encoding($false, $true)
        $json = $utf8.GetString($buffer.ToArray())
        if ($json.IndexOf($credential, [StringComparison]::Ordinal) -ge 0) { throw 'Credential reflected' }
        $decoded = $json | ConvertFrom-Json -ErrorAction Stop
        Assert-NeuroAPINoCredential -Value $decoded -Credential $credential -Depth 0
        return $json
    } catch {
        # Never print the underlying HTTP exception, request headers or body.
        throw 'Не удалось обновить каталог NeuroAPI. Проверьте доступ к сервису и ключ; запуск отменен.'
    } finally {
        $credential = $null
        foreach ($resource in @($buffer, $stream, $response, $request, $timeout, $http)) {
            if ($null -ne $resource) { $resource.Dispose() }
        }
    }
}

function Test-NeuroAPIModelId {
    param($Value)
    return ($Value -is [string] -and $Value -cmatch '^[A-Za-z0-9][A-Za-z0-9._:/\-]{0,255}$')
}

function Get-NeuroAPIProperty {
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return ,$property.Value
}

function Assert-NeuroAPINoCredential {
    param($Value, [string]$Credential, [int]$Depth)
    if ($Depth -gt 64) { throw 'Catalog nesting too deep' }
    if ($Value -is [string]) {
        if ($Value.IndexOf($Credential, [StringComparison]::Ordinal) -ge 0) { throw 'Credential reflected' }
    } elseif ($Value -is [array]) {
        foreach ($item in $Value) { Assert-NeuroAPINoCredential $item $Credential ($Depth + 1) }
    } elseif ($Value -is [pscustomobject]) {
        foreach ($property in $Value.PSObject.Properties) {
            if ($property.Name.IndexOf($Credential, [StringComparison]::Ordinal) -ge 0) { throw 'Credential reflected' }
            Assert-NeuroAPINoCredential $property.Value $Credential ($Depth + 1)
        }
    }
}

function Assert-NeuroAPIKeys {
    param($Object, [string[]]$Allowed)
    if ($Object -isnot [pscustomobject]) { throw 'Invalid object' }
    foreach ($property in $Object.PSObject.Properties) {
        if ($Allowed -cnotcontains $property.Name) { throw 'Unexpected property' }
    }
}

function Test-NeuroAPIText {
    param($Value, [int]$Limit)
    return ($Value -is [string] -and $Value.Length -le $Limit -and $Value -notmatch '[\x00-\x08\x0b\x0c\x0e-\x1f]')
}

function Test-NeuroAPIInteger {
    param($Value, [long]$Minimum, [long]$Maximum)
    return (($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]) -and
        $Value -ge $Minimum -and $Value -le $Maximum -and [Math]::Floor([double]$Value) -eq $Value)
}

function Assert-NeuroAPICodexModel {
    param($Model)
    $strings = @('display_name', 'description', 'base_instructions')
    $booleans = @('supported_in_api', 'supports_reasoning_summary_parameter', 'support_verbosity', 'supports_parallel_tool_calls', 'supports_search_tool', 'use_responses_lite')
    $counts = @('priority', 'context_window', 'max_context_window', 'auto_compact_token_limit', 'effective_context_window_percent', 'input_token_limit', 'output_token_limit')
    Assert-NeuroAPIKeys $Model (@('slug', 'supported_reasoning_levels', 'shell_type', 'visibility', 'model_messages', 'truncation_policy', 'experimental_supported_tools', 'input_modalities') + $strings + $booleans + $counts)
    foreach ($field in $strings) { if (-not (Test-NeuroAPIText (Get-NeuroAPIProperty $Model $field) 65536)) { throw 'Invalid model text' } }
    foreach ($field in $booleans) { if ((Get-NeuroAPIProperty $Model $field) -isnot [bool]) { throw 'Invalid model flag' } }
    foreach ($field in $counts) { if (-not (Test-NeuroAPIInteger (Get-NeuroAPIProperty $Model $field) 0 1000000000)) { throw 'Invalid model count' } }
    if ($Model.context_window -le 0 -or $Model.max_context_window -lt $Model.context_window -or $Model.effective_context_window_percent -le 0 -or $Model.effective_context_window_percent -gt 100) { throw 'Invalid context window' }
    if (@('shell_command', 'default', 'local', 'unified_exec', 'disabled') -cnotcontains $Model.shell_type -or @('list', 'hide', 'hidden') -cnotcontains $Model.visibility) { throw 'Invalid model mode' }
    $levels = Get-NeuroAPIProperty $Model 'supported_reasoning_levels'
    if ($levels -isnot [array] -or $levels.Count -gt 16) { throw 'Invalid reasoning levels' }
    foreach ($level in $levels) {
        Assert-NeuroAPIKeys $level @('effort', 'description')
        if (@('none', 'minimal', 'low', 'medium', 'high', 'xhigh', 'max', 'ultra') -cnotcontains $level.effort -or -not (Test-NeuroAPIText $level.description 4096)) { throw 'Invalid reasoning level' }
    }
    Assert-NeuroAPIKeys $Model.model_messages @('instructions_template')
    if (-not (Test-NeuroAPIText $Model.model_messages.instructions_template 65536)) { throw 'Invalid model instructions' }
    Assert-NeuroAPIKeys $Model.truncation_policy @('mode', 'limit')
    if (@('bytes', 'tokens') -cnotcontains $Model.truncation_policy.mode -or -not (Test-NeuroAPIInteger $Model.truncation_policy.limit 1 1000000000)) { throw 'Invalid truncation policy' }
    $tools = Get-NeuroAPIProperty $Model 'experimental_supported_tools'
    if ($tools -isnot [array] -or $tools.Count -gt 64) { throw 'Invalid tools' }
    foreach ($tool in $tools) { if (-not (Test-NeuroAPIModelId $tool)) { throw 'Invalid tool' } }
    $modalities = Get-NeuroAPIProperty $Model 'input_modalities'
    if ($modalities -isnot [array] -or $modalities.Count -lt 1 -or $modalities.Count -gt 4) { throw 'Invalid modalities' }
    foreach ($modality in $modalities) { if (@('text', 'image', 'audio', 'video') -cnotcontains $modality) { throw 'Invalid modality' } }
}

function Get-NeuroAPIClaudeEnvironmentOverrides {
    # Exact provider/auth selectors only; unrelated feature/tool switches remain.
    return @('ANTHROPIC_API_KEY', 'ANTHROPIC_AUTH_TOKEN', 'ANTHROPIC_CUSTOM_HEADERS', 'CLAUDE_CODE_OAUTH_TOKEN',
        'CLAUDE_CODE_USE_ANTHROPIC_AWS', 'CLAUDE_CODE_USE_BEDROCK', 'CLAUDE_CODE_USE_VERTEX', 'CLAUDE_CODE_USE_FOUNDRY', 'CLAUDE_CODE_USE_MANTLE',
        'ANTHROPIC_AWS_BASE_URL', 'ANTHROPIC_MANTLE_BASE_URL', 'ANTHROPIC_DEFAULT_MODEL',
        'ANTHROPIC_SMALL_FAST_MODEL', 'CLAUDE_CODE_SUBAGENT_MODEL')
}

function ConvertFrom-NeuroAPICatalog {
    param([ValidateSet('codex', 'claude')][string]$Client, [string]$Json, [string]$HelperCommand)
    try {
        $data = $Json | ConvertFrom-Json -ErrorAction Stop
        if ($null -eq $data -or $data -is [array] -or $data -is [string]) { throw 'Invalid object' }
        if ($Client -eq 'codex') {
            Assert-NeuroAPIKeys $data @('models', 'default_model')
            $models = Get-NeuroAPIProperty $data 'models'
            $default = Get-NeuroAPIProperty $data 'default_model'
            if ($models -isnot [array] -or $models.Count -lt 1 -or $models.Count -gt 128 -or -not (Test-NeuroAPIModelId $default)) {
                throw 'Invalid catalog'
            }
            $ids = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
            foreach ($item in $models) {
                $slug = Get-NeuroAPIProperty $item 'slug'
                if (-not (Test-NeuroAPIModelId $slug) -or -not $ids.Add($slug)) { throw 'Invalid model' }
                Assert-NeuroAPICodexModel $item
            }
            if (-not $ids.Contains($default)) { throw 'Default model missing' }
            $defaultInfo = @($models | Where-Object { $_.slug -ceq $default })[0]
            if ($defaultInfo.visibility -cne 'list' -or -not $defaultInfo.supported_in_api) { throw 'Default model unavailable' }
            return [pscustomobject]@{ DefaultModel = $default; Content = @{ models = @($models) } }
        }
        Assert-NeuroAPIKeys $data @('model', 'availableModels', 'enforceAvailableModels', 'modelPicker', 'env', 'fallbackModel')
        $ids = Get-NeuroAPIProperty $data 'availableModels'
        $model = Get-NeuroAPIProperty $data 'model'
        $enforced = Get-NeuroAPIProperty $data 'enforceAvailableModels'
        $picker = Get-NeuroAPIProperty $data 'modelPicker'
        Assert-NeuroAPIKeys $picker @('options', 'replaceBuiltInOptions')
        $options = Get-NeuroAPIProperty $picker 'options'
        $replace = Get-NeuroAPIProperty $picker 'replaceBuiltInOptions'
        $fallback = Get-NeuroAPIProperty $data 'fallbackModel'
        if ($ids -isnot [array] -or $ids.Count -lt 1 -or $ids.Count -gt 256 -or
            $enforced -isnot [bool] -or -not $enforced -or $replace -isnot [bool] -or -not $replace -or
            $fallback -isnot [array] -or $fallback.Count -ne 0 -or $options -isnot [array] -or $options.Count -lt 1 -or $options.Count -gt 128) {
            throw 'Invalid Claude catalog'
        }
        $allowed = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        foreach ($id in $ids) {
            if (-not (Test-NeuroAPIModelId $id) -or -not $allowed.Add($id)) { throw 'Invalid model' }
        }
        if (-not (Test-NeuroAPIModelId $model) -or -not $allowed.Contains($model)) { throw 'Default model missing' }
        $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        $safeOptions = foreach ($option in $options) {
            Assert-NeuroAPIKeys $option @('model', 'label', 'description')
            $id = Get-NeuroAPIProperty $option 'model'
            if (-not (Test-NeuroAPIModelId $id) -or -not $allowed.Contains($id) -or -not $seen.Add($id)) { throw 'Invalid option' }
            $safe = [ordered]@{ model = $id }
            foreach ($field in @('label', 'description')) {
                $value = Get-NeuroAPIProperty $option $field
                if ($null -ne $value) {
                    $limit = if ($field -eq 'label') { 512 } else { 4096 }
                    if (-not (Test-NeuroAPIText $value $limit)) { throw 'Invalid option text' }
                    $safe[$field] = $value
                }
            }
            $safe
        }
        if (-not $seen.Contains($model)) { throw 'Default model hidden from picker' }
        $safeEnv = [ordered]@{
            ANTHROPIC_BASE_URL = 'https://claude.neuroapi.host'
            ANTHROPIC_MODEL = $model
            CLAUDE_CODE_MAX_OUTPUT_TOKENS = '4096'
        }
        foreach ($name in (Get-NeuroAPIClaudeEnvironmentOverrides)) { $safeEnv[$name] = '' }
        $environment = Get-NeuroAPIProperty $data 'env'
        Assert-NeuroAPIKeys $environment @('ANTHROPIC_DEFAULT_SONNET_MODEL', 'ANTHROPIC_DEFAULT_OPUS_MODEL', 'ANTHROPIC_DEFAULT_HAIKU_MODEL', 'ANTHROPIC_DEFAULT_FABLE_MODEL')
        foreach ($family in @('SONNET', 'OPUS', 'HAIKU', 'FABLE')) {
            $key = 'ANTHROPIC_DEFAULT_' + $family + '_MODEL'
            $value = Get-NeuroAPIProperty $environment $key
            if ($null -ne $value) {
                if (-not (Test-NeuroAPIModelId $value) -or -not $allowed.Contains($value)) { throw 'Invalid model family' }
                if ($family -eq 'HAIKU') {
                    # Claude Code uses this alias for background calls. The
                    # target must be a recommended Claude model, not a hidden
                    # compatibility-only entry from availableModels.
                    if (-not $seen.Contains($value) -or $value -notmatch '^claude-(haiku|sonnet|opus|fable)(?:[.\-]|$)') { throw 'Invalid background model' }
                } elseif ($value -notmatch ('^claude-' + $family.ToLowerInvariant() + '(?:[.\-]|$)')) {
                    throw 'Invalid model family'
                }
                $safeEnv[$key] = $value
            }
        }
        return [ordered]@{
            model = $model
            availableModels = @($ids)
            enforceAvailableModels = $true
            fallbackModel = @()
            modelPicker = @{ options = @($safeOptions); replaceBuiltInOptions = $true }
            env = $safeEnv
            apiKeyHelper = $HelperCommand
        }
    } catch {
        throw 'Каталог моделей NeuroAPI некорректен или пуст. Запуск отменен; сохраненный каталог не используется.'
    }
}

function Get-NeuroAPIClientCommand {
    param([string]$Client)
    $stateRoot = Split-Path -Parent $PSScriptRoot
    $nativeCodex = Join-Path $stateRoot 'native-codex/codex.exe'
    $candidate = if ($Client -eq 'codex') { $nativeCodex } else { Join-Path $env:USERPROFILE '.local/bin/claude.exe' }
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    $command = Get-Command $Client -CommandType Application, ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $command) { return $command.Source }
    throw 'Установите Codex CLI или Claude Code и откройте новый терминал.'
}

function Assert-NeuroAPIClientVersion {
    param([string]$Client, [string]$Command)
    $minimum = if ($Client -eq 'codex') { [version]'0.158.0' } else { [version]'2.1.284' }
    try {
        $global:LASTEXITCODE = 0
        $output = @(& $Command --version 2>&1) -join ' '
        if ($LASTEXITCODE -ne 0 -or $output -notmatch '(?<![0-9.])([0-9]+\.[0-9]+\.[0-9]+)(?=$|\s|\()' -or [version]$Matches[1] -lt $minimum) {
            throw 'Unsupported version'
        }
    } catch {
        throw "Обновите $Client до версии $minimum или новее. Запуск отменен."
    }
}

function Invoke-NeuroAPIChild {
    param([string]$Command, [string[]]$Arguments)
    $global:LASTEXITCODE = 0
    & $Command @Arguments
    $script:NeuroAPIChildExitCode = $LASTEXITCODE
}

function Invoke-NeuroAPIManagedClient {
    param([ValidateSet('codex', 'claude')][string]$Client, [string]$StateRoot, [string[]]$ClientArguments)
    $script:NeuroAPIChildExitCode = 1
    if (-not (Test-OwnerMarker (Get-StateMarkerPath $StateRoot))) { throw 'Установка NeuroAPI повреждена. Повторите установку.' }
    if ($Client -eq 'claude' -and ([string]$env:CLAUDE_CODE_PROVIDER_MANAGED_BY_HOST).Trim() -match '^(1|true|yes|on)$') {
        throw 'Провайдер Claude Code управляется организацией. Используйте настройки организации; запуск NeuroAPI отменен.'
    }
    $command = Get-NeuroAPIClientCommand $Client
    Assert-NeuroAPIClientVersion -Client $Client -Command $command
    $secretPath = Join-Path $StateRoot 'secret/api-key.dpapi'
    $helperPath = Join-Path $StateRoot 'bin/get-neuroapi-key.ps1'
    $helperCommand = 'powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $helperPath + '" -SecretPath "' + $secretPath + '"'
    $json = Get-NeuroAPICatalogJson -Client $Client -SecretPath $secretPath
    $catalog = ConvertFrom-NeuroAPICatalog -Client $Client -Json $json -HelperCommand $helperCommand
    $launchRoot = $null
    $savedEnvironment = @{}
    try {
        $launchRoot = New-NeuroAPILaunchDirectory $StateRoot
        if ($Client -eq 'codex') {
            $catalogPath = Join-Path $launchRoot 'models.json'
            Write-Utf8NoBom $catalogPath ($catalog.Content | ConvertTo-Json -Depth 100)
            # Codex's documented -c parser accepts a raw string when TOML parsing
            # fails. Absolute paths are raw values, avoiding PowerShell 5.1's
            # native embedded-double-quote stripping. IDs use TOML literals.
            $launchArguments = @('--profile', 'neuroapi-host', '-c', ('model_catalog_json=' + $catalogPath), '-c', ("model='" + $catalog.DefaultModel + "'")) + @($ClientArguments)
        } else {
            # Environment inherited from a different provider must not override
            # this launch's verified model list. Restore our own process later.
            $names = @('ANTHROPIC_MODEL') + @(Get-NeuroAPIClaudeEnvironmentOverrides)
            $names += @([Environment]::GetEnvironmentVariables('Process').Keys | Where-Object { $_ -match '^ANTHROPIC_DEFAULT_.*_MODEL$|SUBAGENT.*MODEL' })
            foreach ($name in ($names | Select-Object -Unique)) {
                $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
                [Environment]::SetEnvironmentVariable($name, $null, 'Process')
            }
            foreach ($name in $catalog.env.Keys) {
                if (-not $savedEnvironment.ContainsKey($name)) { $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
                [Environment]::SetEnvironmentVariable($name, $catalog.env[$name], 'Process')
            }
            $settingsPath = Join-Path $launchRoot 'claude-settings.json'
            Write-Utf8NoBom $settingsPath ($catalog | ConvertTo-Json -Depth 20)
            $launchArguments = @('--settings', $settingsPath) + @($ClientArguments)
        }
        Invoke-NeuroAPIChild -Command $command -Arguments $launchArguments
    } finally {
        foreach ($name in $savedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process') }
        if ($null -ne $launchRoot -and (Test-Path -LiteralPath $launchRoot)) { Remove-Item -LiteralPath $launchRoot -Recurse -Force }
    }
}
