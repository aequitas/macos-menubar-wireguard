SHELL=/bin/bash

brew_bin=$(shell brew --prefix)/bin
convert=${brew_bin}/convert
xcpretty=${HOME}/.gem/ruby/2.3.0/bin/xcpretty

all: icons WireguardStatusbar.dmg

build_dest=build/Release

WireguardStatusbar.dmg: dist/WireguardStatusbar.app
	rm -rf "$@"
	hdiutil create "$@" -srcfolder "${<D}" -ov

sources=$(shell find "Wireguard Statusbar" Shared HelperTool *.swift|sed 's/ /\\ /')

dist/WireguardStatusbar.app: ${TMPDIR}/WireguardStatusbar.xcarchive/Products/Applications/WireguardStatusbar.app
	rm -fr "${@D}/"
	mkdir -p "${@D}/"
	ln -sf /Applications "${@D}/Applications"
	cp -r "$<" "$@"

${TMPDIR}/WireguardStatusbar.xcarchive/Products/Applications/WireguardStatusbar.app: ${TMPDIR}/WireguardStatusbar.xcarchive | ${xcpretty}

# Generate archive build (this excludes debug symbols (dSYM) which are in a release build)
${TMPDIR}/WireguardStatusbar.xcarchive: ${sources} | ${xcpretty}
	rm -fr "$@"
	xcodebuild -scheme Wireguard\ Statusbar -archivePath "$@" archive | ${xcpretty}

# Generate icons from Wireguard logo
icons: \
	Wireguard\ Statusbar/Assets.xcassets/connected.imageset/logo-18.png \
	Wireguard\ Statusbar/Assets.xcassets/connected.imageset/logo-36.png \
	Wireguard\ Statusbar/Assets.xcassets/disconnected.imageset/logo-18-dim.png \
	Wireguard\ Statusbar/Assets.xcassets/disconnected.imageset/logo-36-dim.png \
	Wireguard\ Statusbar/Assets.xcassets/AppIcon.appiconset/logo-16.png \
	Wireguard\ Statusbar/Assets.xcassets/AppIcon.appiconset/logo-32.png \
	Wireguard\ Statusbar/Assets.xcassets/AppIcon.appiconset/logo-64.png \
	Wireguard\ Statusbar/Assets.xcassets/AppIcon.appiconset/logo-128.png \
	Wireguard\ Statusbar/Assets.xcassets/AppIcon.appiconset/logo-256.png \
	Wireguard\ Statusbar/Assets.xcassets/AppIcon.appiconset/logo-512.png \
	Wireguard\ Statusbar/Assets.xcassets/AppIcon.appiconset/logo-1024.png

Wireguard\ Statusbar/Assets.xcassets/disconnected.imageset/%: ${TMPDIR}/%
	cp "$<" "$@"

Wireguard\ Statusbar/Assets.xcassets/connected.imageset/%: ${TMPDIR}/%
	cp "$<" "$@"

Wireguard\ Statusbar/Assets.xcassets/AppIcon.appiconset/%: ${TMPDIR}/%
	cp "$<" "$@"

%-dim.png: %.png | ${convert}
	${convert} $< -strip -channel A -evaluate Multiply 0.50 +channel $@

define resize
%-${1}.png: %.png
	$${convert} $$< -strip -scale ${1}x${1} $$@
endef
$(foreach size,1024 512 256 128 64 36 32 18 16,$(eval $(call resize,${size})))

${TMPDIR}/logo.png: ${TMPDIR}/wireguard.png | ${convert}
	${convert} $< -strip -colorspace gray +dither -colors 2 -crop 1251x1251+0+0 $@

${TMPDIR}/wireguard.png: ${TMPDIR}/%.png: Misc/%.svg | ${convert}
	${convert} -strip -background transparent -density 400 $< $@

${convert}:
	brew install imagemagick

${xcpretty}:
	gem install --user xcpretty

clean:
	rm -rf \
		WireguardStatusbar.* \
		build/ \
		DerivedData/ \
		${TMPDIR}/logo*.png \
		${TMPDIR}/wireguard.png Wireguard\ Statusbar/Assets.xcassets/connected.imageset/logo-*.png \
		Wireguard\ Statusbar/Assets.xcassets/AppIcon.appiconset/logo-*.png