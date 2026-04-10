$exe = "C:\Program Files\multiOTP\multiotp.exe"

# Probar capturando TODOS los streams de salida
Write-Host "Ingresa el codigo:" -ForegroundColor Cyan
$token = Read-Host "Codigo"

# Ejecutar capturando stdout y stderr por separado
$pinfo = New-Object System.Diagnostics.ProcessStartInfo
$pinfo.FileName               = $exe
$pinfo.Arguments              = "administrator $token"
$pinfo.RedirectStandardOutput = $true
$pinfo.RedirectStandardError  = $true
$pinfo.UseShellExecute        = $false
$pinfo.CreateNoWindow         = $true

$p = New-Object System.Diagnostics.Process
$p.StartInfo = $pinfo
$p.Start() | Out-Null
$p.WaitForExit()

$stdout   = $p.StandardOutput.ReadToEnd()
$stderr   = $p.StandardError.ReadToEnd()
$exitCode = $p.ExitCode

Write-Host "ExitCode : $exitCode" -ForegroundColor Cyan
Write-Host "Stdout   : $stdout"   -ForegroundColor White
Write-Host "Stderr   : $stderr"   -ForegroundColor Yellow

if ($exitCode -eq 0) {
    Write-Host "[OK] Token valido." -ForegroundColor Green
} else {
    Write-Host "[-] Codigo de error: $exitCode" -ForegroundColor Red
}
