# parche_notepad_moderno.ps1
# Ejecutar como Administrador

$Dominio = (Get-ADDomain).DistinguishedName
$GpoAppLocker = "GPO_AppLocker"

Write-Host "1. Obteniendo SID de Grupo_NoCuates..." -ForegroundColor Cyan
$SidNoCuates = (Get-ADGroup "Grupo_NoCuates").SID.Value

Write-Host "2. Generando regla de bloqueo para Aplicaciones Empaquetadas (Appx)..." -ForegroundColor Cyan
# Se deniega el Notepad moderno a los no cuates, y se permite todo lo demas a todos.
$xmlAppx = @"
<AppLockerPolicy Version="1">
  <RuleCollection Type="Appx" EnforcementMode="Enabled">
    <FilePublisherRule Id="$([guid]::NewGuid().ToString())" Name="Bloquear Notepad Moderno" Description="" UserOrGroupSid="$SidNoCuates" Action="Deny">
      <Conditions>
        <FilePublisherCondition PublisherName="CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=Washington, C=US" ProductName="Microsoft.WindowsNotepad" BinaryName="*">
          <BinaryVersionRange LowSection="0.0.0.0" HighSection="*" />
        </FilePublisherCondition>
      </Conditions>
    </FilePublisherRule>
    <FilePublisherRule Id="$([guid]::NewGuid().ToString())" Name="Permitir resto de Apps Modernas" Description="" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions>
        <FilePublisherCondition PublisherName="*" ProductName="*" BinaryName="*">
          <BinaryVersionRange LowSection="0.0.0.0" HighSection="*" />
        </FilePublisherCondition>
      </Conditions>
    </FilePublisherRule>
  </RuleCollection>
</AppLockerPolicy>
"@

$TempXml = "$env:TEMP\AppxNotepad.xml"
$xmlAppx | Out-File $TempXml -Encoding UTF8

$RutaLdap = "LDAP://CN={$( (Get-GPO $GpoAppLocker).Id )},CN=Policies,CN=System,$Dominio"

Write-Host "3. Inyectando regla a la GPO existente..." -ForegroundColor Cyan
Set-AppLockerPolicy -XmlPolicy $TempXml -Ldap $RutaLdap -Merge

Write-Host "[+] ¡Listo! Ahora ni el Notepad clásico ni el moderno podrán abrirse para los no cuates." -ForegroundColor Green
