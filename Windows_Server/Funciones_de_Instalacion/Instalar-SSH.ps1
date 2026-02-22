function Instalar-SSH {

    Write-Host "Verificando OpenSSH Server..." -ForegroundColor Cyan

    $ssh = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'

    if ($ssh.State -ne "Installed") {
        Write-Host "Instalando OpenSSH Server..." -ForegroundColor Green
        Add-WindowsCapability -Online -Name $ssh.Name -ErrorAction Stop
    }
    else {
        Write-Host "OpenSSH ya está instalado." -ForegroundColor Yellow
    }

    # Validar que DHCP ya haya configurado la IP
    if (-not $Global:ServerIP -or $Global:ServerIP -eq "") {
        Write-Host "ERROR: No se ha configurado la IP del servidor." -ForegroundColor Red
        Write-Host "Ejecute primero la configuración de DHCP." -ForegroundColor Yellow
        return
    }

    $ipInterna = $Global:ServerIP
    Write-Host "Configurando SSH para escuchar en $ipInterna" -ForegroundColor Cyan

    $configPath = "C:\ProgramData\ssh\sshd_config"

    if (Test-Path $configPath) {

        # Eliminar líneas anteriores ListenAddress
        (Get-Content $configPath | Where-Object {$_ -notmatch "^ListenAddress"}) |
            Set-Content $configPath

        Add-Content $configPath "`nListenAddress $ipInterna"

        Write-Host "ListenAddress configurado correctamente." -ForegroundColor Green
    }

    # Configurar servicio
    Set-Service sshd -StartupType Automatic
    Restart-Service sshd

    Write-Host "Servicio SSH activo y limitado a la red interna." -ForegroundColor Green
    Pause
}