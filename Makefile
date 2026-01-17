SUBMODULE_DIR = submodules/RetroArch
BUILD_DIR = build
SRC_DIR = src
PATCH_DIR = patches

ECHO = echo

PLATFORM ?= $(UNION_PLATFORM)
ifeq (,$(PLATFORM))
PLATFORM=linux
endif

ifeq ($(PLATFORM),linux)
ECHO = echo -e
endif

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# Function to print status messages
print_status = $(ECHO) "\033[34m--- $1\033[0m"


.PHONY: all build assemble apply-patches copy-submodule create-patch clean


all: build

## Submodule management

$(BUILD_DIR)/.has_submodule:
	@$(call print_status, Copying submodule)
	@if [ -d "$(SUBMODULE_DIR)" ] && [ -z "$$(ls -A $(SUBMODULE_DIR))" ]; then \
		git submodule update --init --recursive; \
	fi
	mkdir -p $(BUILD_DIR)
	cp -r $(SUBMODULE_DIR)/* $(BUILD_DIR)/
	@touch $(BUILD_DIR)/.has_submodule

copy-submodule: $(BUILD_DIR)/.has_submodule

## Patch management

$(BUILD_DIR)/.is_patched: $(BUILD_DIR)/.has_submodule
	@$(call print_status, Converting line endings)
	find $(BUILD_DIR) -type f \( -name '*.c' -o -name '*.h' \) -exec sed -i "s/\r\$$//" {} +
	@for patch in $(sort $(wildcard $(PATCH_DIR)/*.patch)); do \
		$(call print_status, Applying $$patch); \
		patch -d $(BUILD_DIR) -p1 < $$patch; \
	done
	@touch $(BUILD_DIR)/.is_patched

apply-patches: $(BUILD_DIR)/.is_patched

create-patch:
	@$(call print_status, Creating patch)
	./scripts/create_patch.sh

## Source management

$(BUILD_DIR)/.is_assembled: $(BUILD_DIR)/.is_patched
	@$(call print_status, Assembling source)
	cp -r $(SRC_DIR)/* $(BUILD_DIR)/
	@touch $(BUILD_DIR)/.is_assembled

assemble: $(BUILD_DIR)/.is_assembled

## Build targets

$(BUILD_DIR)/retroarch: $(BUILD_DIR)/.is_assembled
	@$(call print_status, Building for Miyoo Mini)
	@cd $(BUILD_DIR) && make clean all -f Makefile.miyoomini PACKAGE_NAME=retroarch

$(BUILD_DIR)/retroarch_miyoo354: $(BUILD_DIR)/.is_assembled
	@$(call print_status, Building for Miyoo 354)
	@cd $(BUILD_DIR) && make clean all -f Makefile.miyoomini MIYOO354=1 PACKAGE_NAME=retroarch_miyoo354

build: $(BUILD_DIR)/retroarch $(BUILD_DIR)/retroarch_miyoo354
	@$(call print_status, Copying binaries)
	mkdir -p bin
	cp $(BUILD_DIR)/retroarch bin/
	cp $(BUILD_DIR)/retroarch_miyoo354 bin/

## Clean everything

clean:
	@$(call print_status, Cleaning)
	rm -rf $(BUILD_DIR) || true
	rm -rf bin || true
