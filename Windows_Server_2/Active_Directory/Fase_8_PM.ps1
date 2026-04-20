#Requires -RunAsAdministrator
Clear-Host
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host " FASE 8: GESTION DE USUARIOS Y PERFILES MOVILES " -ForegroundColor Cyan
Write-Host " Windows Server 2022 - practica.local           " -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# ----------------------------------------------------------
# VARIABLES BASE
# ----------------------------------------------------------
$Dominio        = (Get-ADDomain).DistinguishedName
$NombreDominio  = (Get-ADDomain).Name
$DominioDNS     = (Get-ADDomain).DNSRoot
$NombreServidor = $env:COMPUTERNAME
$RutaHome       = "C:\Shares\Usuarios"
$RutaPerfiles   = "C:\Perfiles"

# SIDs universales (funcionan independiente del idioma del SO)
# S-1-5-11 = Usuarios autenticados (Authenticated Users)
# S-1-5-32-544 = Administradores (Administrators)
# S-1-3-0 = Creador/Propietario (CREATOR OWNER)
# S-1-5-18 = SYSTEM
$SID_UsuariosAuth  = "S-1-5-11"
$SID_Admins        = "S-1-5-32-544"
$SID_CreatorOwner  = "S-1-3-0"
$SID_System        = "S-1-5-18"

Write-Host "`n  Dominio  : $DominioDNS" -ForegroundColor DarkGray
Write-Host "  Servidor : $NombreServidor`n" -ForegroundColor DarkGray

# ----------------------------------------------------------
# MENU PRINCIPAL
# ----------------------------------------------------------
Write-Host "Que deseas hacer?" -ForegroundColor Yellow
Write-Host "  1. Agregar nuevo usuario (cuates o no_cuates)"
Write-Host "  2. Configurar perfiles moviles (todos los usuarios)"
Write-Host "  3. Ambos"
$opcion = Read-Host "Selecciona (1, 2 o 3)"

# ===========================================================
# FUNCION: CONFIGURAR PERFILES MOVILES
# ===========================================================
function Configurar-PerfilesMoviles {
    Write-Host "`n=================================================" -ForegroundColor Cyan
    Write-Host " CONFIGURANDO PERFILES MOVILES                  " -ForegroundColor Cyan
    Write-Host "=================================================" -ForegroundColor Cyan

    # -------------------------------------------------------
    # 1. Crear carpeta de perfiles
    # -------------------------------------------------------
    Write-Host "`n> 1. Preparando carpeta C:\Perfiles..." -ForegroundColor Yellow

    if (-not (Test-Path $RutaPerfiles)) {
        New-Item -Path $RutaPerfiles -ItemType Directory -Force | Out-Null
    }
    Write-Host "  [+] Carpeta existe: $RutaPerfiles" -ForegroundColor Green

    # -------------------------------------------------------
    # 2. Compartir carpeta usando SIDs (idioma-neutral)
    #
    # APRENDIDO: New-SmbShare con nombres de grupo en español
    # falla en algunos entornos. Usar SIDs garantiza que
    # funciona independiente del idioma del SO.
    # -------------------------------------------------------
    Write-Host "`n> 2. Compartiendo carpeta de perfiles..." -ForegroundColor Yellow

    # Eliminar share anterior si existe para recrearlo limpio
    Remove-SmbShare -Name "Perfiles" -Force -ErrorAction SilentlyContinue

    # Resolver nombres desde SIDs para New-SmbShare
    $nombreAdmins       = (New-Object System.Security.Principal.SecurityIdentifier($SID_Admins)).Translate([System.Security.Principal.NTAccount]).Value
    $nombreUsuariosAuth = (New-Object System.Security.Principal.SecurityIdentifier($SID_UsuariosAuth)).Translate([System.Security.Principal.NTAccount]).Value

    New-SmbShare `
        -Name         "Perfiles" `
        -Path         $RutaPerfiles `
        -FullAccess   $nombreAdmins `
        -ChangeAccess $nombreUsuariosAuth `
        -ErrorAction  Stop | Out-Null

    Write-Host "  [+] Compartida como \\$NombreServidor\Perfiles" -ForegroundColor Green
    Write-Host "      Acceso completo : $nombreAdmins" -ForegroundColor DarkGray
    Write-Host "      Cambio          : $nombreUsuariosAuth" -ForegroundColor DarkGray

    # -------------------------------------------------------
    # 3. Permisos NTFS con SIDs (idioma-neutral)
    #
    # Estructura correcta para perfiles moviles en WS2022:
    # - Admins y SYSTEM: Control total heredable
    # - Usuarios autenticados: RX + WD + AD (leer, crear carpetas)
    #   SOLO en este nivel, NO heredable (sin OI/CI)
    #   Esto permite que cada usuario cree SU carpeta .V6
    #   pero no acceda a las carpetas de otros usuarios
    # - CREATOR OWNER: Control total heredable (IO)
    #   Esto da al usuario control total de SU carpeta .V6
    #   una vez que la crea
    #
    # SIN esta configuracion ocurre el error:
    # "Se le ha conectado con un perfil temporal"
    # porque Windows no puede crear la carpeta .V6
    # -------------------------------------------------------
    Write-Host "`n> 3. Aplicando permisos NTFS correctos..." -ForegroundColor Yellow

    # Quitar herencia y permisos existentes
    icacls $RutaPerfiles /inheritance:r 2>$null | Out-Null

    # Admins: Control total, heredable
    icacls $RutaPerfiles /grant "*${SID_Admins}:(OI)(CI)F" 2>$null | Out-Null

    # SYSTEM: Control total, heredable
    icacls $RutaPerfiles /grant "*${SID_System}:(OI)(CI)F" 2>$null | Out-Null

    # Usuarios autenticados: RX + WD + AD en este nivel solamente
    # RX = Leer y ejecutar, WD = Crear carpetas, AD = Agregar datos
    # Sin (OI)(CI) para que NO se propague a subcarpetas
    # Esto permite crear la carpeta .V6 pero no ver otras
    icacls $RutaPerfiles /grant "*${SID_UsuariosAuth}:(RX,WD,AD)" 2>$null | Out-Null

    # CREATOR OWNER: Control total, solo heredable (IO = inherit only)
    # El usuario que crea su carpeta .V6 obtiene control total de ella
    icacls $RutaPerfiles /grant "*${SID_CreatorOwner}:(OI)(CI)(IO)F" 2>$null | Out-Null

    Write-Host "  [+] Permisos NTFS aplicados con SIDs universales." -ForegroundColor Green

    # -------------------------------------------------------
    # 4. Verificar que LogonHours no bloquee el acceso
    #    durante la prueba (horas irrestrictas = 21 bytes 0xFF)
    #
    # NOTA: Los LogonHours de Fase 3 aplican restricciones
    # horarias. Si el usuario intenta iniciar sesion fuera
    # de su horario, el perfil no se puede crear/sincronizar.
    # Los LogonHours correctos ya estan aplicados por Fase 3.
    # Esta verificacion es solo informativa.
    # -------------------------------------------------------
    Write-Host "`n> 4. Verificando LogonHours de usuarios..." -ForegroundColor Yellow

    $OUs = @("OU=cuates,$Dominio", "OU=no_cuates,$Dominio")
    foreach ($OU in $OUs) {
        $usuarios = Get-ADUser -Filter * -SearchBase $OU `
                    -Properties logonHours -ErrorAction SilentlyContinue
        foreach ($user in $usuarios) {
            if ($null -eq $user.logonHours) {
                Write-Host "  [!] $($user.SamAccountName): sin restriccion horaria" -ForegroundColor Yellow
            } else {
                Write-Host "  [OK] $($user.SamAccountName): horario configurado" -ForegroundColor Green
            }
        }
    }

    # -------------------------------------------------------
    # 5. GPO para perfiles moviles
    # -------------------------------------------------------
    Write-Host "`n> 5. Configurando GPO de perfiles moviles..." -ForegroundColor Yellow

    $NombreGPO = "GPO_PerfilesMoviles"
    if (-not (Get-GPO -Name $NombreGPO -ErrorAction SilentlyContinue)) {
        New-GPO -Name $NombreGPO | Out-Null
        New-GPLink -Name $NombreGPO -Target $Dominio | Out-Null

        # Eliminar copia local al cerrar sesion
        Set-GPRegistryValue -Name $NombreGPO `
            -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" `
            -ValueName "DeleteRoamingCache" -Type DWord -Value 1 | Out-Null

        # Esperar perfil completo antes de mostrar escritorio
        Set-GPRegistryValue -Name $NombreGPO `
            -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" `
            -ValueName "SlowLinkDefaultProfile" -Type DWord -Value 1 | Out-Null

        # Tiempo de espera para perfil lento (segundos)
        Set-GPRegistryValue -Name $NombreGPO `
            -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" `
            -ValueName "SlowLinkTimeOut" -Type DWord -Value 30000 | Out-Null

        Write-Host "  [+] GPO '$NombreGPO' creada y vinculada." -ForegroundColor Green
    } else {
        Write-Host "  [-] GPO ya existe." -ForegroundColor DarkGray
    }

    # -------------------------------------------------------
    # 6. Asignar ProfilePath a todos los usuarios
    #
    # CRITICO: SIN sufijo .V6 en el ProfilePath.
    # Windows 10/11 y Server 2022 agregan .V6 automaticamente.
    # Si pones .V6 manualmente o pre-creas la carpeta:
    #   → Error "perfil temporal" al iniciar sesion
    #   → Windows crea usuario.V6 ignorando tu carpeta
    # -------------------------------------------------------
    Write-Host "`n> 6. Asignando ProfilePath a usuarios (sin .V6)..." -ForegroundColor Yellow
    Write-Host "  [!] Windows agrega .V6 automaticamente en el primer login." -ForegroundColor DarkGray

    $totalAsignados = 0
    foreach ($OU in $OUs) {
        $usuarios = Get-ADUser -Filter * -SearchBase $OU -ErrorAction SilentlyContinue
        foreach ($user in $usuarios) {
            $rutaPerfil = "\\$NombreServidor\Perfiles\$($user.SamAccountName)"
            Set-ADUser -Identity $user.SamAccountName -ProfilePath $rutaPerfil
            Write-Host "  [+] $($user.SamAccountName) -> $rutaPerfil" -ForegroundColor Green
            $totalAsignados++
        }
    }

    Write-Host "`n  [+] Total: $totalAsignados usuarios con perfil asignado." -ForegroundColor Cyan
    Write-Host "`n[OK] Perfiles moviles configurados correctamente." -ForegroundColor Green
    Write-Host "     Primer login del usuario: Windows crea .V6 automaticamente." -ForegroundColor DarkGray
    Write-Host "     Segundo login: carga el perfil guardado en el servidor." -ForegroundColor DarkGray
}

# ===========================================================
# FUNCION: AGREGAR NUEVO USUARIO
# Aplica AUTOMATICAMENTE todas las reglas de Fases 3-6
# ===========================================================
function Agregar-NuevoUsuario {
    Write-Host "`n=================================================" -ForegroundColor Cyan
    Write-Host " AGREGAR NUEVO USUARIO AL DOMINIO               " -ForegroundColor Cyan
    Write-Host "=================================================" -ForegroundColor Cyan

    $nombre     = Read-Host "`nNombre completo (ej. Juan Perez)"
    $usuario    = Read-Host "Nombre de usuario (ej. jperez)"
    $contrasena = Read-Host "Contrasena (min 8 chars, mayus, minus, numero)"

    Write-Host "`nGrupo del usuario:"
    Write-Host "  1. cuates     (horario 8AM-3PM, cuota 10MB)"
    Write-Host "  2. no_cuates  (horario 3PM-2AM, cuota 5MB)"
    $grupo = Read-Host "Selecciona (1 o 2)"

    if ($grupo -eq "1") {
        $OU_Nombre  = "cuates"
        $cuotaMB    = 10
        $horaInicio = 8
        $horaFin    = 15
    } else {
        $OU_Nombre  = "no_cuates"
        $cuotaMB    = 5
        $horaInicio = 15
        $horaFin    = 2
    }

    $grupoFGPP      = "Grupo_FGPP_Estandar"
    $OU_Ruta        = "OU=$OU_Nombre,$Dominio"
    $rutaCarpetaRed = "\\$NombreServidor\Usuarios\$usuario"
    $rutaPerfil     = "\\$NombreServidor\Perfiles\$usuario"

    # -------------------------------------------------------
    # 1. Crear usuario en AD
    # -------------------------------------------------------
    Write-Host "`n> 1. Creando usuario en Active Directory..." -ForegroundColor Yellow

    if (Get-ADUser -Filter "SamAccountName -eq '$usuario'" -ErrorAction SilentlyContinue) {
        Write-Host "  [-] El usuario '$usuario' ya existe." -ForegroundColor Red
        return
    }

    $passSegura = ConvertTo-SecureString $contrasena -AsPlainText -Force

    New-ADUser `
        -Name                 $nombre `
        -SamAccountName       $usuario `
        -UserPrincipalName    "$usuario@$DominioDNS" `
        -AccountPassword      $passSegura `
        -Path                 $OU_Ruta `
        -Enabled              $true `
        -PasswordNeverExpires $true `
        -HomeDrive            "H:" `
        -HomeDirectory        $rutaCarpetaRed `
        -ProfilePath          $rutaPerfil | Out-Null

    Write-Host "  [+] Usuario '$usuario' creado en OU=$OU_Nombre." -ForegroundColor Green

    # -------------------------------------------------------
    # 2. Crear carpeta HOME con permisos correctos
    # -------------------------------------------------------
    Write-Host "`n> 2. Creando carpeta HOME..." -ForegroundColor Yellow

    $rutaCarpetaFisica = "$RutaHome\$usuario"
    if (-not (Test-Path $rutaCarpetaFisica)) {
        New-Item -Path $rutaCarpetaFisica -ItemType Directory -Force | Out-Null
    }

    # Permisos: el usuario tiene control total de su propia carpeta
    icacls $rutaCarpetaFisica /grant "${usuario}:(OI)(CI)F" /T 2>$null | Out-Null
    icacls $rutaCarpetaFisica /grant "*${SID_Admins}:(OI)(CI)F" /T 2>$null | Out-Null
    icacls $rutaCarpetaFisica /grant "*${SID_System}:(OI)(CI)F" /T 2>$null | Out-Null
    Write-Host "  [+] Carpeta HOME: $rutaCarpetaFisica" -ForegroundColor Green

    # -------------------------------------------------------
    # 3. Aplicar cuota FSRM
    # -------------------------------------------------------
    Write-Host "`n> 3. Aplicando cuota FSRM..." -ForegroundColor Yellow

    $plantilla = if ($OU_Nombre -eq "cuates") { "Cuota_10MB" } else { "Cuota_5MB" }
    if (-not (Get-FsrmQuota -Path $rutaCarpetaFisica -ErrorAction SilentlyContinue)) {
        New-FsrmQuota -Path $rutaCarpetaFisica -Template $plantilla | Out-Null
        Write-Host "  [+] Cuota ${cuotaMB}MB aplicada en H:." -ForegroundColor Green
    } else {
        Write-Host "  [-] Cuota ya existe." -ForegroundColor DarkGray
    }

    # -------------------------------------------------------
    # 4. Aplicar LogonHours (Fase 3)
    # -------------------------------------------------------
    Write-Host "`n> 4. Aplicando horario de acceso..." -ForegroundColor Yellow

    function Convertir-HorarioABytes {
        param([int]$HoraInicioLocal, [int]$HoraFinLocal)
        [byte[]]$horasArray = New-Object byte[] 21
        $OffsetUTC = [System.TimeZoneInfo]::Local.BaseUtcOffset.Hours
        $InicioUTC = ($HoraInicioLocal - $OffsetUTC + 24) % 24
        $FinUTC    = ($HoraFinLocal    - $OffsetUTC + 24) % 24
        for ($dia = 0; $dia -lt 7; $dia++) {
            for ($hora = 0; $hora -lt 24; $hora++) {
                $dentro = $false
                if ($InicioUTC -lt $FinUTC) {
                    if ($hora -ge $InicioUTC -and $hora -lt $FinUTC) { $dentro = $true }
                } else {
                    if ($hora -ge $InicioUTC -or  $hora -lt $FinUTC) { $dentro = $true }
                }
                if ($dentro) {
                    $byteIndex = ($dia * 3) + [math]::Floor($hora / 8)
                    $bitIndex  = $hora % 8
                    $horasArray[$byteIndex] = $horasArray[$byteIndex] -bor (1 -shl $bitIndex)
                }
            }
        }
        return $horasArray
    }

    [byte[]]$horario = Convertir-HorarioABytes -HoraInicioLocal $horaInicio -HoraFinLocal $horaFin
    Set-ADUser -Identity $usuario -Replace @{logonHours = $horario}
    Write-Host "  [+] Horario: ${horaInicio}:00 - ${horaFin}:00" -ForegroundColor Green

    # -------------------------------------------------------
    # 5. Agregar a grupo FGPP
    # -------------------------------------------------------
    Write-Host "`n> 5. Agregando a grupo FGPP..." -ForegroundColor Yellow
    Add-ADGroupMember -Identity $grupoFGPP -Members $usuario -ErrorAction SilentlyContinue
    Write-Host "  [+] Agregado a '$grupoFGPP' (min 8 chars)." -ForegroundColor Green

    # -------------------------------------------------------
    # 6. Perfil movil: solo asignar el path en AD
    #    NO pre-crear la carpeta (Windows la crea con .V6)
    # -------------------------------------------------------
    Write-Host "`n> 6. Verificando configuracion de perfil movil..." -ForegroundColor Yellow

    if (Test-Path $RutaPerfiles) {
        Write-Host "  [+] ProfilePath asignado: $rutaPerfil" -ForegroundColor Green
        Write-Host "  [!] Windows creara automaticamente: $rutaPerfil.V6" -ForegroundColor DarkGray
        Write-Host "      en el PRIMER inicio de sesion del usuario." -ForegroundColor DarkGray
    } else {
        Write-Host "  [!] C:\Perfiles no existe. Ejecuta opcion 2 primero." -ForegroundColor Yellow
    }

    # -------------------------------------------------------
    # 7. Resumen completo
    # -------------------------------------------------------
    Write-Host "`n=================================================" -ForegroundColor Green
    Write-Host " USUARIO CREADO EXITOSAMENTE                    " -ForegroundColor Green
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host "  Usuario    : $usuario"                                         -ForegroundColor White
    Write-Host "  Nombre     : $nombre"                                          -ForegroundColor White
    Write-Host "  OU         : $OU_Nombre"                                       -ForegroundColor White
    Write-Host "  Horario    : ${horaInicio}:00 - ${horaFin}:00"                -ForegroundColor White
    Write-Host "  Cuota H:   : ${cuotaMB}MB (no .mp3/.mp4/.exe/.msi)"           -ForegroundColor White
    Write-Host "  FGPP       : Min 8 chars + bloqueo 3 intentos/30min"          -ForegroundColor White
    Write-Host "  Home (H:)  : $rutaCarpetaRed"                                 -ForegroundColor White
    Write-Host "  Perfil AD  : $rutaPerfil"                                      -ForegroundColor White
    Write-Host "  Perfil real: $rutaPerfil.V6 (primer login)"                   -ForegroundColor DarkGray
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host " Reglas aplicadas automaticamente:" -ForegroundColor Cyan
    Write-Host "  [OK] OU=$OU_Nombre → AppLocker GPO hereda (Fase 4)" -ForegroundColor Green
    Write-Host "  [OK] LogonHours ${horaInicio}:00-${horaFin}:00 (Fase 3)"     -ForegroundColor Green
    Write-Host "  [OK] Cuota ${cuotaMB}MB FSRM en H: (Fase 4)"                 -ForegroundColor Green
    Write-Host "  [OK] Bloqueo .mp3/.mp4/.exe/.msi en H: (Fase 4)"             -ForegroundColor Green
    Write-Host "  [OK] FGPP min 8 chars (Fase 6)"                               -ForegroundColor Green
    Write-Host "  [OK] Perfil movil .V6 (Fase 8)"                               -ForegroundColor Green
}

# ===========================================================
# EJECUTAR SEGUN OPCION
# ===========================================================
switch ($opcion) {
    "1" { Agregar-NuevoUsuario }
    "2" { Configurar-PerfilesMoviles }
    "3" {
        Configurar-PerfilesMoviles
        Write-Host ""
        Agregar-NuevoUsuario
    }
    default { Write-Host "Opcion invalida." -ForegroundColor Red }
}
}
