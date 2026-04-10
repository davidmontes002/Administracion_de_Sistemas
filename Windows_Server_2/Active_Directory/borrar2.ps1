$exe = "C:\Program Files\multiOTP\multiotp.exe"

# Borrar usuario corrupto directamente
Remove-Item "C:\Program Files\multiOTP\users\administrator.db" -Force -ErrorAction SilentlyContinue

# Crear con -createga que acepta Base32 directamente
& $exe -createga administrator "JBSWY3DPEHPK3PXP"
Start-Sleep -Seconds 1

# Sin PIN adicional
& $exe -set administrator prefix-pin=0 2>$null

# Configurar bloqueo
& $exe -config "max-block-failures"   3    2>$null
& $exe -config "failure-delayed-time" 1800 2>$null

# Verificar que existe
Write-Host "`n=== Info usuario ===" -ForegroundColor Cyan
& $exe -user-info administrator 2>$null

# Probar token
Write-Host "`nEspera a que el codigo cambie en Authenticator." -ForegroundColor Yellow
$token    = Read-Host "Ingresa el codigo de 6 digitos"
$resultado = (& $exe administrator $token 2>$null)
Write-Host "Respuesta: $resultado" -ForegroundColor DarkGray

if ($resultado -match "^0") {
    Write-Host "[OK] Token valido. Procedemos a reiniciar." -ForegroundColor Green

    # Deshabilitar NLA
    $rutaNLA = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
    Set-ItemProperty -Path $rutaNLA -Name "UserAuthentication" -Value 0
    Write-Host "[+] NLA deshabilitado." -ForegroundColor Green

    Write-Host "`nReiniciando en 10 segundos..." -ForegroundColor Cyan
    Start-Sleep -Seconds 10
    Restart-Computer -Force
} else {
    Write-Host "[-] Fallo: $resultado" -ForegroundColor Red
    # Ver el .db para diagnostico
    Write-Host "`nContenido .db:" -ForegroundColor Yellow
    Get-Content "C:\Program Files\multiOTP\users\administrator.db" -ErrorAction SilentlyContinue |
        Where-Object { $_ -match "token_seed|algorithm|digits|locked|error" }
}
