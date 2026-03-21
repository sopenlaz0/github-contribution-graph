# Makefile
# Build, sign, and distribute the GitHub Contributions menu bar app.

APP_NAME = GitHubContributions
DERIVED = build
APP_DEBUG = $(DERIVED)/Build/Products/Debug/$(APP_NAME).app
APP_RELEASE = $(DERIVED)/Build/Products/Release/$(APP_NAME).app

.PHONY: setup build run release sign notarize dmg install clean open

# Generate Xcode project using XcodeGen
setup:
	@echo "Generating Xcode project..."
	xcodegen generate
	@echo "Done! Open $(APP_NAME).xcodeproj"

# Build debug
build:
	xcodebuild -project $(APP_NAME).xcodeproj \
		-scheme $(APP_NAME) \
		-configuration Debug \
		-derivedDataPath $(DERIVED) \
		build

# Build and run
run: build
	@open "$(APP_DEBUG)"

# Build release (ad-hoc signed)
release:
	xcodebuild -project $(APP_NAME).xcodeproj \
		-scheme $(APP_NAME) \
		-configuration Release \
		-derivedDataPath $(DERIVED) \
		CODE_SIGN_IDENTITY="-" \
		build
	@echo "Built: $(APP_RELEASE)"

# Sign with your Developer ID (for distribution outside App Store).
# Usage: make sign IDENTITY="Developer ID Application: Your Name (TEAMID)"
sign: release
	@if [ -z "$(IDENTITY)" ]; then \
		echo ""; \
		echo "Usage:  make sign IDENTITY=\"Developer ID Application: Your Name (TEAMID)\""; \
		echo ""; \
		echo "Find yours with:  security find-identity -v -p codesigning"; \
		echo ""; \
		exit 1; \
	fi
	codesign --force --deep --options runtime \
		--sign "$(IDENTITY)" \
		"$(APP_RELEASE)"
	@echo "Signed: $(APP_RELEASE)"

# Notarize with Apple (requires app-specific password).
# Usage: make notarize APPLE_ID="you@email.com" TEAM_ID="ABCDE12345"
notarize:
	@if [ -z "$(APPLE_ID)" ] || [ -z "$(TEAM_ID)" ]; then \
		echo ""; \
		echo "Usage:  make notarize APPLE_ID=\"you@email.com\" TEAM_ID=\"ABCDE12345\""; \
		echo ""; \
		echo "You also need an app-specific password stored in Keychain:"; \
		echo "  xcrun notarytool store-credentials \"notary\" \\"; \
		echo "    --apple-id you@email.com \\"; \
		echo "    --team-id ABCDE12345"; \
		echo ""; \
		exit 1; \
	fi
	ditto -c -k --keepParent "$(APP_RELEASE)" "$(APP_NAME).zip"
	xcrun notarytool submit "$(APP_NAME).zip" \
		--keychain-profile "notary" \
		--wait
	xcrun stapler staple "$(APP_RELEASE)"
	rm -f "$(APP_NAME).zip"
	@echo "Notarized and stapled: $(APP_RELEASE)"

# Create DMG with drag-to-Applications
dmg: release
	@rm -rf dmg_contents $(APP_NAME).dmg
	@mkdir -p dmg_contents
	@cp -R "$(APP_RELEASE)" dmg_contents/
	@ln -s /Applications dmg_contents/Applications
	hdiutil create \
		-volname "GitHub Contributions" \
		-srcfolder dmg_contents \
		-ov -format UDZO \
		$(APP_NAME).dmg
	@rm -rf dmg_contents
	@echo "Created: $(APP_NAME).dmg"

# Install to /Applications
install: release
	@cp -R "$(APP_RELEASE)" /Applications/
	@echo "Installed to /Applications/$(APP_NAME).app"

# Clean build artifacts
clean:
	rm -rf $(DERIVED)/ $(APP_NAME).xcodeproj $(APP_NAME).dmg $(APP_NAME).zip

# Open in Xcode
open:
	open $(APP_NAME).xcodeproj
