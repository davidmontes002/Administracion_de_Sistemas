function Inicializar-Sitio-FTP {
    Write-Host "=== REPARANDO Y CONFIGURANDO SECCIONES FTP (WS2022) ===" -ForegroundColor Cyan
    Import-Module WebAdministration

    $siteName = "FTPServer_Admin"
    $basePath = "C:\inetpub\ftproot"

    # 1. Verificar si el sitio existe, si no, crear de forma simple
    if (-not (Test-Path "IIS:\Sites\$siteName")) {
        New-WebFtpSite -Name $siteName -PhysicalPath $basePath -Port 21 -IPAddress "*"
        Write-Host "[+] Sitio creado desde cero." -ForegroundColor Green
    } else {
        Write-Host "[!] El sitio ya existe, procediendo a configurar secciones..." -ForegroundColor Yellow
    }

    # 2. Asegurar que el servicio esté iniciado para que el archivo XML sea legible
    Start-Service ftpsvc -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    # 3. Configurar Aislamiento (Usando el modo de "Ruta Forzada")
    try {
        # Intentamos aplicar el aislamiento directamente al sitio
        Set-WebConfigurationProperty -Filter "/system.ftpServer/userIsolation" `
                                     -PSPath "IIS:\Sites\$siteName" -Name "mode" -Value "DirectoryRoot"
        
        # 4. Habilitar Autenticación
        Set-WebConfigurationProperty -Filter "/system.ftpServer/security/authentication/basicAuthentication" `
                                     -PSPath "IIS:\Sites\$siteName" -Name "enabled" -Value $true

        # 5. Regla de Autorización
        # Usamos un método alternativo de inserción para evitar el COMException
        $authPath = "system.ftpServer/security/authorization"
        Add-WebConfigurationProperty -Filter $authPath -PSPath "IIS:\Sites\$siteName" `
                                     -Name "." -Value @{accessType="Allow"; users="*"; permissions="Read, Write"}

        Write-Host "[+] TODO CORRECTO: Aislamiento y Autenticación configurados." -ForegroundColor Green
    }
    catch {
        Write-Host "[!] ERROR CRÍTICO: El motor de IIS no responde." -ForegroundColor Red
        Write-Host "Intentando reinicio forzado del servicio de configuración..."
        net stop apphostsvc /y
        net start apphostsvc
        Write-Host "Ejecuta la opción 13 una última vez."
    }

    Restart-Service ftpsvc
}