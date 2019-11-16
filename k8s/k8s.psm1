function Save-SecretsMetaDataFile {
    param(
        $basePath = (Get-Location).Path,
        $fileName = 'secrets.json',
        $name ,
        $namespace ,
        $entryNames
    )

    $effectiveName = if ($null -eq $name) { 
        $value = (Read-Host "Please enter the secrets name :")
        if ([string]::IsNullOrEmpty($value)) {
            throw "ArgumentNullException:name cannot be empty"
        }
        $value
    }
    else {
        $name
    }
   
    $effectiveEntryNames = if ([string]::IsNullOrEmpty($entryNames)) {
        $value = (Read-Host "Please enter all the entry names(comma separated):")
        if ([string]::IsNullOrEmpty($value)) {
            throw "ArgumentNullException:entryNames cannot be empty"
        }
        $value
    }
    else {
        $entryNames.Clone()
    }

    $effectiveNamespace = if ($null -eq $namespace) {
        $value = (Read-Host "Please enter the namespace(leave it empty to use context namespace):")
        if ([string]::IsNullOrEmpty($value)) { $null }else { $value }
    }
    else {
        $namespace
    }

    $filePath = Join-Path $basePath $fileName
    $metaData = @{
        name       = $effectiveName
        namespace  = $effectiveNamespace 
        entryNames = @($effectiveEntryNames.Split(",")) | ForEach-Object { $_.Trim() }   
    }
    $jsonText = $metaData | ConvertTo-Json 
    [IO.File]::WriteAllText($filePath, $jsonText)
}

function Get-PublishedSecrets {
    param(
        $name,
        $secretsNamespace,
        [switch]
        $decode
    )

    function FromBase64 {
        param($string)
    
        $bytes = [System.Convert]::FromBase64String($string);
        $decoded = [System.Text.Encoding]::UTF8.GetString($bytes); 
    
        return $decoded;
    }

    $existingSecretsManifestResponse = if ($null -eq $secretsNamespace) { kubectl get secrets $name -o json 2>&1 }else { kubectl get secrets $name -o json -n $secretsNamespace 2>&1 }
    if ( ($existingSecretsManifestResponse -match "Forbidden") -or
        $existingSecretsManifestResponse -match "namespaces `"[\w|\d|-]+`" not found" ) {
        $namespaceName = if ( $null -eq $secretsNamespace ) { 'default' }else { $secretsNamespace }
        throw "CannotAccessNamespace: It's likely `"$namespaceName`" namespace does not exists or you have no access to it"
    }
    $existingSecretsManifest = $null
    try {
        $existingSecretsManifest = $existingSecretsManifestResponse | ConvertFrom-Json
    }
    catch {
        if ($existingSecretsManifestResponse -match "secrets `"[\w|\d|-]+`" not found") {
            @{ }
            return 
        }
        throw $existingSecretsManifestResponse
    }
    $existingSecrets = @{ }
    if ($null -ne $existingSecretsManifest) {
        $existingSecretsManifest.data.PsObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' } | ForEach-Object {
            $value = $_.Value
            if ($decode) {
                $value = FromBase64 $value
            }
            $existingSecrets.Add(($_.Name), $value) | Out-Null
        }  
    }
    $existingSecrets
}

function Publish-Secrets {
    param(
        $basePath = (Get-Location).Path,
        $secrets,
        $name,
        $namespace,
        [switch]
        $debug,
        [switch]
        $updateOnly,
        $secretsMetaDataFileName = 'secrets.json'
    )
    function Add-Array {
        param($array1, $array2, [switch]$unique)
        $array = New-Object System.Collections.ArrayList

        if ($null -ne $array1 ) {
            if ($array1 -is [System.Collections.ICollection]) {
                $array.AddRange($array1) | Out-Null
            }
            else {
                $array.Add($array1) | Out-Null                
            }
        }
        
        if ($null -ne $array2 ) {
            if ($array2 -is [System.Collections.ICollection]) {
                $array.AddRange($array2) | Out-Null
            }
            else {
                $array.Add($array2) | Out-Null                
            }
        }
        
        if ($unique) {
            $array | Select-Object -Unique
        }
        else {
            $array
        }
    }

    function ToBase64 {
        param($string)
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($string)
        $encoded = [System.Convert]::ToBase64String($bytes)
        $encoded
    }

    function Read-SecretValues {
        param($entryNames)
        $secretValues = @{ }
        if ($null -ne $entryNames) {
            $entryNames | ForEach-Object {
                $entryName = $_
                $secretValues[$entryName] = (Read-Host "Please provide $entryName secret value")
            }   
        }
        $secretValues
    }

    function Get-SecretValues {
        param(
            $secretMetaData,
            $userInputSecrets,
            $updateOnly)
        if ($null -eq $userInputSecrets) {
            $userInputSecrets = @{ }
        }

        $name = $secretMetaData.name
        $entryNames = $secretMetaData.entryNames 
        $secretsNamespace = $secretMetaData.namespace
        $existingSecrets = Get-PublishedSecrets $name $secretsNamespace
        $existingEntryNames = @($existingSecrets.GetEnumerator() | ForEach-Object { $_.Key })
        $secretValues = @{ }
        $userInputSecretEntryNames = @($userInputSecrets.GetEnumerator() | ForEach-Object { $_.Key })
        $summary = @{ }
        if ( -not ($updateOnly) -and $null -ne $existingSecrets -and $existingSecrets.Count -gt 0) {
            $replaceConfirmation = Read-Host "There are currently $($existingSecrets.Count) existing entries. Do you want to replace the entire secrets with what you will or have provided ($($entryNames.Count) new entries)?(y|n)"
            if ( 'y' -ne $replaceConfirmation) {
                return
            }
            $summary.new = $entryNames
            $summary.override = @()
            $summary.reuse = @()
            $summary.dropped = Compare-Object $existingEntryNames $entryNames | 
            Where-Object { $_.SideIndicator -eq '<=' } | 
            Select-Object -ExpandProperty InputObject    
            $comparisons = Compare-Object $entryNames $userInputSecretEntryNames -IncludeEqual
            $askForValues = $comparisons | Where-Object { $_.SideIndicator -eq '<=' } | Select-Object -ExpandProperty InputObject    
            $userSecretValues = $userInputSecrets + (Read-SecretValues $askForValues)
            $summary.new | ForEach-Object {
                $entryName = $_
                $secretValues[$entryName] = (ToBase64 $userSecretValues[$entryName])
            }
        }
        else {
            $comparisons = Compare-Object $existingEntryNames $entryNames  -IncludeEqual
            $summary.new = $comparisons | Where-Object { $_.SideIndicator -eq '=>' } | Select-Object -ExpandProperty InputObject
            $summary.reuse = $comparisons | 
            Where-Object { $_.SideIndicator -eq '==' -and -not ($userInputSecretEntryNames.Contains($_.InputObject)) } | 
            Select-Object -ExpandProperty InputObject
            $summary.override = $comparisons | Where-Object { $_.SideIndicator -eq '==' -and $userInputSecretEntryNames.Contains($_.InputObject) } | Select-Object -ExpandProperty InputObject
            $summary.dropped = $comparisons | Where-Object { $_.SideIndicator -eq '<=' } | Select-Object -ExpandProperty InputObject
            $newAndOverride = (Add-Array $summary.override $summary.new -unique)
            $comparisons = Compare-Object $newAndOverride $userInputSecretEntryNames -IncludeEqual
            $askForValues = $comparisons | 
            Where-Object { $_.SideIndicator -eq '<=' } | 
            Select-Object -ExpandProperty InputObject
            $secretValues = $existingSecrets.Clone()
            $userSecretValues = $userInputSecrets + (Read-SecretValues $askForValues)
            $newAndOverride | ForEach-Object {
                $entryName = $_
                $secretValues[$entryName] = (ToBase64 $userSecretValues[$entryName])
            }

            if ( $null -ne $summary.dropped ) {
                $summary.dropped | ForEach-Object {
                    $entryName = $_
                    $secretValues.Remove($entryName) | Out-Null
                }
            }
        }            
        if ( $null -ne $summary.new -and $summary.new.Count -gt 0) {
            Write-Information "New entry names - $([string]::Join(", ", $summary.new))"
        }
        if ( $null -ne $summary.dropped -and $summary.dropped.Count -gt 0 ) {
            Write-Information "Dropped entry names - $([string]::Join(", ", $summary.dropped))"
        }
        if ( $null -ne $summary.override -and $summary.override.Count -gt 0) {
            Write-Information "Overriden entry names - $([string]::Join(", ", $summary.override))"
        }
        if ( $null -ne $summary.reuse -and $summary.reuse.Count -gt 0 ) {
            Write-Information "Reuse entry names - $([string]::Join(", ", $summary.reuse))"
        }
        $secretValues
    }

    function Assert-SecretsMetaDataIsValid {
        param($secretMetaData, $secretsMetaDataFileName)
        $missingFields = New-Object System.Collections.ArrayList
        if ($null -eq $secretMetaData.entryNames) {
            $missingFields.Add('entryNames')
        }

        if ($null -eq $secretMetaData.name) {
            $missingFields.Add('name')
        }

        if ($missingFields.Count -gt 0 ) {
            throw  "SecretsMetaDataMissingFields: The following fields are missing - $([string]::join(",", $missingFields)). Ensure they are provided either in the secrets metadata file or as part of the parameters ( entryNames is sourced from the metadata file or the secrets parameter)"
        }
    }

    function Assert-SecretsMetaIsUpdated {
        param($userInputSecretEntryNames, $secretMetaDataEntryNames)

        if ($null -eq $userInputSecretEntryNames) {
            return
        }
        
        $comparisons = Compare-Object $secretMetaDataEntryNames $userInputSecretEntryNames
        $missingEntryNames = @($comparisons | Where-Object { $_.SideIndicator -eq '=>' }) | Select-Object -ExpandProperty InputObject
        if ( $missingEntryNames.Count -gt 0 ) {
            throw "SecretsMetaDataNotUpdated: Ensure these entries are included in secrets.psd1 - $([string]::Join(", ", $missingEntryNames))" 
        }
    }

    $secretsMetaDataFilePath = Join-Path $basePath $secretsMetaDataFileName 
    if ( $null -eq $secrets -and -not([IO.File]::Exists($secretsMetaDataFilePath)) ) {
        throw "MissingSecretsMetaData: Ensure $secretsMetaDataFilePath exist or provide the secrets and secretsName parameters"
    }
    
    $userInputEntryNames = if ($null -eq $secrets) { @() }else { @($secrets.GetEnumerator() | ForEach-Object { $_.Key }) }
    $secretMetaData = @{
        entryNames = $userInputEntryNames
        name       = $name
        namespace  = $namespace
    }

    if ([IO.File]::Exists($secretsMetaDataFilePath)) {
        $defaultSecretsMetaData = Get-Content $secretsMetaDataFilePath | ConvertFrom-Json
        # the name and entry names are primarily sourced from the secrets meta data file ( if it exists )
        $secretMetaData.entryNames = $defaultSecretsMetaData.entryNames
        Assert-SecretsMetaIsUpdated $userInputEntryNames $defaultSecretsMetaData.entryNames

        $secretMetaData.name = $defaultSecretsMetaData.name
        
        if ( $null -ne $defaultSecretsMetaData.namespace ) {
            $secretMetaData.namespace = $defaultSecretsMetaData.namespace
        }
    }

    Assert-SecretsMetaDataIsValid $secretMetaData
    $secretValues = Get-SecretValues $secretMetaData $secrets $updateOnly
    if ($null -eq $secretValues) {
        Write-Error 'Publish secrets aborted'
        return
    }

    $entryNames = $secretMetaData.entryNames
    $secretsName = $secretMetaData.name
    $secretsNamespace = $secretMetaData.namespace
    $indent = "`n  "
    $data = $entryNames | ForEach-Object {
        $key = $_
        "$($indent)$($key): $($secretValues[$key])"
    }

    $template = @"
apiVersion: v1
kind: Secret
metadata:
  name: @[secretsName]
type: Opaque
data:@[data]
"@

    $k8sManifestFilePath = "$($basePath)/secrets.yml"
    $manifestContent = $template.Replace('@[secretsName]', $secretsName).Replace('@[data]', $data)
    if ($debug) {
        Write-Host  $manifestContent
        return
    }
    try {
        $manifestContent | Out-File -Force $k8sManifestFilePath
        $currentContext = kubectl config current-context
        $confirmation = Read-Host "Are you sure you want to update(or create) $secretsName in $($currentContext)? (y|n)"
        if ( $confirmation -ne 'y' ) {
            return
        }
        if ([string]::IsNullOrEmpty($secretsNamespace) ) {
            kubectl apply -f  $k8sManifestFilePath
        }
        else {
            kubectl apply -f  $k8sManifestFilePath -n $secretsNamespace
        }
    }
    finally {
        Remove-Item -Force $k8sManifestFilePath
    }
}

Export-ModuleMember Save-SecretsMetaDataFile, Get-PublishedSecrets, Publish-Secrets