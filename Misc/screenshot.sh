#!/bin/bash

set -ex

# create a screenshot of the WireGuard statusbar App

screenshotfile=${1:?Provide screenshot destination file as first argument}
configdir=/etc/wireguard
localconfigdir=/usr/local/etc/wireguard

cleanup (){
    # stop the application
    osascript -e 'tell application "WireGuardStatusbar" to quit'

    # restore configuration directories
    sudo rm -f "$configdir"/{example.com,Home,Server}.conf
    sudo mv "$configdir"/backup/*.conf "$configdir"/ || true
    sudo mv "$localconfigdir"/backup/*.conf "$localconfigdir" || true

    # restore desktop icons
    defaults write com.apple.finder CreateDesktop true
    killall Finder
}
trap cleanup EXIT

hide_all () {
    osascript - <<EOF
tell application "System Events"
	--set visible of every process whose visible is true and name is not in {"Finder", name of current application} to false
	set visible of every process whose visible is true and name is not "Finder" and frontmost is false to false
end tell
EOF
}

hide_all
defaults write com.apple.finder CreateDesktop false && killall Finder

sudo mkdir -p "$configdir"/backup/ "$localconfigdir"/backup/
sudo mv "$configdir"/*.conf "$configdir"/backup/ || true
sudo mv "$localconfigdir"/*.conf "$localconfigdir"/backup/ || true

sudo cp Misc/example.com.conf "$configdir"/
sudo cp Misc/example.com.conf "$configdir"/Home.conf
sudo cp Misc/example.com.conf "$configdir"/Server.conf

open WireGuardStatusbar.app

echo "Taking screenshot in 5 seconds."
sleep 5
screencapture -R1200,0,480,300 "$screenshotfile"
