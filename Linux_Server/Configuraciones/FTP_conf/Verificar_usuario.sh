#!/bin/bash
verificar_usuarios_ftp() {

    GRUPO_PUBLICO="ftp_public"
    GRUPOS_ORIGEN=("Reprobados" "Recursadores")

    # Crear grupo público si no existe
    if ! getent group "$GRUPO_PUBLICO" > /dev/null; then
        echo "Creando grupo $GRUPO_PUBLICO..."
        groupadd "$GRUPO_PUBLICO"
    fi

    for grupo in "${GRUPOS_ORIGEN[@]}"; do

        # Verificar que el grupo exista
        if getent group "$grupo" > /dev/null; then
            
            echo "Procesando grupo $grupo..."

            # Obtener miembros del grupo
            miembros=$(getent group "$grupo" | cut -d: -f4)

            # Recorrer cada miembro
            IFS=',' read -ra usuarios <<< "$miembros"
            for usuario in "${usuarios[@]}"; do

                if [ -n "$usuario" ]; then
                    # Verificar si ya pertenece al grupo público
                    if id -nG "$usuario" | grep -qw "$GRUPO_PUBLICO"; then
                        echo "$usuario ya pertenece a $GRUPO_PUBLICO"
                    else
                        echo "Agregando $usuario a $GRUPO_PUBLICO"
                        sudo usermod -aG "$GRUPO_PUBLICO" "$usuario"
                    fi
                fi
            done
        else
            echo "El grupo $grupo no existe."
        fi
    done

    echo "Proceso terminado."
}

verificar_usuarios_ftp
