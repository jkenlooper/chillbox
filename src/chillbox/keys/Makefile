SHELL := sh
.SHELLFLAGS := -eu -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
project_dir := $(dir $(mkfile_path))
BINDIR ?= $(HOME)/.local/bin

objects := bin/generate-new-chillbox-keys bin/decrypt-file

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
	# No longer used.
	#install --owner=dev --group=dev --mode=0700 bin/generate-new-chillbox-keys $(BINDIR)
	#install --owner=dev --group=dev --mode=0700 bin/decrypt-file $(BINDIR)

bin:
	mkdir -p bin

bin/generate-new-chillbox-keys: import-map.json bin src/*.js
	@echo "No longer used."
	#deno compile \
	#	--allow-read="/home/dev/.local/share/chillbox/keys" \
	#	--allow-write="/home/dev/.local/share/chillbox/keys" \
	#	--allow-run=hostname \
	#	--import-map import-map.json \
	#	--no-prompt \
	#	--output $(abspath $@) \
	#	src/generate-new-chillbox-keys.js

# Only need to decrypt files and not encrypt them on the server.
bin/decrypt-file: import-map.json bin src/*.js
	@echo "No longer used."
	#deno compile \
	#	--allow-read=/home/dev/.local/share/chillbox/keys,/tmp/,/run/tmp/chillbox_secrets/ \
	#	--allow-write=/home/dev/.local/share/chillbox/keys,/run/tmp/chillbox_secrets/ \
	#	--allow-run=hostname \
	#	--import-map import-map.json \
	#	--no-prompt \
	#	--output $(abspath $@) \
	#	src/decrypt-file.js

