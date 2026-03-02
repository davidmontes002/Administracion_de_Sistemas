#!/bin/bash
if [ ! -d "/etc/bind" ]; then
	sudo mkdir -p /etc/bind
	sudo touch /etc/bind/named.conf.local
fi
# ==============================
#        MENU PRINCIPAL
# ==============================

source ./Validaciones/validaciones.sh
source ./Funciones_de_Instalacion/Instalar-DHCP.sh
source ./Funciones_de_Instalacion/Instalar-DNS.sh
source ./Funciones_de_Instalacion/Instalar-SSH.sh
source ./Funciones_de_Instalacion/Instalar-FTP.sh
source ./Configuraciones/Configurar-DHCP.sh
source ./Configuraciones/Configurar-DNS.sh
source ./Configuraciones/Configurar-SSH.sh
source ./Configuraciones/FTP_conf/Registro_grupos.sh
source ./Configuraciones/FTP_conf/Registro_alumnos.sh
source ./Configuraciones/FTP_conf/cambio_grupo.sh
source ./Configuraciones/FTP_conf/anonimo.sh
source ./Configuraciones/FTP_conf/Verificar_usuario.sh
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
		echo "4) FTP"
		echo "5) Volver"
                echo "================================="
                read -p "Seleccione una opcion: " subopcion

                case $subopcion in
                    1) Instalar_Silencioso ;;
                    2) Instalar_DNS ;;
		    3) Instalar_SSH ;;
		    4) Instalar_FTP ;;
                    5) break ;;
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
		echo "4) Configuracion FTP"
                echo "5) Volver"
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
		    4)
        		while true; do
            		    clear
            		    echo "================================="
            		    echo "        CONFIGURACION FTP"
            		    echo "================================="
            		    echo "1) Registrar Grupo"
            		    echo "2) Registrar Alumno"
            		    echo "3) Cambiar Grupo"
            		    echo "4) Activar/Desactivar Anonimo"
			    echo "5) Verificar Usuarios existentes"
            		    echo "6) Volver"
            		    echo "================================="
            		    read -p "Seleccione una opcion: " ftpconf

            		    case $ftpconf in
                		1) crear_grupo ;;
                		2) Registrar_Alumno ;;
                		3) Cambiar_Grupo ;;
                		4) Usuario_Anonimo ;;
				5) Verificar_usuario.sh ;;
                		6) break ;;
                		*) echo "Opcion invalida"; sleep 2 ;;
            		    esac
        		done
        		;;
                    5) break ;;
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
