#Requires -RunAsAdministrator
Clear-Host
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host " FASE 4: FSRM (CUOTAS) Y APPLOCKER             " -ForegroundColor Cyan
Write-Host " Windows Server 2022 - Sin entorno grafico      " -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

$Dominio      = (Get-ADDomain).DistinguishedName
$NombreDominio = (Get-ADDomain).Name
$RutaBase     = "C:\Shares\Usuarios"

# ---------------------------------------------------------
# 1. INSTALACION DE FSRM
# ---------------------------------------------------------
Write-Host "`n> 1. Instalando el rol de FSRM..." -ForegroundColor Yellow
Install-WindowsFeature FS-Resource-Manager -IncludeManagementTools -ErrorAction SilentlyContinue | Out-Null
Write-Host "  [+] FSRM instalado." -ForegroundColor Green

# ---------------------------------------------------------
# 2. APANTALLAMIENTO DE ARCHIVOS
#
# IMPORTANTE: El apantallamiento se aplica SOLO sobre
# C:\Shares\Usuarios (carpetas HOME de los usuarios).
# NO se aplica sobre C:\Perfiles para no interferir
# con los archivos del perfil movil (.dat, .pol, etc.)
# ---------------------------------------------------------
Write-Host "`n> 2. Configurando bloqueo de archivos (.mp3,.mp4,.exe,.msi)..." -ForegroundColor Yellow

$NombreGrupo = "Bloqueo_Multimedia_Ejecutables"

if (-not (Get-FsrmFileGroup -Name $NombreGrupo -ErrorAction SilentlyContinue)) {
    New-FsrmFileGroup `
        -Name            $NombreGrupo `
        -IncludePattern  @("*.mp3","*.mp4","*.exe","*.msi") | Out-Null
    Write-Host "  [+] Grupo de archivos bloqueados creado." -ForegroundColor Green
} else {
    Write-Host "  [-] Grupo ya existe." -ForegroundColor DarkGray
}

if (-not (Get-FsrmFileScreenTemplate -Name "Plantilla_Bloqueo_Total" -ErrorAction SilentlyContinue)) {
    New-FsrmFileScreenTemplate `
        -Name         "Plantilla_Bloqueo_Total" `
        -IncludeGroup $NombreGrupo `
        -Active:$true | Out-Null
    Write-Host "  [+] Plantilla de bloqueo creada." -ForegroundColor Green
} else {
    Write-Host "  [-] Plantilla ya existe." -ForegroundColor DarkGray
}

# Aplicar SOLO a C:\Shares\Usuarios, NO a C:\Perfiles
if (-not (Get-FsrmFileScreen -Path $RutaBase -ErrorAction SilentlyContinue)) {
    New-FsrmFileScreen `
        -Path     $RutaBase `
        -Template "Plantilla_Bloqueo_Total" `
        -Active:$true | Out-Null
    Write-Host "  [+] Apantallamiento aplicado a: $RutaBase" -ForegroundColor Green
    Write-Host "  [!] NO aplicado a C:\Perfiles (protege archivos del perfil movil)" -ForegroundColor DarkGray
} else {
    Write-Host "  [-] Apantallamiento ya configurado." -ForegroundColor DarkGray
}

# ---------------------------------------------------------
# 3. CUOTAS ESTRICTAS
# ---------------------------------------------------------
Write-Host "`n> 3. Creando plantillas de cuotas..." -ForegroundColor Yellow

if (-not (Get-FsrmQuotaTemplate -Name "Cuota_5MB" -ErrorAction SilentlyContinue)) {
    New-FsrmQuotaTemplate -Name "Cuota_5MB"  -Size 5MB  | Out-Null
    New-FsrmQuotaTemplate -Name "Cuota_10MB" -Size 10MB | Out-Null
    Write-Host "  [+] Plantillas Cuota_5MB y Cuota_10MB creadas." -ForegroundColor Green
} else {
    Write-Host "  [-] Plantillas ya existen." -ForegroundColor DarkGray
}

# Aplicar cuotas a cuates (10MB)
$UsuariosCuates = Get-ADUser -Filter * -SearchBase "OU=cuates,$Dominio"
foreach ($User in $UsuariosCuates) {
    $RutaUser = "$RutaBase\$($User.SamAccountName)"
    if ((Test-Path $RutaUser) -and -not (Get-FsrmQuota -Path $RutaUser -ErrorAction SilentlyContinue)) {
        New-FsrmQuota -Path $RutaUser -Template "Cuota_10MB" | Out-Null
        Write-Host "  [+] Cuota 10MB -> $($User.SamAccountName)" -ForegroundColor Green
    }
}

# Aplicar cuotas a no_cuates (5MB)
$UsuariosNoCuates = Get-ADUser -Filter * -SearchBase "OU=no_cuates,$Dominio"
foreach ($User in $UsuariosNoCuates) {
    $RutaUser = "$RutaBase\$($User.SamAccountName)"
    if ((Test-Path $RutaUser) -and -not (Get-FsrmQuota -Path $RutaUser -ErrorAction SilentlyContinue)) {
        New-FsrmQuota -Path $RutaUser -Template "Cuota_5MB" | Out-Null
        Write-Host "  [+] Cuota 5MB -> $($User.SamAccountName)" -ForegroundColor Green
    }
}

# ---------------------------------------------------------
# 4. APPLOCKER VIA GPO
# ---------------------------------------------------------
Write-Host "`n> 4. Configurando AppLocker..." -ForegroundColor Yellow
$GpoAppLocker = "GPO_AppLocker"

if (-not (Get-GPO -Name $GpoAppLocker -ErrorAction SilentlyContinue)) {
    $Gpo = New-GPO -Name $GpoAppLocker
    New-GPLink -Name $GpoAppLocker -Target $Dominio | Out-Null

    $AppIdKey = "HKLM\System\CurrentControlSet\Services\AppIDSvc"
    Set-GPRegistryValue -Name $GpoAppLocker -Key $AppIdKey `
        -ValueName "Start" -Type DWord -Value 2 | Out-Null

    $NotepadInfo = Get-AppLockerFileInformation -Path "C:\Windows\System32\notepad.exe"

    $ReglaPermitir = New-AppLockerPolicy `
        -RuleType Hash -User "$NombreDominio\cuates" `
        -FileInformation $NotepadInfo

    $XmlDenegar = New-AppLockerPolicy `
        -RuleType Hash -User "$NombreDominio\no_cuates" `
        -FileInformation $NotepadInfo -Xml
    $XmlDenegar = $XmlDenegar -replace 'Action="Allow"', 'Action="Deny"'

    $TempXmlPath = "$env:TEMP\AppLockerDeny.xml"
    $XmlDenegar | Out-File $TempXmlPath

    $RutaLdap = "LDAP://CN=$($Gpo.Id),CN=Policies,CN=System,$Dominio"
    Set-AppLockerPolicy -PolicyObject $ReglaPermitir -Ldap $RutaLdap -Merge
    Set-AppLockerPolicy -XmlPolicy $TempXmlPath -Ldap $RutaLdap -Merge

    Write-Host "  [+] GPO AppLocker creada." -ForegroundColor Green
} else {
    Write-Host "  [-] GPO AppLocker ya existe." -ForegroundColor DarkGray
}

Write-Host "`n=================================================" -ForegroundColor Cyan
Write-Host " FASE 4 COMPLETADA EXITOSAMENTE                 " -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Cyan
