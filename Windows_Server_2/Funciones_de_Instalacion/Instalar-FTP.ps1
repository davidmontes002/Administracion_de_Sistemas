function Instalar-FTP {
    Write-Host "=================================" -ForegroundColor Cyan
    Write-Host "     INSTALACION SERVIDOR FTP" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Cyan

    # Verificar si el rol de Servidor FTP ya está instalado
    $feature = Get-WindowsFeature -Name Web-Ftp-Server
    if ($feature.Installed) {
        Write-Host "[+] El rol de Servidor FTP ya está instalado." -ForegroundColor Yellow
        
        $servicio = Get-Service -Name ftpsvc -ErrorAction SilentlyContinue
        if ($servicio -and $servicio.Status -ne "Running") {
            Write-Host "[!] El servicio FTP está detenido. Iniciándolo..." -ForegroundColor Yellow
            Start-Service ftpsvc
        }
        return
    }

    Write-Host "Instalando Servicio FTP y herramientas de administración para WS2022..." -ForegroundColor Green
    try {
        # Instalación de características específicas para Windows Server 2022
        # Web-Mgmt-Console: Consola de IIS
        # Web-Scripting-Tools: Habilita el módulo WebAdministration (necesario para los cmdlets)
        Install-WindowsFeature -Name Web-Ftp-Server, Web-Mgmt-Console, Web-Scripting-Tools -IncludeManagementTools -ErrorAction Stop

        # Crear estructura de carpetas base para replicar la lógica de Linux
        $basePath = "C:\inetpub\ftproot"
        $paths = @(
            "$basePath\Public",
            "$basePath\grupos",
            "$basePath\usuarios"
        )

        foreach ($p in $paths) {
            if (-not (Test-Path $p)) {
                New-Item -Path $p -ItemType Directory | Out-Null
                Write-Host "[+] Carpeta creada: $p" -ForegroundColor Gray
            }
        }

        # Configurar servicio en automático e iniciar
        Set-Service ftpsvc -StartupType Automatic
        Start-Service ftpsvc

        Write-Host "=================================" -ForegroundColor Green
        Write-Host "FTP instalado. REINICIA LA CONSOLA PARA CARGAR LOS COMANDOS." -ForegroundColor Green
        Write-Host "=================================" -ForegroundColor Green
    }
    catch {
        Write-Host "Error durante la instalación: $($_.Exception.Message)" -ForegroundColor Red
    }

    Pause
}