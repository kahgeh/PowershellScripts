function Get-LocalIps {
    [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | ForEach-Object { 
        $_.GetIPProperties() 
    }
}