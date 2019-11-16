#!/usr/bin/env pwsh
param(
    $basePath = $PSScriptRoot
)
$filesChanged = git --no-pager diff --name-only --cached

$pwshModulesChanged = $filesChanged | Where-Object { $_.Trim().EndsWith(".psm1") } | % {
    Join-Path $basePath $_
}

./Run-Tests.ps1 $pwshModulesChanged