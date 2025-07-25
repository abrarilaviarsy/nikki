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

setup_colors

feed_url="https://github.com/rizkikotet-dev/OpenWrt-nikki-Mod/releases/latest/download"

if [ -x "/bin/opkg" ]; then
    # update feeds
    echo -e "${INFO} update feeds"
    opkg update
    # get languages
    echo -e "${INFO} get languages"
    languages=$(opkg list-installed luci-i18n-base-* | cut -d ' ' -f 1 | cut -d '-' -f 4-)
    # get latest version
    echo -e "${INFO} get latest version"
    wget -O nikki.version $feed_url/index.json
    # install ipks
    echo -e "${INFO} install ipks"
    eval "$(jsonfilter -i nikki.version -e "nikki_version=@['packages']['nikki']" -e "luci_app_nikki_version=@['packages']['luci-app-nikki']")"
    arch="$(. /etc/openwrt_release; echo $DISTRIB_ARCH)"
    opkg install "$feed_url/nikki_${nikki_version}_${arch}.ipk"
    opkg install "$feed_url/luci-app-nikki_${luci_app_nikki_version}_all.ipk"
    for lang in $languages; do
        lang_version=$(jsonfilter -i nikki.version -e "@['packages']['luci-i18n-nikki-${lang}']")
        opkg install "$feed_url/luci-i18n-nikki-${lang}_${lang_version}_all.ipk"
    done

    rm -f nikki.version
elif [ -x "/usr/bin/apk" ]; then
    # update feeds
    echo -e "${INFO} update feeds"
    apk update
    # get languages
    echo -e "${INFO} get languages"
    languages=$(apk list --installed --manifest luci-i18n-base-* | cut -d ' ' -f 1 | cut -d '-' -f 4-)
    # install apks from remote repository
    echo -e "${INFO} install apks from remote repository"
    apk add --allow-untrusted -X $feed_url/packages.adb nikki luci-app-nikki
    for lang in $languages; do
        apk add --allow-untrusted -X $feed_url/packages.adb "luci-i18n-nikki-${lang}"
    done
fi

echo -e "${SUCCESS} success"