# ==============================
# Funciones de validacion
# ==============================
function validar_ip() {
    local ip=$1
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a oct <<< "$ip"
        for o in "${oct[@]}"; do
            if (( o < 0 || o > 255 )); then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

function es_broadcast_o_red() {
    local ip=$1
    IFS='.' read -r -a oct <<< "$ip"
    [[ ${oct[3]} -eq 0 || ${oct[3]} -eq 255 ]]
}

function ip_a_num() {
    local ip=$1
    IFS='.' read -r -a oct <<< "$ip"
    echo $(( (${oct[0]} << 24) + (${oct[1]} << 16) + (${oct[2]} << 8) + ${oct[3]} ))
}
