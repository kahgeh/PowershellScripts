Describe 'Save-SecretsMetaDataFile' {
    Context 'Given no parameters provided' {
        $tmpFolderPath = ".tmp/$([Guid]::NewGuid().ToString("N"))"
        $tmpFolder = New-Item $tmpFolderPath -ItemType Directory 
        
        $entryNames = 'secret1'
        $name = 'secrets x'
        $namespace = 'namespace x'
        $defaultSecretsMetaDataFileName = 'secrets.json'

        $expected = @{
            entryNames= @('secret1')
            name = 'secrets x'
            namespace = 'namespace x'
        }
        Mock -ModuleName 'firefly-k8s' `
        -CommandName Read-Host `
        -ParameterFilter { $Prompt[0].Contains('secrets') } `
        -MockWith { 
            $name 
        }.GetNewClosure()

        Mock -ModuleName 'firefly-k8s' `
        -CommandName Read-Host `
        -ParameterFilter { $Prompt[0].Contains('namespace') } `
        -MockWith { 
            $namespace
        }.GetNewClosure()

        Mock -ModuleName 'firefly-k8s' `
        -CommandName Read-Host `
        -ParameterFilter { $Prompt[0].Contains('entry') } `
        -MockWith { 
            $entryNames 
        }.GetNewClosure()

        Save-SecretsMetaDataFile -basePath $tmpFolder.FullName

        It 'Should use values read in from user' {         
            $secretsMetaDataFilePath = Join-Path $tmpFolder.FullName $defaultSecretsMetaDataFileName
            (Get-Item $secretsMetaDataFilePath)| Should -Exist

            $metaData=Get-Content $secretsMetaDataFilePath | ConvertFrom-Json
            $metaData.entryNames | Should -Be $expected.entryNames
            $metaData.name | Should -Be $expected.name
            $metaData.namespace | Should -Be $expected.namespace
        }
    }    
}