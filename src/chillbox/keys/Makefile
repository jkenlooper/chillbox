SHELL := sh
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
project_dir := $(dir $(mkfile_path))
BINDIR ?= $(HOME)/.local/bin

objects := bin/generate-new-chillbox-keys

# For debugging what is set in variables.
inspect.%:
	@printf "%s" '$($*)'

# Always run.  Useful when target is like targetname.% .
# Use $* to get the stem
FORCE:

.PHONY: all
all: $(objects)

# Remove any created files which were created by the `make all` recipe.
.PHONY: clean
clean:
	rm -f $(objects)

.PHONY: install
install: $(objects)
	mkdir -p $(BINDIR)
	install --owner=dev --group=dev --mode=0700 bin/generate-new-chillbox-keys $(BINDIR)

bin/generate-new-chillbox-keys: import-map.json src/*.js
	mkdir -p bin
	deno compile \
		--allow-read="/home/dev/.local/share/chillbox/keys" \
		--allow-write="/home/dev/.local/share/chillbox/keys" \
		--allow-run=hostname \
		--import-map import-map.json \
		--no-prompt \
		--output $(abspath $@) \
		src/generate-new-chillbox-keys.js
