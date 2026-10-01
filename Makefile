PROJECT := MicMuter.xcodeproj
SCHEME := Mic Muter
CONFIGURATION ?= Debug
BUILD_DIR := .build
DERIVED_DATA := $(BUILD_DIR)/DerivedData
SOURCE_PACKAGES := $(BUILD_DIR)/SourcePackages
DIST_DIR := dist
APP_NAME := Mic Muter
APP_SOURCE := $(DERIVED_DATA)/Build/Products/Release/$(APP_NAME).app

# Set by CI from git tag. Default keeps `make install`/`release` working.
VERSION ?= 1.0.0

XCODEBUILD = SWIFTPM_MODULECACHE_OVERRIDE="$(CURDIR)/$(BUILD_DIR)/SwiftPMModuleCache" xcodebuild \
	-project "$(PROJECT)" \
	-scheme "$(SCHEME)" \
	-destination 'platform=macOS' \
	-derivedDataPath "$(DERIVED_DATA)" \
	-clonedSourcePackagesDirPath "$(SOURCE_PACKAGES)" \
	CLANG_MODULE_CACHE_PATH="$(CURDIR)/$(BUILD_DIR)/ClangModuleCache"

.PHONY: build test lint install release clean

build:
	@mkdir -p "$(BUILD_DIR)/SwiftPMModuleCache" "$(BUILD_DIR)/ClangModuleCache"
	$(XCODEBUILD) -configuration "$(CONFIGURATION)" build

test:
	@mkdir -p "$(BUILD_DIR)/SwiftPMModuleCache"
	SWIFTPM_MODULECACHE_OVERRIDE="$(CURDIR)/$(BUILD_DIR)/SwiftPMModuleCache" swift test --scratch-path "$(BUILD_DIR)/SwiftPM"

lint:
	xcrun swift-format lint --configuration .swift-format --strict --recursive Package.swift Sources Tests

install:
	./install.zsh

# Build universal Release .app and package into $(DIST_DIR).
release:
	@mkdir -p "$(BUILD_DIR)/SwiftPMModuleCache" "$(BUILD_DIR)/ClangModuleCache"
	$(XCODEBUILD) -configuration Release ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO MARKETING_VERSION="$(VERSION)" CURRENT_PROJECT_VERSION="$(VERSION)" build
	@test -d "$(APP_SOURCE)" || { echo "expected an app at $(APP_SOURCE)" >&2; exit 1; }
	DIST_DIR="$(DIST_DIR)" ./Scripts/make-dmg.sh "$(APP_SOURCE)"

clean:
	rm -rf "$(BUILD_DIR)" "$(DIST_DIR)"
