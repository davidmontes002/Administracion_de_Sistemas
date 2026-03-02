function Validar-IP {
    param([string]$ip)

    $ip = $ip.Trim()

    if ($ip -notmatch '^(\d{1,3}\.){3}\d{1,3}$') { return $false }

    $octetos = $ip.Split('.')
    foreach ($o in $octetos) {
        if ([int]$o -lt 0 -or [int]$o -gt 255) { return $false }
    }

    if ($ip -eq "0.0.0.0") { return $false }
    if ($ip -eq "127.0.0.1") { return $false }
    if ($octetos[3] -eq "0" -or $octetos[3] -eq "255") { return $false }

    return $true
}

function IPaNum {
    param([string]$ip)

    $p = $ip.Split('.')

    return [uint32](
        ([uint32]$p[0] -shl 24) -bor
        ([uint32]$p[1] -shl 16) -bor
        ([uint32]$p[2] -shl 8)  -bor
        ([uint32]$p[3])
    )
}

function Validar-Rango {
    param($inicio,$fin)

    if (-not (Validar-IP $inicio)) { return $false }
    if (-not (Validar-IP $fin)) { return $false }

    if ((IPaNum $inicio) -ge (IPaNum $fin)) { return $false }

    return $true
}