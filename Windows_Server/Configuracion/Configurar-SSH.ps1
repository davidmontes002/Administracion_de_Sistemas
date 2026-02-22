function Configurar-SSH {

    # Verificar que esté instalado
    $ssh = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'

    if ($ssh.State -ne "Installed") {
        Write-Host "ERROR: OpenSSH no está instalado." -ForegroundColor Red
        Write-Host "Ejecute primero la opción de instalación." -ForegroundColor Yellow
        return
    }

    # Verificar IP del servidor
    if (-not $Global:ServerIP -or $Global:ServerIP -eq "") {
        Write-Host "ERROR: No se ha configurado la IP del servidor." -ForegroundColor Red
        Write-Host "Ejecute primero la configuración de DHCP." -ForegroundColor Yellow
        return
    }

    $ipInterna = $Global:ServerIP
    $configPath = "C:\ProgramData\ssh\sshd_config"

    Write-Host "Configurando SSH para escuchar en $ipInterna" -ForegroundColor Cyan

    if (Test-Path $configPath) {

        (Get-Content $configPath | Where-Object {$_ -notmatch "^ListenAddress"}) |
            Set-Content $configPath

        Add-Content $configPath "`nListenAddress $ipInterna"
    }

    # Firewall
    if (-not (Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule `
        -Name "OpenSSH-Server-In-TCP" `
        -DisplayName "OpenSSH Server (TCP 22)" `
        -Enabled True `
        -Direction Inbound `
        -Protocol TCP `
        -Action Allow `
        -LocalPort 22
    }

    Set-Service sshd -StartupType Automatic
    Restart-Service sshd

    Write-Host "SSH configurado correctamente." -ForegroundColor Green
    Pause
}