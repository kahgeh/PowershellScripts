param(
    $moduleName,
    $targetFolderPath
)

Get-Command -Module $moduleName | ForEach-Object {
    $command = $_
    $scriptFileName = Join-Path $targetFolderPath "$($command.Name).ps1"
        
    [IO.File]::WriteAllLines($scriptFileName,
        @("#! /usr/bin/env pwsh`n") + $command.ScriptBlock )

    chmod u+x $scriptFileName    
}