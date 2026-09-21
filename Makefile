.PHONY: bootstrap generate test-core build open

bootstrap:
	./scripts/bootstrap.sh

generate:
	xcodegen generate

test-core:
	cd Packages/MeilogCore && swift test

build: generate
	xcodebuild -project Meilog.xcodeproj -scheme Meilog -destination 'generic/platform=iOS Simulator' -quiet build

open: generate
	open Meilog.xcodeproj
