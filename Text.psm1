function Get-PropertyNamesFromFirstLine
{
    param(
	[parameter(ValueFromPipeline=$True)]
    [string[]] $strings)
    
    begin
    {
        $lineNumber=1
    }
		
	process{
        if($lineNumber -eq 1)
        {
		  $strings | select -first 1 {("'" + [string]::join("','",($_ -split ' '|where{$_.Length -gt 0})) + "'")}
        }
        $lineNumber++
	}
}

function Convert-FromFixedWidthString
{
    
    param([array]$PropertyNames,
    [parameter(ValueFromPipeline=$True)]
    [string[]] $strings)

    begin
    {
        $Properties = New-Object System.Collections.ArrayList
        $lineNumber=1
    }

    process
    {
        ForEach ($string in $strings) 
        {
            if($lineNumber -eq 1)
            {
                $PropertyNames | %{
                    $propertyName = $_
                    $indexOfText=$string.IndexOf($propertyName)
                    $properties.Add((New-Object -TypeName PsObject -Property @{Name=$propertyName;Width=-1;IndexOfText=$indexOfText}))|Out-Null
                }

                for($i=0; $i -lt $properties.Count;$i++)
                {
                    if($i+1 -lt $properties.Count)
                    {
                        $properties[$i].Width=$properties[$i+1].IndexOfText - $properties[$i].IndexOfText
                    }
                } 
            }
            else
            {
                $result=New-Object -Type PSObject
                ForEach ( $property in $properties )
                {
                    if($property.Width -ne -1 )
                    {
                        $result =$result | Add-Member -PassThru -MemberType NoteProperty -Name $property.Name  -Value $string.SubString($property.IndexOfText,$property.Width)
                    }
                    else
                    {
                        $result =$result | Add-Member -PassThru -MemberType NoteProperty -Name $property.Name -Value $string.SubString($property.IndexOfText,$string.Length-$property.IndexOfText)
                    }
                }
                Write-Output $result 
            }
            $lineNumber++
        }
    }

    end
    {
        Write-Host "Total lines = $($lineNumber)"
    }
}
function Convert-ToBase64($string) {
   $bytes  = [System.Text.Encoding]::UTF8.GetBytes($string);
   $encoded = [System.Convert]::ToBase64String($bytes); 

   return $encoded;
}

function Convert-FromBase64($string) {
   $bytes  = [System.Convert]::FromBase64String($string);
   $decoded = [System.Text.Encoding]::UTF8.GetString($bytes); 

   return $decoded;
}

function Convert-FromBase64ToHexString
{
    param($base64)

    "0x" +[System.BitConverter]::ToString( [System.Convert]::FromBase64String($base64)).Replace("-","")
}

function Convert-FromHexToBase64
{
    param($hexString)
    
    $byteArray=$hexString -replace '^0x', '' -split "(?<=\G\w{2})(?=\w{2})" | %{ [Convert]::ToByte( $_, 16 ) }
    [System.Convert]::ToBase64String($byteArray)
}

Export-ModuleMember -Function *