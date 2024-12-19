#!/bin/bash
#
# pve-nag-buster.sh (v04) https://github.com/foundObjects/pve-nag-buster
# Copyright (C) 2019 /u/seaQueue (reddit.com/u/seaQueue)
#
# Removes Proxmox VE 6.x+ license nags automatically after updates
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

set -euo pipefail

NAGFILE="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
SCRIPT="$(basename "$0")"

# disable license nag: https://johnscs.com/remove-proxmox51-subscription-notice/

echo "$SCRIPT: Removing Nag ..."
if ! out=$(patch -N -p0 -r - -d "$(dirname "${NAGFILE}")" -i "${SCRIPT_DIR}/${SCRIPT%.sh}.patch"); then
  if [[ $out == *"Skipping patch"* ]]; then
    echo "$SCRIPT: Patch was already applied."
  else
    echo "$SCRIPT: Patch failed!"
    echo "$out"
    exit 1
  fi
else
  echo "$SCRIPT: Patch applied, restarting pveproxy.service ..."
  systemctl restart pveproxy.service
fi

# disable paid repo list

PAID_BASE="/etc/apt/sources.list.d/pve-enterprise"

if [ -f "$PAID_BASE.list" ]; then
  echo "$SCRIPT: Disabling PVE paid repo list ..."
  mv -f "$PAID_BASE.list" "$PAID_BASE.disabled"
fi
