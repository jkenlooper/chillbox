SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
project_dir := $(dir $(mkfile_path))

manifest_files := $(shell ./build/list-manifest-files.sh)

# The version string includes the build metadata
VERSION := $(shell cat $(project_dir)/src/chillbox/VERSION)+$(shell cat $(manifest_files) | md5sum - | cut -d' ' -f1)

objects := dist/chillbox-cli-$(VERSION).tar.gz build/MANIFEST

# Verify version string compiles with semver.org, output it for chillbox to use.
inspect.VERSION: ## Show the version string along with build metadata
	@printf "%s" '$(VERSION)' | grep -q -P '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$$' - || (printf "\n%s\n" "ERROR Invalid version string '$(VERSION)' See https://semver.org" >&2 && exit 1)
	@printf "%s" '$(VERSION)'

# For debugging what is set in variables.
inspect.%:
	@printf "%s" '$($*)'

# Always run.  Useful when target is like targetname.% .
# Use $* to get the stem
FORCE:

.PHONY: all
all: $(objects) ## Default is to create the dist file

.PHONY: help
help: ## Show this help
	@egrep -h '\s##\s' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: clean
clean: ## Remove any created files which were created by the `make all` recipe.
	printf '%s\0' $(objects) | xargs -0 rm -f

.PHONY: dist
dist: dist/chillbox-cli-$(VERSION).tar.gz ## Create the dist file

dist/chillbox-cli-$(VERSION).tar.gz: build/dist.sh build/MANIFEST
	./$< $(abspath $@)

.PHONY: manifest
manifest: build/MANIFEST ## Create just build/MANIFEST file

build/MANIFEST: build/create-manifest.sh $(manifest_files)
	./$<

.PHONY: test
test: ## Run the test script
	INTERACTIVE=n ./tests/test.sh
