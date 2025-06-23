.PHONY: build run test clean install package install-sudo xcode dmg help

# Configuration variables - easy to change for different projects
PRODUCT_NAME = CiteBar
SCHEME = CiteBar
BUILD_DIR = .build
VERSION = $(shell date +%Y%m%d)
DMG_NAME = $(PRODUCT_NAME)-$(VERSION)

# Paths
DIST_DIR = dist
APP_BUNDLE = $(DIST_DIR)/$(PRODUCT_NAME).app
DMG_TEMP_DIR = $(DIST_DIR)/dmg-temp
RESOURCES_DIR = Assets.xcassets/AppIcon.appiconset

# Icon files
ICON_1024 = $(RESOURCES_DIR)/1024.png
ICON_512 = $(RESOURCES_DIR)/512.png

build:
	@echo "Building $(PRODUCT_NAME)..."
	swift build -c release

debug:
	@echo "Building $(PRODUCT_NAME) (debug)..."
	swift build

run: build
	@echo "Running $(PRODUCT_NAME)..."
	./$(BUILD_DIR)/release/$(PRODUCT_NAME)

run-debug: debug
	@echo "Running $(PRODUCT_NAME) (debug with console output)..."
	./$(BUILD_DIR)/debug/$(PRODUCT_NAME)

test:
	@echo "Running tests..."
	swift test

clean:
	@echo "Cleaning build artifacts..."
	swift package clean
	rm -rf $(BUILD_DIR)
	rm -rf $(DIST_DIR)
	rm -rf "$(PRODUCT_NAME).app"

install: build
	@echo "Installing $(PRODUCT_NAME) to /Applications..."
	mkdir -p "$(PRODUCT_NAME).app/Contents/MacOS"
	mkdir -p "$(PRODUCT_NAME).app/Contents/Resources"
	cp ./.build/release/$(PRODUCT_NAME) "$(PRODUCT_NAME).app/Contents/MacOS/"
	cp Info.plist "$(PRODUCT_NAME).app/Contents/"
	# Copy app icon
	cp Assets.xcassets/AppIcon.appiconset/1024.png "$(PRODUCT_NAME).app/Contents/Resources/AppIcon.png" 2>/dev/null || true
	cp Assets.xcassets/AppIcon.appiconset/512.png "$(PRODUCT_NAME).app/Contents/Resources/AppIcon@2x.png" 2>/dev/null || true
	@echo "App bundle created: $(PRODUCT_NAME).app"
	@echo ""
	@echo "To complete installation:"
	@echo "1. Run: sudo cp -r \"$(PRODUCT_NAME).app\" /Applications/"
	@echo "2. Or drag $(PRODUCT_NAME).app to your Applications folder"
	@echo ""

install-sudo: build
	@echo "Installing $(PRODUCT_NAME) to /Applications with sudo..."
	mkdir -p "$(PRODUCT_NAME).app/Contents/MacOS"
	mkdir -p "$(PRODUCT_NAME).app/Contents/Resources"
	cp ./.build/release/$(PRODUCT_NAME) "$(PRODUCT_NAME).app/Contents/MacOS/"
	cp Info.plist "$(PRODUCT_NAME).app/Contents/"
	# Copy app icon
	cp Assets.xcassets/AppIcon.appiconset/1024.png "$(PRODUCT_NAME).app/Contents/Resources/AppIcon.png" 2>/dev/null || true
	cp Assets.xcassets/AppIcon.appiconset/512.png "$(PRODUCT_NAME).app/Contents/Resources/AppIcon@2x.png" 2>/dev/null || true
	sudo cp -r "$(PRODUCT_NAME).app" /Applications/
	# Force macOS to refresh icon cache
	sudo touch "/Applications/$(PRODUCT_NAME).app"
	sudo killall Finder 2>/dev/null || true

package: build
	@echo "Creating installer package in '$(DIST_DIR)/'..."
	@mkdir -p "$(DIST_DIR)"
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp ./.build/release/$(PRODUCT_NAME) "$(APP_BUNDLE)/Contents/MacOS/" || { echo "❌ Failed to copy executable"; exit 1; }
	@cp Info.plist "$(APP_BUNDLE)/Contents/" || { echo "❌ Failed to copy Info.plist"; exit 1; }
	@# Copy app icons with error handling
	@if [ -f "$(ICON_1024)" ]; then \
		cp "$(ICON_1024)" "$(APP_BUNDLE)/Contents/Resources/AppIcon.png"; \
		echo "✅ Copied 1024px icon"; \
	else \
		echo "⚠️  Warning: 1024px icon not found"; \
	fi
	@if [ -f "$(ICON_512)" ]; then \
		cp "$(ICON_512)" "$(APP_BUNDLE)/Contents/Resources/AppIcon@2x.png"; \
		echo "✅ Copied 512px icon"; \
	else \
		echo "⚠️  Warning: 512px icon not found"; \
	fi
	@echo "✅ Package created: $(APP_BUNDLE)"

dmg: package
	@echo "Creating DMG distribution package..."
	@# Create a temporary directory for DMG contents
	@mkdir -p "$(DMG_TEMP_DIR)"
	@# Copy the app to the temp directory
	@cp -r "$(APP_BUNDLE)" "$(DMG_TEMP_DIR)/" || { echo "❌ Failed to copy app bundle"; exit 1; }
	@# Create Applications symlink for easy installation
	@ln -sf /Applications "$(DMG_TEMP_DIR)/Applications"
	@# Create the DMG
	@echo "Creating DMG file..."
	@hdiutil create -volname "$(PRODUCT_NAME)" \
		-srcfolder "$(DMG_TEMP_DIR)" \
		-ov -format UDZO \
		"$(DIST_DIR)/$(DMG_NAME).dmg" || { echo "❌ Failed to create DMG"; rm -rf "$(DMG_TEMP_DIR)"; exit 1; }
	@# Clean up temp directory
	@rm -rf "$(DMG_TEMP_DIR)"
	@echo ""
	@echo "✅ DMG created successfully: $(DIST_DIR)/$(DMG_NAME).dmg"
	@echo ""
	@echo "The DMG contains:"
	@echo "  • $(PRODUCT_NAME).app"
	@echo "  • Applications folder shortcut for easy drag-and-drop installation"
	@echo ""
	@echo "Users can install by:"
	@echo "  1. Double-clicking the DMG file"
	@echo "  2. Dragging $(PRODUCT_NAME).app to the Applications folder"
	@echo ""

xcode:
	@echo "Opening Xcode project..."
	open $(PRODUCT_NAME).xcodeproj

help:
	@echo "Available commands:"
	@echo "  build        - Build the application (release mode)"
	@echo "  debug        - Build in debug mode"
	@echo "  run          - Build and run the application (release)"
	@echo "  run-debug    - Build and run in debug mode"
	@echo "  test         - Run unit tests"
	@echo "  clean        - Clean build artifacts and distribution files"
	@echo "  install      - Create app bundle in current dir and guide to install to /Applications"
	@echo "  install-sudo - Create app bundle and install to /Applications with sudo"
	@echo "  package      - Create distribution package in '$(DIST_DIR)/' folder"
	@echo "  dmg          - Create DMG distribution file (includes package step)"
	@echo "  xcode        - Open Xcode project"
	@echo "  help         - Show this help message"
	@echo ""
	@echo "Configuration:"
	@echo "  PRODUCT_NAME: $(PRODUCT_NAME)"
	@echo "  VERSION:      $(VERSION)"
	@echo "  DMG_NAME:     $(DMG_NAME)"