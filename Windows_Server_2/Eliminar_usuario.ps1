Write-Host "=== ELIMINAR USUARIO FTP ===" -ForegroundColor Cyan
$user = Read-Host "Ingrese el nombre del usuario a eliminar (ej. A1)"

if ([string]::IsNullOrWhiteSpace($user)) {
    Write-Host "[!] Cancelando..." -ForegroundColor Red
    exit
}

Write-Host "[*] 1. Eliminando cuenta local de Windows..." -ForegroundColor Yellow
Remove-LocalUser -Name $user -ErrorAction SilentlyContinue

Write-Host "[*] 2. Limpiando enlaces virtuales en IIS..." -ForegroundColor Yellow
Import-Module WebAdministration
Get-WebVirtualDirectory -Site "FTP" | Where-Object { $_.path -like "/LocalUser/$user/*" } | ForEach-Object {
    Remove-WebVirtualDirectory -Site "FTP" -Application "/" -Name $_.path.TrimStart('/') -ErrorAction SilentlyContinue
}

Write-Host "[*] 3. Destruyendo jaula y archivos físicos..." -ForegroundColor Yellow
$rutaUser = "C:\FTP\LocalUser\$user"
if (Test-Path $rutaUser) {
    # Forzamos el borrado de la carpeta y todo su contenido
    Remove-Item -Path $rutaUser -Recurse -Force
}

Write-Host "[+] El usuario $user ha sido borrado totalmente de la nueva arquitectura." -ForegroundColor Green