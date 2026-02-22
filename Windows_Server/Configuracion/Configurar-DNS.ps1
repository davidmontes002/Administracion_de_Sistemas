function Configurar-DNS {

    if (-not $Global:ServerIP) {
        Write-Host "Debe configurar primero el DHCP."
        Pause
        return
    }

    $dominio = Read-Host "Ingrese nombre del dominio"

    Add-DnsServerPrimaryZone `
        -Name $dominio `
        -ZoneFile "$dominio.dns"

    Add-DnsServerResourceRecordA `
        -ZoneName $dominio `
        -Name "@" `
        -IPv4Address $Global:ServerIP

    Add-DnsServerResourceRecordCName `
        -ZoneName $dominio `
        -Name "www" `
        -HostNameAlias $dominio

    Write-Host "Dominio creado correctamente."
    Pause
}