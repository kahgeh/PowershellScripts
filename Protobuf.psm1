function ConvertTo-Proto {
    param($obj, $messageName, $header)
    $header
    "`n`nmessage $messageName {"
    $i = 0
    $obj.PsObject.Properties | 
    Where-Object { $_.MemberType -eq 'NoteProperty' } | 
    ForEach-Object {
        $i++
        $member = $_
        $name = $_ | Select-Object -Expand name 

        if ( $member.TypeNameOfValue -eq 'System.String' ) {
            "    string $name = $i ;";
        }
        else {
            $capName = "$(([string]$name.ToCharArray()[0]).ToUpper())$($name.Substring(1,$name.Length-1))"
            if ($member.TypeNameOfValue -eq 'System.Object[]' ) {
                "    repeated $($capName) $name = $i ;"
            }
            else {
                "    $($capName) $name = $i ;"                
            }
        }
    }
    "}" 
}

Export-ModuleMember -Function *