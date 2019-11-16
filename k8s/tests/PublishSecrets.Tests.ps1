
Describe 'Publish-Secrets - New' {
    Context 'No parameters and secrets file provided' {
        $tmpFolderPath = ".tmp/$([Guid]::NewGuid().ToString("N"))"
        $tmpFolder = New-Item $tmpFolderPath -ItemType Directory 
        It 'Should throw an exception' {
            { Publish-Secrets -basePath $tmpFolder.FullName } | 
            Should -Throw 
        }
    }
    
    Context 'Secrets file provided and no parameters provided' {
        $uniqeId = [Guid]::NewGuid().ToString("N")
        $tmpFolderPath = ".tmp/$($uniqeId)"
        $tmpFolder = New-Item $tmpFolderPath -ItemType Directory 
        $entryNames = @('secret1')
        $secretValues = @('xxx')
        $name = "test-$($uniqeId)"
        $namespace = $null
        $expected = @{
            name   = $name
            values = @{secret1 = 'xxx' }
        }
        Mock -ModuleName 'firefly-k8s' `
            -CommandName Read-Host `
            -ParameterFilter { $Prompt[0].Contains('enter the namespace') } `
            -MockWith { 
            ''
        }.GetNewClosure()

        Mock -ModuleName 'firefly-k8s' `
            -CommandName Read-Host `
            -ParameterFilter { $Prompt[0] -match "Please provide $($entryNames[0]) secret value" } `
            -MockWith { 
            $secretValues[0]
        }.GetNewClosure()

        Mock -ModuleName 'firefly-k8s' `
            -CommandName Read-Host `
            -ParameterFilter { $Prompt[0].Contains("Are you sure you want to update(or create) $name") } `
            -MockWith { 
            'y'
        }.GetNewClosure()

        
        Save-SecretsMetaDataFile -basePath $tmpFolder.FullName `
            -name $name -namespace $namespace -entryNames $entryNames
        
        It 'Should use namespace and secret value from console input' {
            Publish-Secrets -basePath $tmpFolder.FullName
            $publishedSecrets = Get-PublishedSecrets -name $expected.name -decode
            $publishedSecrets | Should -Not -Be $null
            $expected.values.GetEnumerator() | ForEach-Object {
                $key = $_.Key
                $expectedValue = $expected.values[$key]
                $publishedSecrets.ContainsKey($key) | Should -BeTrue -Because "Expected `"$key`" does not existing in published secrets"
                $publishedValue = $publishedSecrets[$key]
                ( $publishedValue -eq $expectedValue) | Should -BeTrue -Because "Actual secrets entry value $($publishedValue) is not the same as expected of `"$($expectedValue)`""
            }
        }
    }

    Context 'New entries added' {
        $uniqeId = [Guid]::NewGuid().ToString("N")
        $tmpFolderPath = ".tmp/$($uniqeId)"
        $tmpFolder = New-Item $tmpFolderPath -ItemType Directory 
        $entryNames = @('secret1')
        $secretValues = @('xxx')
        $name = "test-$($uniqeId)"
        $namespace = $null
        $newEntryNames = @('newSecret')
        $newSecretValues = @('newValue')
        $expected = @{
            name   = $name
            values = @{
                secret1   = 'xxx'
                newSecret = 'newValue'
            }
        }

        Mock -ModuleName 'firefly-k8s' `
            -CommandName Read-Host `
            -ParameterFilter { $Prompt[0].Contains('enter the namespace') } `
            -MockWith { 
            ''
        }.GetNewClosure()

        Mock -ModuleName 'firefly-k8s' `
            -CommandName Read-Host `
            -ParameterFilter { $Prompt[0] -match "Please provide $($entryNames[0]) secret value" } `
            -MockWith { 
            $secretValues[0]
        }.GetNewClosure()

        Mock -ModuleName 'firefly-k8s' `
            -CommandName Read-Host `
            -ParameterFilter { $Prompt[0] -match "Please provide $($newEntryNames[0]) secret value" } `
            -MockWith { 
            $newSecretValues[0]
        }.GetNewClosure()

        Mock -ModuleName 'firefly-k8s' `
            -CommandName Read-Host `
            -ParameterFilter { $Prompt[0].Contains("Are you sure you want to update(or create) $name") } `
            -MockWith { 
            'y'
        }.GetNewClosure()
        
        Save-SecretsMetaDataFile -basePath $tmpFolder.FullName `
            -name $name -namespace $namespace -entryNames $entryNames
        
        Publish-Secrets -basePath $tmpFolder.FullName

        $combinedNames = $entryNames + $newEntryNames
        Save-SecretsMetaDataFile -basePath $tmpFolder.FullName `
            -name $name -namespace $namespace -entryNames $combinedNames

        It 'Should reuse existing values and add new values' {
            Publish-Secrets -basePath $tmpFolder.FullName -updateOnly
            $publishedSecrets = Get-PublishedSecrets -name $expected.name -decode
            $publishedSecrets | Should -Not -Be $null
            $expected.values.GetEnumerator() | ForEach-Object {
                $key = $_.Key
                $expectedValue = $expected.values[$key]
                $publishedSecrets.ContainsKey($key) | Should -BeTrue -Because "Expected `"$key`" does not existing in published secrets"
                $publishedValue = $publishedSecrets[$key]
                ( $publishedValue -eq $expectedValue) | Should -BeTrue -Because "Actual secrets entry value $($publishedValue) is not the same as expected of `"$($expectedValue)`""
            }
        }
    }

    Context 'Secrets already exists' {
        $uniqeId = [Guid]::NewGuid().ToString("N")
        $tmpFolderPath = ".tmp/$($uniqeId)"
        $tmpFolder = New-Item $tmpFolderPath -ItemType Directory 
        $entryNames = @('secret1')
        $secretValues = @('xxx')
        $name = "test-$($uniqeId)"
        $namespace = $null
        $newEntryNames = @('secret1', 'newSecret')
        $newSecretValues = @('replacedValue', 'newValue')
        $expected = @{
            name   = $name
            values = @{
                secret1   = 'replacedValue'
                newSecret = 'newValue'
            }
        }

        Mock -ModuleName 'firefly-k8s' `
            -CommandName Read-Host `
            -ParameterFilter { $Prompt[0].Contains('enter the namespace') } `
            -MockWith { 
            ''
        }.GetNewClosure()

        Mock -ModuleName 'firefly-k8s' `
            -CommandName Read-Host `
            -ParameterFilter { $Prompt[0] -match "Please provide $($entryNames[0]) secret value" } `
            -MockWith { 
            $secretValues[0]
        }.GetNewClosure()

        Mock -ModuleName 'firefly-k8s' `
            -CommandName Read-Host `
            -ParameterFilter { $Prompt[0].Contains("Are you sure you want to update(or create) $name") } `
            -MockWith { 
            'y'
        }.GetNewClosure()

        Mock -ModuleName 'firefly-k8s' `
            -CommandName Read-Host `
            -ParameterFilter { $Prompt[0].Contains("Do you want to replace the entire secrets") } `
            -MockWith { 
            'y'
        }.GetNewClosure()
    
        
        Save-SecretsMetaDataFile -basePath $tmpFolder.FullName `
            -name $name -namespace $namespace -entryNames $entryNames
        
        Publish-Secrets -basePath $tmpFolder.FullName

        Save-SecretsMetaDataFile -basePath $tmpFolder.FullName `
            -name $name -namespace $namespace -entryNames $newEntryNames

        Mock -ModuleName 'firefly-k8s' `
            -CommandName Read-Host `
            -ParameterFilter { $Prompt[0] -match "Please provide $($newEntryNames[0]) secret value" } `
            -MockWith { 
            $newSecretValues[0]
        }.GetNewClosure()

        Mock -ModuleName 'firefly-k8s' `
            -CommandName Read-Host `
            -ParameterFilter { $Prompt[0] -match "Please provide $($newEntryNames[1]) secret value" } `
            -MockWith { 
            $newSecretValues[1]
        }.GetNewClosure()
        
        It 'Should clear all and use new values when no updateOnly flag is provided' {
            Publish-Secrets -basePath $tmpFolder.FullName
            $publishedSecrets = Get-PublishedSecrets -name $expected.name -decode
            $publishedSecrets | Should -Not -Be $null
            $expected.values.GetEnumerator() | ForEach-Object {
                $key = $_.Key
                $expectedValue = $expected.values[$key]
                $publishedSecrets.ContainsKey($key) | Should -BeTrue -Because "Expected `"$key`" does not existing in published secrets"
                $publishedValue = $publishedSecrets[$key]
                ( $publishedValue -eq $expectedValue) | Should -BeTrue -Because "Actual secrets entry value $($publishedValue) is not the same as expected of `"$($expectedValue)`""
            }
        }
    }
}