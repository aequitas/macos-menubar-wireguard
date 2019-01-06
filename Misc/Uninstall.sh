#!/bin/sh

set -x

osascript -e 'tell application "WireGuardStatusbar" to quit'

# Also uninstall old version of the helper
sudo launchctl unload /Library/LaunchDaemons/nl.ijohan.WireGuardStatusbarHelper.plist
sudo rm /Library/LaunchDaemons/nl.ijohan.WireGuardStatusbarHelper.plist
sudo rm /Library/PrivilegedHelperTools/nl.ijohan.WireGuardStatusbarHelper

# Unload and remove the Helper
sudo launchctl unload /Library/LaunchDaemons/WireGuardStatusbarHelper.plist
sudo rm /Library/LaunchDaemons/WireGuardStatusbarHelper.plist
sudo rm /Library/PrivilegedHelperTools/WireGuardStatusbarHelper

# Also remove application
sudo rm -r /Applications/WireGuardStatusbar.app/

# And all settings
defaults delete WireGuardStatusbar
sudo defaults delete WireGuardStatusbarHelper

exit 0
