function Configurar-SSH {

    $ssh = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'

    if ($ssh.State -ne "Installed") {
        Write-Host "ERROR: OpenSSH no está instalado." -ForegroundColor Red
        return
    }

    # Crear regla firewall si no existe
    if (-not (Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule `
        -Name "OpenSSH-Server-In-TCP" `
        -DisplayName "OpenSSH Server (TCP 22)" `
        -Enabled True `
        -Direction Inbound `
        -Protocol TCP `
        -Action Allow `
        -LocalPort 22
    }

    Set-Service sshd -StartupType Automatic
    Restart-Service sshd -Force

    Write-Host "SSH configurado y escuchando en todas las interfaces." -ForegroundColor Green
}