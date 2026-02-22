function Estado-Servicios {

    Write-Host "===== DHCP ====="
    Get-WindowsFeature DHCP
    Get-Service DHCPServer
    Get-DhcpServerv4Scope

    Write-Host ""
    Write-Host "===== DNS ====="
    Get-WindowsFeature DNS
    Get-Service DNS
    Get-DnsServerZone

    Pause
}