function Configurar-DHCP {

    $adaptador = "Ethernet 2"

    do {
        $ServerIP = Read-Host "Ingrese IP del servidor"
    } while (-not (Validar-IP $ServerIP))

    $Global:ServerIP = $ServerIP

    Remove-NetIPAddress -InterfaceAlias $adaptador -Confirm:$false -ErrorAction SilentlyContinue

    New-NetIPAddress -InterfaceAlias $adaptador `
                     -IPAddress $ServerIP `
                     -PrefixLength 24

    Set-DnsClientServerAddress -InterfaceAlias $adaptador `
                                -ServerAddresses $ServerIP

    do {
        $inicio = Read-Host "IP inicio rango"
        $fin = Read-Host "IP fin rango"
    } while (-not (Validar-Rango $inicio $fin))

    Add-DhcpServerv4Scope `
        -Name "ScopePrincipal" `
        -StartRange $inicio `
        -EndRange $fin `
        -SubnetMask 255.255.255.0 `
        -State Active

    Set-DhcpServerv4OptionValue `
        -ScopeId $inicio `
        -DnsServer $ServerIP

    Write-Host "DHCP configurado correctamente."
    Pause
}