#!/bin/sh
# shellcheck disable=SC2064
set -eu

# pve-nag-buster (v04) https://github.com/foundObjects/pve-nag-buster
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

# ensure a predictable environment
PATH=/usr/sbin:/usr/bin:/sbin:/bin
\unalias -a

# installer main body:
_main() {
  # ensure $1 exists so 'set -u' doesn't error out
  { [ "$#" -eq "0" ] && set -- ""; } > /dev/null 2>&1

  case "$1" in
    "--uninstall")
      # uninstall, requires root
      assert_root
      _uninstall
      ;;
    "--install" | "")
      # install dpkg hooks, requires root
      assert_root
      _install "$@"
      ;;
    *)
      # unknown flags, print usage and exit
      _usage
      ;;
  esac
  exit 0
}

_uninstall() {
  set -x
  [ -f "/etc/apt/apt.conf.d/86pve-nags" ] &&
    rm -f "/etc/apt/apt.conf.d/86pve-nags"
  [ -f "/usr/share/pve-nag-buster.sh" ] &&
    rm -f "/usr/share/pve-nag-buster.sh"
  [ -f "/usr/share/pve-nag-buster.patch" ] &&
    rm -f "/usr/share/pve-nag-buster.patch"

  echo "Script and dpkg hooks removed, please manually remove /etc/apt/sources.list.d/pve-no-subscription.list if desired"
}

_install() {
  # create hooks and no-subscription repo list, install hook script, run once

  VERSION_CODENAME=''
  ID=''
  . /etc/os-release
  if [ -n "$VERSION_CODENAME" ]; then
    RELEASE="$VERSION_CODENAME"
  else
    RELEASE=$(awk -F"[)(]+" '/VERSION=/ {print $2}' /etc/os-release)
  fi

  # create the pve-no-subscription list
  echo "Creating PVE no-subscription repo list ..."
  cat <<- EOF > "/etc/apt/sources.list.d/pve-no-subscription.list"
	# .list file automatically generated by pve-nag-buster at $(date)
	#
	# If pve-nag-buster is installed again this file will be overwritten
	#

	deb http://download.proxmox.com/debian/pve $RELEASE pve-no-subscription
	EOF

  # create dpkg pre/post install hooks for persistence
  echo "Creating dpkg hooks in /etc/apt/apt.conf.d ..."
  cat <<- 'EOF' > "/etc/apt/apt.conf.d/86pve-nags"
	DPkg::Pre-Install-Pkgs {
	    "while read -r pkg; do case $pkg in *proxmox-widget-toolkit* | *pve-manager*) touch /tmp/.pve-nag-buster && exit 0; esac done < /dev/stdin";
	};

	DPkg::Post-Invoke {
	    "[ -f /tmp/.pve-nag-buster ] && { /usr/share/pve-nag-buster.sh; rm -f /tmp/.pve-nag-buster; }; exit 0";
	};
	EOF

  # install the hook script
  echo "Installing hook script as /usr/share/pve-nag-buster.sh"
  install -o root -m 0550 "pve-nag-buster.sh" "/usr/share/pve-nag-buster.sh"
  install -o root -m 0440 "pve-nag-buster.patch" "/usr/share/pve-nag-buster.patch"

  echo "Running patch script"
  /usr/share/pve-nag-buster.sh

  return 0
}

assert_root() { [ "$(id -u)" -eq '0' ] || { echo "This action requires root." && exit 1; }; }
_usage() { echo "Usage: $(basename "$0") (--uninstall)"; }

_main "$@"
