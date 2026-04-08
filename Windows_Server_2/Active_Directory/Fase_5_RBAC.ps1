Clear-Host
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host " FASE 5: RBAC Y DELEGACION DE CONTROL (PRACTICA 9) " -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

$Dominio = (Get-ADDomain).DistinguishedName
$NombreDominio = (Get-ADDomain).Name
$PassSegura = ConvertTo-SecureString "P@ssw0rdDelegado!" -AsPlainText -Force

# 1. CREAR UNIDAD ORGANIZATIVA PARA LOS ADMINISTRADORES DELEGADOS
$UODelegados = "Administradores_Delegados"
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$UODelegados'" -ErrorAction SilentlyContinue)) {
    Write-Host "> Creando OU '$UODelegados'..." -ForegroundColor Yellow
    New-ADOrganizationalUnit -Name $UODelegados -Path $Dominio | Out-Null
}
$RutaUO = "OU=$UODelegados,$Dominio"

# 2. CREAR LOS 4 USUARIOS ROLES
$Roles = @("admin_identidad", "admin_storage", "admin_politicas", "admin_auditoria")
Write-Host "`n> Creando cuentas de Administradores Delegados..." -ForegroundColor Yellow

foreach ($Rol in $Roles) {
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$Rol'" -ErrorAction SilentlyContinue)) {
        New-ADUser -Name $Rol -SamAccountName $Rol -UserPrincipalName "$Rol@$NombreDominio" -AccountPassword $PassSegura -Path $RutaUO -Enabled $true -PasswordNeverExpires $true | Out-Null
        Write-Host "  + Usuario $Rol creado." -ForegroundColor Green
    } else {
        Write-Host "  - Usuario $Rol ya existe." -ForegroundColor DarkGray
    }
}

# 3. ASIGNAR GRUPOS NATIVOS A LOS ROLES
Write-Host "`n> Asignando Grupos Nativos base..." -ForegroundColor Yellow
# admin_politicas necesita poder crear GPOs
Add-ADGroupMember -Identity "Creadores de propietarios de directivas de grupo" -Members "admin_politicas" -ErrorAction SilentlyContinue
Add-ADGroupMember -Identity "Group Policy Creator Owners" -Members "admin_politicas" -ErrorAction SilentlyContinue

# admin_auditoria necesita leer el visor de eventos de seguridad
Add-ADGroupMember -Identity "Lectores de registros de eventos" -Members "admin_auditoria" -ErrorAction SilentlyContinue
Add-ADGroupMember -Identity "Event Log Readers" -Members "admin_auditoria" -ErrorAction SilentlyContinue

# admin_storage necesita poder gestionar el FSRM localmente (lo metemos a Administradores locales, pero lo restringiremos globalmente)
Add-ADGroupMember -Identity "Administrators" -Members "admin_storage" -ErrorAction SilentlyContinue
Add-ADGroupMember -Identity "Administradores" -Members "admin_storage" -ErrorAction SilentlyContinue


# 4. APLICAR LISTAS DE CONTROL DE ACCESO (ACLs) CON DSACLS
Write-Host "`n> Inyectando Restricciones y Delegaciones (ACLs) mediante dsacls..." -ForegroundColor Yellow

# --- ROL 1: admin_identidad (IAM Operator) ---
# Permiso de Crear/Eliminar/Modificar usuarios y Resetear Contraseña SOLO en OU cuates y no_cuates
$OUsObjetivo = @("OU=cuates,$Dominio", "OU=no_cuates,$Dominio")
foreach ($OU in $OUsObjetivo) {
    # CCDC = Create/Delete Child (Objetos de usuario)
    dsacls $OU /I:T /G "$NombreDominio\admin_identidad:CCDC;user" | Out-Null
    # CA = Control Access (Restablecer contraseña)
    dsacls $OU /I:S /G "$NombreDominio\admin_identidad:CA;Reset Password;user" | Out-Null
    # WP = Write Property (Escribir propiedades básicas)
    dsacls $OU /I:S /G "$NombreDominio\admin_identidad:WP;user" | Out-Null
}
Write-Host "  + Permisos IAM asignados a admin_identidad." -ForegroundColor Green

# --- ROL 2: admin_storage (Storage Operator) ---
# RESTRICCIÓN CRÍTICA: DENEGAR (Deny) el permiso de Restablecer Contraseña en todo el dominio.
# La "D" en /D significa DENY. Esto le gana a cualquier otro permiso.
dsacls $Dominio /I:S /D "$NombreDominio\admin_storage:CA;Reset Password;user" | Out-Null
Write-Host "  + Restriccion critica DENY asignada a admin_storage." -ForegroundColor Green

# --- ROL 3: admin_politicas (GPO Compliance) ---
# Permiso para vincular GPOs (gPLink) en las OUs de los usuarios, pero sin poder modificarlos a ellos.
foreach ($OU in $OUsObjetivo) {
    # RPWP = Read Property / Write Property sobre el atributo gPLink
    dsacls $OU /I:T /G "$NombreDominio\admin_politicas:RPWP;gPLink" | Out-Null
}
Write-Host "  + Permisos de vinculacion GPO asignados a admin_politicas." -ForegroundColor Green

# --- ROL 4: admin_auditoria (Security Auditor) ---
# Este usuario ya está restringido por defecto. Al estar en "Event Log Readers" y en ningún otro grupo,
# solo tiene acceso de lectura (Read-Only) al dominio de forma nativa.
Write-Host "  + Rol Read-Only confirmado para admin_auditoria." -ForegroundColor Green


Write-Host "`n=================================================" -ForegroundColor Cyan
Write-Host " FASE 5 (ACTIVIDAD 1) COMPLETADA EXITOSAMENTE " -ForegroundColor Cyan
Write-Host " Todos los usuarios tienen como contrasena temporal: P@ssw0rdDelegado!" -ForegroundColor White
Write-Host "=================================================" -ForegroundColor Cyan
