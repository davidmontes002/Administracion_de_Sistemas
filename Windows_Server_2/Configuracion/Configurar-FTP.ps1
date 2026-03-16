function Registrar-Grupo-FTP {
    if (-not $global:ADSI) { $global:ADSI = [ADSI]"WinNT://$env:ComputerName" }

    Write-Host "[*] Inicializando Grupos Base (Reprobados / Recursadores)..." -ForegroundColor Cyan

    # Grupo Reprobados
    if(-not($global:ADSI.Children | Where-Object { $_.SchemaClassName -eq "Group" -and $_.Name -eq "Reprobados"})){
        if(-not (Test-Path "C:\FTP\Reprobados")) { New-Item -Path "C:\FTP\Reprobados" -ItemType Directory | Out-Null }
        $FTPUserGroup = $global:ADSI.Create("Group", "Reprobados")
        $FTPUserGroup.SetInfo()
        $FTPUserGroup.Description = "Team de reprobados"
        $FTPUserGroup.SetInfo()
        Write-Host "  [+] Grupo Reprobados creado." -ForegroundColor Green
    }
    
    # Grupo Recursadores
    if(-not($global:ADSI.Children | Where-Object { $_.SchemaClassName -eq "Group" -and $_.Name -eq "Recursadores"})){
        if(-not (Test-Path "C:\FTP\Recursadores")) { New-Item -Path "C:\FTP\Recursadores" -ItemType Directory | Out-Null }
        $FTPUserGroup = $global:ADSI.Create("Group", "Recursadores")
        $FTPUserGroup.SetInfo()
        $FTPUserGroup.Description = "Este grupo son los q valieron queso en ASM y SysADM"
        $FTPUserGroup.SetInfo()
        Write-Host "  [+] Grupo Recursadores creado." -ForegroundColor Green
    }
}

function Registrar-Alumno-FTP {
    do {
        $FTPUserName = Read-Host "Ingrese el nombre de usuario"
        if ((Get-LocalUser -Name $FTPUserName -ErrorAction SilentlyContinue)) {
            Write-Host "Usuario ya Existente ($FTPUserName)" -ForegroundColor Red
        }
    } while ((Get-LocalUser -Name $FTPUserName -ErrorAction SilentlyContinue))
    
    $regex = "^(?=.*[A-Z])(?=.*[a-z])(?=.*[0-9]).{8,}$"
    
    do {
        $FTPPassword = Read-Host "Ingresar una contraseña"
        if ($FTPPassword -notmatch $regex) {
            Write-Host "Contraseña no válida. Debe contener Mayúscula, minúscula y mínimo 8 caracteres." -ForegroundColor Red
        } else { break }
    } while ($FTPPassword -notmatch $regex)

    Write-Host "INGRESE A CUÁL GRUPO PERTENECERÁ"
    $opcGrupo = Read-Host "1-Reprobados  2-Recursadores"
    
    # Asignación segura de variable
    if ($opcGrupo -eq "1") { 
        $FTPUserGroupName = "Reprobados" 
    } else { 
        $FTPUserGroupName = "Recursadores" 
    }

    Write-Host "[*] 1. Creando usuario nativo..." -ForegroundColor Cyan
    $passSecure = ConvertTo-SecureString $FTPPassword -AsPlainText -Force
    New-LocalUser -Name $FTPUserName -Password $passSecure -Description "Usuario FTP" | Out-Null
    
    # Micro-descanso para que Windows registre el usuario en su base de datos
    Start-Sleep -Seconds 1

    Write-Host "[*] 2. Asignando al grupo '$FTPUserGroupName'..." -ForegroundColor Cyan
    $miembros = Get-LocalGroupMember -Group $FTPUserGroupName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
    if ($miembros -notmatch $FTPUserName) {
        Add-LocalGroupMember -Group $FTPUserGroupName -Member $FTPUserName
    }

    Write-Host "[*] 3. Creando estructura y Enlaces Simbólicos..." -ForegroundColor Cyan
    $rutaUser = "C:\FTP\LocalUser\$FTPUserName"
    
    # El parámetro -Force hace que si la carpeta o enlace ya existe a medias, lo arregle/sobreescriba
    if (-not(Test-Path $rutaUser)) { New-Item -Path $rutaUser -ItemType Directory -Force | Out-Null }
    if (-not(Test-Path "$rutaUser\$FTPUserName")) { New-Item -Path "$rutaUser\$FTPUserName" -ItemType Directory -Force | Out-Null }
        
    New-Item -ItemType SymbolicLink -Path "$rutaUser\General" -Target "C:\FTP\LocalUser\Public\General" -Force | Out-Null
    New-Item -ItemType SymbolicLink -Path "$rutaUser\$FTPUserGroupName" -Target "C:\FTP\$FTPUserGroupName" -Force | Out-Null

    Write-Host "[*] 4. Aplicando permisos NTFS..." -ForegroundColor Cyan
    icacls "C:\FTP\Reprobados" /grant "Reprobados:(OI)(CI)M" /Q | Out-Null
    icacls "C:\FTP\Recursadores" /grant "Recursadores:(OI)(CI)M" /Q | Out-Null
    icacls "C:\FTP\LocalUser\Public\General" /grant "Reprobados:(OI)(CI)M" /Q | Out-Null
    icacls "C:\FTP\LocalUser\Public\General" /grant "Recursadores:(OI)(CI)M" /Q | Out-Null
    icacls "C:\FTP\LocalUser\Public\General" /grant "IUSR:(OI)(CI)RX" /Q | Out-Null
    
    icacls $rutaUser /grant:r "${FTPUserName}:(OI)(CI)M" /Q | Out-Null

    Write-Host "[+] ¡Listo! Usuario $FTPUserName creado y enjaulado correctamente." -ForegroundColor Green
}