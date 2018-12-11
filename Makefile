SHELL=/bin/bash

tmp=${TMPDIR:/=}
brew_bin:=$(shell brew --prefix || echo /usr/local)/bin
convert=${brew_bin}/convert
xcpretty=${HOME}/.gem/ruby/2.3.0/bin/xcpretty
swiftlint=${brew_bin}/swiftlint
tailor=${brew_bin}/tailor

swift_sources=$(shell find * -name *.swift|grep -vE 'SKQueue|INIParse')
other_sources=$(shell find * -name *.plist)
sources=${swift_sources} ${other_sources}

.PHONY: all
all: test test-integration WireGuardStatusbar.dmg

## Testing & Code quality

# run tests
test: check | ${xcpretty}
	set -o pipefail; xcodebuild -scheme WireGuardStatusbar test | ${xcpretty}

# verify code quality
check: fix .check.tailor | ${swiftlint}
	swiftlint --strict

# only run tailor on changed files as it is slow
.check.tailor: ${swift_sources} | fix ${tailor}
	tailor $?
	touch $@

# automatically fix all trivial code quality issues
fix: | ${swiftformat}
	swiftformat .

# setup requirements and run integration tests
test-integration: prep-integration
	set -o pipefail; xcodebuild -scheme IntegrationTests test | ${xcpretty}

prep-integration: /etc/wireguard/test.conf

/etc/wireguard/test.conf: IntegrationTests/test.conf
	sudo cp $< $@

## Building and distribution

# Location where xcodebuild puts .app when archiving
archive=${tmp}/WireGuardStatusbar.xcarchive
build_dest=${archive}/Products/Applications
dist=${tmp}/WireGuardStatusbar

# Create just the .app in the current working directory
WireGuardStatusbar.app: ${build_dest}/WireGuardStatusbar.app
	rm -rf "$@" && cp -r "${<}" "$@"

# Create distributable .dmg in current working directory
WireGuardStatusbar.dmg: ${dist}/WireGuardStatusbar.app
	hdiutil create "$@" -srcfolder "${<D}" -ov

# Generate contents for distributable .dmg
${dist}/WireGuardStatusbar.app: ${build_dest}/WireGuardStatusbar.app Misc/Uninstall.sh
	rm -rf "${@D}/"; mkdir -p "${@D}/"
	ln -sf /Applications "${@D}/Applications"
	cp Misc/Uninstall.sh "${@D}/Uninstall"
	rm -rf "$@" && cp -r "$<" "$@"

# Generate archive build (this excludes debug symbols (dSYM) which are in a release build)
${build_dest}/WireGuardStatusbar.app: ${sources} | icons ${xcpretty}
	xcodebuild -scheme WireGuardStatusbar -archivePath "${archive}" archive | ${xcpretty}

## Icon/image generation

assets=WireGuardStatusbar/Assets.xcassets
.PHONY: icons appicon imagesets
icons: appicon imagesets

# The icon used by the application
appicon: \
	${assets}/AppIcon.appiconset/16.png \
	${assets}/AppIcon.appiconset/32.png \
	${assets}/AppIcon.appiconset/64.png \
	${assets}/AppIcon.appiconset/128.png \
	${assets}/AppIcon.appiconset/256.png \
	${assets}/AppIcon.appiconset/512.png \
	${assets}/AppIcon.appiconset/1024.png

# Provide different sizes of appicon
${assets}/AppIcon.appiconset/%.png: ${tmp}/logo.png
	${convert} $< -strip -scale $*x$* $@

# Icons used for the menubar
imagesets: \
	${assets}/silhouette.imageset/ \
	${assets}/silhouette.imageset/Contents.json \
	${assets}/silhouette.imageset/18.png \
	${assets}/silhouette.imageset/36.png \
	${assets}/silhouette-dim.imageset/ \
	${assets}/silhouette-dim.imageset/Contents.json \
	${assets}/silhouette-dim.imageset/18.png \
	${assets}/silhouette-dim.imageset/36.png \
	${assets}/dragon.imageset/ \
	${assets}/dragon.imageset/Contents.json \
	${assets}/dragon.imageset/18.png \
	${assets}/dragon.imageset/36.png \
	${assets}/dragon-dim.imageset/ \
	${assets}/dragon-dim.imageset/Contents.json \
	${assets}/dragon-dim.imageset/18.png \
	${assets}/dragon-dim.imageset/36.png

# Provide 2 required sizes for any imageset variant
${assets}/%.imageset/18.png: ${tmp}/%.png
	${convert} $< -strip -scale 18x18 $@
${assets}/%.imageset/36.png: ${tmp}/%.png
	${convert} $< -strip -scale 36x36 $@
# Provide standard imageset definition
${assets}/%.imageset/Contents.json: Misc/imageset.Contents.json | ${assets}/%.imageset/
	mkdir -p $@
	cp $< $@

# Create a dimmed version of a image
%-dim.png: %.png | ${convert}
	${convert} $< -strip -channel A -evaluate Multiply 0.50 +channel $@

# Extract the logo part from the banner, color it black and white
${tmp}/logo.png: ${tmp}/wireguard.png | ${convert}
	${convert} $< -strip -crop 1251x1251+0+0 -colorspace gray +dither -colors 2 \
		-floodfill +600+200 white -floodfill +600+400 white -floodfill +350+900 white \
		-floodfill +400+200 black -floodfill +777+117 black\
		$@

# Extract the logo part from the banner, invert to keep only the dragon
${tmp}/dragon.png: ${tmp}/wireguard.png | ${convert}
	${convert} $< -strip -colorspace gray +dither -colors 2 -crop 1251x1251+0+0\
		-floodfill +600+200 black -floodfill +600+400 black -floodfill +350+900 black\
		-floodfill +400+200 transparent -floodfill +777+117 transparent \
		$@

# Extract the logo part from the banner, but keep the dragon transparent
${tmp}/silhouette.png: ${tmp}/wireguard.png | ${convert}
	${convert} $< -strip -colorspace gray +dither -colors 2 -crop 1251x1251+0+0 \
		-floodfill +400+200 black -floodfill +777+117 black\
		$@

# Convert SVG wireguard banner to png
${tmp}/%.png: Misc/%.svg | ${convert}
	${convert} -strip -background transparent -density 400 $< $@

# Download the official logo
Misc/wireguard.svg:
	curl -s https://www.wireguard.com/img/wireguard.svg > $@

## Setup and maintenance

${convert} ${swiftlint} ${tailor} ${swiftformat}:
	brew bundle install --verbose --no-upgrade

# Used to generate less verbose xcodebuild output
${xcpretty}:
	gem install --user xcpretty

.PHONY: clean mrproper
# cleanup build artifacts
clean:
	rm -rf \
		${archive} \
		${dist} \
		WireGuardStatusbar.{dmg,app} \
		DerivedData/

# cleanup most artifacts that could be generated by the Makefile
mrproper: clean
	rm -rf \
		${tmp}/logo*.png \
		${tmp}/wireguard.png WireGuardStatusbar/Assets.xcassets/connected.imageset/logo-*.png \
		WireGuardStatusbar/Assets.xcassets/AppIcon.appiconset/logo-*.png
	sudo rm -rf /etc/wireguard/test.conf
