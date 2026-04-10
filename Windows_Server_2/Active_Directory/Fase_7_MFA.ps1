#Requires -RunAsAdministrator
Clear-Host
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host " FASE 7: MFA VIA SSH + TOTP                     " -ForegroundColor Cyan
Write-Host " Windows Server 2022 - Sin entorno grafico      " -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# ----------------------------------------------------------
# VARIABLES BASE
# ----------------------------------------------------------
$RutaMSI      = "C:\Users\Administrador\Windows_Server\Active_Directory\MFA_Install.msi"
$RutaMultiOTP = "C:\Program Files\multiOTP"
$ExeMultiOTP  = "$RutaMultiOTP\multiotp.exe"
$LlaveSecreta = "JBSWY3DPEHPK3PXP"
$UsuarioMFA   = "administrator"
$LogMSI       = "C:\mfa_install.log"
$VCDest       = "C:\vc_redist.x64.exe"
$sshdConfig   = "C:\ProgramData\ssh\sshd_config"
$sshdScript   = "C:\ProgramData\ssh\multiotp_auth.ps1"

# ----------------------------------------------------------
# PASO 1: Verificar que el instalador MSI existe
# ----------------------------------------------------------
Write-Host "`n> 1. Verificando instalador MSI..." -ForegroundColor Yellow

if (-not (Test-Path $RutaMSI)) {
    Write-Host "  [-] No se encontro el instalador en: $RutaMSI" -ForegroundColor Red
    exit
}
Write-Host "  [+] Instalador encontrado." -ForegroundColor Green

# ----------------------------------------------------------
# PASO 2: Instalar Visual C++ Redistributable x64
# ----------------------------------------------------------
Write-Host "`n> 2. Verificando Visual C++ Redistributable x64..." -ForegroundColor Yellow

$vcInstalado = Get-ItemProperty `
    "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" `
    -ErrorAction SilentlyContinue

if ($vcInstalado -and $vcInstalado.Installed -eq 1) {
    Write-Host "  [+] VC++ ya instalado (version $($vcInstalado.Version))." -ForegroundColor Green
} else {
    Write-Host "  [!] VC++ no encontrado. Descargando..." -ForegroundColor Yellow
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest `
            -Uri     "https://aka.ms/vs/17/release/vc_redist.x64.exe" `
            -OutFile $VCDest `
            -UseBasicParsing
        Write-Host "  [+] Descarga completada." -ForegroundColor Green
    } catch {
        Write-Host "  [-] Error al descargar VC++: $($_.Exception.Message)" -ForegroundColor Red
        exit
    }

    $vcResult = Start-Process $VCDest `
        -ArgumentList "/install /quiet /norestart" `
        -Wait -PassThru

    switch ($vcResult.ExitCode) {
        0    { Write-Host "  [+] VC++ instalado correctamente." -ForegroundColor Green }
        3010 { Write-Host "  [+] VC++ instalado (reinicio pendiente, continuamos)." -ForegroundColor Green }
        default {
            Write-Host "  [-] VC++ fallo con codigo: $($vcResult.ExitCode)" -ForegroundColor Red
            exit
        }
    }
    Start-Sleep -Seconds 5
}

# ----------------------------------------------------------
# PASO 3: Instalar motor multiOTP desde MSI
# ----------------------------------------------------------
Write-Host "`n> 3. Instalando motor multiOTP..." -ForegroundColor Yellow

if (Test-Path $LogMSI) { Remove-Item $LogMSI -Force }

Start-Process "msiexec.exe" `
    -ArgumentList "/i `"$RutaMSI`" /quiet /norestart /L*V `"$LogMSI`"" `
    -Wait

Start-Sleep -Seconds 3

$hayError = Get-Content $LogMSI -ErrorAction SilentlyContinue |
            Where-Object { $_ -match "Return value 3|error 1603|Installation failed" }

if ($hayError) {
    Write-Host "  [-] El MSI reporto errores:" -ForegroundColor Red
    $hayError | Select-Object -First 3 |
        ForEach-Object { Write-Host "      $_" -ForegroundColor DarkGray }
    exit
}
Write-Host "  [+] Motor multiOTP instalado." -ForegroundColor Green

# Verificar que multiotp.exe existe
if (-not (Test-Path $ExeMultiOTP)) {
    Write-Host "  [-] multiotp.exe no encontrado en: $ExeMultiOTP" -ForegroundColor Red
    exit
}
Write-Host "  [+] multiotp.exe verificado." -ForegroundColor Green

# ----------------------------------------------------------
# PASO 4: Configurar usuario TOTP con -createga
# Usa directamente la llave Base32 de Google Authenticator
# ----------------------------------------------------------
Write-Host "`n> 4. Configurando usuario TOTP..." -ForegroundColor Yellow

# Limpiar usuario anterior si existe
$dbPath = "$RutaMultiOTP\users\$UsuarioMFA.db"
if (Test-Path $dbPath) {
    Remove-Item $dbPath -Force
    Write-Host "  [!] Usuario anterior eliminado." -ForegroundColor Yellow
}

# Crear usuario con -createga (acepta Base32 directamente)
& $ExeMultiOTP -createga $UsuarioMFA $LlaveSecreta
Start-Sleep -Seconds 1

# Sin PIN adicional
& $ExeMultiOTP -set $UsuarioMFA prefix-pin=0 2>$null

# Bloqueo: 3 intentos fallidos = 30 minutos
& $ExeMultiOTP -config max-block-failures=3      2>$null
& $ExeMultiOTP -config failure-delayed-time=1800  2>$null

# Verificar que el usuario existe
$p = New-Object System.Diagnostics.ProcessStartInfo
$p.FileName               = $ExeMultiOTP
$p.Arguments              = "-user-info $UsuarioMFA"
$p.RedirectStandardOutput = $true
$p.RedirectStandardError  = $true
$p.UseShellExecute        = $false
$proc = [System.Diagnostics.Process]::Start($p)
$proc.WaitForExit()
$info = $proc.StandardOutput.ReadToEnd()

if ($info -match "Algorithm.*totp") {
    Write-Host "  [+] Usuario configurado con TOTP." -ForegroundColor Green
} else {
    Write-Host "  [-] Error al crear usuario." -ForegroundColor Red
    Write-Host $info -ForegroundColor DarkGray
    exit
}

# ----------------------------------------------------------
# PASO 5: Probar token ANTES de configurar SSH
# Usa el metodo correcto que captura ExitCode
# ----------------------------------------------------------
Write-Host "`n> 5. Prueba obligatoria del token TOTP..." -ForegroundColor Yellow
Write-Host "  Abre Google Authenticator. Llave: $LlaveSecreta" -ForegroundColor Cyan
Write-Host "  Espera a que el codigo cambie y usa el nuevo." -ForegroundColor Yellow
$token = Read-Host "  Ingresa el codigo de 6 digitos"

$p = New-Object System.Diagnostics.ProcessStartInfo
$p.FileName               = $ExeMultiOTP
$p.Arguments              = "$UsuarioMFA $token"
$p.RedirectStandardOutput = $true
$p.RedirectStandardError  = $true
$p.UseShellExecute        = $false
$proc = [System.Diagnostics.Process]::Start($p)
$proc.WaitForExit()
$exitCode = $proc.ExitCode

Write-Host "  ExitCode: $exitCode" -ForegroundColor DarkGray

if ($exitCode -eq 0) {
    Write-Host "  [OK] Token valido." -ForegroundColor Green
} else {
    Write-Host "  [-] Token invalido." -ForegroundColor Red
    Write-Host "  [!] Verifica la llave en Authenticator: $LlaveSecreta" -ForegroundColor Yellow
    Write-Host "  [!] O sincroniza el reloj: w32tm /resync /force" -ForegroundColor Yellow
    exit
}

# ----------------------------------------------------------
# PASO 6: Verificar OpenSSH instalado
# ----------------------------------------------------------
Write-Host "`n> 6. Verificando OpenSSH..." -ForegroundColor Yellow

$ssh = Get-WindowsCapability -Online |
       Where-Object Name -like 'OpenSSH.Server*'

if ($ssh.State -ne "Installed") {
    Write-Host "  [!] OpenSSH no instalado. Instalando..." -ForegroundColor Yellow
    Add-WindowsCapability -Online -Name $ssh.Name | Out-Null
}

Set-Service sshd -StartupType Automatic
Start-Service sshd -ErrorAction SilentlyContinue
Write-Host "  [+] OpenSSH Server activo." -ForegroundColor Green

# ----------------------------------------------------------
# PASO 7: Crear script de validacion MFA para SSH
# Usa ProcessStartInfo para capturar ExitCode correctamente
# ----------------------------------------------------------
Write-Host "`n> 7. Creando script de validacion MFA para SSH..." -ForegroundColor Yellow

$scriptContenido = @'
# ============================================
# Script MFA multiOTP para SSH
# Se ejecuta en cada conexion SSH entrante
# ============================================

$exe  = "C:\Program Files\multiOTP\multiotp.exe"

# Normalizar usuario a minusculas (multiOTP es case-sensitive)
$user = $env:USERNAME.ToLower()

Write-Host ""
Write-Host "============================================"
Write-Host "  AUTENTICACION MFA REQUERIDA"
Write-Host "  Usuario: $user"
Write-Host "============================================"
Write-Host ""
$token = Read-Host "Ingresa tu codigo de Google Authenticator"

# Validar usando ProcessStartInfo para capturar ExitCode correctamente
$p = New-Object System.Diagnostics.ProcessStartInfo
$p.FileName               = $exe
$p.Arguments              = "$user $token"
$p.RedirectStandardOutput = $true
$p.RedirectStandardError  = $true
$p.UseShellExecute        = $false

$proc = [System.Diagnostics.Process]::Start($p)
$proc.WaitForExit()
$exitCode = $proc.ExitCode

if ($exitCode -eq 0) {
    Write-Host ""
    Write-Host "[OK] Token valido. Acceso concedido." -ForegroundColor Green
    Write-Host ""
    # Iniciar sesion PowerShell normal
    & powershell.exe -NoLogo
} else {
    Write-Host ""
    Write-Host "[-] Token invalido (codigo: $exitCode). Acceso denegado." -ForegroundColor Red
    Write-Host ""
    exit 1
}
'@

$scriptContenido | Out-File $sshdScript -Encoding UTF8 -Force
Write-Host "  [+] Script creado en: $sshdScript" -ForegroundColor Green

# ----------------------------------------------------------
# PASO 8: Configurar sshd_config con ForceCommand
# ----------------------------------------------------------
Write-Host "`n> 8. Configurando sshd_config..." -ForegroundColor Yellow

# Crear sshd_config base si no existe
if (-not (Test-Path $sshdConfig)) {
    New-Item -Path (Split-Path $sshdConfig) -ItemType Directory -Force | Out-Null
    @"
Port 22
PasswordAuthentication yes
PubkeyAuthentication yes
"@ | Out-File $sshdConfig -Encoding UTF8
}

# Leer config actual
$config = Get-Content $sshdConfig -Raw

# Eliminar ForceCommand anterior si existe
$config = $config -replace "(?m)^\s*ForceCommand.*(\r?\n)?", ""
$config = $config -replace "(?m)^\s*# MFA.*(\r?\n)?", ""

# Agregar ForceCommand al final
$forceCmd = "`n# MFA multiOTP - Token TOTP requerido en cada conexion SSH`nForceCommand powershell.exe -ExecutionPolicy Bypass -NonInteractive -File `"$sshdScript`"`n"
($config.TrimEnd() + $forceCmd) | Out-File $sshdConfig -Encoding UTF8 -Force

Write-Host "  [+] sshd_config actualizado con ForceCommand." -ForegroundColor Green

# ----------------------------------------------------------
# PASO 9: Abrir puerto SSH en firewall
# ----------------------------------------------------------
Write-Host "`n> 9. Verificando firewall SSH..." -ForegroundColor Yellow

$regla = Get-NetFirewallRule -DisplayName "SSH-MFA-22" -ErrorAction SilentlyContinue
if (-not $regla) {
    New-NetFirewallRule `
        -DisplayName "SSH-MFA-22" `
        -Direction   Inbound `
        -Protocol    TCP `
        -LocalPort   22 `
        -Action      Allow | Out-Null
}
Write-Host "  [+] Puerto 22 abierto." -ForegroundColor Green

# ----------------------------------------------------------
# PASO 10: Reiniciar SSH para aplicar cambios
# ----------------------------------------------------------
Write-Host "`n> 10. Reiniciando SSH..." -ForegroundColor Yellow
Restart-Service sshd -Force
Start-Sleep -Seconds 2
$estado = (Get-Service sshd).Status
Write-Host "  [+] SSH estado: $estado" -ForegroundColor Green

# ----------------------------------------------------------
# PASO 11: Verificacion final
# ----------------------------------------------------------
Write-Host "`n> 11. Verificacion final..." -ForegroundColor Yellow

$checks = [ordered]@{
    "Motor multiotp.exe"       = (Test-Path $ExeMultiOTP)
    "Usuario TOTP configurado" = ($exitCode -eq 0)
    "Script MFA creado"        = (Test-Path $sshdScript)
    "sshd_config actualizado"  = ((Get-Content $sshdConfig -Raw) -match "ForceCommand")
    "SSH corriendo"            = ((Get-Service sshd).Status -eq "Running")
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

Write-Host "`n=================================================" -ForegroundColor Cyan
if ($todoOK) {
    Write-Host " FASE 7 COMPLETADA EXITOSAMENTE                 " -ForegroundColor Green
} else {
    Write-Host " FASE 7 COMPLETADA CON ERRORES                  " -ForegroundColor Red
}
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host " Flujo de acceso MFA via SSH:" -ForegroundColor White
Write-Host "   ssh Administrador@<IP_SERVIDOR>" -ForegroundColor DarkGray
Write-Host "   1. Ingresa contrasena de Windows." -ForegroundColor DarkGray
Write-Host "   2. Script pide codigo de Google Authenticator." -ForegroundColor DarkGray
Write-Host "   3. Token valido  = acceso concedido." -ForegroundColor DarkGray
Write-Host "   4. Token invalido = conexion cerrada." -ForegroundColor DarkGray
Write-Host "   5. 3 fallos = cuenta bloqueada 30 minutos." -ForegroundColor DarkGray
Write-Host "=================================================" -ForegroundColor Cyan
