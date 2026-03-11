# ==========================================
# SCRIPT INDEPENDIENTE: ELIMINAR USUARIO FTP
# ==========================================

Write-Host "=== ELIMINAR USUARIO FTP (WINDOWS) ===" -ForegroundColor Cyan

Write-Host "`n[*] Usuarios actuales en el servidor:" -ForegroundColor Yellow
$usuarios = Get-ChildItem -Path "C:\inetpub\ftproot\LocalUser" -Directory | Where-Object { $_.Name -ne "Public" } | Select-Object -ExpandProperty Name

if ($usuarios) {
    $usuarios | ForEach-Object { Write-Host "  - $_" }
} else {
    Write-Host "  (No hay usuarios registrados)" -ForegroundColor DarkGray
}

Write-Host ""
$user = Read-Host "Ingrese el nombre del usuario a eliminar"

if ([string]::IsNullOrWhiteSpace($user)) {
    Write-Host "[!] No ingresó ningún nombre. Cancelando..." -ForegroundColor Red
    exit
}

Write-Host "`n[*] 1. Eliminando cuenta local de Windows..." -ForegroundColor Yellow
Remove-LocalUser -Name $user -ErrorAction SilentlyContinue
Write-Host "[-] Cuenta local eliminada (si existía)." -ForegroundColor DarkGray

Write-Host "[*] 2. Limpiando enlaces virtuales en IIS..." -ForegroundColor Yellow
$siteName = "FTPServer_Admin"
Import-Module WebAdministration
Get-WebVirtualDirectory -Site $siteName | Where-Object { $_.path -like "/LocalUser/$user/*" } | ForEach-Object {
    Remove-WebVirtualDirectory -Site $siteName -Application "/" -Name $_.path.TrimStart('/') -ErrorAction SilentlyContinue
}
Write-Host "[-] Enlaces de IIS limpiados." -ForegroundColor DarkGray

Write-Host "[*] 3. Destruyendo jaula y archivos físicos..." -ForegroundColor Yellow
$rutaUser = "C:\inetpub\ftproot\LocalUser\$user"
if (Test-Path $rutaUser) {
    Remove-Item -Path $rutaUser -Recurse -Force
    Write-Host "[-] Carpeta $rutaUser eliminada." -ForegroundColor DarkGray
}

Write-Host "`n[+] Proceso completado. El usuario $user ha sido borrado totalmente." -ForegroundColor Green