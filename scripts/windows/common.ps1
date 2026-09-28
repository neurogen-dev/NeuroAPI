Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:OwnerMarkerText = 'neuroapi-agents:v1'
$script:ProfileFileName = 'neuroapi-host.config.toml'
$script:ProfileMarkerFileName = '.neuroapi-host.config.toml.neuroapi-agents-owned'
$script:PathMarkerFileName = '.neuroapi-agents-path-added'

function Get-DefaultStateRoot {
    if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        throw 'LOCALAPPDATA is not available.'
    }
    return [System.IO.Path]::Combine($env:LOCALAPPDATA, 'NeuroAPIAgents')
}

function Resolve-CodexConfigRoot {
    param(
        [AllowNull()][string]$ConfiguredRoot,
        [AllowNull()][string]$UserRoot
    )
    if (-not [string]::IsNullOrWhiteSpace($ConfiguredRoot)) {
        return $ConfiguredRoot
    }
    if ([string]::IsNullOrWhiteSpace($UserRoot)) {
        throw 'USERPROFILE is not available.'
    }
    return [System.IO.Path]::Combine($UserRoot, '.codex')
}

function Get-DefaultCodexHome {
    return Resolve-CodexConfigRoot -ConfiguredRoot $env:CODEX_HOME -UserRoot $env:USERPROFILE
}

function Get-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path)
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content
    )
    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Get-StateMarkerPath {
    param([Parameter(Mandatory = $true)][string]$StateRoot)
    return [System.IO.Path]::Combine($StateRoot, '.neuroapi-agents-owned')
}

function Get-ProfileMarkerPath {
    param([Parameter(Mandatory = $true)][string]$CodexHome)
    return [System.IO.Path]::Combine($CodexHome, $script:ProfileMarkerFileName)
}

function Get-PathMarkerPath {
    param([Parameter(Mandatory = $true)][string]$StateRoot)
    return [System.IO.Path]::Combine($StateRoot, $script:PathMarkerFileName)
}

function Test-OwnerMarker {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }
    return ((Get-Content -LiteralPath $Path -Raw).Trim() -eq $script:OwnerMarkerText)
}

function Write-OwnerMarker {
    param([Parameter(Mandatory = $true)][string]$Path)
    Write-Utf8NoBom -Path $Path -Content $script:OwnerMarkerText
}

function Assert-StateRootIsOwnedOrEmpty {
    param([Parameter(Mandatory = $true)][string]$StateRoot)
    if (-not (Test-Path -LiteralPath $StateRoot -PathType Container)) {
        return
    }

    $marker = Get-StateMarkerPath -StateRoot $StateRoot
    if (Test-OwnerMarker -Path $marker) {
        return
    }

    $firstItem = Get-ChildItem -LiteralPath $StateRoot -Force | Select-Object -First 1
    if ($null -ne $firstItem) {
        throw "Refusing to modify unowned directory: $StateRoot"
    }
}

function ConvertTo-TomlBasicString {
    param([Parameter(Mandatory = $true)][string]$Value)
    $escaped = $Value.Replace('\', '\\').Replace('"', '\"')
    return '"' + $escaped + '"'
}

function Add-UserPathEntry {
    param([Parameter(Mandatory = $true)][string]$Entry)
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @()
    if (-not [string]::IsNullOrWhiteSpace($current)) {
        $parts = @($current -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    $alreadyPresent = $false
    foreach ($part in $parts) {
        if ([string]::Equals(
            (Get-FullPath -Path $part.TrimEnd('\')),
            (Get-FullPath -Path $Entry.TrimEnd('\')),
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            $alreadyPresent = $true
            break
        }
    }

    if (-not $alreadyPresent) {
        $parts += $Entry
        [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')
    }
    return (-not $alreadyPresent)
}

function Add-OwnedUserPathEntry {
    param([string]$Entry, [string]$StateRoot)
    $marker = Get-PathMarkerPath -StateRoot $StateRoot
    $owned = @()
    if (Test-Path -LiteralPath $marker -PathType Leaf) {
        $owned = @(Get-Content -LiteralPath $marker | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }
    $added = Add-UserPathEntry -Entry $Entry
    if ($added -and $owned -notcontains $Entry) {
        $owned += $Entry
        Write-Utf8NoBom -Path $marker -Content ($owned -join "`n")
    }
}

function Remove-OwnedUserPathEntries {
    param([string]$StateRoot)
    $marker = Get-PathMarkerPath -StateRoot $StateRoot
    if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) { return }
    foreach ($entry in @(Get-Content -LiteralPath $marker)) {
        if (-not [string]::IsNullOrWhiteSpace($entry)) { Remove-UserPathEntry -Entry $entry }
    }
}

function Remove-UserPathEntry {
    param([Parameter(Mandatory = $true)][string]$Entry)
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ([string]::IsNullOrWhiteSpace($current)) {
        return
    }

    $target = Get-FullPath -Path $Entry.TrimEnd('\')
    $kept = foreach ($part in ($current -split ';')) {
        if ([string]::IsNullOrWhiteSpace($part)) {
            continue
        }
        $candidate = Get-FullPath -Path $part.TrimEnd('\')
        if (-not [string]::Equals(
            $candidate,
            $target,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            $part
        }
    }
    [Environment]::SetEnvironmentVariable('Path', (@($kept) -join ';'), 'User')
}

function Get-NeuroAPIHTTPSContent {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string[]]$AllowedHosts,
        [Parameter(Mandatory = $true)][long]$MaxBytes,
        [string]$Bearer,
        [string]$OutputPath,
        [int]$TimeoutSeconds = 30
    )
    Add-Type -AssemblyName System.Net.Http
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $handler = New-Object Net.Http.HttpClientHandler
    $handler.AllowAutoRedirect = $false
    $handler.UseCookies = $false
    $http = New-Object Net.Http.HttpClient($handler)
    $http.Timeout = [TimeSpan]::FromSeconds($TimeoutSeconds)
    $deadline = New-Object Threading.CancellationTokenSource
    $deadline.CancelAfter([TimeSpan]::FromSeconds($TimeoutSeconds))
    $current = [Uri]$Url
    try {
        for ($redirect = 0; $redirect -le 5; $redirect++) {
            if ($current.Scheme -cne 'https' -or $current.Port -ne 443 -or
                $AllowedHosts -notcontains $current.Host -or $current.UserInfo.Length -gt 0) {
                throw 'Untrusted download destination'
            }
            $request = New-Object Net.Http.HttpRequestMessage([Net.Http.HttpMethod]::Get, $current)
            $response = $null
            try {
                $request.Headers.UserAgent.ParseAdd('NeuroAPI-Agents-Installer/1')
                if (-not [string]::IsNullOrEmpty($Bearer)) {
                    $request.Headers.Authorization = New-Object Net.Http.Headers.AuthenticationHeaderValue('Bearer', $Bearer)
                }
                $response = $http.SendAsync($request, [Net.Http.HttpCompletionOption]::ResponseHeadersRead, $deadline.Token).GetAwaiter().GetResult()
                $status = [int]$response.StatusCode
                if ($status -in @(301, 302, 303, 307, 308)) {
                    if ($null -eq $response.Headers.Location -or $redirect -eq 5) { throw 'Invalid redirect' }
                    $current = New-Object Uri($current, $response.Headers.Location)
                    continue
                }
                if ($status -ne 200) { return [pscustomobject]@{ Status = $status; Bytes = $null } }
                if ($null -ne $response.Content.Headers.ContentLength -and
                    $response.Content.Headers.ContentLength -gt $MaxBytes) { throw 'Download too large' }
                $inputStream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
                $outputStream = if ([string]::IsNullOrWhiteSpace($OutputPath)) {
                    New-Object IO.MemoryStream
                } else {
                    New-Object IO.FileStream($OutputPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
                }
                try {
                    $chunk = New-Object byte[] 65536
                    $total = [long]0
                    while (($count = $inputStream.ReadAsync($chunk, 0, $chunk.Length, $deadline.Token).GetAwaiter().GetResult()) -gt 0) {
                        $total += $count
                        if ($total -gt $MaxBytes) { throw 'Download too large' }
                        $outputStream.Write($chunk, 0, $count)
                    }
                    $bytes = if ($outputStream -is [IO.MemoryStream]) { $outputStream.ToArray() } else { $null }
                    return [pscustomobject]@{ Status = 200; Bytes = $bytes }
                } finally {
                    $outputStream.Dispose()
                    $inputStream.Dispose()
                }
            } finally {
                if ($null -ne $response) { $response.Dispose() }
                $request.Dispose()
            }
        }
    } finally {
        $deadline.Dispose()
        $http.Dispose()
        $handler.Dispose()
    }
}

function Assert-NeuroAPIKeyCatalogs {
    param([Parameter(Mandatory = $true)][Security.SecureString]$SecureKey)
    $pointer = [IntPtr]::Zero
    $credential = $null
    try {
        $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureKey)
        $credential = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        if ([string]::IsNullOrWhiteSpace($credential) -or $credential.IndexOfAny([char[]]"`r`n") -ge 0) {
            throw 'Неверный формат ключа NeuroAPI.'
        }
        foreach ($client in @('codex', 'claude')) {
            $endpoint = if ($client -eq 'codex') { 'https://neuroapi.host/v1/codex/models' } else { 'https://neuroapi.host/v1/claude-code/client-settings' }
            try {
                $result = Get-NeuroAPIHTTPSContent -Url $endpoint -AllowedHosts @('neuroapi.host') -MaxBytes (2 * 1024 * 1024) -Bearer $credential -TimeoutSeconds 20
            } catch {
                throw 'Не удалось проверить ключ: каталог NeuroAPI временно недоступен. Попробуйте позже.'
            }
            if ($result.Status -in @(401, 403)) { throw 'Ключ NeuroAPI отклонен. Проверьте ключ и его доступ к моделям.' }
            if ($result.Status -ne 200) { throw 'Не удалось проверить ключ: каталог NeuroAPI временно недоступен. Попробуйте позже.' }
            try {
                $raw = (New-Object Text.UTF8Encoding($false, $true)).GetString($result.Bytes)
                if ($raw.IndexOf($credential, [StringComparison]::Ordinal) -ge 0) { throw 'Credential reflected' }
                $json = $raw | ConvertFrom-Json -ErrorAction Stop
                Assert-NeuroAPINoCredential -Value $json -Credential $credential -Depth 0
                ConvertFrom-NeuroAPICatalog -Client $client -Json $raw -HelperCommand 'local-credential-helper' | Out-Null
            } catch {
                throw 'Не удалось проверить ключ: каталог NeuroAPI вернул некорректный ответ.'
            }
        }
    } finally {
        if ($pointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
        $credential = $null
    }
}

function Get-NeuroAPIClientExecutable {
    param([ValidateSet('codex', 'claude')][string]$Client, [string]$StateRoot)
    $nativeCodex = Join-Path $StateRoot 'native-codex/codex.exe'
    $candidate = if ($Client -eq 'codex') { $nativeCodex } else { Join-Path $env:USERPROFILE '.local/bin/claude.exe' }
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    $command = Get-Command $Client -CommandType Application, ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $command) { return $command.Source }
    return $null
}

function Assert-NeuroAPIClientReady {
    param([ValidateSet('codex', 'claude')][string]$Client, [string]$Command)
    $minimum = if ($Client -eq 'codex') { [version]'0.158.0' } else { [version]'2.1.284' }
    if ([string]::IsNullOrWhiteSpace($Command)) { throw "Не найден $Client. Повторите установку NeuroAPI." }
    try {
        $global:LASTEXITCODE = 0
        $output = @(& $Command --version 2>&1) -join ' '
        if ($LASTEXITCODE -ne 0 -or $output -notmatch '(?<![0-9.])([0-9]+\.[0-9]+\.[0-9]+)(?=$|\s|\()' -or
            [version]$Matches[1] -lt $minimum) { throw 'Unsupported version' }
    } catch {
        throw "Установленный $Client не работает или старше версии $minimum. Обновите его через официальный установщик и повторите настройку NeuroAPI."
    }
}

function Install-NeuroAPICodex {
    param([string]$StateRoot)
    $assetName = if ([Environment]::Is64BitOperatingSystem -and $env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {
        'codex-aarch64-pc-windows-msvc.exe.zip'
    } else { 'codex-x86_64-pc-windows-msvc.exe.zip' }
    $release = Get-NeuroAPIHTTPSContent -Url 'https://api.github.com/repos/openai/codex/releases/latest' -AllowedHosts @('api.github.com') -MaxBytes (4 * 1024 * 1024)
    if ($release.Status -ne 200) { throw 'Не удалось получить официальный релиз Codex.' }
    $manifest = (New-Object Text.UTF8Encoding($false, $true)).GetString($release.Bytes) | ConvertFrom-Json -ErrorAction Stop
    $asset = @($manifest.assets | Where-Object { $_.name -ceq $assetName })
    if ($asset.Count -ne 1 -or $asset[0].digest -cnotmatch '^sha256:[a-f0-9]{64}$' -or
        $asset[0].size -gt (250 * 1024 * 1024)) { throw 'Официальный релиз Codex не содержит проверяемый пакет Windows.' }
    $uri = [Uri]$asset[0].browser_download_url
    if ($uri.Scheme -cne 'https' -or $uri.Host -cne 'github.com' -or
        $uri.AbsolutePath -cnotmatch '^/openai/codex/releases/download/[^/]+/codex-(x86_64|aarch64)-pc-windows-msvc\.exe\.zip$') {
        throw 'Недоверенный адрес пакета Codex.'
    }
    $stage = Join-Path $StateRoot ('codex-download-' + [Guid]::NewGuid().ToString('N') + '.zip')
    $extractRoot = Join-Path $StateRoot ('codex-stage-' + [Guid]::NewGuid().ToString('N'))
    $nativeRoot = Join-Path $StateRoot 'native-codex'
    $backupRoot = Join-Path $StateRoot ('codex-backup-' + [Guid]::NewGuid().ToString('N'))
    try {
        $download = Get-NeuroAPIHTTPSContent -Url $uri.AbsoluteUri -AllowedHosts @('github.com', 'release-assets.githubusercontent.com') -MaxBytes (250 * 1024 * 1024) -OutputPath $stage -TimeoutSeconds 300
        if ($download.Status -ne 200) { throw 'Не удалось загрузить официальный пакет Codex.' }
        $actual = (Get-FileHash -LiteralPath $stage -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -cne $asset[0].digest.Substring(7)) { throw 'Контрольная сумма пакета Codex не совпала.' }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        Ensure-Directory -Path $extractRoot
        $archive = [IO.Compression.ZipFile]::OpenRead($stage)
        try {
            if ($archive.Entries.Count -gt 128) { throw 'Пакет Codex содержит слишком много файлов.' }
            $total = [long]0
            foreach ($entry in $archive.Entries) {
                $name = $entry.FullName
                if ($name -cnotmatch '^[A-Za-z0-9._/-]+$' -or $name -match '(^|/)\.\.(/|$)' -or
                    $name.StartsWith('/') -or $name.Contains('//')) { throw 'Пакет Codex содержит небезопасный путь.' }
                if ($name.EndsWith('/')) { continue }
                if ($entry.Length -gt (400 * 1024 * 1024)) { throw 'Файл Codex слишком велик.' }
                $total += $entry.Length
                if ($total -gt (700 * 1024 * 1024)) { throw 'Пакет Codex слишком велик.' }
                $relative = if ($name -ceq $assetName.Replace('.zip', '')) { 'codex.exe' } else { $name.Replace('/', [IO.Path]::DirectorySeparatorChar) }
                $target = [IO.Path]::GetFullPath((Join-Path $extractRoot $relative))
                if (-not $target.StartsWith(($extractRoot + [IO.Path]::DirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase)) {
                    throw 'Пакет Codex содержит небезопасный путь.'
                }
                Ensure-Directory -Path (Split-Path -Parent $target)
                $inputStream = $entry.Open()
                $outputStream = New-Object IO.FileStream($target, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
                try {
                    $chunk = New-Object byte[] 65536
                    $written = [long]0
                    while (($count = $inputStream.Read($chunk, 0, $chunk.Length)) -gt 0) {
                        $written += $count
                        if ($written -gt (400 * 1024 * 1024) -or $total - $entry.Length + $written -gt (700 * 1024 * 1024)) {
                            throw 'Пакет Codex слишком велик.'
                        }
                        $outputStream.Write($chunk, 0, $count)
                    }
                    if ($written -ne $entry.Length) { throw 'Поврежденный пакет Codex.' }
                } finally { $outputStream.Dispose(); $inputStream.Dispose() }
            }
            if (-not (Test-Path -LiteralPath (Join-Path $extractRoot 'codex.exe') -PathType Leaf)) {
                throw 'Пакет Codex не содержит исполняемый файл.'
            }
        } finally { $archive.Dispose() }
        if (Test-Path -LiteralPath $nativeRoot) { Move-Item -LiteralPath $nativeRoot -Destination $backupRoot -ErrorAction Stop }
        try {
            Move-Item -LiteralPath $extractRoot -Destination $nativeRoot -ErrorAction Stop
            $wrapper = '@echo off' + "`r`n" + '"%~dp0..\native-codex\codex.exe" %*' + "`r`n" + 'exit /b %errorlevel%' + "`r`n"
            $wrapperPath = Join-Path $StateRoot 'bin/codex.cmd'
            if (-not (Test-Path -LiteralPath $wrapperPath -PathType Leaf)) {
                Write-Utf8NoBom -Path $wrapperPath -Content $wrapper
            } elseif ((Get-Content -LiteralPath $wrapperPath -Raw) -cne $wrapper) {
                throw 'Файл запуска Codex занят другой настройкой.'
            }
        } catch {
            if (Test-Path -LiteralPath $nativeRoot) { Remove-Item -LiteralPath $nativeRoot -Recurse -Force }
            if (Test-Path -LiteralPath $backupRoot) { Move-Item -LiteralPath $backupRoot -Destination $nativeRoot }
            throw
        }
        if (Test-Path -LiteralPath $backupRoot) { Remove-Item -LiteralPath $backupRoot -Recurse -Force }
    } finally {
        if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Force }
        if (Test-Path -LiteralPath $extractRoot) { Remove-Item -LiteralPath $extractRoot -Recurse -Force }
    }
}

function Install-NeuroAPIClaude {
    param([string]$StateRoot)
    $installer = Get-NeuroAPIHTTPSContent -Url 'https://claude.ai/install.ps1' -AllowedHosts @('claude.ai', 'downloads.claude.ai') -MaxBytes (1024 * 1024)
    if ($installer.Status -ne 200) { throw 'Не удалось получить официальный установщик Claude Code.' }
    $source = (New-Object Text.UTF8Encoding($false, $true)).GetString($installer.Bytes)
    $scriptPath = Join-Path $StateRoot ('claude-installer-' + [Guid]::NewGuid().ToString('N') + '.ps1')
    try {
        Write-Utf8NoBom -Path $scriptPath -Content $source
        & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $scriptPath
        if ($LASTEXITCODE -ne 0) { throw 'Официальный установщик Claude Code завершился с ошибкой. Проверьте сеть и повторите настройку NeuroAPI.' }
    } finally {
        if (Test-Path -LiteralPath $scriptPath) { Remove-Item -LiteralPath $scriptPath -Force }
    }
}

function Ensure-NeuroAPIClients {
    param([string]$StateRoot)
    $install = @()
    foreach ($client in @('codex', 'claude')) {
        $command = Get-NeuroAPIClientExecutable -Client $client -StateRoot $StateRoot
        if ([string]::IsNullOrWhiteSpace($command)) { $install += $client; continue }
        try { Assert-NeuroAPIClientReady -Client $client -Command $command }
        catch { $install += $client }
    }
    if ($install.Count -gt 0) {
        $answer = Read-Host ('Установить или обновить Codex CLI и Claude Code из официальных источников? (' + ($install -join ', ') + ') [Y/n]')
        if ($answer -match '^(n|no|н|нет)$') { throw 'Установите отсутствующие клиенты и повторите настройку NeuroAPI.' }
        if (-not [string]::IsNullOrWhiteSpace($answer) -and $answer -notmatch '^(y|yes|д|да)$') { throw 'Установка клиентов отменена.' }
        foreach ($client in $install) {
            try {
                if ($client -eq 'codex') { Install-NeuroAPICodex -StateRoot $StateRoot }
                else { Install-NeuroAPIClaude -StateRoot $StateRoot | Out-Host }
            } catch {
                throw "Не удалось установить $client из официального источника. Проверьте подключение и повторите настройку NeuroAPI."
            }
            $command = Get-NeuroAPIClientExecutable -Client $client -StateRoot $StateRoot
            Assert-NeuroAPIClientReady -Client $client -Command $command
        }
    }
    return $install
}
