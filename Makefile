# Makefile
# Build and run commands for the GitHub Contributions menu bar app.

.PHONY: setup build run release install clean open

# Generate Xcode project using XcodeGen
setup:
	@echo "Generating Xcode project..."
	xcodegen generate
	@echo "Done! Open GitHubContributions.xcodeproj"

# Build debug
build:
	xcodebuild -project GitHubContributions.xcodeproj \
		-scheme GitHubContributions \
		-configuration Debug \
		-derivedDataPath build \
		build

# Build and run
run: build
	@open build/Build/Products/Debug/GitHubContributions.app

# Build release .app
release:
	xcodebuild -project GitHubContributions.xcodeproj \
		-scheme GitHubContributions \
		-configuration Release \
		-derivedDataPath build \
		CODE_SIGN_IDENTITY="-" \
		build
	@echo "Built: build/Build/Products/Release/GitHubContributions.app"

# Install to /Applications
install: release
	@cp -R build/Build/Products/Release/GitHubContributions.app /Applications/
	@echo "Installed to /Applications/GitHubContributions.app"

# Clean build artifacts
clean:
	rm -rf build/
	rm -rf GitHubContributions.xcodeproj

# Open in Xcode
open:
	open GitHubContributions.xcodeproj
