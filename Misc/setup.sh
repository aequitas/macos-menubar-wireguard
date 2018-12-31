#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2018 Charlie Matlack. All Rights Reserved.

die() {
	echo "[-] Error: $1" >&2
	exit 1
}

PROGRAM="${0##*/}"
ARGS=( "$@" )
SELF="${BASH_SOURCE[0]}"
[[ $SELF == */* ]] || SELF="./$SELF"
SELF="$(cd "${SELF%/*}" && pwd -P)/${SELF##*/}"

[[ ${BASH_VERSINFO[0]} -ge 4 ]] || die "bash ${BASH_VERSINFO[0]} detected, when bash 4+ required"

echo "[+] Checking for required dependencies using Homebrew..."
type brew >/dev/null || /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" || die "Failed to install Homebrew"
type wg >/dev/null || brew install wireguard-tools || die "Failed to install wireguard"
type jq >/dev/null || brew install jq || die "Failed to install jq"

# This will be slow
brew update && brew upgrade

echo "[+] Done setting up required dependencies."