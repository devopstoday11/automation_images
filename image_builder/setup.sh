#!/bin/bash


# This script is called by packer on a vanilla CentOS VM, to setup the image
# used for building images FROM base images. It's not intended to be used
# outside of this context.

set -e

SCRIPT_FILEPATH=$(realpath "$0")
SCRIPT_DIRPATH=$(dirname "$SCRIPT_FILEPATH")
REPO_DIRPATH=$(realpath "$SCRIPT_DIRPATH/../")

# Run as quickly as possible after boot
/bin/bash $REPO_DIRPATH/systemd_banish.sh

# shellcheck source=./lib.sh
source "$REPO_DIRPATH/lib.sh"

$SUDO /bin/bash "$SCRIPT_DIRPATH/install_packages.sh"

$SUDO systemctl enable rngd

$SUDO tee /etc/modprobe.d/kvm-nested.conf <<EOF
options kvm-intel nested=1
options kvm-intel enable_shadow_vmcs=1
options kvm-intel enable_apicv=1
options kvm-intel ept=1
EOF

# This does lots of ugly stuff
finalize
