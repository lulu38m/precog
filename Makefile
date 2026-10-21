.PHONY: project open build-release install release clean

APP := build/DerivedData/Build/Products/Release/Precog.app
EXPORTED := build/export/Precog.app
# Profil du trousseau créé avec : xcrun notarytool store-credentials precog ...
NOTARY_PROFILE ?= precog

# Génère le projet Xcode puis l'ouvre
open: project
	open Precog.xcodeproj

project:
	@command -v xcodegen >/dev/null 2>&1 || { echo "XcodeGen manquant : brew install xcodegen"; exit 1; }
	xcodegen generate

# Compile la version Release (signature de développement, pour ce Mac)
build-release:
	@test -d Precog.xcodeproj || $(MAKE) project
	xcodebuild -project Precog.xcodeproj -scheme Precog -configuration Release \
		-derivedDataPath build/DerivedData -allowProvisioningUpdates -quiet build

# Installe (ou met à jour) Precog dans /Applications et le lance
install: build-release
	-pkill -x Precog
	rm -rf /Applications/Precog.app
	cp -R "$(APP)" /Applications/
	open /Applications/Precog.app
	@echo "Precog installé dans /Applications"

# Version publique : signée Developer ID, notarisée par Apple, prête à publier
release:
	@test -d Precog.xcodeproj || $(MAKE) project
	rm -rf build/Precog.xcarchive build/export build/Precog.zip build/notarize.zip
	xcodebuild -project Precog.xcodeproj -scheme Precog -configuration Release \
		-archivePath build/Precog.xcarchive -allowProvisioningUpdates -quiet archive
	xcodebuild -exportArchive -archivePath build/Precog.xcarchive \
		-exportOptionsPlist Config/ExportOptions.plist -exportPath build/export -allowProvisioningUpdates
	ditto -c -k --keepParent "$(EXPORTED)" build/notarize.zip
	xcrun notarytool submit build/notarize.zip --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple "$(EXPORTED)"
	spctl --assess --type execute -vv "$(EXPORTED)"
	ditto -c -k --keepParent "$(EXPORTED)" build/Precog.zip
	rm -f build/notarize.zip
	@echo "build/Precog.zip signé et notarisé, prêt à publier"

clean:
	rm -rf Precog.xcodeproj build DerivedData
