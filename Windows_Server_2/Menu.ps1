Clear-Host

# ===== Cargar módulos =====
. "$PSScriptRoot\Validaciones\Validaciones.ps1"

. "$PSScriptRoot\Funciones_de_Instalacion\Instalar-DHCP.ps1"
. "$PSScriptRoot\Funciones_de_Instalacion\Instalar-DNS.ps1"
. "$PSScriptRoot\Funciones_de_Instalacion\Instalar-SSH.ps1"
. "$PSScriptRoot\Funciones_de_Instalacion\Instalar-FTP.ps1"

. "$PSScriptRoot\Configuracion\Configurar-DHCP.ps1"
. "$PSScriptRoot\Configuracion\Configurar-DNS.ps1"
. "$PSScriptRoot\Configuracion\Configurar-SSH.ps1"
. "$PSScriptRoot\Configuracion\Configurar-FTP.ps1"
. "$PSScriptRoot\Configuracion\Inicializar-FTP.ps1"
. "$PSScriptRoot\Configuracion\http_funciones.ps1"

. "$PSScriptRoot\Eliminacion\Eliminar-DHCP.ps1"
. "$PSScriptRoot\Eliminacion\Eliminar-DNS.ps1"

. "$PSScriptRoot\Monitoreo\Estado-Servicios.ps1"

$Global:ServerIP = ""

function Menu-Principal {

    do {
        Clear-Host
        Write-Host "====== SERVIDOR DHCP / DNS ======"
        Write-Host "1. Instalar DHCP"
        Write-Host "2. Instalar DNS"
        Write-Host "3. Instalar SSH"
	Write-Host "4. Instalar FTP"
        Write-Host "5. Configurar DHCP"
        Write-Host "6. Configurar DNS"
        Write-Host "7. Configurar SSH"
        Write-Host "8. Eliminar Scope DHCP"
        Write-Host "9. Eliminar Dominio DNS"
	Write-Host "10. Registrar Grupo FTP"
	Write-Host "11. Registrar Alumno FTP"
	Write-Host "12. Configurar Acceso Anonimo"
	Write-Host "13. Inicar FTP"
        Write-Host "14. Estado Servicios"
	Write-Host "15. Servidores Web (HTTP)"
        Write-Host "16. Salir"
        Write-Host ""

        $op = Read-Host "Seleccione una opcion"

        switch ($op) {
            "1" { Instalar-DHCP }
            "2" { Instalar-DNS }
	    "3" { Instalar-SSH }
	    "4" { Instalar-FTP }
            "5" { Configurar-DHCP }
            "6" { Configurar-DNS }
            "7" { Configurar-SSH }
            "8" { Eliminar-Scope }
            "9" { Eliminar-Dominio }
	    "10" { Registrar-Grupo-FTP }
	    "11" { Registrar-Alumno-FTP }
	    "12" { Configurar-Anonimo-FTP }
	    "13" { Inicializar-Sitio-FTP }
            "14" { Estado-Servicios }
	    "15" { 
                Clear-Host
                Write-Host "=== DESPLIEGUE HTTP ==="
                Write-Host "1. Desplegar IIS (Requisito Forzoso)"
                Write-Host "2. Desplegar Nginx (via Chocolatey)"
                Write-Host "3. Desplegar Apache (via Chocolatey)"
                $subOp = Read-Host "Seleccione el servidor"
                if ($subOp -eq "1") { Desplegar-IIS }
                elseif ($subOp -eq "2") { Desplegar-Nginx-Windows }
                elseif ($subOp -eq "3") { Desplegar-Apache-Windows }
                else { Write-Host "Opcion invalida"; Pause }
            }
            "16" { break }
            default { Write-Host "Opcion invalida"; Pause }
        }

    } while ($op -ne "0")
}

Menu-Principal