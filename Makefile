#MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
project_dir := $(dir $(mkfile_path))

objects := todo

VERSION := $(shell cat $(project_dir)/VERSION)

# Set to tmp/ when debugging the install
# make PREFIXDIR=${PWD}/tmp inspect.SRVDIR
# make PREFIXDIR=${PWD}/tmp ENVIRONMENT=development install
PREFIXDIR :=

# For debugging what is set in variables
inspect.%:
	@echo $($*)


# Always run.  Useful when target is like targetname.% .
# Use $* to get the stem
FORCE:

.PHONY: all
all: $(objects)

.PHONY: install
install:
	./build/install.sh

# Remove any created files which were created by the `make all` recipe.
.PHONY: clean
clean:
	rm $(objects)

# Remove files placed outside of src directory and uninstall app.
.PHONY: uninstall
uninstall:
	./build/uninstall.sh

.PHONY: dist
dist: dist/chillbox-cli-$(VERSION).tar.gz

.PHONY: dist/chillbox-cli-$(VERSION).tar.gz
dist/chillbox-cli-$(VERSION).tar.gz: build/dist.sh
	./$< $(abspath $@)

# TODO
todo:
	touch $@
