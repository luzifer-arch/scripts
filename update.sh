#!/bin/bash
set -euxo pipefail

# Create a tempdir to operate in
tempdir=$(mktemp -d)

# Ensure tempdir is removed on exit
function cleanup() {
  rm -rf ${tempdir}
}
trap cleanup EXIT

# Check input
PKG=${1:-}
[[ -n ${PKG} ]] || {
  echo "No package given as first argument" >&2
  exit 1
}

# Initialize git directory
cd ${tempdir}
git init

# Configure user details
git config user.email "jenkins@luzifer.io"
git config user.name "Luzifer.io Jenkins"

# Add AUR as remote
git remote add origin "git@github.com:luzifer-aur/${PKG}.git"

# Get latest state of remote
git fetch --all --tags

# Reset to latest master
git reset --hard origin/master
git branch -u origin/master

# Check for update script
[ -f update_version.sh ] || {
  echo "No update_version.sh found, skipping build."
  exit 0
}

# Execute update script
docker run --rm -i -u $(id -u) \
  -v "$(pwd):$(pwd)" -w "$(pwd)" \
  luzifer/aur-update \
  bash ./update_version.sh

# Check for new commits
(git status --porcelain -b | grep -q '^## .*ahead') || {
  echo "No update-commits were made."
  exit 0
}

# Check whether the build is possible
curl -sSfLo pacman.conf "https://github.com/luzifer-aur/scripts/raw/master/pacman.conf"
docker run --rm -i \
  -v "$(pwd):/src" \
  -v "$(pwd)/pacman.conf:/etc/pacman.conf:ro" \
  --ulimit nofile=262144:262144 \
  luzifer/arch-repo-builder:latest

# Push changes including tags to fork
git push origin master
