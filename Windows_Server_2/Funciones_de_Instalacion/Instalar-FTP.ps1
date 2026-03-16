function Instalar-FTP {
    Write-Host '=================================' -ForegroundColor Cyan
    Write-Host '     INSTALACION SERVIDOR FTP' -ForegroundColor Cyan
    Write-Host '=================================' -ForegroundColor Cyan

    Install-WindowsFeature Web-Server -IncludeAllSubFeature | Out-Null
    Install-WindowsFeature Web-FTP-Service -IncludeAllSubFeature | Out-Null
    Install-WindowsFeature Web-FTP-Server -IncludeAllSubFeature | Out-Null
    Install-WindowsFeature Web-Basic-Auth | Out-Null

    New-NetFirewallRule -DisplayName 'FTP' -Direction Inbound -Protocol TCP -LocalPort 21 -Action Allow -ErrorAction SilentlyContinue | Out-Null
    Import-Module WebAdministration

    if (-not (Test-Path 'C:\FTP')) {
        mkdir 'C:\FTP' | Out-Null
        mkdir 'C:\FTP\LocalUser' | Out-Null
        mkdir 'C:\FTP\LocalUser\Public' | Out-Null
        mkdir 'C:\FTP\LocalUser\Public\General' | Out-Null
    }
    
    icacls 'C:\FTP\LocalUser\Public' /inheritance:r /Q | Out-Null
    icacls 'C:\FTP\LocalUser\Public' /remove 'BUILTIN\Usuarios' /Q | Out-Null
    icacls 'C:\FTP\LocalUser\Public' /grant 'IUSR:(OI)(CI)RX' /Q | Out-Null
    icacls 'C:\FTP\LocalUser\Public' /grant 'SYSTEM:(OI)(CI)F' /Q | Out-Null
    icacls 'C:\FTP\LocalUser\Public' /grant 'Administradores:(OI)(CI)F' /Q | Out-Null

    icacls 'C:\FTP\LocalUser\Public\General' /grant 'IUSR:(OI)(CI)RX' /Q | Out-Null

    if (-not (Get-WebSite -Name 'FTP' -ErrorAction SilentlyContinue)) {
        New-WebFtpSite -Name 'FTP' -Port 21 -PhysicalPath 'C:\FTP' | Out-Null
        Write-Host '[+] Sitio FTP creado en C:\FTP.'
    } else {
        Write-Host '[-] El sitio FTP ya existe.'
    }

    Set-ItemProperty 'IIS:\Sites\FTP' -Name ftpServer.security.authentication.basicAuthentication.enabled -Value $true
    Set-ItemProperty 'IIS:\Sites\FTP' -Name ftpServer.security.authentication.anonymousAuthentication.enabled -Value $true
    Set-ItemProperty 'IIS:\Sites\FTP' -Name ftpServer.security.authentication.anonymousAuthentication.username -Value 'IUSR'

    Clear-WebConfiguration -Filter '/system.ftpServer/security/authorization' -PSPath 'IIS:\' -Location 'FTP'
    Add-WebConfiguration '/system.ftpServer/security/authorization' -Value @{accessType='Allow';users='?';permissions=1} -PSPath 'IIS:\' -Location 'FTP'
    Add-WebConfiguration '/system.ftpServer/security/authorization' -Value @{accessType='Allow';users='*';permissions=3} -PSPath 'IIS:\' -Location 'FTP'

    Write-Host '[+] Instalacion base completada.'
    Pause
}