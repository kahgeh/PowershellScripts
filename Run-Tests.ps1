#!/usr/bin/env pwsh
param(
    [System.Collections.ArrayList]
    $modulesPath,
    $testsFolderName = 'tests'
)
Set-StrictMode -Version 3
$ErrorActionPreference = "Stop"
if ($null -eq $modulesPath) {
    return
}
Import-Module Pester -Force

function Use-DockerDesktopK8s {
    $context = kubectl config current-context
    if ($context -ne 'docker-desktop') {
        Write-Host 'WARNING: Switching to docker-desktop automatically to run tests'
        kubectl config use-context docker-desktop
    }
}

function Remove-TestFiles {
    Remove-Item -Recurse -Force '.tmp'
}

function Remove-PublishedTestSecrets {
    $testSecretNamePattern = 'test-*'
    $testSecretNames = ((kubectl get secrets -o json) | ConvertFrom-Json).items | 
    ForEach-Object { $_.metadata.name } |
    Where-Object { $_ -like $testSecretNamePattern } 
    $testSecretNames | ForEach-Object {
        kubectl delete secrets $_ 
    }
}

function Cleanup() {
    Remove-TestFiles
    Remove-PublishedTestSecrets
}

Use-DockerDesktopK8s

$modules = $modulesPath | ForEach-Object {
    $path = $_
    $module = Get-Item $path
    @{
        Path      = $path
        TestsPath = Join-Path $module.Directory.FullName $testsFolderName
        Name      = $module.Name.Replace($module.Extension, '')
        FileName  = $module.Name

    }
}

$modules | % {
    $module = $_
    Import-Module $module.Path -Force
    Invoke-Pester -Path  $module.TestsPath
}

Cleanup