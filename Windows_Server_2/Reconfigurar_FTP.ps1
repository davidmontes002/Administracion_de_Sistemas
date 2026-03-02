# ==========================================
# SCRIPT REPARADOR DE PERMISOS FTP
# ==========================================

$user = Read-Host "Ingresa el nombre del usuario a corregir (ej. David)"

$rutaLobby = "C:\inetpub\ftproot\LocalUser\$user"
$rutaPersonal = "$rutaLobby\$user"

# Validar que al menos exista la jaula principal
if (-not (Test-Path $rutaLobby)) {
    Write-Host "[!] La carpeta del usuario $user no existe en LocalUser." -ForegroundColor Red
    exit
}

Write-Host "[*] 1. Verificando/Creando subcarpeta personal..." -ForegroundColor Cyan
New-Item -Path $rutaPersonal -ItemType Directory -Force | Out-Null

Write-Host "[*] 2. Reseteando permisos corruptos..." -ForegroundColor Cyan
icacls "$rutaLobby" /reset /T /Q | Out-Null

Write-Host "[*] 3. Aplicando candado al Lobby (Solo Lectura)..." -ForegroundColor Cyan
icacls "$rutaLobby" /inheritance:r /grant:r "${user}:(RX)" /grant:r "Administradores:(OI)(CI)F" /grant:r "SYSTEM:(OI)(CI)F" /Q | Out-Null

Write-Host "[*] 4. Otorgando permisos de escritura en subcarpeta personal..." -ForegroundColor Cyan
icacls "$rutaPersonal" /grant:r "${user}:(OI)(CI)M" /T /Q | Out-Null

Write-Host "[+] ¡Listo! Los permisos de $user han sido corregidos." -ForegroundColor Green