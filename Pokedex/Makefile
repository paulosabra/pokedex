#!make

help:
	@echo "Usage: make [ ... ]"
	@echo ""
	@echo "Usage:"
	@echo "  make setup: 	Setup project;"
	@echo "  make fix: 	Automatically apply fixes suggested by the Dart Dev Compiler;"
	@echo "  make format: 	Automatically format your Dart project's code, applying the style conventions"
	@echo "  make lint: 	Analyse your Flutter project code for potential issues and possible static analysis errors;"
	@echo "  make tests: 	Run the automated tests and collect code coverage information."
	@echo ""

setup:
	flutter clean
	flutter pub get
	dart run build_runner build --delete-conflicting-outputs

fix:
	dart fix --apply

format:
	dart format .

lint:
	flutter analyze .

tests:
	flutter test --coverage
