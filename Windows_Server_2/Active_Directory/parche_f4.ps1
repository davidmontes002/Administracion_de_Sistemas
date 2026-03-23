$Dominio = (Get-ADDomain).DistinguishedName
$NombreDominio = (Get-ADDomain).Name
$GpoAppLocker = "GPO_AppLocker"

Write-Host "1. Creando Grupo de Seguridad y agregando a 'no cuates'..." -ForegroundColor Cyan
if (-not (Get-ADGroup -Filter "Name -eq 'Grupo_NoCuates'" -ErrorAction SilentlyContinue)) {
    New-ADGroup -Name "Grupo_NoCuates" -GroupCategory Security -GroupScope Global -Path "CN=Users,$Dominio"
}

$UsuariosNoCuates = Get-ADUser -Filter * -SearchBase "OU=no_cuates,$Dominio"
foreach ($User in $UsuariosNoCuates) {
    Add-ADGroupMember -Identity "Grupo_NoCuates" -Members $User -ErrorAction SilentlyContinue
}

Write-Host "2. Preparando GPO limpia..." -ForegroundColor Cyan
Remove-GPO -Name $GpoAppLocker -ErrorAction SilentlyContinue
$Gpo = New-GPO -Name $GpoAppLocker
New-GPLink -Name $GpoAppLocker -Target $Dominio | Out-Null
$RutaLdap = "LDAP://CN={$($Gpo.Id)},CN=Policies,CN=System,$Dominio"

Write-Host "3. Inyectando Salvavidas (Path) mediante XML puro..." -ForegroundColor Cyan
$xmlSalvavidas = @"
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
  </RuleCollection>
</AppLockerPolicy>
"@
$TempXmlSalvavidas = "$env:TEMP\Salvavidas.xml"
$xmlSalvavidas | Out-File $TempXmlSalvavidas -Encoding UTF8
Set-AppLockerPolicy -XmlPolicy $TempXmlSalvavidas -Ldap $RutaLdap

Write-Host "4. Calculando HASH criptográfico de Notepad e inyectando..." -ForegroundColor Cyan
$NotepadInfo = Get-AppLockerFileInformation -Path "C:\Windows\System32\notepad.exe"
$XmlHash = New-AppLockerPolicy -RuleType Hash -User "$NombreDominio\Grupo_NoCuates" -FileInformation $NotepadInfo -Xml
# Invertir el permiso de Permitir a Denegar
$XmlHash = $XmlHash -replace 'Action="Allow"', 'Action="Deny"'
$TempXmlHash = "$env:TEMP\NotepadHash.xml"
$XmlHash | Out-File $TempXmlHash -Encoding UTF8

# El parámetro -Merge une la regla Hash con el XML de Salvavidas que pusimos arriba
Set-AppLockerPolicy -XmlPolicy $TempXmlHash -Ldap $RutaLdap -Merge

Write-Host "5. Configurando auto-arranque del servicio en clientes..." -ForegroundColor Cyan
$AppIdKey = "HKLM\System\CurrentControlSet\Services\AppIDSvc"
Set-GPRegistryValue -Name $GpoAppLocker -Key $AppIdKey -ValueName "Start" -Type DWord -Value 2 | Out-Null

Write-Host "`n¡Éxito total! GPO aplicada y Notepad bloqueado por HASH." -ForegroundColor Green