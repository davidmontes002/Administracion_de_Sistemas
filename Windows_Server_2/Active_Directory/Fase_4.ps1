Clear-Host
Write-Host "================================================="
Write-Host " FASE 4: FSRM (CUOTAS) Y APPLOCKER (EJECUCION)   "
Write-Host "================================================="

$Dominio = (Get-ADDomain).DistinguishedName
$NombreDominio = (Get-ADDomain).Name
$RutaBase = "C:\Shares\Usuarios"

# ---------------------------------------------------------
# 1. INSTALACIÓN DE FSRM
# ---------------------------------------------------------
Write-Host "1. Instalando el rol de FSRM..."
Install-WindowsFeature FS-Resource-Manager -IncludeManagementTools -ErrorAction SilentlyContinue | Out-Null

# ---------------------------------------------------------
# 2. CONFIGURACIÓN DE APANTALLAMIENTO DE ARCHIVOS
# ---------------------------------------------------------
Write-Host "`n2. Configurando Bloqueo de Archivos (.mp3, .mp4, .exe, .msi)..."
$NombreGrupo = "Bloqueo_Multimedia_Ejecutables"

if (-not (Get-FsrmFileGroup -Name $NombreGrupo -ErrorAction SilentlyContinue)) {
    New-FsrmFileGroup -Name $NombreGrupo -IncludePattern @("*.mp3", "*.mp4", "*.exe", "*.msi") | Out-Null
    New-FsrmFileScreenTemplate -Name "Plantilla_Bloqueo_Total" -IncludeGroup $NombreGrupo -Active:$true | Out-Null
    New-FsrmFileScreen -Path $RutaBase -Template "Plantilla_Bloqueo_Total" -Active:$true | Out-Null
    Write-Host "   -> Apantallamiento aplicado a $RutaBase."
} else {
    Write-Host "   -> El bloqueo de archivos ya estaba configurado."
}

# ---------------------------------------------------------
# 3. CONFIGURACIÓN DE CUOTAS ESTRICTAS
# ---------------------------------------------------------
Write-Host "`n3. Creando plantillas de cuotas y aplicandolas a los usuarios..."

# CORRECCIÓN: Al omitir el parámetro, la cuota es "Hard" (Estricta) por defecto.
if (-not (Get-FsrmQuotaTemplate -Name "Cuota_5MB" -ErrorAction SilentlyContinue)) {
    New-FsrmQuotaTemplate -Name "Cuota_5MB" -Size 5MB | Out-Null
    New-FsrmQuotaTemplate -Name "Cuota_10MB" -Size 10MB | Out-Null
}

$UsuariosCuates = Get-ADUser -Filter * -SearchBase "OU=cuates,$Dominio"
foreach ($User in $UsuariosCuates) {
    $RutaUser = "$RutaBase\$($User.SamAccountName)"
    if (-not (Get-FsrmQuota -Path $RutaUser -ErrorAction SilentlyContinue)) {
        New-FsrmQuota -Path $RutaUser -Template "Cuota_10MB" | Out-Null
        Write-Host "   -> Cuota de 10 MB asignada a $($User.SamAccountName)."
    }
}

$UsuariosNoCuates = Get-ADUser -Filter * -SearchBase "OU=no_cuates,$Dominio"
foreach ($User in $UsuariosNoCuates) {
    $RutaUser = "$RutaBase\$($User.SamAccountName)"
    if (-not (Get-FsrmQuota -Path $RutaUser -ErrorAction SilentlyContinue)) {
        New-FsrmQuota -Path $RutaUser -Template "Cuota_5MB" | Out-Null
        Write-Host "   -> Cuota de 5 MB asignada a $($User.SamAccountName)."
    }
}

# ---------------------------------------------------------
# 4. CONFIGURACIÓN DE APPLOCKER VÍA GPO (Solución para la Práctica)
# ---------------------------------------------------------
Write-Host "`n4. Configurando politicas de AppLocker..."
$GpoAppLocker = "GPO_AppLocker"

if (-not (Get-GPO -Name $GpoAppLocker -ErrorAction SilentlyContinue)) {
    $Gpo = New-GPO -Name $GpoAppLocker
    New-GPLink -Name $GpoAppLocker -Target $Dominio | Out-Null
    
    $AppIdKey = "HKLM\System\CurrentControlSet\Services\AppIDSvc"
    Set-GPRegistryValue -Name $GpoAppLocker -Key $AppIdKey -ValueName "Start" -Type DWord -Value 2 | Out-Null
    
    $NotepadInfo = Get-AppLockerFileInformation -Path "C:\Windows\System32\notepad.exe"
    
    # Regla Permitir (Cuates)
    $ReglaPermitir = New-AppLockerPolicy -RuleType Hash -User "$NombreDominio\cuates" -FileInformation $NotepadInfo
    
    # Regla Denegar (No Cuates)
    $XmlDenegar = New-AppLockerPolicy -RuleType Hash -User "$NombreDominio\no_cuates" -FileInformation $NotepadInfo -Xml
    $XmlDenegar = $XmlDenegar -replace 'Action="Allow"', 'Action="Deny"'
    $TempXmlPath = "$env:TEMP\AppLockerDeny.xml"
    $XmlDenegar | Out-File $TempXmlPath
    
    $RutaLdap = "LDAP://CN=$($Gpo.Id),CN=Policies,CN=System,$Dominio"
    
    Set-AppLockerPolicy -PolicyObject $ReglaPermitir -Ldap $RutaLdap -Merge
    Set-AppLockerPolicy -XmlPolicy $TempXmlPath -Ldap $RutaLdap -Merge
    
    Write-Host "   -> Reglas de Hash para Notepad inyectadas en la GPO '$GpoAppLocker'."
    Write-Host "   -> Servicio AppIDSvc configurado para auto-arranque."
} else {
    Write-Host "   -> La GPO de AppLocker ya estaba configurada."
}

Write-Host "`n================================================="
Write-Host " FASE 4 COMPLETADA EXITOSAMENTE "
Write-Host "================================================="