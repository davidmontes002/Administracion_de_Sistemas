function Eliminar-Dominio {

    Get-DnsServerZone

    $dominio = Read-Host "Dominio a eliminar"

    Remove-DnsServerZone -Name $dominio -Force

    Write-Host "Dominio eliminado."
    Pause
}