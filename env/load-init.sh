#!/bin/bash

# Some default configuration variables
: ${CVMFS_NAMESPACE='/cvmfs/alice-nightlies.cern.ch'}
: ${ARCH_DIR_CVMFS='el7-x86_64/Packages'}
: ${ARCH_DIR_ALIBUILD='slc7_x86-64'}

if [[ ! $LOAD_PACKAGES ]]; then
  echo "ERROR: export the variable \$LOAD_PACKAGES first" >&2
  return
fi

# Creates a fake temporary work directory to load packages
PACKAGES_PREFIX="$CVMFS_NAMESPACE/$ARCH_DIR_CVMFS"
WORK_DIR="$(mktemp -d)"
ln -nfs "$PACKAGES_PREFIX" "$WORK_DIR/slc7_x86-64"

for PKG in $(echo "$LOAD_PACKAGES" | sed -e 's/,/ /g'); do
  # Loading the environment is non-fatal
  source "$PACKAGES_PREFIX/$PKG/etc/profile.d/init.sh" > /dev/null 2>&1
done

# Cleanup
rm -rf "$WORK_DIR"
unset PKG PACKAGES_PREFIX WORK_DIR
