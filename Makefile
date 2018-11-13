SHELL=/bin/bash

brew_bin=$(shell brew --prefix)/bin
convert=${brew_bin}/convert

all: icons

# Generate icons from Wireguard logo
icons: Misc/logo-1024.png Misc/logo-512.png Misc/logo-256.png \
	Misc/logo-128.png Misc/logo-36.png Misc/logo-18.png \
	Misc/logo-36-dim.png Misc/logo-18-dim.png \
	Wireguard\ Statusbar/Assets.xcassets/connected.imageset/logo-18.png \
	Wireguard\ Statusbar/Assets.xcassets/connected.imageset/logo-36.png \
	Wireguard\ Statusbar/Assets.xcassets/disconnected.imageset/logo-18-dim.png \
	Wireguard\ Statusbar/Assets.xcassets/disconnected.imageset/logo-36-dim.png

Wireguard\ Statusbar/Assets.xcassets/disconnected.imageset/%: Misc/%
	cp "$<" "$@"

Wireguard\ Statusbar/Assets.xcassets/connected.imageset/%: Misc/%
	cp "$<" "$@"

Misc/logo.png: Misc/wireguard.png | ${convert}
	${convert} $< -colorspace gray +dither -colors 2 -crop 1251x1251+0+0 $@

%-dim.png: %.png | ${convert}
	${convert} $< -channel A -evaluate Multiply 0.50 +channel $@

define resize
%-${1}.png: %.png
	$${convert} $$< -scale ${1}x${1} $$@
endef
$(foreach size,1024 512 256 128 36 18,$(eval $(call resize,${size})))

%.png: %.svg | ${convert}
	${convert} -background transparent -density 400 $< $@

${convert}:
	brew install

clean:
	rm -f Misc/logo*.png Misc/wireguard.png Wireguard\ Statusbar/Assets.xcassets/connected.imageset/logo-*.png