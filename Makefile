SHELL=/bin/bash

tmp=${TMPDIR:/=}
brew_bin:=$(shell brew --prefix || echo /usr/local)/bin
convert=${brew_bin}/convert
xcpretty=${HOME}/.gem/ruby/2.3.0/bin/xcpretty
swiftlint=${brew_bin}/swiftlint
swiftformat=${brew_bin}/swiftformat
tailor=${brew_bin}/tailor

git_sha=$(shell git rev-parse --short HEAD)

swift_sources=$(shell find * -name "*.swift"|grep -vE 'SKQueue|INIParse')
other_sources=$(shell find * -name "*.plist") WireGuardStatusbar.xcodeproj/project.pbxproj
sources=${swift_sources} ${other_sources}

version?=$(shell git describe --tags --always --abbrev=0)
next_version:=$(shell echo ${version} | ( IFS=".$$IFS" ; read major minor && echo $$major.$$((minor + 1)) ))
new_version?=${next_version}
revisions=$(shell git rev-list --all --count HEAD)
helper_revisions=$(shell git rev-list --all  --count WireGuardStatusbarHelper/*.swift)

# without argument make will run all tests and checks, build a distributable image and install the app in /Applications
.PHONY: all
all: test dist install

## Testing & Code quality

# run tests
test: .test-unit .test-integration
.test-unit: ${sources} .check | icons ${xcpretty}
	set -o pipefail; xcodebuild -scheme WireGuardStatusbar test | ${xcpretty}
	@touch $@

# verify code quality
check: .check
.check: ${swift_sources} .fix .check.tailor | ${swiftlint}
	swiftlint --strict
	@touch $@

# only run tailor on changed files as it is slow
.check.tailor: ${swift_sources} | .fix ${tailor}
	tailor $?
	@touch $@

# automatically fix all trivial code quality issues
fix: .fix
.fix: ${swift_sources} | ${swiftformat}
	swiftformat $?
	@touch $@

# setup requirements and run integration tests
test-integration: .test-integration
.test-integration: ${sources} /etc/wireguard/test-localhost.conf | icons
	# application running in Xcode will hang the test
	-osascript -e 'tell application "Xcode" to set actionResult to stop workspace document 1'
	set -o pipefail; xcodebuild -scheme IntegrationTests test | ${xcpretty}
	@touch $@

prep-integration: /etc/wireguard/test-localhost.conf /etc/wireguard/test-invalid.conf /usr/local/etc/wireguard/test-usr-local.conf
/etc/wireguard/test-%.conf /usr/local/etc/wireguard/test-%.conf: IntegrationTests/test-%.conf
	sudo chmod 0755 ${@D}
	sudo cp $< $@

## Building and distribution

# Location where xcodebuild puts .app when archiving
archive=${tmp}/WireGuardStatusbar.xcarchive
build_dest=${archive}/Products/Applications
dist=${tmp}/WireGuardStatusbar

# Create just the .app in the current working directory
app: WireGuardStatusbar.app
WireGuardStatusbar.app: ${build_dest}/WireGuardStatusbar.app
	rm -rf "$@" && cp -r "${<}" "$@"

# Create distributable .dmg in current working directory
dist: WireGuardStatusbar-${version}-${revisions}.dmg
WireGuardStatusbar-${version}-${revisions}.dmg: ${dist}/WireGuardStatusbar.app
	hdiutil create -fs HFS+ "$@" -srcfolder "${<D}" -ov

# Zipped distributable with current git commit sha
zip: WireGuardStatusbar-${git_sha}.zip
WireGuardStatusbar-${git_sha}.zip: ${tmp}/WireGuardStatusbar-${git_sha}.app
	cd ${<D}; zip -r ${PWD}/$@ ${<F}

${tmp}/WireGuardStatusbar-${git_sha}.app: ${build_dest}/WireGuardStatusbar.app
	rm -rf "$@" && cp -r "${<}" "$@"

# Generate contents for distributable .dmg
${dist}/WireGuardStatusbar.app: ${build_dest}/WireGuardStatusbar.app Misc/Uninstall.sh
	rm -rf "${@D}/"; mkdir -p "${@D}/"
	ln -sf /Applications "${@D}/Applications"
	cp Misc/Uninstall.sh "${@D}/Uninstall"
	rm -rf "$@" && cp -r "$<" "$@"

# Generate archive build (this excludes debug symbols (dSYM) which are in a release build)
${build_dest}/WireGuardStatusbar.app: ${sources} | icons ${xcpretty}
	xcodebuild -scheme WireGuardStatusbar -archivePath "${archive}" archive | ${xcpretty}

# install and run the App /Application using the distributable .dmg
install: /Applications/WireGuardStatusbar.app
/Applications/WireGuardStatusbar.app: WireGuardStatusbar-${version}-${revisions}.dmg
	-osascript -e 'tell application "WireGuardStatusbar" to quit'
	-hdiutil detach -quiet /Volumes/WireGuardStatusbar/
	hdiutil attach -quiet WireGuardStatusbar-${version}-${revisions}.dmg
	cp -r /Volumes/WireGuardStatusbar/WireGuardStatusbar.app /Volumes/WireGuardStatusbar/Applications/
	hdiutil detach -quiet /Volumes/WireGuardStatusbar/
	touch $@
	open "$@"

uninstall:
	Misc/Uninstall.sh

screenshot: Misc/demo.png
Misc/demo.png: ${all_sources} WireGuardStatusbar.app
	Misc/screenshot.sh $@

bump:
	@if ! git diff-index --quiet HEAD;then echo "Uncommited changes!"; exit 1; fi
	@if git tag | grep -w ${new_version};then echo "Version exists!"; exit 1; fi
	/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString ${new_version}" WireGuardStatusbar/Info.plist
	/usr/libexec/PlistBuddy -c "Set CFBundleVersion ${revisions}" WireGuardStatusbar/Info.plist
	/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString ${new_version}" WireGuardStatusbarHelper/Info.plist
	/usr/libexec/PlistBuddy -c "Set CFBundleVersion ${helper_revisions}" WireGuardStatusbarHelper/Info.plist
	git add */Info.plist
	git commit --amend --no-edit
	git tag ${new_version}

prep-release: test dist install
release: prep-release
	git push
	git push --tags
	open .
	open https://github.com/aequitas/macos-menubar-wireguard/releases/edit/${version}

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
${assets}/AppIcon.appiconset/%.png: Misc/logo.png
	${convert} $< -strip -scale $*x$* $@

# Icons used for the menubar
imagesets: \
	${assets}/silhouette.imageset/Contents.json \
	${assets}/silhouette.imageset/18.png \
	${assets}/silhouette.imageset/36.png \
	${assets}/silhouette-dim.imageset/Contents.json \
	${assets}/silhouette-dim.imageset/18.png \
	${assets}/silhouette-dim.imageset/36.png \
	${assets}/dragon.imageset/Contents.json \
	${assets}/dragon.imageset/18.png \
	${assets}/dragon.imageset/36.png \
	${assets}/dragon-dim.imageset/Contents.json \
	${assets}/dragon-dim.imageset/18.png \
	${assets}/dragon-dim.imageset/36.png

# Provide 2 required sizes for any imageset variant
${assets}/%.imageset/18.png: Misc/%.png
	${convert} $< -strip -scale 18x18 $@
${assets}/%.imageset/36.png: Misc/%.png
	${convert} $< -strip -scale 36x36 $@
# Provide standard imageset definition
${assets}/%.imageset/Contents.json: Misc/imageset.Contents.json
	mkdir -p ${@D}
	cp $< $@

source=circle

# Create a dimmed version of a image
%-dim.png: %.png | ${convert}
	${convert} $< -strip -channel A -evaluate Multiply 0.50 +channel $@

Misc/logo.png:
	${convert} -background transparent -size 1000x1000 xc: -fill black  \
    	-draw 'translate 500,500 circle 0,0 500,0' $@

Misc/dragon.png:
	${convert} -background transparent -size 1000x1000 xc: -fill transparent -stroke black -strokewidth 50  \
    	-draw 'translate 500,500 circle 0,0 400,0' $@

Misc/silhouette.png:
	${convert} -background transparent -size 1000x1000 xc: -fill black  \
    	-draw 'translate 500,500 circle 0,0 500,0' $@

# # Extract the logo part from the banner, color it black and white
# Misc/logo.png: Misc/${source}.png | ${convert}
# 	${convert} --version | grep 7.0.8-9 || exit 1 	# versions 7.0.8-{15,16} have a bug breaking floodfill
# 	${convert} $< -strip -crop 1251x1251+0+0 -colorspace gray +dither -colors 2 \
# 		-floodfill +600+200 white -floodfill +600+400 white -floodfill +350+900 white \
# 		-floodfill +400+200 black -floodfill +777+117 black\
# 		$@

# # Extract the logo part from the banner, invert to keep only the dragon
# Misc/dragon.png: Misc/${source}.png | ${convert}
# 	${convert} --version | grep 7.0.8-9 || exit 1 	# versions 7.0.8-{15,16} have a bug breaking floodfill
# 	${convert} $< -strip -colorspace gray +dither -colors 2 -crop 1251x1251+0+0\
# 		-floodfill +600+200 black -floodfill +600+400 black -floodfill +350+900 black\
# 		-floodfill +400+200 transparent -floodfill +777+117 transparent \
# 		$@

# # Extract the logo part from the banner, but keep the dragon transparent
# Misc/silhouette.png: Misc/${source}.png | ${convert}
# 	${convert} --version | grep 7.0.8-9 || exit 1 	# versions 7.0.8-{15,16} have a bug breaking floodfill
# 	${convert} $< -strip -colorspace gray +dither -colors 2 -crop 1251x1251+0+0 \
# 		-floodfill +400+200 black -floodfill +777+117 black\
# 		$@

# Convert SVG wireguard banner to png
Misc/%.png: Misc/%.svg | ${convert}
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
		.{fix,check,test}* \
		${archive} \
		${dist} \
		WireGuardStatusbar.app \
		WireGuardStatusbar-*.dmg \
		WireGuardStatusbar-*.zip \
		${tmp}/WireGuardStatusbar-*.app \
		DerivedData/

# cleanup most artifacts that could be generated by the Makefile
mrproper_images:
	rm -rf \
		Misc/{logo,dragon,wireguard,silhouette}.png  \
		${tmp}/wireguard.png WireGuardStatusbar/Assets.xcassets/*.imageset/ \
		WireGuardStatusbar/Assets.xcassets/AppIcon.appiconset/logo-*.png

mrproper: clean mrproper_images
	sudo rm -rf /etc/wireguard/test-localhost.conf
