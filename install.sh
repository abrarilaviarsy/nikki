#!/bin/bash

# Script configuration
VERSION="3.2"
LOCKFILE="/tmp/nikkitproxy.lock"
BACKUP_DIR="/root/backups-nikki"
TEMP_DIR="/tmp"
NIKKI_DIR="/etc/nikki"
NIKKI_CONFIG="/etc/config/nikki"

setup_colors() {
    PURPLE="\033[95m"
    BLUE="\033[94m"
    GREEN="\033[92m"
    YELLOW="\033[93m"
    RED="\033[91m"
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    RESET="\033[0m"

    STEPS="[${PURPLE} STEPS ${RESET}]"
    INFO="[${BLUE} INFO ${RESET}]"
    SUCCESS="[${GREEN} SUCCESS ${RESET}]"
    WARNING="[${YELLOW} WARNING ${RESET}]"
    ERROR="[${RED} ERROR ${RESET}]"

    # Formatting
    CL=$(echo "\033[m")
    UL=$(echo "\033[4m")
    BOLD=$(echo "\033[1m")
    BFR="\\r\\033[K"
    HOLD=" "
    TAB="  "
}

error_msg() {
    local line_number=${2:-${BASH_LINENO[0]}}
    echo -e "${ERROR} ${1} (Line: ${line_number})" >&2
    echo "Call stack:" >&2
    local frame=0
    while caller $frame; do
        ((frame++))
    done >&2
    exit 1
}

spinner() {
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local colors=("\033[31m" "\033[33m" "\033[32m" "\033[36m" "\033[34m" "\033[35m" "\033[91m" "\033[92m" "\033[93m" "\033[94m")
    local spin_i=0
    local color_i=0
    local interval=0.1

    if ! sleep $interval 2>/dev/null; then
        interval=1
    fi

    printf "\e[?25l"

    while true; do
        local color="${colors[color_i]}"
        printf "\r ${color}%s${CL}" "${frames[spin_i]}"

        spin_i=$(( (spin_i + 1) % ${#frames[@]} ))
        color_i=$(( (color_i + 1) % ${#colors[@]} ))

        sleep "$interval" 2>/dev/null || sleep 1
    done
}

setup_colors

# ... (bagian lain tidak berubah, langsung ke fungsi install_nikki)

install_nikki() {
    echo -e "${INFO} Starting Nikki-TProxy installation..."

    # Check environment
    if [[ ! -x "/bin/opkg" && ! -x "/usr/bin/apk" || ! -x "/sbin/fw4" ]]; then
        error_msg "System requirements not met. Only supports OpenWrt build with firewall4!"
    fi

    # Include openwrt_release
    if [[ ! -f "/etc/openwrt_release" ]]; then
        error_msg "OpenWrt release file not found"
    fi
    . /etc/openwrt_release

    # Get branch/arch
    arch="$DISTRIB_ARCH"
    [[ -z "$arch" ]] && error_msg "Could not determine system architecture"
    
    # Determine branch
    case "$DISTRIB_RELEASE" in
        *"23.05"*)
            branch="openwrt-23.05"
            ;;
        *"24.10"*)
            branch="openwrt-24.10"
            ;;
        "SNAPSHOT")
            branch="SNAPSHOT"
            ;;
        *)
            error_msg "Unsupported OpenWrt release: $DISTRIB_RELEASE"
            ;;
    esac

    # Feed URL (sesuaikan jika ada)
    feed_url="https://github.com/rizkikotet-dev/OpenWrt-nikki-Mod/releases/latest/download"

    # Update & install packages based on package manager
    if [ -x "/bin/opkg" ]; then
        echo -e "${INFO} Using OpenWrt package manager (opkg)"
        cmdinstall "opkg update" "Updating feeds"
        # Get version info by fetching index.json and filtering
        eval "$(wget -O - $feed_url/index.json | jsonfilter -e 'nikki_version=@["packages"]["nikki"]' -e 'luci_app_nikki_version=@["packages"]["luci-app-nikki"]' -e 'luci_i18n_nikki_version=@["packages"]["luci-i18n-nikki-zh-cn"]')"
        cmdinstall "opkg install $feed_url/nikki_${nikki_version}_${arch}.ipk" "Install Nikki"
        cmdinstall "opkg install $feed_url/luci-app-nikki_${luci_app_nikki_version}_all.ipk" "Install Luci Nikki"
        cmdinstall "opkg install $feed_url/luci-i18n-nikki-zh-cn_${luci_i18n_nikki_version}_all.ipk" "Install Luci Nikki i18n"
        rm -f -- *nikki*.ipk
    elif [ -x "/usr/bin/apk" ]; then
        echo -e "${INFO} Using Alpine package manager (apk)"
        cmdinstall "apk update" "Updating feeds"
        cmdinstall "apk add --allow-untrusted -X $feed_url/packages.adb nikki luci-app-nikki luci-i18n-nikki-zh-cn" "Install Nikki Packages"
    fi

    echo -e "${INFO} Nikki-TProxy installation completed successfully!"
}

# ... (lanjutkan fungsi lain sesuai versi kamu)

main