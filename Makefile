SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
project_dir := $(dir $(mkfile_path))

manifest_files := $(shell find . -type f -not -path './.git/*' -not -path './.github/*' -not -name '.gitignore' -not -path './build/MANIFEST' -not -path './dist/*' | sort)

# The version string includes the build metadata
VERSION := $(shell cat $(project_dir)/src/chillbox/VERSION)+$(shell cat $(manifest_files) | md5sum - | cut -d' ' -f1)

objects := dist/chillbox-cli-$(VERSION).tar.gz build/MANIFEST

# For debugging what is set in variables
inspect.%:
	@echo $($*)

# Always run.  Useful when target is like targetname.% .
# Use $* to get the stem
FORCE:

.PHONY: all
all: $(objects)

# Remove any created files which were created by the `make all` recipe.
.PHONY: clean
clean:
	rm -f $(objects)

.PHONY: dist
dist: dist/chillbox-cli-$(VERSION).tar.gz

dist/chillbox-cli-$(VERSION).tar.gz: build/dist.sh build/MANIFEST
	./$< $(abspath $@)

.PHONY: manifest
manifest: build/MANIFEST

build/MANIFEST: build/create-manifest.sh $(manifest_files)
	./$<
