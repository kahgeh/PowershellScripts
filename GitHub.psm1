function Set-BranchProtection {
    param(
        [Parameter(Mandatory)]
        $repo,        
        [Parameter(Mandatory)]
        $org,
        $baseUri = "api.github.com/api/v3"
    )

    $url = "https://$($baseUri)/repos/$($org)/branches/$($branch)/protection"
    Invoke-WebRequest -Method GET -Uri $url
}