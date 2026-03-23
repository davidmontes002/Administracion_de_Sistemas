$Dominio = (Get-ADDomain).DistinguishedName
$GpoAppLocker = "GPO_AppLocker"

Write-Host "1. Creando Grupo de Seguridad y agregando a 'no cuates'..." -ForegroundColor Cyan
if (-not (Get-ADGroup -Filter "Name -eq 'Grupo_NoCuates'" -ErrorAction SilentlyContinue)) {
    New-ADGroup -Name "Grupo_NoCuates" -GroupCategory Security -GroupScope Global -Path "CN=Users,$Dominio"
}

$UsuariosNoCuates = Get-ADUser -Filter * -SearchBase "OU=no_cuates,$Dominio"
foreach ($User in $UsuariosNoCuates) {
    Add-ADGroupMember -Identity "Grupo_NoCuates" -Members $User -ErrorAction SilentlyContinue
}
$GrupoSID = (Get-ADGroup "Grupo_NoCuates").SID.Value

Write-Host "2. Preparando GPO limpia..." -ForegroundColor Cyan
Remove-GPO -Name $GpoAppLocker -ErrorAction SilentlyContinue
$Gpo = New-GPO -Name $GpoAppLocker
New-GPLink -Name $GpoAppLocker -Target $Dominio | Out-Null

# ¡LA CORRECCIÓN ESTÁ AQUÍ! Las llaves {} alrededor del ID
$RutaLdap = "LDAP://CN={$($Gpo.Id)},CN=Policies,CN=System,$Dominio"

Write-Host "3. Construyendo la arquitectura XML de AppLocker..." -ForegroundColor Cyan
$xml = @"
<AppLockerPolicy Version="1">
  <RuleCollection Type="Exe" EnforcementMode="Enabled">
    <FilePathRule Id="921cc481-6e17-4653-8f75-050b80acca20" Name="(Salvavidas) Program Files" Description="" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions><FilePathCondition Path="%PROGRAMFILES%\*" /></Conditions>
    </FilePathRule>
    <FilePathRule Id="a61c8b2c-a319-4cd0-9690-d2177cad7b51" Name="(Salvavidas) Windows" Description="" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions><FilePathCondition Path="%WINDIR%\*" /></Conditions>
    </FilePathRule>
    <FilePathRule Id="fd686d83-a829-4351-8ff4-27c7de5755d2" Name="(Salvavidas) Administradores" Description="" UserOrGroupSid="S-1-5-32-544" Action="Allow">
      <Conditions><FilePathCondition Path="*" /></Conditions>
    </FilePathRule>
    <FilePathRule Id="d84793f7-53c7-4abf-b88a-36fb222a7288" Name="Bloqueo Notepad System32" Description="" UserOrGroupSid="$GrupoSID" Action="Deny">
      <Conditions><FilePathCondition Path="%SYSTEM32%\notepad.exe" /></Conditions>
    </FilePathRule>
    <FilePathRule Id="e84793f7-53c7-4abf-b88a-36fb222a7289" Name="Bloqueo Notepad Windows" Description="" UserOrGroupSid="$GrupoSID" Action="Deny">
      <Conditions><FilePathCondition Path="%WINDIR%\notepad.exe" /></Conditions>
    </FilePathRule>
  </RuleCollection>
</AppLockerPolicy>
"@

$TempXmlPath = "$env:TEMP\AppLockerPolicy.xml"
$xml | Out-File $TempXmlPath -Encoding UTF8

Write-Host "4. Inyectando XML en la Directiva de Grupo (GPO)..." -ForegroundColor Cyan
Set-AppLockerPolicy -XmlPolicy $TempXmlPath -Ldap $RutaLdap

Write-Host "5. Configurando auto-arranque del servicio en clientes..." -ForegroundColor Cyan
$AppIdKey = "HKLM\System\CurrentControlSet\Services\AppIDSvc"
Set-GPRegistryValue -Name $GpoAppLocker -Key $AppIdKey -ValueName "Start" -Type DWord -Value 2 | Out-Null

Write-Host "`n¡Éxito total! GPO de AppLocker aplicada sin errores." -ForegroundColor Green