Import-Module WebAdministration
$siteName = "FTPServer_Admin"
$BaseFTP = "C:\inetpub\ftproot"

Write-Host "=== INICIANDO REPARACIÓN DE ENLACES ===" -ForegroundColor Cyan

# Obtener todas las carpetas de usuarios reales
$usuarios = Get-ChildItem -Path "$BaseFTP\LocalUser" -Directory | Where-Object { $_.Name -ne "Public" }

foreach ($carpeta in $usuarios) {
    $user = $carpeta.Name
    Write-Host "`n[*] Revisando usuario: $user" -ForegroundColor Yellow

    # 1. Reparar el enlace a la carpeta Public
    $rutaVDirPublic = "LocalUser/$user/Public"
    if (-not (Get-WebVirtualDirectory -Site $siteName -Name $rutaVDirPublic -ErrorAction SilentlyContinue)) {
        New-WebVirtualDirectory -Site $siteName -Name $rutaVDirPublic -PhysicalPath "$BaseFTP\Public" -Force | Out-Null
        Write-Host "  [+] Enlace 'Public' reconstruido." -ForegroundColor Green
    } else {
        Write-Host "  [-] Enlace 'Public' intacto." -ForegroundColor DarkGray
    }

    # 2. Reparar el enlace a su Grupo
    $gruposFTP = @("Reprobados", "Recursadores")
    foreach ($grupo in $gruposFTP) {
        $esMiembro = $false
        try {
            $miembros = Get-LocalGroupMember -Group $grupo -ErrorAction Stop | Select-Object -ExpandProperty Name
            if ($miembros -match $user) { $esMiembro = $true }
        } catch {}

        if ($esMiembro) {
            $rutaVDirGrupo = "LocalUser/$user/$grupo"
            if (-not (Get-WebVirtualDirectory -Site $siteName -Name $rutaVDirGrupo -ErrorAction SilentlyContinue)) {
                New-WebVirtualDirectory -Site $siteName -Name $rutaVDirGrupo -PhysicalPath "$BaseFTP\grupos\$grupo" -Force | Out-Null
                Write-Host "  [+] Enlace al grupo '$grupo' reconstruido." -ForegroundColor Green
            } else {
                Write-Host "  [-] Enlace al grupo '$grupo' intacto." -ForegroundColor DarkGray
            }
        }
    }
}

Write-Host "`n[+] REPARACIÓN COMPLETADA! Todos los accesos han sido restaurados." -ForegroundColor Cyan