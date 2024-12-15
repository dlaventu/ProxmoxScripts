#!/usr/bin/env bash

# Copyright (c) 2024 dlaventu
# Author: dlaventu
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# https://patorjk.com/software/taag/#p=display&f=Small%20Slant&t=Wake%20on%20LAN

header_info() {
  clear
  cat <<"EOF"
  _      __     __                     __   ___   _  __
 | | /| / /__ _/ /_____   ___  ___    / /  / _ | / |/ /
 | |/ |/ / _ `/  '_/ -_) / _ \/ _ \  / /__/ __ |/    / 
 |__/|__/\_,_/_/\_\\__/  \___/_//_/ /____/_/ |_/_/|_/ 

EOF
}

RD=$(echo "\033[01;31m")
YW=$(echo "\033[33m")
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"

set -euo pipefail
shopt -s inherit_errexit nullglob

msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}..."
}

msg_ok() {
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

msg_error() {
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

header_info
whiptail --backtitle "Proxmox VE Helper Scripts" --title "Wake on LAN" --yesno "This script will activate Wake on LAN. Proceed?" 10 58 || exit
WOL_MENU=()
MSG_MAX_LENGTH=0
while read -r TAG ITEM; do
  OFFSET=2
  ((${#ITEM} + OFFSET > MSG_MAX_LENGTH)) && MSG_MAX_LENGTH=${#ITEM}+OFFSET
  WOL_MENU+=("$TAG" "$ITEM " "OFF")
done < <(ip link show master vmbr0 | awk '/vmbr0/ {sub(/:$/, "", $2); print $2}')
interface=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "Select Interface" --checklist "\nSelect on which interface to activate Wake on LAN:\n" 16 $((MSG_MAX_LENGTH + 58)) 6 "${WOL_MENU[@]}" 3>&1 1>&2 2>&3 | tr -d '"') || exit
[ -z "$interface" ] && {
    whiptail --backtitle "Proxmox VE Helper Scripts" --title "No Interface" --msgbox "It appears that no interface was selected" 10 68
    msg_error "No change was made to the system"
    exit
}
CHOICE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "Activate Wake on LAN" --menu "\nThis will activate Wake on LAN on interface $interface.\n \nContinue?" 14 68 2 \
  "yes" " " \
  "no" " " 3>&2 2>&1 1>&3)

case $CHOICE in
  yes)
    set +e
	ETHTOOL_INSTALLED=$(dpkg-query -W ethtool)
	if [[ $? -gt 0 ]]; then
		msg_error "Package ethtool not installed."
		exit
	fi
	WOL_ACTIVE=$(grep "post-up /usr/sbin/ethtool -s $interface wol g" /etc/network/interfaces)
	if [[ -z "$WOL_ACTIVE" ]]; then
		sed -i "/^iface $interface/a \\\tpost-up /usr/sbin/ethtool -s $interface wol g" /etc/network/interfaces
		msg_ok "Wake on LAN activated on $interface\n"
  		echo -e "-- Remember to activate Wake on LAN in the BIOS --\n"
    		echo -e "-- Changes will take effect after next reboot --\n"
	else
		msg_error "Wake on LAN already active on interface $interface\n"
	fi
    ;;
  no)
    msg_error "No change was made to the system\n"
    ;;
esac
