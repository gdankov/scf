#!/bin/bash
set -o errexit -o nounset

# Versions of the pieces pulled into SCF (outside of submodules).
# This file is sourced everywhere one or more of the versions are
# needed.

# Used in: bin/dev/install_tools.sh

export BOSH_CLI_VERSION="fcaa9c6caff58ab8da8c56481320681cdea492ee"
export CFCLI_VERSION="6.37.0"
export FISSILE_FLAVOR="develop"
export FISSILE_VERSION="7.0.0+131.g973bfeb"
export HELM_VERSION="2.11.0"
export KK_VERSION="576a42386770423ced46ab4ae9955bee59b0d4dd"
export KUBECTL_VERSION="1.9.6"
export K_VERSION="0.0.12"
export STAMPY_VERSION="0.0.0.22.gbb93bf3"
export UBUNTU_VERSION="14.04"

# For stampy we need the major+minor+patch as a separate value.
export STAMPY_MAJOR=$(echo "$STAMPY_VERSION" | sed -e 's/\.g.*//' -e 's/\.[^.]*$//')

# Used in: .envrc

if [ "${USE_SLE_BASE:-false}" == "false" ]
then
	export FISSILE_STEMCELL_VERSION=${FISSILE_STEMCELL_VERSION:-42.3-14.g36210d2-30.32}
else
	export FISSILE_STEMCELL_VERSION=${FISSILE_STEMCELL_VERSION:-12SP3-15.g9446815-0.170}
fi

# Used in: bin/generate-dev-certs.sh

export GOLANG_VERSION=1.7

# Used in: make/include/versioning

export CF_VERSION=2.7.0

# Show versions, if called on its own.
# # ## ### ##### ######## ############# #####################

if [ "X$(basename -- "$0")" = "Xversions.sh" ]
then
    echo bosh-cli '     =' $BOSH_CLI_VERSION
    echo cf '           =' $CF_VERSION
    echo cf-cli '       =' $CFCLI_VERSION
    echo fissile '      =' $FISSILE_VERSION
    echo go '           =' $GOLANG_VERSION
    echo helm '         =' $HELM_VERSION
    echo k '            =' $K_VERSION
    echo kk '           =' $KK_VERSION
    echo kubectl '      =' $KUBECTL_VERSION
    echo stampy '       =' $STAMPY_VERSION
    echo stemcell '     =' $FISSILE_STEMCELL_VERSION
    echo ubuntu '       =' $UBUNTU_VERSION
    echo
fi
