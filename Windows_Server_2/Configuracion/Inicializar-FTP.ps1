function Inicializar-Sitio-FTP {
    Write-Host "=== INICIALIZANDO AISLAMIENTO FTP ===" -ForegroundColor Cyan
    Import-Module WebAdministration

    # Configurar Aislamiento
    Set-WebConfigurationProperty `
        -Filter "/system.applicationHost/sites/site[@name='FTP']/ftpServer/userIsolation" `
        -Name "mode" `
        -Value "IsolateAllDirectories"

    # Apagar políticas SSL por ahora (resolveme.ps1)
    Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.security.ssl.controlChannelPolicy -Value 0
    Set-ItemProperty "IIS:\Sites\FTP" -Name ftpServer.security.ssl.dataChannelPolicy -Value 0

    # Registrar el objeto ADSI global para usarlo en todo el script
    $global:ADSI = [ADSI]"WinNT://$env:ComputerName"

    Restart-WebItem "IIS:\Sites\FTP"
    Write-Host "[+] Aislamiento 'IsolateAllDirectories' y configuración SSL inicial aplicados." -ForegroundColor Green
}