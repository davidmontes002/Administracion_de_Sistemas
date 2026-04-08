Clear-Host
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host " FASE 6: FGPP Y AUDITORIA DE EVENTOS (PRACTICA 9)" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

$Dominio = (Get-ADDomain).DistinguishedName

# 1. CREACION DE GRUPOS DE SEGURIDAD PARA FGPP (FGPP no se aplica a OUs, se aplica a Grupos)
Write-Host "`n> 1. Creando Grupos de Seguridad para politicas de contrasenas..." -ForegroundColor Yellow
$GrupoAdmins = "Grupo_FGPP_Admins"
$GrupoEstandar = "Grupo_FGPP_Estandar"

if (-not (Get-ADGroup -Filter "Name -eq '$GrupoAdmins'" -ErrorAction SilentlyContinue)) {
    New-ADGroup -Name $GrupoAdmins -GroupCategory Security -GroupScope Global -Path "CN=Users,$Dominio"
}
if (-not (Get-ADGroup -Filter "Name -eq '$GrupoEstandar'" -ErrorAction SilentlyContinue)) {
    New-ADGroup -Name $GrupoEstandar -GroupCategory Security -GroupScope Global -Path "CN=Users,$Dominio"
}

# Meter usuarios a los grupos
$Admins = Get-ADUser -Filter * -SearchBase "OU=Administradores_Delegados,$Dominio"
foreach ($admin in $Admins) { Add-ADGroupMember -Identity $GrupoAdmins -Members $admin -ErrorAction SilentlyContinue }

$Estandar1 = Get-ADUser -Filter * -SearchBase "OU=cuates,$Dominio"
$Estandar2 = Get-ADUser -Filter * -SearchBase "OU=no_cuates,$Dominio"
foreach ($usr in $Estandar1) { Add-ADGroupMember -Identity $GrupoEstandar -Members $usr -ErrorAction SilentlyContinue }
foreach ($usr in $Estandar2) { Add-ADGroupMember -Identity $GrupoEstandar -Members $usr -ErrorAction SilentlyContinue }


# 2. CREAR Y APLICAR FGPP (Directivas de Contraseña Ajustada y Bloqueo MFA)
Write-Host "> 2. Generando Directivas FGPP (12 chars VIP / 8 chars Estandar)..." -ForegroundColor Yellow

if (-not (Get-ADFineGrainedPasswordPolicy -Filter "Name -eq 'FGPP_Admins_12'" -ErrorAction SilentlyContinue)) {
    # NOTA: Aqui incluimos el umbral de 3 fallos = 30 minutos de bloqueo que pide la Actividad 3
    New-ADFineGrainedPasswordPolicy -Name "FGPP_Admins_12" -Precedence 10 -MinPasswordLength 12 -MaxPasswordAge (New-TimeSpan -Days 90) -MinPasswordAge (New-TimeSpan -Days 1) -PasswordHistoryCount 5 -ComplexityEnabled $true -LockoutDuration (New-TimeSpan -Minutes 30) -LockoutObservationWindow (New-TimeSpan -Minutes 15) -LockoutThreshold 3
    Add-ADFineGrainedPasswordPolicySubject -Identity "FGPP_Admins_12" -Subjects $GrupoAdmins
    Write-Host "  + FGPP de 12 caracteres (y bloqueo de 30min) aplicada a Admins." -ForegroundColor Green
}

if (-not (Get-ADFineGrainedPasswordPolicy -Filter "Name -eq 'FGPP_Estandar_8'" -ErrorAction SilentlyContinue)) {
    New-ADFineGrainedPasswordPolicy -Name "FGPP_Estandar_8" -Precedence 20 -MinPasswordLength 8 -MaxPasswordAge (New-TimeSpan -Days 90) -MinPasswordAge (New-TimeSpan -Days 1) -PasswordHistoryCount 3 -ComplexityEnabled $true -LockoutDuration (New-TimeSpan -Minutes 30) -LockoutObservationWindow (New-TimeSpan -Minutes 15) -LockoutThreshold 3
    Add-ADFineGrainedPasswordPolicySubject -Identity "FGPP_Estandar_8" -Subjects $GrupoEstandar
    Write-Host "  + FGPP de 8 caracteres (y bloqueo de 30min) aplicada a Usuarios Estandar." -ForegroundColor Green
}


# 3. HABILITAR LA AUDITORIA DE EVENTOS CON AUDITPOL
Write-Host "`n> 3. Hardening de Auditoria: Encendiendo rastreo de eventos..." -ForegroundColor Yellow
# Lanzamos comandos tanto en ingles como en espanol para evitar errores de idioma en el Server Core
auditpol /set /subcategory:"Logon" /success:enable /failure:enable 2>$null | Out-Null
auditpol /set /subcategory:"Inicio de sesión" /success:enable /failure:enable 2>$null | Out-Null
auditpol /set /subcategory:"Object Access" /success:enable /failure:enable 2>$null | Out-Null
auditpol /set /subcategory:"Acceso a objetos" /success:enable /failure:enable 2>$null | Out-Null
Write-Host "  + Auditoria de Inicio de Sesion y Acceso a Objetos HABILITADA." -ForegroundColor Green


# 4. GENERAR SCRIPT INDEPENDIENTE DE MONITOREO
Write-Host "`n> 4. Creando Script de Extraccion de Alertas para el Auditor..." -ForegroundColor Yellow
$ScriptAuditor = @"
Clear-Host
Write-Host "=== REPORTE DE INTENTOS DE INTRUSION (ACCESO DENEGADO) ===" -ForegroundColor Red
`$RutaReporte = "C:\Reporte_Auditoria_4625.txt"
try {
    # ID 4625 es el evento oficial de Windows para Logon Fallido / Acceso Denegado
    `$Eventos = Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4625} -MaxEvents 10 -ErrorAction Stop
    `$Eventos | Select-Object TimeCreated, Id, Message | Out-File `$RutaReporte
    Write-Host "[+] Se encontraron eventos. Reporte guardado en: `$RutaReporte" -ForegroundColor Green
    Get-Content `$RutaReporte | Select-Object -First 15
} catch {
    Write-Host "[-] Sistema limpio. No se encontraron eventos recientes de Acceso Denegado (ID 4625)." -ForegroundColor Green
}
"@

$ScriptAuditor | Out-File "C:\Auditar_Accesos.ps1"
Write-Host "  + Script del auditor generado en C:\Auditar_Accesos.ps1" -ForegroundColor Green

Write-Host "`n=================================================" -ForegroundColor Cyan
Write-Host " FASE 6 COMPLETADA EXITOSAMENTE " -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
