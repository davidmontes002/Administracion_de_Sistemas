# Ejecuta esto en el servidor para probar el token directamente
$exe = "C:\Program Files\multiOTP\multiotp.exe"

$p = New-Object System.Diagnostics.ProcessStartInfo
$p.FileName               = $exe
$p.Arguments              = "administrator 059010"
$p.RedirectStandardOutput = $true
$p.RedirectStandardError  = $true
$p.UseShellExecute        = $false
$proc = [System.Diagnostics.Process]::Start($p)
$proc.WaitForExit()
Write-Host "ExitCode: $($proc.ExitCode)"
