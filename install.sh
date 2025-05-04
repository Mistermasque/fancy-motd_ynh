#!/usr/bin/env bash

# Fancy MOTD install script for a YunoHost server
set -euo pipefail

declare -r INSTALL_DIR='/usr/local/share/fancy_motd'
declare -r FANCY_MOTD_SOURCE='https://github.com/bcyran/fancy-motd/archive/refs/heads/master.zip'
declare -r FANCY_MOTD_YNH_SOURCE='https://github.com/Mistermasque/fancy-motd_ynh/archive/refs/heads/main.zip'

# Usage function
usage() {
    cat << USAGE
Usage : 
    sudo -v ; curl -s https://raw.githubusercontent.com/Mistermasque/fancy-motd_ynh/refs/heads/main/install.sh 2>/dev/null | sudo bash [-s uninstall]

OPTIONS :
    -s uninstall : Execute uninstallation instead of installation
USAGE
}


do_install() {
    echo "Check available tools"

    local unzip_tool=''
    local -a unzip_tools_list=('unzip' '7z' 'busybox')
    #make sure unzip tool is available and choose one to work with
    set +e
    for tool in "${unzip_tools_list[@]}"; do
        if type "$tool"; then
            unzip_tool="$tool"
            break
        fi
    done  
    set -e

    if [ -z "$unzip_tool" ]; then
        echo "None of the supported tools for extracting zip archives (${unzip_tools_list[*]}) were found. "
        echo "Please install one of them and try again."
        exit 4
    fi

    echo "Get Fancy MOTD source"

    local tmp_dir=''
    tmp_dir=$(mktemp -d 2>/dev/null)
    cd "$tmp_dir"

    
    local fancy_motd_zip="fancy_motd.zip"
    local unzip_fancy_motd_dir="${tmp_dir}/unzip_dir_fancy_motd"
    wget "$FANCY_MOTD_SOURCE" -O "$fancy_motd_zip"

    local fancy_motd_ynh_zip="fancy_motd_ynh.zip"
    local unzip_fancy_motd_ynh_dir="${tmp_dir}/unzip_dir_fancy_motd_ynh"
    wget "$FANCY_MOTD_YNH_SOURCE" -O "$fancy_motd_ynh_zip"

    # there should be an entry in this switch for each element of unzip_tools_list
    case "$unzip_tool" in
    'unzip')
        unzip -a "$fancy_motd_zip" -d "$unzip_fancy_motd_dir"
        unzip -a "$fancy_motd_ynh_zip" -d "$unzip_fancy_motd_ynh_dir"
        ;;
    '7z')
        7z x "$fancy_motd_zip" "-o$unzip_fancy_motd_dir"
        7z x "$fancy_motd_ynh_zip" "-o$unzip_fancy_motd_ynh_dir"
        
        ;;
    'busybox')
        mkdir -p "$unzip_fancy_motd_dir"
        busybox unzip "$fancy_motd_zip" -d "$unzip_fancy_motd_dir"
        mkdir -p "$unzip_fancy_motd_ynh_dir"
        busybox unzip "$fancy_motd_ynh_zip" -d "$unzip_fancy_motd_ynh_dir"
        ;;
    esac

    echo "Install source to $INSTALL_DIR"

    mkdir -p "$INSTALL_DIR"
    cd "${unzip_fancy_motd_dir}"/*


    cp framework.sh "$INSTALL_DIR"
    cp motd.sh "$INSTALL_DIR"
    cp README.md "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/modules"
    cp ./modules/* "$INSTALL_DIR/modules/"

    echo "Install specific conf to YunoHost"

    mkdir -p /etc/yunohost/hooks.d/{backup,restore}
    
    cd "${unzip_fancy_motd_ynh_dir}"/*
    cp "scripts/backup" /etc/yunohost/hooks.d/backup/40_conf_fancy-motd
    cp "scripts/restore" /etc/yunohost/hooks.d/restore/40_conf_fancy-motd
    cp "config/config" "${INSTALL_DIR}/config.sh"
    

    echo "Setting permissions..."
    chown -R root:root "$INSTALL_DIR"
    chmod -R -x "$INSTALL_DIR"
    chmod -R u=rwX,g=rX,o=rX "$INSTALL_DIR"
    chmod +x "$INSTALL_DIR/motd.sh"
    chmod +x "$INSTALL_DIR/modules/"*


    echo "Activate Fancy MOTD" 
    if [[ -f /etc/motd ]]; then
        mv /etc/motd /etc/motd.disabled
    fi
    ln -sfn "$INSTALL_DIR/motd.sh" "/etc/update-motd.d/30-fancy-motd"

    #cleanup
    cd /
    rm -rf "$tmp_dir"
}

do_uninstall() {
    echo "Uninstall Fancy MOTD"

    rm -f "/etc/update-motd.d/30-fancy-motd"

    if [[ ! -f /etc/motd ]]; then
        mv /etc/motd.disabled /etc/motd
    else
        rm -f /etc/motd.disabled
    fi

    rm -f "/etc/yunohost/hooks.d/backup/40_conf_fancy-motd"
    rm -f "/etc/yunohost/hooks.d/restore/40_conf_fancy-motd"
    rm -rf "$INSTALL_DIR"
}

# Check if I am root
if [[ ${EUID} -ne 0 ]]; then
  echo "You need to be root to run this script" >&2
  usage
  exit 1
fi

# Check if we are in a YunoHost instance
if ! type yunohost > /dev/null 2>&1; then
    echo "You are not in a YunoHost server !" >&2
    exit 1
fi

#check for uninstall flag
flag=${1-}
if [[ -n "$flag" ]] && [[ "$flag" != "uninstall" ]]; then
    usage
fi

if [ -n "$flag" ]; then
    do_uninstall
    exit 0
fi

do_install
