APP    = unlocker
BUILD  = .build
BINARY = $(BUILD)/$(APP)

ARCH   = $(shell uname -m)
SDK    = $(shell xcrun --sdk macosx --show-sdk-path 2>/dev/null)
TARGET = $(ARCH)-apple-macos11.0
SIGN  ?= -

SOURCES = src/main.swift src/App.swift

.PHONY: build clean install

build: $(BINARY)
	codesign --force --sign "$(SIGN)" \
		--entitlements unlocker.entitlements \
		$(BINARY)

$(BINARY): $(SOURCES) src/Bridging-Header.h src/CGVirtualDisplayPrivate.h
	mkdir -p $(BUILD)
	swiftc \
		-target $(TARGET) \
		-sdk $(SDK) \
		-import-objc-header src/Bridging-Header.h \
		-framework Cocoa \
		-O \
		$(SOURCES) \
		-o $(BINARY)

clean:
	rm -rf $(BUILD)

install: build
	mkdir -p /usr/local/bin
	cp $(BINARY) /usr/local/bin/$(APP)
