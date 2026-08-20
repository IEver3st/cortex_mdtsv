$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$localModePath = Join-Path $root 'server/localMode.lua'
$source = Get-Content -LiteralPath $localModePath -Raw
$sessionStorePath = Join-Path $root 'server/storage/sessionStore.lua'
$sessionStoreSource = Get-Content -LiteralPath $sessionStorePath -Raw

$checks = @(
    @{ Name = 'global storage keys exist'; Pattern = "GLOBAL_SETTINGS_KEY\s*=\s*'cortex_mdt:settings'" },
    @{ Name = 'announcements storage key exists'; Pattern = "ANNOUNCEMENTS_STORAGE_KEY\s*=\s*'cortex_mdt:announcements'" },
    @{ Name = 'settings loaded from local storage'; Pattern = 'state\.settings\s*=\s*getStoredGlobalSettings\(\)' },
    @{ Name = 'settings saved to local storage'; Pattern = 'LocalStorage\.set\(GLOBAL_SETTINGS_KEY,\s*state\.settings\)' },
    @{ Name = 'announcements loaded from local storage'; Pattern = 'state\.announcements\s*=\s*getStoredAnnouncements\(\)' },
    @{ Name = 'announcements saved to local storage'; Pattern = 'LocalStorage\.set\(ANNOUNCEMENTS_STORAGE_KEY,\s*state\.announcements\)' }
    @{ Name = 'standalone record snapshot exists'; Pattern = "SNAPSHOT_STORAGE_KEY\s*=\s*'cortex_mdt:standalone_records:v2'" }
    @{ Name = 'standalone record snapshot is restored'; Pattern = 'restoreDurableSnapshot\(\)' }
    @{ Name = 'standalone record snapshot flushes on stop'; Pattern = 'flushDurableSnapshot\(\)' }
)

$failed = @()
foreach ($check in $checks) {
    if ($source -notmatch $check.Pattern) {
        $failed += $check.Name
    }
}

if ($failed.Count -gt 0) {
    throw "Missing local-mode persistence: $($failed -join ', ')"
}

$sessionChecks = @(
    @{ Name = 'persistent namespace key exists'; Pattern = "STORAGE_KEY\s*=\s*'cortex_mdt:persistent_namespaces:v2'" },
    @{ Name = 'persistent namespaces restore'; Pattern = 'LocalStorage\.get\(STORAGE_KEY\)' },
    @{ Name = 'persistent namespaces save'; Pattern = 'LocalStorage\.set\(STORAGE_KEY,\s*SessionStore\.state\)' },
    @{ Name = 'persistent namespaces flush on stop'; Pattern = "AddEventHandler\('onResourceStop'" }
)

foreach ($check in $sessionChecks) {
    if ($sessionStoreSource -notmatch $check.Pattern) {
        $failed += $check.Name
    }
}

if ($failed.Count -gt 0) {
    throw "Missing persistent namespace storage: $($failed -join ', ')"
}

Write-Output 'localMode persistence checks passed'
