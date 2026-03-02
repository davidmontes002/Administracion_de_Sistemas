$BaseFTP = "C:\inetpub\ftproot"

function Registrar-Grupo-FTP {
    $grupo = Read-Host "Nombre del grupo (ej. Reprobados)"
    $rutaGrupo = "$BaseFTP\grupos\$grupo"

    # 1. Crear carpeta física
    if (-not (Test-Path $rutaGrupo)) {
        New-Item -Path $rutaGrupo -ItemType Directory -Force | Out-Null
        Write-Host "[+] Carpeta de grupo creada en $rutaGrupo" -ForegroundColor Green
    }

    # 2. En Windows, el grupo debe existir en el sistema
    if (-not (Get-LocalGroup -Name $grupo -ErrorAction SilentlyContinue)) {
        New-LocalGroup -Name $grupo
        Write-Host "[+] Grupo local '$grupo' creado." -ForegroundColor Green
    }

    # 3. Dar permisos al grupo sobre su propia carpeta compartida
    icacls "$rutaGrupo" /grant:r "${grupo}:(OI)(CI)M" /T /Q | Out-Null
}

function Registrar-Alumno-FTP {
    $user = Read-Host "Nombre de usuario"
    $pass = Read-Host "Contraseña" -AsSecureString
    $grupo = Read-Host "Grupo al que pertenece (ej. Reprobados)"

    # 1. Crear usuario local y añadir al grupo
    if (-not (Get-LocalUser -Name $user -ErrorAction SilentlyContinue)) {
        New-LocalUser -Name $user -Password $pass -Description "Usuario FTP" | Out-Null
        Add-LocalGroupMember -Group $grupo -Member $user
        Write-Host "[+] Usuario $user creado y añadido a $grupo." -ForegroundColor Green
    }

    # 2. Crear carpetas físicas (Usando LocalUser para el aislamiento de IIS)
    $rutaUser = "$BaseFTP\LocalUser\$user" # <-- CAMBIO CRÍTICO AQUÍ
    $rutaGrupoFisica = "$BaseFTP\grupos\$grupo"
    $rutaPublicFisica = "$BaseFTP\Public"
    
    # Solo necesitamos la carpeta raíz del usuario, no una anidada
    if (-not (Test-Path $rutaUser)) { New-Item -Path $rutaUser -ItemType Directory -Force | Out-Null }
    if (-not (Test-Path $rutaPublicFisica)) { New-Item -Path $rutaPublicFisica -ItemType Directory -Force | Out-Null }

    # 3. AUTOMATIZACIÓN DE PERMISOS (Equivalente a chmod 770)
    Write-Host "[*] Aplicando permisos NTFS..." -ForegroundColor Cyan
    
    # Quitar herencia y dar control total al usuario y al grupo en su carpeta personal
    icacls "$rutaUser" /inheritance:r /grant:r "${user}:(OI)(CI)F" /grant:r "${grupo}:(OI)(CI)F" /T /Q | Out-Null

    # Permisos de solo lectura para la carpeta Public
    # Nota: Usa "Users" si tu Windows Server está en inglés, o "Usuarios" si está en español.
    icacls "$rutaPublicFisica" /grant:r "Usuarios:(OI)(CI)R" /T /Q | Out-Null

    # 4. Configurar Directorios Virtuales
    $siteName = "FTPServer_Admin"
    # Importante: El enlace virtual debe ir dentro del contenedor LocalUser en IIS
    Import-Module WebAdministration
    New-WebVirtualDirectory -Site $siteName -Name "LocalUser/$user/$grupo" -PhysicalPath $rutaGrupoFisica -ErrorAction SilentlyContinue | Out-Null
    New-WebVirtualDirectory -Site $siteName -Name "LocalUser/$user/Public" -PhysicalPath $rutaPublicFisica -ErrorAction SilentlyContinue | Out-Null

    Write-Host "[+] Permisos NTFS y enlaces virtuales automatizados correctamente." -ForegroundColor Green
}

function Configurar-Anonimo-FTP {
    # Cambiado al nombre real de tu sitio
    $siteName = "FTPServer_Admin" 
    Import-Module WebAdministration
    
    # Habilitar autenticación anónima
    Set-WebConfigurationProperty -Filter "/system.ftpServer/security/authentication/anonymousAuthentication" `
                                 -PSPath "IIS:\Sites\$siteName" -Name "enabled" -Value $true
    
    Write-Host "[+] Acceso anónimo configurado (Solo Lectura) en $siteName." -ForegroundColor Green
}