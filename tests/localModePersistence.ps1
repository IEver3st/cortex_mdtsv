$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$localModePath = Join-Path $root 'server/localMode.lua'
$source = Get-Content -LiteralPath $localModePath -Raw

$checks = @(
    @{ Name = 'global storage keys exist'; Pattern = "GLOBAL_SETTINGS_KEY\s*=\s*'cortex_mdt:settings'" },
    @{ Name = 'announcements storage key exists'; Pattern = "ANNOUNCEMENTS_STORAGE_KEY\s*=\s*'cortex_mdt:announcements'" },
    @{ Name = 'settings loaded from local storage'; Pattern = 'state\.settings\s*=\s*getStoredGlobalSettings\(\)' },
    @{ Name = 'settings saved to local storage'; Pattern = 'LocalStorage\.set\(GLOBAL_SETTINGS_KEY,\s*state\.settings\)' },
    @{ Name = 'announcements loaded from local storage'; Pattern = 'state\.announcements\s*=\s*getStoredAnnouncements\(\)' },
    @{ Name = 'announcements saved to local storage'; Pattern = 'LocalStorage\.set\(ANNOUNCEMENTS_STORAGE_KEY,\s*state\.announcements\)' }
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

Write-Output 'localMode persistence checks passed'
