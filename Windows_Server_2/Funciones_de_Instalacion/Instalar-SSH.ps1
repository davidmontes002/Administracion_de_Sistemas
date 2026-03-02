function Instalar-SSH {

    Write-Host "Verificando OpenSSH Server..." -ForegroundColor Cyan

    $ssh = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'

    if ($ssh.State -eq "Installed") {
        Write-Host "OpenSSH ya está instalado." -ForegroundColor Yellow
        return
    }

    Write-Host "Instalando OpenSSH Server..." -ForegroundColor Green
    Add-WindowsCapability -Online -Name $ssh.Name -ErrorAction Stop

    Write-Host "Instalación completada." -ForegroundColor Green
    Pause
}