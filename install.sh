#!/bin/bash

# Copyright (C) 2021 Elliot Killick <elliotkillick@zohomail.eu>
# Licensed under the MIT License. See LICENSE file for details.

error() {
    exit_code="$?"
    echo -e "${RED}[!]${NC} An unexpected error has occurred! Exiting..." >&2
    exit "$exit_code"
}

trap error ERR

RED='\033[0;31m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

# Step 3
if [ -f "/usr/lib/qubes/qubes-windows-tools.iso" ]; then
    echo -e "${BLUE}[i]${NC} Qubes Windows Tools is already installed in Dom0. Skipping download..." >&2
else
    echo -e "${BLUE}[i]${NC} Installing Qubes Windows Tools..." >&2
    if ! sudo qubes-dom0-update -y qubes-windows-tools; then
        echo -e "${RED}[!]${NC} Error installing Qubes Windows Tools! Exiting..." >&2
        exit 1
    fi
    if ! [ -f "/usr/lib/qubes/qubes-windows-tools.iso" ]; then
        echo -e "${RED}[!]${NC} Qubes Windows Tools package is installed, but /usr/lib/qubes/qubes-windows-tools.iso is still missing in Dom0. Exiting..." >&2
        exit 1
    fi
fi

resources_qube="$(qubes-prefs default_dispvm)"
resources_dir="/home/user/Documents/qvm-create-windows-qube"
template="$(qubes-prefs default_dispvm)"

echo -e "${BLUE}[i]${NC} Increasing storage capacity of $resources_qube..." >&2
qvm-volume extend "$resources_qube:private" 60GiB


echo -e "${BLUE}[i]${NC} Installing package dependencies on $template..." >&2
fedora_packages="genisoimage geteltorito datefudge"
debian_packages="genisoimage curl datefudge"
script='if grep -q '\''ID=fedora'\'' /etc/os-release; then
  sudo dnf -y install '"$fedora_packages"'
elif grep -q '\''ID=debian'\'' /etc/os-release; then
  sudo apt-get -y install '"$debian_packages"'
else
  echo "Unsupported distribution."
  exit 1
fi'

qvm-run -p "$template" "$script"


echo -e "${BLUE}[i]${NC} Cloning qvm-create-windows-qube GitHub repository..." >&2
qvm-run -p "$resources_qube" "cd ${resources_dir%/*} && git clone https://github.com/elliotkillick/qvm-create-windows-qube"

echo -e "${BLUE}[i]${NC} Please check for a \"Good signature\" from GPG (Verify it out-of-band if necessary)..." >&2
qvm-run -p "$resources_qube" "cd '$resources_dir' && gpg --import author.asc && git verify-commit \$(git rev-list --max-parents=0 HEAD)"


echo -e "${BLUE}[i]${NC} Copying qvm-create-windows-qube main program to Dom0..." >&2
qvm-run -p --filter-escape-chars --no-color-output "$resources_qube" "cat '$resources_dir/qvm-create-windows-qube'" | sudo tee /usr/bin/qvm-create-windows-qube > /dev/null

# Allow execution of script
sudo chmod +x /usr/bin/qvm-create-windows-qube

echo -e "${GREEN}[+]${NC} Installation complete!"
