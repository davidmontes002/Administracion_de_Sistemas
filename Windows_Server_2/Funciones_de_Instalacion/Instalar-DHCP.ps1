function Instalar-DHCP {

    Write-Host "Verificando estado del rol DHCP..." -ForegroundColor Cyan

    $feature = Get-WindowsFeature -Name DHCP

    if ($feature.Installed) {
        Write-Host "El rol DHCP ya está instalado." -ForegroundColor Yellow

        $servicio = Get-Service -Name DHCPServer -ErrorAction SilentlyContinue
        if ($servicio -and $servicio.Status -ne "Running") {
            Write-Host "El servicio DHCP está detenido. Iniciándolo..." -ForegroundColor Yellow
            Start-Service DHCPServer
        }

        Write-Host "Estado actual del servicio DHCP:" -ForegroundColor Green
        Get-Service DHCPServer

        Pause
        return
    }

    Write-Host "Instalando rol DHCP..." -ForegroundColor Green

    try {
        Install-WindowsFeature -Name DHCP -IncludeManagementTools -ErrorAction Stop
        Write-Host "DHCP instalado correctamente." -ForegroundColor Green
    }
    catch {
        Write-Host "Error al instalar DHCP: $($_.Exception.Message)" -ForegroundColor Red
    }

    Pause
}