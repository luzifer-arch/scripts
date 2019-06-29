#!/bin/bash
set -euo pipefail

function cleanup() {
	step "Cleaning up"
	rm -rf \
		"${workdir}"
}
trap cleanup EXIT

function error() {
	echo -e "$(tput setaf 1)$@$(tput sgr0)" >&2
}

function fail() {
	error "$@"
	exit 1
}

function step() {
	echo -e "$(tput setaf 6)[$(date)] $@...$(tput sgr0)" >&2
}

function success() {
	echo -e "$(tput setaf 2)$@$(tput sgr0)" >&2
}

function warn() {
	echo -e "$(tput setaf 3)$@$(tput sgr0)" >&2
}

# ---

step "Creating a tempdir as working dir"
workdir=$(mktemp -d)

step "Checking input"
PKG=${1:-}
[[ -n ${PKG} ]] || fail "No package given as first argument"

step "Entering workdir"
pushd "${workdir}"

step "Initialize empty repo"
git init

step "Fetching remote state"
git remote add github git@github.com:luzifer-aur/${PKG}.git
git remote add aur ssh://aur@aur.archlinux.org/${PKG}.git

git fetch github
git fetch aur

step "Checking for differences in remotes"
[[ $(git rev-parse github/master) == $(git rev-parse aur/master) ]] && {
	success "Remote refs are at the same commit"
	exit 0
} || warn "Differences found, action needed"

step "Resetting to Github working state"
git reset --hard github/master

step "Rebasing onto AUR working state"
git rebase aur/master

step "Push to both remotes"
git push aur master
git push github master

step "Leaving working dir"
popd
