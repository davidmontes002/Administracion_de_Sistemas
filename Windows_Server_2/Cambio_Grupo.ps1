# ==========================================
# SCRIPT INDEPENDIENTE: CAMBIAR GRUPO FTP
# ==========================================

Write-Host "=== MIGRACIÓN DE GRUPO FTP ===" -ForegroundColor Cyan
$user = Read-Host "Nombre del usuario (ej. David)"
$viejoGrupo = Read-Host "Grupo actual a borrar (ej. Reprobados)"
$nuevoGrupo = Read-Host "Nuevo grupo a asignar (ej. Recursadores)"

$siteName = "FTPServer_Admin"
$BaseFTP = "C:\inetpub\ftproot"
$rutaNuevoGrupoFisica = "$BaseFTP\grupos\$nuevoGrupo"

Write-Host "`n[*] 1. Actualizando membresía de grupos en Windows..." -ForegroundColor Cyan

# Quitar al usuario del grupo viejo
try {
    Remove-LocalGroupMember -Group $viejoGrupo -Member $user -ErrorAction Stop
    Write-Host "[-] Usuario $user removido del grupo local '$viejoGrupo'." -ForegroundColor Yellow
} catch {
    Write-Host "[!] Nota: El usuario no pertenecía al grupo '$viejoGrupo' o el grupo no existe." -ForegroundColor DarkYellow
}

# Añadir al usuario al grupo nuevo
try {
    Add-LocalGroupMember -Group $nuevoGrupo -Member $user -ErrorAction Stop
    Write-Host "[+] Usuario $user añadido al grupo local '$nuevoGrupo'." -ForegroundColor Green
} catch {
    Write-Host "[!] Nota: El usuario ya pertenece al grupo '$nuevoGrupo' o el grupo no ha sido creado." -ForegroundColor DarkYellow
}

Write-Host "`n[*] 2. Actualizando enlaces virtuales en IIS..." -ForegroundColor Cyan
Import-Module WebAdministration

# 1. Eliminar el enlace virtual del grupo viejo
Remove-WebVirtualDirectory -Site $siteName -Name "LocalUser/$user/$viejoGrupo" -ErrorAction SilentlyContinue | Out-Null
Write-Host "[-] Enlace a '$viejoGrupo' eliminado de la jaula del usuario." -ForegroundColor Yellow

# 2. Verificar que exista la carpeta física del nuevo grupo (por seguridad)
if (-not (Test-Path $rutaNuevoGrupoFisica)) {
    New-Item -Path $rutaNuevoGrupoFisica -ItemType Directory -Force | Out-Null
}

# 3. Crear el enlace virtual hacia el grupo nuevo
New-WebVirtualDirectory -Site $siteName -Name "LocalUser/$user/$nuevoGrupo" -PhysicalPath $rutaNuevoGrupoFisica -ErrorAction SilentlyContinue | Out-Null
Write-Host "[+] Nuevo enlace a '$nuevoGrupo' creado en la jaula del usuario." -ForegroundColor Green

Write-Host "`n[+] ¡MIGRACIÓN EXITOSA! El usuario $user ahora pertenece exclusivamente a $nuevoGrupo." -ForegroundColor Cyan