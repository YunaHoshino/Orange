#!/usr/bin/env bash

export LC_ALL=C

# ---------- COLORS ----------
RESET="\033[0m"
WHITE="\033[97m"
GRAY="\033[38;5;245m"
ORANGE="\033[38;5;214m"
DARK_ORANGE="\033[38;5;208m"
LIGHT_ORANGE="\033[38;5;221m"
RED="\033[38;5;203m"
GREEN="\033[38;5;114m"

# ---------- TERMINAL ----------
hide_cursor() { printf "\033[?25l"; }
show_cursor() { printf "\033[?25h"; }

cleanup() {
    show_cursor
    printf "\033[0m"
    stty echo 2>/dev/null
    exit
}

trap cleanup INT TERM EXIT

hide_cursor

# ---------- HELPERS ----------
bar() {
    local percent=$1
    local width=24
    local filled=$((percent * width / 100))
    local empty=$((width - filled))

    printf "${DARK_ORANGE}"
    printf "%0.s█" $(seq 1 $filled 2>/dev/null)
    printf "${GRAY}"
    printf "%0.s░" $(seq 1 $empty 2>/dev/null)
    printf "${RESET}"
}

human_bytes() {
    local bytes=$1
    local unit=("B" "KB" "MB" "GB" "TB")
    local i=0

    while ((bytes > 1024 && i < 4)); do
        bytes=$((bytes / 1024))
        ((i++))
    done

    echo "${bytes}${unit[$i]}"
}

get_ip() {
    ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}'
}

cpu_usage() {
    read -r cpu a b c idle rest < /proc/stat
    total1=$((a+b+c+idle))
    idle1=$idle

    sleep 0.3

    read -r cpu a b c idle rest < /proc/stat
    total2=$((a+b+c+idle))
    idle2=$idle

    diff_total=$((total2-total1))
    diff_idle=$((idle2-idle1))

    echo $((100 * (diff_total-diff_idle) / diff_total))
}

ram_usage() {
    awk '
    /MemTotal/ {t=$2}
    /MemAvailable/ {a=$2}
    END {printf "%.0f", ((t-a)/t)*100}
    ' /proc/meminfo
}

swap_usage() {
    awk '
    /SwapTotal/ {t=$2}
    /SwapFree/ {f=$2}
    END {
        if (t==0) print 0;
        else printf "%.0f", ((t-f)/t)*100
    }' /proc/meminfo
}

disk_usage() {
    df / --output=pcent | tail -1 | tr -dc '0-9'
}

load_avg() {
    awk '{print $1" "$2" "$3}' /proc/loadavg
}

uptime_pretty() {
    uptime -p 2>/dev/null | sed 's/up //'
}

net_totals() {
    awk '
    NR>2 {
        rx+=$2
        tx+=$10
    }
    END {
        printf "%s %s", rx, tx
    }' /proc/net/dev
}

cpu_temp() {
    local temp="N/A"

    if command -v sensors >/dev/null 2>&1; then
        temp=$(sensors 2>/dev/null | awk '
        /Package id 0:/ {gsub("\\+",""); gsub("°C",""); print $4; exit}
        /Tctl:/ {gsub("\\+",""); gsub("°C",""); print $2; exit}
        ')
    elif [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
        temp=$(awk '{printf "%.1f°C",$1/1000}' /sys/class/thermal/thermal_zone0/temp)
    fi

    echo "${temp:-N/A}"
}

docker_status() {
    if command -v docker >/dev/null 2>&1; then
        if systemctl is-active docker >/dev/null 2>&1; then
            local running total
            running=$(docker ps -q 2>/dev/null | wc -l)
            total=$(docker ps -aq 2>/dev/null | wc -l)
            echo "Running (${running}/${total})"
        else
            echo "Stopped"
        fi
    else
        echo "Not Installed"
    fi
}

detect_panel() {
    local panels=()

    [[ -d /var/www/pterodactyl ]] && panels+=("Pterodactyl")
    [[ -d /var/www/pelican ]] && panels+=("Pelican")
    [[ -d /usr/local/cpanel ]] && panels+=("cPanel")

    if [[ ${#panels[@]} -eq 0 ]]; then
        echo "None"
    else
        echo "${panels[*]}"
    fi
}

# ---------- STATIC INFO ----------
HOST=$(hostname)
OS=$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
KERNEL=$(uname -r)
CPU_MODEL=$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | sed 's/^ //')
CPU_CORES=$(nproc)
IP_ADDR=$(get_ip)

# ---------- NETWORK BASELINE ----------
read RX_PREV TX_PREV <<< "$(net_totals)"
TIME_PREV=$(date +%s)

# ---------- LOOP ----------
while true; do

    CPU=$(cpu_usage)
    RAM=$(ram_usage)
    SWAP=$(swap_usage)
    DISK=$(disk_usage)

    LOAD=$(load_avg)
    USERS=$(who | wc -l)
    PROCS=$(ps -e --no-headers | wc -l)
    TCP=$(ss -tan 2>/dev/null | tail -n +2 | wc -l)

    UPTIME=$(uptime_pretty)
    NOW=$(date +"%H:%M:%S")

    TEMP=$(cpu_temp)

    DOCKER=$(docker_status)
    PANELS=$(detect_panel)

    read RX_NOW TX_NOW <<< "$(net_totals)"
    TIME_NOW=$(date +%s)

    DIFF_TIME=$((TIME_NOW - TIME_PREV))
    ((DIFF_TIME == 0)) && DIFF_TIME=1

    RX_SPEED=$(((RX_NOW - RX_PREV) / DIFF_TIME))
    TX_SPEED=$(((TX_NOW - TX_PREV) / DIFF_TIME))

    RX_PREV=$RX_NOW
    TX_PREV=$TX_NOW
    TIME_PREV=$TIME_NOW

    RX_TOTAL=$(human_bytes "$RX_NOW")
    TX_TOTAL=$(human_bytes "$TX_NOW")
    RX_HUMAN=$(human_bytes "$RX_SPEED")
    TX_HUMAN=$(human_bytes "$TX_SPEED")

    ISSUES=()

    ((CPU > 85)) && ISSUES+=("High CPU")
    ((RAM > 85)) && ISSUES+=("High RAM")
    ((DISK > 90)) && ISSUES+=("Disk Almost Full")

    if [[ "$DOCKER" == "Stopped" ]]; then
        ISSUES+=("Docker Stopped")
    fi

    printf "\033[H\033[J"

    printf "${LIGHT_ORANGE}"
    printf "        /\\\\___/\\\\            ${GRAY}Created by ${WHITE}YunaHoshino${RESET}\n"
    printf "${LIGHT_ORANGE}       (  =^.^= )\n"
    printf "        (\")_(\")${RESET}\n\n"

    printf "${DARK_ORANGE}System${RESET}\n"
    printf "${GRAY}Hostname : ${WHITE}%s\n" "$HOST"
    printf "${GRAY}OS       : ${WHITE}%s\n" "$OS"
    printf "${GRAY}Kernel   : ${WHITE}%s\n" "$KERNEL"
    printf "${GRAY}CPU      : ${WHITE}%s\n" "$CPU_MODEL"
    printf "${GRAY}Cores    : ${WHITE}%s\n" "$CPU_CORES"
    printf "${GRAY}IP       : ${WHITE}%s\n" "${IP_ADDR:-N/A}"
    printf "${GRAY}Users    : ${WHITE}%s   ${GRAY}Processes:${WHITE} %s\n" "$USERS" "$PROCS"
    printf "${GRAY}TCP Conn : ${WHITE}%s\n" "$TCP"
    printf "${GRAY}Uptime   : ${WHITE}%s\n" "$UPTIME"
    printf "${GRAY}Time     : ${WHITE}%s\n\n" "$NOW"

    printf "${DARK_ORANGE}Resources${RESET}\n"

    printf "${GRAY}CPU   ${WHITE}%3s%% ${RESET}" "$CPU"
    bar "$CPU"
    printf "\n"

    printf "${GRAY}RAM   ${WHITE}%3s%% ${RESET}" "$RAM"
    bar "$RAM"
    printf "\n"

    printf "${GRAY}Swap  ${WHITE}%3s%% ${RESET}" "$SWAP"
    bar "$SWAP"
    printf "\n"

    printf "${GRAY}Disk  ${WHITE}%3s%% ${RESET}" "$DISK"
    bar "$DISK"
    printf "\n\n"

    printf "${GRAY}Load Avg : ${WHITE}%s\n" "$LOAD"
    printf "${GRAY}CPU Temp : ${WHITE}%s\n" "$TEMP"
    printf "${GRAY}RX/TX    : ${WHITE}%s/s ↓   %s/s ↑\n" "$RX_HUMAN" "$TX_HUMAN"
    printf "${GRAY}Total    : ${WHITE}%s ↓   %s ↑\n\n" "$RX_TOTAL" "$TX_TOTAL"

    printf "${DARK_ORANGE}Services${RESET}\n"
    printf "${GRAY}Docker : ${WHITE}%s\n" "$DOCKER"
    printf "${GRAY}Panels : ${WHITE}%s\n\n" "$PANELS"

    printf "${DARK_ORANGE}Health${RESET}\n"

    if [[ ${#ISSUES[@]} -eq 0 ]]; then
        printf "${GREEN}System Healthy${RESET}\n"
    else
        for issue in "${ISSUES[@]}"; do
            printf "${RED}• %s${RESET}\n" "$issue"
        done
    fi

    sleep 5
done
