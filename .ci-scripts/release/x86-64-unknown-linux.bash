#!/bin/bash

# x86-64-unknown-linux release:
#
# - Builds release package
# - Uploads to Cloudsmith
#
# Tools required in the environment that runs this:
#
# - bash
# - cloudsmith-cli
# - GNU gzip
# - GNU make
# - ponyc (musl based version)
# - GNU tar

set -o errexit

# Pull in shared configuration specific to this repo
base=$(dirname "$0")
source "${base}/config.bash"

# Verify ENV is set up correctly
# We validate all that need to be set in case, in an absolute emergency,
# we need to run this by hand. Otherwise the GitHub actions environment should
# provide all of these if properly configured
if [[ -z "${CLOUDSMITH_API_KEY}" ]]; then
  echo -e "\e[31mCloudsmith API key needs to be set in CLOUDSMITH_API_KEY. Exiting."
  exit 1
fi

if [[ -z "${GITHUB_REPOSITORY}" ]]; then
  echo -e "\e[31mName of this repository needs to be set in GITHUB_REPOSITORY."
  echo -e "\e[31mShould be in the form OWNER/REPO, for example:"
  echo -e "\e[31m     ponylang/ponyup"
  echo -e "\e[31mExiting."
  exit 1
fi

if [[ -z "${APPLICATION_NAME}" ]]; then
  echo -e "\e[31mAPPLICATION_NAME needs to be set."
  echo -e "\e[31mExiting."
  exit 1
fi

if [[ -z "${APPLICATION_SUMMARY}" ]]; then
  echo -e "\e[31mAPPLICATION_SUMMARY needs to be set."
  echo -e "\e[31mIt's a short description of the application that will appear in Cloudsmith."
  echo -e "\e[31mExiting."
  exit 1
fi

if [[ -z "${CLOUDSMITH_REPO}" ]]; then
  echo -e "\e[31mCLOUDSMITH_REPO needs to be set."
  echo -e "\e[31mShould be one of:"
  echo -e "\e[35m     nightlies"
  echo -e "\e[35m     releases"
  echo -e "\e[31mExiting."
  exit 1
fi

# no unset variables allowed from here on out
# allow above so we can display nice error messages for expected unset variables
set -o nounset

TODAY=$(date +%Y%m%d)

# Compiler target parameters
ARCH=x86-64

# Triple construction
VENDOR=unknown
OS=linux
TRIPLE=${ARCH}-${VENDOR}-${OS}

# Build parameters
BUILD_PREFIX=$(mktemp -d)
APPLICATION_VERSION="nightly-${TODAY}"
BUILD_DIR=${BUILD_PREFIX}/${APPLICATION_VERSION}

# Asset information
PACKAGE_DIR=$(mktemp -d)
PACKAGE=${APPLICATION_NAME}-${TRIPLE}

# Cloudsmith configuration
CLOUDSMITH_VERSION=${TODAY}
ASSET_OWNER=ponylang
ASSET_REPO=${CLOUDSMITH_REPO}
ASSET_PATH=${ASSET_OWNER}/${ASSET_REPO}
ASSET_FILE=${PACKAGE_DIR}/${PACKAGE}.tar.gz
ASSET_SUMMARY="${APPLICATION_SUMMARY}"
ASSET_DESCRIPTION="https://github.com/${GITHUB_REPOSITORY}"

# Build application installation
echo -e "\e[34mBuilding ${APPLICATION_NAME}..."
make install prefix="${BUILD_DIR}" arch=${ARCH} \
  version="${APPLICATION_VERSION}" static=true linker=bfd

# Package it all up
echo -e "\e[34mCreating .tar.gz of ${APPLICATION_NAME}..."
pushd "${BUILD_PREFIX}" || exit 1
tar -cvzf "${ASSET_FILE}" *
popd || exit 1

# Ship it off to cloudsmith
echo -e "\e[34mUploading package to cloudsmith..."
cloudsmith push raw --version "${CLOUDSMITH_VERSION}" \
  --api-key "${CLOUDSMITH_API_KEY}" --summary "${ASSET_SUMMARY}" \
  --description "${ASSET_DESCRIPTION}" ${ASSET_PATH} "${ASSET_FILE}"