# No parameter binder: retain arbitrary client flags as data, including --model.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"
. "$PSScriptRoot\managed-catalog.ps1"
try {
    if ($args.Count -lt 1 -or $args[0] -cnotin @('codex', 'claude')) { throw 'Неизвестный клиент NeuroAPI.' }
    $clientName = [string]$args[0]
    $forwarded = @()
    if ($args.Count -gt 1) { $forwarded = @($args[1..($args.Count - 1)]) }
    Invoke-NeuroAPIManagedClient -Client $clientName -StateRoot (Split-Path -Parent $PSScriptRoot) -ClientArguments $forwarded
    exit $script:NeuroAPIChildExitCode
} catch {
    $message = 'Запуск NeuroAPI отменен. Проверьте подключение, ключ и актуальность клиента. Повторите установку при повреждении файлов.'
    if ($_.Exception.Message -ceq 'Провайдер Claude Code управляется организацией. Используйте настройки организации; запуск NeuroAPI отменен.') {
        $message = $_.Exception.Message
    }
    if ($_.Exception.Message -cin @('Идентификатор модели не подтверждён (model_identity_unverified). Возможно сопоставление имени; проверьте настройки модели.', 'Используйте --doctor или --doctor-generate без дополнительных параметров.', 'Генерация не подтверждена. Проверьте баланс и доступность модели; повтор автоматически не выполняется.')) {
        $message = $_.Exception.Message
    }
    if ($_.Exception.Message -match '^Обновите (codex|claude) до версии [0-9.]+ или новее\. Запуск отменен\.$') {
        $message = $_.Exception.Message
    }
    [Console]::Error.WriteLine($message)
    exit 1
}
