PROJECT := MicMuter.xcodeproj
SCHEME := Mic Muter
CONFIGURATION ?= Debug
BUILD_DIR := .build
DERIVED_DATA := $(BUILD_DIR)/DerivedData
SOURCE_PACKAGES := $(BUILD_DIR)/SourcePackages

.PHONY: build test lint install

build:
	mkdir -p "$(BUILD_DIR)/SwiftPMModuleCache" "$(BUILD_DIR)/ClangModuleCache"
	SWIFTPM_MODULECACHE_OVERRIDE="$(CURDIR)/$(BUILD_DIR)/SwiftPMModuleCache" xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration "$(CONFIGURATION)" -destination 'platform=macOS' -derivedDataPath "$(DERIVED_DATA)" -clonedSourcePackagesDirPath "$(SOURCE_PACKAGES)" CLANG_MODULE_CACHE_PATH="$(CURDIR)/$(BUILD_DIR)/ClangModuleCache" build

test:
	mkdir -p "$(BUILD_DIR)/SwiftPMModuleCache"
	SWIFTPM_MODULECACHE_OVERRIDE="$(CURDIR)/$(BUILD_DIR)/SwiftPMModuleCache" swift test --scratch-path "$(BUILD_DIR)/SwiftPM"

lint:
	xcrun swift-format lint --configuration .swift-format --strict --recursive Package.swift Sources Tests

install:
	./install.zsh
