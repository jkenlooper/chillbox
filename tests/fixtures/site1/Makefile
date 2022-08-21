SHELL := sh
.SHELLFLAGS := -o errexit -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
project_dir := $(dir $(mkfile_path))
slugname := site1

project_files := $(shell find . -type f -not -path './.git/*' -not -path './dist/*' | sort)

# The version string includes the build metadata
VERSION := $(shell cat VERSION)+$(shell cat $(project_files) | md5sum - | cut -d' ' -f1)

# Verify version string compiles with semver.org, output it for chillbox to use.
inspect.VERSION:
	@printf "%s" '$(VERSION)' | grep -q -P '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$$' - || (printf "\n%s\n" "ERROR Invalid version string '$(VERSION)' See https://semver.org" >&2 && exit 1)
	@printf "%s" '$(VERSION)'

# For debugging what is set in variables.
inspect.%:
	@printf "%s" '$($*)'

# Always run.  Useful when target is like targetname.% .
# Use $* to get the stem
FORCE:

# Chillbox will need the dist/artifact.tar.gz and dist/immutable.tar.gz when
# deploying.
objects := dist/artifact.tar.gz dist/immutable.tar.gz

.PHONY: all
all: $(objects)

# Run the bin/artifact.sh script to create the dist/artifact.tar.gz file.
dist/artifact.tar.gz: bin/artifact.sh
	./$< $(abspath $@)

# Run the bin/immutable.sh script to create the dist/immutable.tar.gz file.
dist/immutable.tar.gz: bin/immutable.sh
	./$< $(abspath $@)

.PHONY: clean
clean:
	printf '%s\0' $(objects) | xargs -0 rm -f
