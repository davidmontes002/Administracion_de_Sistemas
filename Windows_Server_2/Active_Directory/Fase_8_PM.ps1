#Requires -RunAsAdministrator
Clear-Host
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host " GESTION DE USUARIOS Y PERFILES MOVILES         " -ForegroundColor Cyan
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
    # 1. Crear y compartir carpeta de perfiles
    # -------------------------------------------------------
    Write-Host "`n> 1. Preparando carpeta de perfiles moviles..." -ForegroundColor Yellow

    if (-not (Test-Path $RutaPerfiles)) {
        New-Item -Path $RutaPerfiles -ItemType Directory -Force | Out-Null
    }

    if (-not (Get-SmbShare -Name "Perfiles" -ErrorAction SilentlyContinue)) {
        New-SmbShare -Name "Perfiles" `
            -Path $RutaPerfiles `
            -FullAccess "Administradores" `
            -ChangeAccess "Usuarios autenticados" `
            -ErrorAction SilentlyContinue | Out-Null
        Write-Host "  [+] Carpeta compartida como \\$NombreServidor\Perfiles" -ForegroundColor Green
    } else {
        Write-Host "  [-] Carpeta ya compartida." -ForegroundColor DarkGray
    }

    # Permisos NTFS correctos para perfiles moviles en WS2022
    # CRITICO: CREATOR OWNER con (IO) para que cada usuario
    # tenga control total SOLO de su propia subcarpeta .V6
    icacls $RutaPerfiles /inheritance:r                              2>$null | Out-Null
    icacls $RutaPerfiles /grant "Administradores:(OI)(CI)F"          2>$null | Out-Null
    icacls $RutaPerfiles /grant "SYSTEM:(OI)(CI)F"                   2>$null | Out-Null
    icacls $RutaPerfiles /grant "Usuarios autenticados:(OI)(CI)M"    2>$null | Out-Null
    icacls $RutaPerfiles /grant "CREATOR OWNER:(OI)(CI)(IO)F"        2>$null | Out-Null
    Write-Host "  [+] Permisos NTFS aplicados." -ForegroundColor Green

    # -------------------------------------------------------
    # 2. GPO para configuracion de perfiles moviles
    # -------------------------------------------------------
    Write-Host "`n> 2. Configurando GPO de perfiles moviles..." -ForegroundColor Yellow

    $NombreGPO = "GPO_PerfilesMoviles"
    if (-not (Get-GPO -Name $NombreGPO -ErrorAction SilentlyContinue)) {
        New-GPO -Name $NombreGPO | Out-Null
        New-GPLink -Name $NombreGPO -Target $Dominio | Out-Null

        # Eliminar copia local del perfil al cerrar sesion
        Set-GPRegistryValue -Name $NombreGPO `
            -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" `
            -ValueName "DeleteRoamingCache" `
            -Type DWord -Value 1 | Out-Null

        # Esperar perfil completo antes de mostrar escritorio
        Set-GPRegistryValue -Name $NombreGPO `
            -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" `
            -ValueName "SlowLinkDefaultProfile" `
            -Type DWord -Value 1 | Out-Null

        Write-Host "  [+] GPO '$NombreGPO' creada y vinculada." -ForegroundColor Green
    } else {
        Write-Host "  [-] GPO ya existe." -ForegroundColor DarkGray
    }

    # -------------------------------------------------------
    # 3. Asignar ProfilePath a todos los usuarios existentes
    #
    # IMPORTANTE sobre el sufijo .V6:
    # En Windows 10/11 y Server 2016+ el sistema agrega
    # automaticamente el sufijo .V6 a la carpeta del perfil.
    # El ProfilePath en AD NO debe incluir .V6.
    # Windows lee el path sin sufijo y el agrega .V6 solo.
    # NO pre-crear la carpeta - Windows la crea en el
    # primer login con los permisos correctos automaticamente.
    # Si pre-creas la carpeta puede generar:
    #   - Error "perfil temporal"
    #   - Windows ignora la carpeta y crea jperez.V6 al lado
    # -------------------------------------------------------
    Write-Host "`n> 3. Asignando ruta de perfil (sin .V6)..." -ForegroundColor Yellow
    Write-Host "  [!] Windows agrega .V6 automaticamente en el primer login." -ForegroundColor DarkGray

    $OUs = @("OU=cuates,$Dominio", "OU=no_cuates,$Dominio")
    $totalAsignados = 0

    foreach ($OU in $OUs) {
        $usuarios = Get-ADUser -Filter * -SearchBase $OU -ErrorAction SilentlyContinue
        foreach ($user in $usuarios) {
            # Path SIN .V6 - Windows lo agrega automaticamente
            $rutaPerfil = "\\$NombreServidor\Perfiles\$($user.SamAccountName)"
            Set-ADUser -Identity $user.SamAccountName -ProfilePath $rutaPerfil
            Write-Host "  [+] $($user.SamAccountName) -> $rutaPerfil" -ForegroundColor Green
            $totalAsignados++
        }
    }

    Write-Host "`n  [+] Total: $totalAsignados usuarios con perfil asignado." -ForegroundColor Cyan
    Write-Host "`n[OK] Perfiles moviles configurados." -ForegroundColor Green
    Write-Host "     La carpeta .V6 se creara en el primer inicio de sesion." -ForegroundColor DarkGray
}

# ===========================================================
# FUNCION: AGREGAR NUEVO USUARIO
# Aplica AUTOMATICAMENTE todas las reglas de Fases 3-6
# ===========================================================
function Agregar-NuevoUsuario {
    Write-Host "`n=================================================" -ForegroundColor Cyan
    Write-Host " AGREGAR NUEVO USUARIO AL DOMINIO               " -ForegroundColor Cyan
    Write-Host "=================================================" -ForegroundColor Cyan

    # -------------------------------------------------------
    # Recopilar datos del nuevo usuario
    # -------------------------------------------------------
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

    $grupoFGPP       = "Grupo_FGPP_Estandar"
    $OU_Ruta         = "OU=$OU_Nombre,$Dominio"
    $rutaCarpetaRed  = "\\$NombreServidor\Usuarios\$usuario"

    # ProfilePath SIN .V6
    # Windows Server 2022 / Windows 10-11 usan .V6
    # El sistema agrega el sufijo automaticamente en el
    # primer inicio de sesion. Poner .V6 manualmente causa
    # conflictos y errores de perfil temporal.
    $rutaPerfil = "\\$NombreServidor\Perfiles\$usuario"

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
    # 2. Crear carpeta HOME y aplicar cuota FSRM
    # -------------------------------------------------------
    Write-Host "`n> 2. Creando carpeta HOME y aplicando cuota FSRM..." -ForegroundColor Yellow

    $rutaCarpetaFisica = "$RutaHome\$usuario"
    if (-not (Test-Path $rutaCarpetaFisica)) {
        New-Item -Path $rutaCarpetaFisica -ItemType Directory -Force | Out-Null
    }

    icacls $rutaCarpetaFisica /grant "$usuario`:(OI)(CI)F" /T 2>$null | Out-Null
    Write-Host "  [+] Carpeta HOME: $rutaCarpetaFisica" -ForegroundColor Green

    $plantilla = if ($OU_Nombre -eq "cuates") { "Cuota_10MB" } else { "Cuota_5MB" }
    if (-not (Get-FsrmQuota -Path $rutaCarpetaFisica -ErrorAction SilentlyContinue)) {
        New-FsrmQuota -Path $rutaCarpetaFisica -Template $plantilla | Out-Null
        Write-Host "  [+] Cuota ${cuotaMB}MB aplicada." -ForegroundColor Green
    } else {
        Write-Host "  [-] Cuota ya existe." -ForegroundColor DarkGray
    }

    # -------------------------------------------------------
    # 3. Aplicar LogonHours (Fase 3)
    # -------------------------------------------------------
    Write-Host "`n> 3. Aplicando horario de acceso (LogonHours)..." -ForegroundColor Yellow

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
                    if ($hora -ge $InicioUTC -or $hora -lt $FinUTC) { $dentro = $true }
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
    # 4. Agregar a grupo FGPP (Fase 6)
    # -------------------------------------------------------
    Write-Host "`n> 4. Agregando a grupo FGPP..." -ForegroundColor Yellow

    Add-ADGroupMember -Identity $grupoFGPP -Members $usuario -ErrorAction SilentlyContinue
    Write-Host "  [+] Agregado a '$grupoFGPP' (FGPP min 8 chars)." -ForegroundColor Green

    # -------------------------------------------------------
    # 5. Perfil movil
    #
    # CORRECCION: NO pre-crear la carpeta del perfil.
    # En Windows Server 2022 + clientes Win10/11:
    # - El ProfilePath se guarda en AD sin .V6
    # - En el PRIMER LOGIN el sistema crea automaticamente
    #   la carpeta "usuario.V6" con los permisos correctos
    # - Si pre-creamos "usuario" (sin .V6), Windows la ignora
    #   y crea "usuario.V6" al lado → dos carpetas, confusion
    # - Si pre-creamos "usuario.V6", puede fallar ownership
    #   y generar el error "perfil temporal"
    # CONCLUSION: Solo asignar el path en AD y dejar que
    # Windows cree la carpeta en el primer login.
    # -------------------------------------------------------
    Write-Host "`n> 5. Perfil movil asignado en AD..." -ForegroundColor Yellow

    if (Test-Path $RutaPerfiles) {
        Write-Host "  [+] ProfilePath: $rutaPerfil" -ForegroundColor Green
        Write-Host "  [!] Carpeta .V6 se creara en el primer inicio de sesion." -ForegroundColor DarkGray
    } else {
        Write-Host "  [!] La carpeta C:\Perfiles no existe aun." -ForegroundColor Yellow
        Write-Host "      Ejecuta la opcion 2 para configurar perfiles moviles." -ForegroundColor Yellow
    }

    # -------------------------------------------------------
    # 6. Resumen
    # -------------------------------------------------------
    Write-Host "`n=================================================" -ForegroundColor Green
    Write-Host " USUARIO CREADO EXITOSAMENTE                    " -ForegroundColor Green
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host "  Usuario    : $usuario"            -ForegroundColor White
    Write-Host "  Nombre     : $nombre"             -ForegroundColor White
    Write-Host "  OU         : $OU_Nombre"          -ForegroundColor White
    Write-Host "  Horario    : ${horaInicio}:00 - ${horaFin}:00" -ForegroundColor White
    Write-Host "  Cuota      : ${cuotaMB}MB en H:"  -ForegroundColor White
    Write-Host "  FGPP       : Min 8 chars"         -ForegroundColor White
    Write-Host "  Home (H:)  : $rutaCarpetaRed"     -ForegroundColor White
    Write-Host "  Perfil AD  : $rutaPerfil"         -ForegroundColor White
    Write-Host "  Perfil real: $rutaPerfil.V6 (creado en primer login)" -ForegroundColor DarkGray
    Write-Host "=================================================" -ForegroundColor Green

    Write-Host "`nReglas aplicadas automaticamente:" -ForegroundColor Cyan
    Write-Host "  [OK] Creado en OU=$OU_Nombre (AppLocker via GPO hereda)" -ForegroundColor Green
    Write-Host "  [OK] LogonHours ${horaInicio}:00-${horaFin}:00 (Fase 3)" -ForegroundColor Green
    Write-Host "  [OK] Cuota ${cuotaMB}MB FSRM en H: (Fase 4)"             -ForegroundColor Green
    Write-Host "  [OK] FGPP min 8 chars (Fase 6)"                          -ForegroundColor Green
    Write-Host "  [OK] ProfilePath en AD (perfil .V6 en primer login)"     -ForegroundColor Green
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
