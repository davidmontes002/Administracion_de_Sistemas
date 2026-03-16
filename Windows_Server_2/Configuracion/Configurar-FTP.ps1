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
    
    if ($opcGrupo -eq "1") { 
        $FTPUserGroupName = "Reprobados" 
    } else { 
        $FTPUserGroupName = "Recursadores" 
    }

    Write-Host "[*] 1. Creando usuario nativo..." -ForegroundColor Cyan
    $passSecure = ConvertTo-SecureString $FTPPassword -AsPlainText -Force
    New-LocalUser -Name $FTPUserName -Password $passSecure -Description "Usuario FTP" | Out-Null
    Start-Sleep -Seconds 1

    Write-Host "[*] 2. Asignando al grupo '$FTPUserGroupName'..." -ForegroundColor Cyan
    $miembros = Get-LocalGroupMember -Group $FTPUserGroupName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
    if ($miembros -notmatch $FTPUserName) {
        Add-LocalGroupMember -Group $FTPUserGroupName -Member $FTPUserName
    }

    Write-Host "[*] 3. Creando Uniones de Directorio (Nativo NTFS)..." -ForegroundColor Cyan
    $rutaUser = "C:\FTP\LocalUser\$FTPUserName"
    
    if (-not(Test-Path $rutaUser)) { New-Item -Path $rutaUser -ItemType Directory -Force | Out-Null }
    if (-not(Test-Path "$rutaUser\$FTPUserName")) { New-Item -Path "$rutaUser\$FTPUserName" -ItemType Directory -Force | Out-Null }
        
    if (Test-Path "$rutaUser\General") { cmd /c rmdir "$rutaUser\General" }
    if (Test-Path "$rutaUser\$FTPUserGroupName") { cmd /c rmdir "$rutaUser\$FTPUserGroupName" }

    cmd /c mklink /J "$rutaUser\General" "C:\FTP\LocalUser\Public\General" | Out-Null
    cmd /c mklink /J "$rutaUser\$FTPUserGroupName" "C:\FTP\$FTPUserGroupName" | Out-Null

    Write-Host "[*] 4. Aplicando Permisos Automatizados (Anti-Error 550)..." -ForegroundColor Cyan
    
    # Permiso base para que Windows no bloquee el cruce de carpetas
    icacls "C:\FTP\LocalUser\Public" /grant "Usuarios:(X)" /Q | Out-Null
    icacls "C:\FTP\LocalUser\Public" /grant "Users:(X)" /Q | Out-Null
    
    # Inyección de Control Total (F) directamente al USUARIO RECIÉN CREADO
    icacls "C:\FTP\LocalUser\Public\General" /grant "${FTPUserName}:(OI)(CI)F" /T /Q | Out-Null
    icacls "C:\FTP\$FTPUserGroupName" /grant "${FTPUserName}:(OI)(CI)F" /T /Q | Out-Null
    icacls $rutaUser /grant "${FTPUserName}:(OI)(CI)F" /T /Q | Out-Null
    
    # Permisos sobre los enlaces de unión
    icacls "$rutaUser\General" /grant "${FTPUserName}:(OI)(CI)F" /Q | Out-Null
    icacls "$rutaUser\$FTPUserGroupName" /grant "${FTPUserName}:(OI)(CI)F" /Q | Out-Null

    Write-Host "[*] 5. Refrescando reglas de IIS de forma automática..." -ForegroundColor Cyan
    Import-Module WebAdministration
    Clear-WebConfiguration -Filter "/system.ftpServer/security/authorization" -PSPath IIS:\ -Location "FTP"
    Add-WebConfiguration "/system.ftpServer/security/authorization" -Value @{accessType="Allow";users="?";permissions=1} -PSPath IIS:\ -Location "FTP"
    Add-WebConfiguration "/system.ftpServer/security/authorization" -Value @{accessType="Allow";users="*";permissions=3} -PSPath IIS:\ -Location "FTP"
    
    Restart-Service ftpsvc -Force

    Write-Host "[+] ¡Listo! Usuario $FTPUserName creado y configurado con acceso total 100% automático." -ForegroundColor Green
}