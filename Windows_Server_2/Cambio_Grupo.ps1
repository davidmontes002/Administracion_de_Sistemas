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
    if (-not $global:ADSI) { $global:ADSI = [ADSI]"WinNT://$env:ComputerName" }

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
    $FTPUserGroupName = if ($opcGrupo -eq "1") { "Reprobados" } else { "Recursadores" }

    # Crear usuario con ADSI
    $CreateUserFTPUser = $global:ADSI.create("User", $FTPUserName)
    $CreateUserFTPUser.SetInfo()    
    $CreateUserFTPUser.SetPassword($FTPPassword)    
    $CreateUserFTPUser.SetInfo()    

    # Añadir al grupo
    if (-not (Get-LocalGroupMember $FTPUserGroupName | Where-Object { $_.Name -like "*$FTPUserName" })) {
        Add-LocalGroupMember -Group $FTPUserGroupName -Member $FTPUserName
    }

    # Crear estructura de carpetas físicas y ENLACES SIMBÓLICOS
    if (-not(Test-Path "C:\FTP\LocalUser\$FTPUserName")) {
        mkdir "C:\FTP\LocalUser\$FTPUserName" | Out-Null
        mkdir "C:\FTP\LocalUser\$FTPUserName\$FTPUserName" | Out-Null
        
        # Enlaces Simbólicos (La nueva arquitectura)
        New-Item -ItemType SymbolicLink -Path "C:\FTP\LocalUser\$FTPUserName\General" -Target "C:\FTP\LocalUser\Public\General" | Out-Null
        New-Item -ItemType SymbolicLink -Path "C:\FTP\LocalUser\$FTPUserName\$FTPUserGroupName" -Target "C:\FTP\$FTPUserGroupName" | Out-Null
    }       
    
    # Asignar Permisos NTFS
    icacls "C:\FTP\Reprobados" /grant "Reprobados:(OI)(CI)M" /Q | Out-Null
    icacls "C:\FTP\Recursadores" /grant "Recursadores:(OI)(CI)M" /Q | Out-Null
    icacls "C:\FTP\LocalUser\Public\General" /grant "Reprobados:(OI)(CI)M" /Q | Out-Null
    icacls "C:\FTP\LocalUser\Public\General" /grant "Recursadores:(OI)(CI)M" /Q | Out-Null
    icacls "C:\FTP\LocalUser\Public\General" /grant "IUSR:(OI)(CI)RX" /Q | Out-Null
    
    $permiso = "$($FTPUserName):(OI)(CI)M"
    icacls "C:\FTP\LocalUser\$FTPUserName" /grant:r $permiso /Q | Out-Null

    Write-Host "[+] Usuario $FTPUserName creado y configurado mediante enlaces simbólicos." -ForegroundColor Green
}