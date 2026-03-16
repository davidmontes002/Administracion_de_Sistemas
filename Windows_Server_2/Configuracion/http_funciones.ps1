# ==============================================================
# FUNCIONES AUXILIARES Y VALIDACIONES
# ==============================================================

function Validar-Puerto-HTTP {
    param([string]$Puerto)
    
    # Validar que sea un número entre 1 y 65535
    if ($Puerto -notmatch "^\d+$" -or [int]$Puerto -lt 1 -or [int]$Puerto -gt 65535) {
        return 1
    }
    
    # Validar si el puerto está ocupado
    $ocupado = Get-NetTCPConnection -LocalPort $Puerto -ErrorAction SilentlyContinue
    if ($ocupado) {
        return 2
    }
    
    return 0
}

function Instalar-Chocolatey {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "[*] Instalando Gestor de Paquetes (Chocolatey)..." -ForegroundColor Cyan
        Set-ExecutionPolicy Bypass -Scope Process -Force
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        $env:Path += ";$env:ALLUSERSPROFILE\chocolatey\bin"
    }
}

# Nueva función inteligente para seleccionar versiones en Windows
function Seleccionar-Version-Choco {
    param([string]$Paquete)
    
    Write-Host "[*] Consultando repositorios para $Paquete..." -ForegroundColor Cyan
    
    # Obtenemos todas las versiones (la más nueva arriba, la más vieja abajo)
    $lineas = choco search $Paquete --exact --all-versions --limit-output 2>$null
    if (-not $lineas) {
        Write-Host "[-] Error: No se encontraron versiones para $Paquete." -ForegroundColor Red
        return $null
    }
    
    $versiones = $lineas | ForEach-Object { ($_ -split '\|')[1] }
    
    $verLatest = $versiones[0]
    $verOldest = $versiones[-1]
    
    # Buscamos la versión estable/candidata por defecto
    $estableRaw = choco search $Paquete --exact --limit-output 2>$null | Select-Object -First 1
    $verLts = ($estableRaw -split '\|')[1]
    
    if ([string]::IsNullOrWhiteSpace($verLts)) {
        $verLts = $verLatest
    }
    
    Write-Host "Versiones disponibles para $Paquete :"
    Write-Host "  1) Versión LTS    : $verLts"
    Write-Host "  2) Versión Latest : $verLatest"
    Write-Host "  3) Versión Oldest : $verOldest"
    
    $sel = Read-Host "Seleccione el número de la versión deseada"
    
    if ($sel -eq "1") { return $verLts }
    elseif ($sel -eq "2") { return $verLatest }
    elseif ($sel -eq "3") { return $verOldest }
    else {
        Write-Host "[-] Selección inválida." -ForegroundColor Red
        return $null
    }
}

# ==============================================================
# DESPLIEGUE DE IIS (INTERNET INFORMATION SERVICES)
# ==============================================================

function Desplegar-IIS {
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "      DESPLIEGUE DINAMICO: IIS" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan

    do {
        $PUERTO = Read-Host "Ingrese el puerto de escucha (ej. 80, 8080)"
        $estado = Validar-Puerto-HTTP -Puerto $PUERTO
        
        if ($estado -eq 1) { Write-Host "[-] Error: Puerto inválido." -ForegroundColor Red }
        if ($estado -eq 2) { Write-Host "[-] Error: El puerto $PUERTO ya está ocupado." -ForegroundColor Red }
    } while ($estado -ne 0)

    Write-Host "[*] Instalando IIS de forma silenciosa..." -ForegroundColor Cyan
    Install-WindowsFeature -Name Web-Server -IncludeManagementTools -ErrorAction SilentlyContinue | Out-Null
    Import-Module WebAdministration

    Write-Host "[*] Configurando Puerto y Bindings..." -ForegroundColor Cyan
    # Eliminar binding del puerto 80 por defecto y asignar el nuevo
    Get-WebBinding -Name "Default Web Site" | Remove-WebBinding -ErrorAction SilentlyContinue
    New-WebBinding -Name "Default Web Site" -IPAddress "*" -Port $PUERTO -Protocol http | Out-Null

    Write-Host "[*] Aplicando Hardening (Seguridad y Ocultación)..." -ForegroundColor Cyan
    # 1. Eliminar X-Powered-By
    Remove-WebConfigurationProperty -Filter "system.webServer/httpProtocol/customHeaders" -Name "." -AtElement @{name="X-Powered-By"} -PSPath "IIS:\Sites\Default Web Site" -ErrorAction SilentlyContinue | Out-Null
    
    # 2. Configurar Request Filtering para ocultar la versión del servidor
    Set-WebConfigurationProperty -Filter "system.webServer/security/requestFiltering" -Name "removeServerHeader" -Value "True" -PSPath "IIS:\" -ErrorAction SilentlyContinue | Out-Null
    
    # 3. Inyectar Cabeceras de Seguridad
    Add-WebConfigurationProperty -Filter "system.webServer/httpProtocol/customHeaders" -Name "." -Value @{name="X-Frame-Options";value="SAMEORIGIN"} -PSPath "IIS:\Sites\Default Web Site" -ErrorAction SilentlyContinue | Out-Null
    Add-WebConfigurationProperty -Filter "system.webServer/httpProtocol/customHeaders" -Name "." -Value @{name="X-Content-Type-Options";value="nosniff"} -PSPath "IIS:\Sites\Default Web Site" -ErrorAction SilentlyContinue | Out-Null

    Write-Host "[*] Generando página personalizada..." -ForegroundColor Cyan
    $htmlPath = "C:\inetpub\wwwroot\index.html"
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head><title>Despliegue IIS</title></head>
<body>
    <h1>Servidor: Internet Information Services (IIS)</h1>
    <h2>Puerto de Escucha: $PUERTO</h2>
    <p>Desplegado y asegurado automaticamente.</p>
</body>
</html>
"@
    Set-Content -Path $htmlPath -Value $htmlContent -Force

    Write-Host "[*] Configurando Firewall..." -ForegroundColor Cyan
    New-NetFirewallRule -DisplayName "HTTP-IIS-Custom" -LocalPort $PUERTO -Protocol TCP -Action Allow -ErrorAction SilentlyContinue | Out-Null
    
    # Reiniciar el servicio IIS para aplicar cambios
    iisreset /restart | Out-Null

    Write-Host "=====================================" -ForegroundColor Green
    Write-Host "[+] Despliegue de IIS completado con éxito." -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Green
    Pause
}

# ==============================================================
# DESPLIEGUE DE NGINX
# ==============================================================

function Desplegar-Nginx-Windows {
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "    DESPLIEGUE DINÁMICO: NGINX WIN" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan

    Instalar-Chocolatey

    $versionElegida = Seleccionar-Version-Choco -Paquete "nginx"
    if (-not $versionElegida) {
        Pause; return
    }
    Write-Host "[+] Versión seleccionada: $versionElegida" -ForegroundColor Green

    do {
        $PUERTO = Read-Host "Ingrese el puerto de escucha (ej. 80, 8080)"
        $estado = Validar-Puerto-HTTP -Puerto $PUERTO
        if ($estado -eq 1) { Write-Host "[-] Error: Puerto inválido." -ForegroundColor Red }
        if ($estado -eq 2) { Write-Host "[-] Error: Puerto ocupado." -ForegroundColor Red }
    } while ($estado -ne 0)

    Write-Host "[*] Instalando Nginx $versionElegida..." -ForegroundColor Cyan
    choco install nginx --version $versionElegida -y --force --package-parameters="/port:$PUERTO"

    Write-Host "[*] Localizando binarios de Nginx dinámicamente..." -ForegroundColor Cyan
    $nginxDir = $null
    $posiblesRutas = @("C:\tools", "C:\ProgramData\chocolatey\lib\nginx")

    foreach ($ruta in $posiblesRutas) {
        if (Test-Path $ruta) {
            $busqueda = Get-ChildItem -Path $ruta -Filter "nginx.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($busqueda) {
                $nginxDir = $busqueda.DirectoryName
                break
            }
        }
    }

    if (-not $nginxDir) {
        Write-Host "[-] ERROR CRÍTICO: No se pudo localizar Nginx." -ForegroundColor Red
        Pause; return
    }

    Write-Host "[+] Nginx localizado en: $nginxDir" -ForegroundColor Green

    Write-Host "[*] Configurando el puerto y seguridad..." -ForegroundColor Cyan
    $confPath = "$nginxDir\conf\nginx.conf"
    if (Test-Path $confPath) {
        $contenido = Get-Content $confPath
        # Expresión regular para reemplazar cualquier puerto que traiga por defecto
        $contenido = $contenido -replace 'listen\s+\d+;', "listen       $PUERTO;"
        # Ocultar tokens (Hardening)
        $contenido = $contenido -replace '#tcp_nopush     on;', "#tcp_nopush     on;`n    server_tokens off;"
        $contenido | Set-Content $confPath
    } else {
        Write-Host "[-] Advertencia: No se encontró nginx.conf" -ForegroundColor Yellow
    }

    Write-Host "[*] Generando página web personalizada..." -ForegroundColor Cyan
    $htmlDir = "$nginxDir\html"
    if (Test-Path $htmlDir) {
        $htmlContent = @"
<!DOCTYPE html>
<html>
<head><title>Despliegue Nginx Win</title></head>
<body>
    <h1>Servidor: Nginx (Windows)</h1>
    <h2>Version: $versionElegida</h2>
    <h3>Puerto de Escucha: $PUERTO</h3>
</body>
</html>
"@
        Set-Content -Path "$htmlDir\index.html" -Value $htmlContent -Force
    }

    Write-Host "[*] Configurando Firewall..." -ForegroundColor Cyan
    New-NetFirewallRule -DisplayName "HTTP-Nginx-Custom" -LocalPort $PUERTO -Protocol TCP -Action Allow -ErrorAction SilentlyContinue | Out-Null

    Write-Host "[*] Reiniciando/Iniciando Nginx para aplicar cambios..." -ForegroundColor Cyan
    $servicio = Get-Service -Name "nginx" -ErrorAction SilentlyContinue
    if ($servicio) {
        Restart-Service -Name "nginx" -Force -ErrorAction SilentlyContinue | Out-Null
    } else {
        Stop-Process -Name "nginx" -Force -ErrorAction SilentlyContinue
        Start-Process -FilePath "$nginxDir\nginx.exe" -WorkingDirectory $nginxDir -WindowStyle Hidden
    }

    Write-Host "=====================================" -ForegroundColor Green
    Write-Host "[+] Despliegue de Nginx finalizado." -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Green
    Pause
}

# ==============================================================
# DESPLIEGUE DE APACHE 
# ==============================================================

function Desplegar-Apache-Windows {
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "   DESPLIEGUE DINÁMICO: APACHE WIN" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan

    Instalar-Chocolatey

    $versionElegida = Seleccionar-Version-Choco -Paquete "apache-httpd"
    if (-not $versionElegida) {
        Pause; return
    }
    Write-Host "[+] Versión seleccionada: $versionElegida" -ForegroundColor Green

    do {
        $PUERTO = Read-Host "Ingrese el puerto de escucha (ej. 80, 8080)"
        $estado = Validar-Puerto-HTTP -Puerto $PUERTO
        if ($estado -eq 1) { Write-Host "[-] Error: Puerto inválido." -ForegroundColor Red }
        if ($estado -eq 2) { Write-Host "[-] Error: Puerto ocupado." -ForegroundColor Red }
    } while ($estado -ne 0)

    Write-Host "[*] Instalando Apache HTTPD $versionElegida..." -ForegroundColor Cyan
    choco install apache-httpd --version $versionElegida -y --force

    Write-Host "[*] Localizando binarios de Apache dinámicamente..." -ForegroundColor Cyan
    $apacheDir = $null
    
    # Agregamos $env:APPDATA (que es la carpeta Roaming) y C:\ para atraparlo donde sea
    $posiblesRutas = @("C:\tools", "C:\Apache24", "C:\ProgramData\chocolatey\lib", $env:APPDATA)

    # Busca exactamente dónde quedó el httpd.exe
    foreach ($ruta in $posiblesRutas) {
        if (Test-Path $ruta) {
            $busqueda = Get-ChildItem -Path $ruta -Filter "httpd.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($busqueda) {
                # Como httpd.exe está en la carpeta "bin", necesitamos la carpeta padre (la raíz de Apache)
                $apacheDir = (Get-Item $busqueda.DirectoryName).Parent.FullName
                break
            }
        }
    }

    if (-not $apacheDir) {
        Write-Host "[-] ERROR CRÍTICO: No se pudo localizar Apache. La instalación pudo fallar." -ForegroundColor Red
        Pause; return
    }

    Write-Host "[+] Apache localizado en: $apacheDir" -ForegroundColor Green

    $confPath = "$apacheDir\conf\httpd.conf"

    Write-Host "[*] Configurando el puerto, rutas y seguridad..." -ForegroundColor Cyan
    if (Test-Path $confPath) {
        $contenido = Get-Content $confPath
        
        # 1. Cambiar el puerto (sea cual sea el que traiga, ej 80 u 8080)
        $contenido = $contenido -replace 'Listen \d+', "Listen $PUERTO"
        $contenido = $contenido -replace 'ServerName localhost:\d+', "ServerName localhost:$PUERTO"
        
        # 2. Arreglar la ruta raíz (SRVROOT)
        $rutaCorregida = $apacheDir -replace '\\', '/'
        $contenido = $contenido -replace 'Define SRVROOT ".*"', "Define SRVROOT `"$rutaCorregida`""
        
        $contenido | Set-Content $confPath
        
        # 3. Hardening (Apagar firmas del servidor)
        Add-Content -Path $confPath -Value "`nServerTokens Prod`nServerSignature Off"
    } else {
        Write-Host "[-] Advertencia: No se encontró httpd.conf en la ruta: $confPath" -ForegroundColor Yellow
    }

    Write-Host "[*] Generando página web personalizada..." -ForegroundColor Cyan
    $htdocsPath = "$apacheDir\htdocs\index.html"
    if (Test-Path "$apacheDir\htdocs") {
        $htmlContent = @"
<!DOCTYPE html>
<html>
<head><title>Despliegue Apache Win</title></head>
<body>
    <h1>Servidor: Apache (Windows)</h1>
    <h2>Version: $versionElegida</h2>
    <h3>Puerto de Escucha: $PUERTO</h3>
</body>
</html>
"@
        Set-Content -Path $htdocsPath -Value $htmlContent -Force
    }

    Write-Host "[*] Configurando Firewall..." -ForegroundColor Cyan
    New-NetFirewallRule -DisplayName "HTTP-Apache-Custom" -LocalPort $PUERTO -Protocol TCP -Action Allow -ErrorAction SilentlyContinue | Out-Null

    Write-Host "[*] Reiniciando Servicio Apache para aplicar cambios..." -ForegroundColor Cyan
    
    $nomServicio = "Apache2.4"
    if (-not (Get-Service -Name $nomServicio -ErrorAction SilentlyContinue)) {
        $nomServicio = "Apache" 
    }
    if (-not (Get-Service -Name $nomServicio -ErrorAction SilentlyContinue)) {
        $nomServicio = "apache"
    }

    $servicio = Get-Service -Name $nomServicio -ErrorAction SilentlyContinue
    if ($servicio) {
        # CRUCIAL: Reiniciamos para que lea el nuevo httpd.conf
        Restart-Service -Name $nomServicio -Force -ErrorAction SilentlyContinue | Out-Null
    }
    
    $servicioCheck = Get-Service -Name $nomServicio -ErrorAction SilentlyContinue
    if (-not $servicioCheck -or $servicioCheck.Status -ne 'Running') {
        Write-Host "[*] Arrancando proceso manualmente..." -ForegroundColor Cyan
        Stop-Process -Name "httpd" -Force -ErrorAction SilentlyContinue
        Start-Process -FilePath "$apacheDir\bin\httpd.exe" -WindowStyle Hidden
    }

    Write-Host "=====================================" -ForegroundColor Green
    Write-Host "[+] Despliegue de Apache finalizado." -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Green
    Pause
}