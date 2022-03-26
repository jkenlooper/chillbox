#MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
project_dir := $(dir $(mkfile_path))
slugname := site1

VERSION := $(shell cat chill/VERSION)

# For debugging what is set in variables
inspect.%:
	@echo $($*)

# Always run.  Useful when target is like targetname.% .
# Use $* to get the stem
FORCE:

objects := $(slugname)-$(VERSION).artifact.tar.gz $(slugname)-$(VERSION).immutable.tar.gz

.PHONY: all
all: $(objects)

$(slugname)-$(VERSION).artifact.tar.gz: bin/artifact.sh chill/VERSION
	./$< $(abspath $@)

$(slugname)-$(VERSION).immutable.tar.gz: bin/immutable.sh chill/VERSION
	./$< $(abspath $@)

.PHONY: clean
clean:
	printf '%s\0' $(objects) | xargs -0 rm -f
