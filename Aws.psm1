
function Use-Profile
{
    param(
        [Parameter(Mandatory=$true)]
        $profileName,
        [Parameter(Mandatory=$true)]
        $region
    )
    Set-AWSCredential -StoredCredentials $profileName
    Set-DefaultAWSRegion $region
}

Export-ModuleMember -Function *
