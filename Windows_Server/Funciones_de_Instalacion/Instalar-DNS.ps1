function Instalar-DNS {

    Write-Host "Verificando estado del rol DNS..." -ForegroundColor Cyan

    $feature = Get-WindowsFeature -Name DNS

    if ($feature.Installed) {
        Write-Host "El rol DNS ya está instalado." -ForegroundColor Yellow

        $servicio = Get-Service -Name DNS -ErrorAction SilentlyContinue
        if ($servicio -and $servicio.Status -ne "Running") {
            Write-Host "El servicio DNS está detenido. Iniciándolo..." -ForegroundColor Yellow
            Start-Service DNS
        }

        Write-Host "Estado actual del servicio DNS:" -ForegroundColor Green
        Get-Service DNS

        Pause
        return
    }

    Write-Host "Instalando rol DNS..." -ForegroundColor Green

    try {
        Install-WindowsFeature -Name DNS -IncludeManagementTools -ErrorAction Stop
        Write-Host "DNS instalado correctamente." -ForegroundColor Green
    }
    catch {
        Write-Host "Error al instalar DNS: $($_.Exception.Message)" -ForegroundColor Red
    }

    Pause
}