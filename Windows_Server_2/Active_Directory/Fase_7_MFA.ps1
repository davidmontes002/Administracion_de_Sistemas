#Requires -RunAsAdministrator
Clear-Host
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host " FASE 7: MFA CON MULTIOTP                       " -ForegroundColor Cyan
Write-Host " Windows Server 2022 - Sin entorno grafico      " -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# ----------------------------------------------------------
# VARIABLES BASE
# Ajusta LlaveSecreta si generaste una diferente.
# Esta es la que ya tienes en Google Authenticator.
# ----------------------------------------------------------
$RutaMSI      = "C:\Users\Administrador\Windows_Server_2\Active_Directory\MFA_Install.msi"
$LlaveSecreta = "JBSWY3DPEHPK3PXP"
$UsuarioMFA   = "administrator"
$LogMSI       = "C:\mfa_install.log"

# ----------------------------------------------------------
# PASO 1: Verificar que el instalador existe
# ----------------------------------------------------------
Write-Host "`n> 1. Verificando instalador MSI..." -ForegroundColor Yellow

if (-not (Test-Path $RutaMSI)) {
    Write-Host "  [-] No se encontro el instalador en: $RutaMSI" -ForegroundColor Red
    exit
}
Write-Host "  [+] Instalador encontrado." -ForegroundColor Green

# ----------------------------------------------------------
# PASO 2: Instalar MSI con log completo
# /L*V activa log verbose para detectar errores silenciosos
# ----------------------------------------------------------
Write-Host "`n> 2. Instalando multiOTP desde MSI..." -ForegroundColor Yellow

Start-Process "msiexec.exe" `
    -ArgumentList "/i `"$RutaMSI`" /quiet /norestart /L*V `"$LogMSI`"" `
    -Wait

Start-Sleep -Seconds 3

# Revisar log por errores criticos
$logContenido = Get-Content $LogMSI -ErrorAction SilentlyContinue
$hayError     = $logContenido | Where-Object { $_ -match "error|value 3|1603|1619|failed" }

if ($hayError) {
    Write-Host "  [-] El MSI reporto errores:" -ForegroundColor Red
    $hayError | Select-Object -First 5 |
        ForEach-Object { Write-Host "      $_" -ForegroundColor DarkGray }
    Write-Host "  [!] Log completo en: $LogMSI" -ForegroundColor Yellow
    exit
}
Write-Host "  [+] Instalacion sin errores criticos." -ForegroundColor Green

# ----------------------------------------------------------
# PASO 3: Localizar multiotp.exe y la DLL
# ----------------------------------------------------------
Write-Host "`n> 3. Localizando archivos instalados..." -ForegroundColor Yellow

$posiblesRutas = @(
    "C:\multiOTP",
    "C:\Program Files\multiOTP",
    "C:\Program Files (x86)\multiOTP",
    "C:\Program Files\multiOTP Credential Provider"
)

$rutaBase    = $null
$exeMultiOTP = $null

foreach ($ruta in $posiblesRutas) {
    $encontrado = Get-ChildItem -Path $ruta -Recurse -Filter "multiotp.exe" `
                  -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($encontrado) {
        $rutaBase    = $ruta
        $exeMultiOTP = $encontrado.FullName
        break
    }
}

if (-not $exeMultiOTP) {
    Write-Host "  [-] multiotp.exe no encontrado en rutas conocidas." -ForegroundColor Red
    Write-Host "  [!] Revisa el log del MSI en: $LogMSI" -ForegroundColor Yellow
    exit
}
Write-Host "  [+] multiotp.exe : $exeMultiOTP" -ForegroundColor Green

# Buscar DLL del Credential Provider
$dll = Get-ChildItem -Path $rutaBase -Recurse -Filter "*.dll" `
       -ErrorAction SilentlyContinue |
       Where-Object { $_.Name -match "credential|CP|multiOTP" } |
       Select-Object -First 1

if (-not $dll) {
    Write-Host "  [-] DLL del Credential Provider no encontrada." -ForegroundColor Red
    Write-Host "  [!] Listando todos los archivos en $rutaBase :" -ForegroundColor Yellow
    Get-ChildItem -Path $rutaBase -Recurse -ErrorAction SilentlyContinue |
        Select-Object FullName | Format-List
    exit
}
Write-Host "  [+] DLL encontrada : $($dll.FullName)" -ForegroundColor Green

# ----------------------------------------------------------
# PASO 4: Copiar DLL a System32 y registrar en COM
# Sin este paso LSASS no sabe que el proveedor existe.
# ----------------------------------------------------------
Write-Host "`n> 4. Registrando Credential Provider en Windows..." -ForegroundColor Yellow

$dllDestino = "C:\Windows\System32\$($dll.Name)"
Copy-Item $dll.FullName -Destination $dllDestino -Force
Write-Host "  [+] DLL copiada a System32." -ForegroundColor Green

$regResult = Start-Process "regsvr32.exe" `
    -ArgumentList "/s `"$dllDestino`"" `
    -Wait -PassThru

if ($regResult.ExitCode -ne 0) {
    Write-Host "  [-] regsvr32 fallo (codigo: $($regResult.ExitCode))." -ForegroundColor Red
    exit
}
Write-Host "  [+] DLL registrada en COM (regsvr32 exitoso)." -ForegroundColor Green

# Detectar GUID automaticamente desde el registro COM
$guidDetectado = Get-ChildItem "HKLM:\SOFTWARE\Classes\CLSID" `
    -ErrorAction SilentlyContinue |
    Where-Object {
        $inproc = "$($_.PSPath)\InprocServer32"
        (Test-Path $inproc) -and
        ((Get-ItemProperty $inproc -ErrorAction SilentlyContinue)."(Default)" `
            -match [regex]::Escape($dll.Name))
    } |
    Select-Object -ExpandProperty PSChildName -First 1

# Si no se detecta usar GUID oficial conocido de multiOTP CP
if (-not $guidDetectado) {
    $guidDetectado = "{FCEFDFAB-B0A1-4C4D-8B2B-4FF4E0A3D978}"
    Write-Host "  [!] GUID no detectado automaticamente." -ForegroundColor Yellow
    Write-Host "      Usando GUID oficial de multiOTP: $guidDetectado" -ForegroundColor Yellow
} else {
    Write-Host "  [+] GUID detectado : $guidDetectado" -ForegroundColor Green
}

# Registrar la subclave correcta en Credential Providers
# (Este era el paso que faltaba en el script original)
$rutaCP = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers\$guidDetectado"
if (-not (Test-Path $rutaCP)) {
    New-Item -Path $rutaCP -Force | Out-Null
}
Set-ItemProperty -Path $rutaCP -Name "(Default)" -Value "multiOTP Credential Provider"
Write-Host "  [+] GUID registrado correctamente en Credential Providers." -ForegroundColor Green

# ----------------------------------------------------------
# PASO 5: Deshabilitar NLA
#
# En Server Core 2022 el acceso es via RDP.
# NLA autentica al usuario a nivel de red ANTES de que
# LogonUI arranque, saltandose completamente el CP.
# Con NLA=0 el flujo pasa por LogonUI y el CP intercepta.
# ----------------------------------------------------------
Write-Host "`n> 5. Configurando NLA para que el CP sea invocado..." -ForegroundColor Yellow

$rutaNLA = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
Set-ItemProperty -Path $rutaNLA -Name "UserAuthentication" -Value 0

$nlaValor = (Get-ItemProperty $rutaNLA).UserAuthentication
if ($nlaValor -eq 0) {
    Write-Host "  [+] NLA deshabilitado. El CP sera invocado en el login RDP." -ForegroundColor Green
} else {
    Write-Host "  [-] No se pudo deshabilitar NLA." -ForegroundColor Red
    exit
}

# ----------------------------------------------------------
# PASO 6: Configurar usuario en multiOTP CLI
# ----------------------------------------------------------
Write-Host "`n> 6. Configurando usuario '$UsuarioMFA' en multiOTP..." -ForegroundColor Yellow

# Crear usuario con TOTP y la llave de Google Authenticator
& $exeMultiOTP -create $UsuarioMFA TOTP $LlaveSecreta 6 2>$null
Write-Host "  [+] Usuario creado con llave TOTP." -ForegroundColor Green

# Sin PIN adicional: el factor es unicamente el token de 6 digitos
& $exeMultiOTP -set $UsuarioMFA "request-prefix-pin" 0 2>$null
Write-Host "  [+] Sin PIN adicional (solo token de 6 digitos)." -ForegroundColor Green

# Politica de bloqueo: 3 intentos fallidos = 30 minutos (1800 segundos)
& $exeMultiOTP -config "max-block-failures" 3      2>$null
& $exeMultiOTP -config "failure-delayed-time" 1800  2>$null
Write-Host "  [+] Bloqueo configurado: 3 fallos = 30 minutos." -ForegroundColor Green

# ----------------------------------------------------------
# PASO 7: Prueba del token ANTES de reiniciar
# Si el token no valida aqui, no valdra despues del reinicio.
# ----------------------------------------------------------
Write-Host "`n> 7. Prueba obligatoria del token TOTP..." -ForegroundColor Yellow
Write-Host "  Abre Google Authenticator en tu celular ahora." -ForegroundColor Cyan
Write-Host "  La cuenta debe mostrar la llave: $LlaveSecreta" -ForegroundColor DarkGray
$token = Read-Host "  Ingresa el codigo de 6 digitos"

$resultado = (& $exeMultiOTP $UsuarioMFA $token 2>$null)
Write-Host "  Codigo de respuesta multiOTP: $resultado" -ForegroundColor DarkGray

# multiOTP devuelve 0 cuando el token es valido
if ($resultado -match "^0") {
    Write-Host "  [OK] Token valido. multiOTP esta funcionando correctamente." -ForegroundColor Green
} else {
    Write-Host "  [-] Token invalido." -ForegroundColor Red
    Write-Host "`n  Posibles causas:" -ForegroundColor Yellow
    Write-Host "  1. La llave en tu Authenticator no coincide con: $LlaveSecreta" -ForegroundColor Yellow
    Write-Host "  2. El reloj del servidor y del celular no estan sincronizados." -ForegroundColor Yellow
    Write-Host "     Verifica con: w32tm /query /status" -ForegroundColor Yellow
    Write-Host "`n  [!] NO reinicies hasta resolver esto. Quedarias sin acceso." -ForegroundColor Red
    exit
}

# ----------------------------------------------------------
# PASO 8: Verificacion completa antes del reinicio
# ----------------------------------------------------------
Write-Host "`n> 8. Verificacion final de todos los componentes..." -ForegroundColor Yellow

$rutaNLACheck = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"

$checks = [ordered]@{
    "DLL en System32"              = (Test-Path $dllDestino)
    "GUID en Credential Providers" = (Test-Path $rutaCP)
    "NLA deshabilitado"            = ((Get-ItemProperty $rutaNLACheck).UserAuthentication -eq 0)
    "multiotp.exe accesible"       = (Test-Path $exeMultiOTP)
    "Token validado correctamente" = ($resultado -match "^0")
}

$todoOK = $true
foreach ($c in $checks.GetEnumerator()) {
    if ($c.Value) {
        Write-Host "  [OK]    $($c.Key)" -ForegroundColor Green
    } else {
        Write-Host "  [FALLO] $($c.Key)" -ForegroundColor Red
        $todoOK = $false
    }
}

if (-not $todoOK) {
    Write-Host "`n[!] Hay componentes con fallo. Resuelve antes de reiniciar." -ForegroundColor Red
    Write-Host "    Si reinicias sin resolver quedas sin acceso al servidor." -ForegroundColor Red
    exit
}

# ----------------------------------------------------------
# PASO 9: Reinicio controlado
# ----------------------------------------------------------
Write-Host "`n=================================================" -ForegroundColor Cyan
Write-Host " TODO VERIFICADO - REINICIANDO EN 10 SEGUNDOS  " -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host " Tras reiniciar conectate por RDP." -ForegroundColor White
Write-Host " Flujo esperado en el login:" -ForegroundColor White
Write-Host "   1. Ingresa tu contrasena de Windows normalmente." -ForegroundColor DarkGray
Write-Host "   2. El CP intercepta y solicita el token TOTP." -ForegroundColor DarkGray
Write-Host "   3. Ingresa el codigo de 6 digitos de Google Authenticator." -ForegroundColor DarkGray
Write-Host "   4. Acceso concedido." -ForegroundColor DarkGray
Write-Host "=================================================" -ForegroundColor Cyan

Start-Sleep -Seconds 10
Restart-Computer -Force
