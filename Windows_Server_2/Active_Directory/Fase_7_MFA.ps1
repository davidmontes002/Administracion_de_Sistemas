Clear-Host
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host " FASE 7: IMPLEMENTACION DE MFA (PRACTICA 9)      " -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# Ruta exacta donde descargaste el instalador
$RutaMSI = "C:\Users\Administrador\MFA_Install.msi"

if (-not (Test-Path $RutaMSI)) {
    Write-Host "[-] ERROR: No se encontro el instalador en $RutaMSI." -ForegroundColor Red
    exit
}

Write-Host "> 1. Inyectando el Proveedor de Credenciales en LSASS..." -ForegroundColor Yellow
# Instalacion silenciosa (/quiet) y sin reiniciar automaticamente (/norestart)
Start-Process "msiexec.exe" -ArgumentList "/i `"$RutaMSI`" /quiet /norestart" -Wait
Write-Host "  + Software MFA instalado correctamente." -ForegroundColor Green

Write-Host "`n> 2. Configurando politicas de inicio de sesion (Obligatorio)..." -ForegroundColor Yellow
# Forzamos a que el sistema exija el proveedor personalizado de MFA
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers" -Name "MFA_Activo" -Value 1 -ErrorAction SilentlyContinue
Write-Host "  + Registros de inicio de sesion actualizados." -ForegroundColor Green

Write-Host "`n=================================================" -ForegroundColor Cyan
Write-Host " [!] REINICIO REQUERIDO [!] " -ForegroundColor Red
Write-Host " El servidor se reiniciara en 5 segundos para aplicar el MFA." -ForegroundColor White
Write-Host "=================================================" -ForegroundColor Cyan

Start-Sleep -Seconds 5
Restart-Computer -Force
