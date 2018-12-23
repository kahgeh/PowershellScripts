
if ($null -eq $global:Language){
    $global:Language = @{
        name = 'C#'
        lookupPatternTemplate = 'class\W+[className]\W+{'
        lookupIdentifierPlaceHolder= '[className]'
        FileExtension = ".cs"
    }
}

function Get-StringLiteralToVariableLookup
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $className,
        [Parameter(Mandatory=$true)]
        [string]
        $sourceFileName,
        [string] 
        $variableAssignmentPattern='\W+(?<varname>[\w|_]+)\W*=\W*@{0,1}"(?<literal>[^"]+)"',             
        [string]
        $classPatternTemplate = 'class\W+[className]\W+{\W+(?<classContent>[^\}]+)}'
    )
    
    $classPattern = $classPatternTemplate.Replace('[className]', $className)

    $sourceText = [IO.File]::ReadAllText($sourceFileName)
    $classMatch=[regex]::Match($sourceText, $classPattern)
    $lookupRawText = $classMatch.Groups['classContent'].Value

    Write-Debug "Extracted class containing look up : "
    Write-Debug "********************************************************************************"
    Write-Debug $lookupRawText
    Write-Debug "********************************************************************************"

    $assignmentMatches=[regex]::Matches($lookupRawText, $variableAssignmentPattern)
    $lookUp = @{}
    $assignmentMatches.GetEnumerator()|ForEach-Object{
        $lookUp.Add($_.Groups['literal'], "$className.$($_.Groups['varname'])")|Out-Null
    }

    if ( $null -eq $lookUp -or $lookUp.Keys.Count -eq 0 ){
        Write-Information "No matching assignment found"
        return
    }

    Write-Debug "Literal lookup table : "
    Write-Debug ([string]::Join("`n", ($lookUp.GetEnumerator() | %{ "$($_.Key) = $($_.Value)" } ) ) )

    $lookUp
}

function Get-StringLiteralToVariableText
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Hashtable]
        $lookUp,
        [Parameter(ValueFromPipeline)]
        [string]
        $codeText,
        $stringLiteralPatternTemplate= '@{0,1}"[literal]"'   
    )

    $totalChanges=0
    $lookUp.GetEnumerator() | ForEach-Object{
        $entry=$_ 
        $stringLiteralPattern= $stringLiteralPatternTemplate.Replace('[literal]',$entry.Key)
        Write-Debug "String Literal Replacement Pattern $stringLiteralPattern"
        $possibleReplacementMatches=[regex]::Matches($codeText, $stringLiteralPattern)
        $cnt = $possibleReplacementMatches.Groups.Count
        if ( $cnt -gt 0 ){
            $codeText = [regex]::Replace($codeText, $stringLiteralPattern, $entry.Value)
            Write-Information "Replaced $($entry.Key) with $($entry.Value) $($cnt) times"
            $totalChanges = $totalChanges + $cnt
        }
        else {
            Write-Information "$($entry.Key) not found"
        }
    }

    Write-Information "$totalChanges change$(if($totalChanges -gt 1){'s'})"

    if ( $totalChanges -gt 0 ) {
        $codeText 
    }
    else{
        Write-Information "Nothing changed"
    }

}
<#
.Example

# separate calls
$lookUp = Get-StringLiteralToVariableLookup `
    -className "MyLookUpClassName" `
    -sourceFileName "/Dev/LookupCodes.cs"

$codeText=Get-Content '/Dev/CodeUsage.cs'
Get-StringLiteralToVariableText -lookUp $lookUp -codeText ([string]$codeText)

# one shot
Convert-StringLiteralToVariable -lookUp @{ 
         Specification=@{ 
             className ="MyLookUpClassName" 
             sourceFileName="/Dev/LookupCodes.cs"
         } 
     } -codeFileFullName '/Dev/CodeUsage.cs'
#>
function Convert-StringLiteralToVariable
{
    [CmdletBinding()]
    param(
        $className, 
        [Hashtable]
        $lookUp,
        [Parameter(ValueFromPipeline)]
        [string]
        $codeText,
        [string]
        $codeFileFullName,
        [hashtable]
        $replacementSpecification = @{},
        [switch] $save
    )

    if ($null -ne $className -and ($null -eq $lookUp -or $null -eq $lookUp.Specification)){
        $pattern=$Language.lookupPatternTemplate.Replace(
            $Language.lookupIdentifierPlaceHolder,
            $className)
        $searchResult=@(Search-FilesForText ./ $pattern -fileSpecification @{Include="*$($Language.FileExtension)"} -asObject)
        
        $fileMatched=$searchResult[0].File.FullName

        if ( $searchResult.Count -gt 1 ){
            $selectedFileIndex= (Read-Host "More than one file found, pick 1..$($searchResult.Count)") -1
            $fileMatched = $searchResult[$selectedFileIndex].File.FullName
        }
        
        $lookUp=@{
                    Specification=@{
                        className=$className
                        sourceFileName=$fileMatched
                    }  
                }  
    }

    if ($null -ne $lookUp.Specification){
        $lookUpParams = $lookUp.Specification
        $lookUp = Get-StringLiteralToVariableLookup @lookUpParams
    }

    if ( $null -ne $codeFileFullName){
        $codeText=[IO.File]::ReadAllText($codeFileFullName)
    }
    Write-Debug "Code before processed:"
    Write-Debug "********************************************************************************"
    Write-Debug $codeText
    Write-Debug "********************************************************************************"

    $processedCode = Get-StringLiteralToVariableText $lookUp $codeText @replacementSpecification

    if (-not([string]::IsNullOrEmpty($processedCode))){
        Write-Debug "Code after processed:"
        Write-Debug "********************************************************************************"
        Write-Debug $processedCode
        Write-Debug "********************************************************************************"
    }


    if($save -and -not([string]::IsNullOrEmpty($codeFileFullName)) -and -not([string]::IsNullOrEmpty($processedCode))){
        [IO.File]::WriteAllText($codeFileFullName, $processedCode)
        return
    }

    $processedCode
}

Set-Alias -Name rsl -Value Convert-StringLiteralToVariable

Export-ModuleMember -Function * -Alias *