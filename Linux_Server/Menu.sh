
# ==============================
#        MENU PRINCIPAL
# ==============================

source ./Validaciones/validaciones.sh
source ./Funciones_de_Instalacion/Instalar-DHCP.sh
source ./Funciones_de_Instalacion/Instalar-DNS.sh
source ./Funciones_de_Instalacion/Instalar-SSH.sh
source ./Configuraciones/Configurar-DHCP.sh
source ./Configuraciones/Configurar-DNS.sh
source ./Configuraciones/Configurar-SSH.sh
source ./Monitoreos/Lista-Dominios.sh
source ./Monitoreos/Clientes-Conectados.sh
source ./Monitoreos/Reinicio-DHCP.sh

while true; do
    clear
    echo "================================="
    echo "        MENU PRINCIPAL"
    echo "================================="
    echo "1) Instalacion y Verificacion"
    echo "2) Configuracion"
    echo "3) Monitoreo"
    echo "4) Salir"
    echo "================================="
    read -p "Seleccione una opcion: " opcion

    case $opcion in
        1)
            while true; do
                clear
                echo "================================="
                echo "  INSTALACION Y VERIFICACION"
                echo "================================="
                echo "1) DHCP"
                echo "2) DNS"
		echo "3) SSH"
                echo "4) Volver"
                echo "================================="
                read -p "Seleccione una opcion: " subopcion

                case $subopcion in
                    1) Instalar_Silencioso ;;
                    2) Instalar_DNS ;;
		    3) Instalar_SSH ;;
                    4) break ;;
                    *) echo "Opcion invalida"; sleep 2 ;;
                esac
            done
            ;;
        2)
            while true; do
                clear
                echo "================================="
                echo "        CONFIGURACION"
                echo "================================="
                echo "1) Configurar DHCP"
                echo "2) Configuracion DNS"
		echo "3) Configurar_SSH"
                echo "4) Volver"
                echo "================================="
                read -p "Seleccione una opcion: " subopcion

                case $subopcion in
                    1) Configurar_DHCP ;;
                    2)
                        while true; do
                            clear
                            echo "================================="
                            echo "        CONFIGURACION DNS"
                            echo "================================="
                            echo "1) Crear Dominio"
                            echo "2) Eliminar Dominio"
                            echo "3) Volver"
                            echo "================================="
                            read -p "Seleccione una opcion: " dnsop

                            case $dnsop in
                                1) Crear_Dominio ;;
                                2) Eliminar_Dominio ;;
                                3) break ;;
                                *) echo "Opcion invalida"; sleep 2 ;;
                            esac
                        done
                        ;;
		    3) Configurar_SSH ;;
                    4) break ;;
                    *) echo "Opcion invalida"; sleep 2 ;;
                esac
            done
            ;;
        3)
            while true; do
                clear
                echo "================================="
                echo "           MONITOREO"
                echo "================================="
                echo "1) Lista de Dominios"
                echo "2) Clientes conectados"
                echo "3) Reiniciar DHCP"
                echo "4) Volver"
                echo "================================="
                read -p "Seleccione una opcion: " mon

                case $mon in
                    1) listar_dominios ;;
                    2) Monitorear_Clientes ;;
                    3) Iniciar_DHCP ;;
                    4) break ;;
                    *) echo "Opcion invalida"; sleep 2 ;;
                esac
            done
            ;;
        4)
            echo "Saliendo..."
            exit 0
            ;;
        *)
            echo "Opcion invalida"
            sleep 2
            ;;
    esac
done