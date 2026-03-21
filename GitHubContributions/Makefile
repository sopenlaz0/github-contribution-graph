# GitHubContributions/Makefile
# Build and run commands for the GitHub Contributions menu bar app.

.PHONY: setup build run clean

# Generate Xcode project using XcodeGen
setup:
	@echo "Generating Xcode project..."
	xcodegen generate
	@echo "Done! Open GitHubContributions.xcodeproj"

# Build the app
build:
	xcodebuild -project GitHubContributions.xcodeproj \
		-scheme GitHubContributions \
		-configuration Release \
		build

# Build and run
run:
	xcodebuild -project GitHubContributions.xcodeproj \
		-scheme GitHubContributions \
		-configuration Debug \
		build
	@open build/Debug/GitHubContributions.app

# Clean build artifacts
clean:
	xcodebuild -project GitHubContributions.xcodeproj \
		-scheme GitHubContributions \
		clean
	rm -rf build/

# Open in Xcode
open:
	open GitHubContributions.xcodeproj
