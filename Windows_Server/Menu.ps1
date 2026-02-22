Clear-Host

# ===== Cargar módulos =====
. "$PSScriptRoot\Validaciones\Validaciones.ps1"

. "$PSScriptRoot\Funciones_de_Instalacion\Instalar-DHCP.ps1"
. "$PSScriptRoot\Funciones_de_Instalacion\Instalar-DNS.ps1"
. "$PSScriptRoot\Funciones_de_Instalacion\Instalar-SSH.ps1"

. "$PSScriptRoot\Configuracion\Configurar-DHCP.ps1"
. "$PSScriptRoot\Configuracion\Configurar-DNS.ps1"
. "$PSScriptRoot\Configuracion\Configurar-SSH.ps1"

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
        Write-Host "4. Configurar DHCP"
        Write-Host "5. Configurar DNS"
        Write-Host "5. Configurar SSH"
        Write-Host "6. Eliminar Scope DHCP"
        Write-Host "7. Eliminar Dominio DNS"
        Write-Host "8. Estado Servicios"
        Write-Host "0. Salir"
        Write-Host ""

        $op = Read-Host "Seleccione una opcion"

        switch ($op) {
            "1" { Instalar-DHCP }
            "2" { Instalar-DNS }
	    "3" { Instalar-SSH }
            "4" { Configurar-DHCP }
            "5" { Configurar-DNS }
            "6" { Configurar-SSH }
            "7" { Eliminar-Scope }
            "8" { Eliminar-Dominio }
            "9" { Estado-Servicios }
            "0" { break }
            default { Write-Host "Opción invalida"; Pause }
        }

    } while ($op -ne "0")
}

Menu-Principal