#---------------------------------------------------------------------
# vim:set noexpandtab:
#---------------------------------------------------------------------
# Copyright (c) 2023 James O. D. Hunt <jamesodhunt@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0
#---------------------------------------------------------------------

# Override make's default value of "as" (as(1) / gas) which isn't
# helpful as it uses different syntax (AT&T format!)
AS = nasm

BUILD_DIR = builddir

# meson program arguments
MESON_ARGS =

# configure arguments
MESON_CONFIGURE_OPTIONS =

# Handle the build type
#
# (only passed to the configure meson sub-command).
ifneq (,$(RELEASE))
    MESON_CONFIGURE_OPTIONS += --buildtype release
else
    MESON_CONFIGURE_OPTIONS += --buildtype debug
endif

# options from "meson_options.txt"
MESON_OPTIONS =

ifneq (,$(MESON_DEBUG))
    # Show assembler CLI.
    MESON_ARGS += -v
endif

ifneq (1,$(V))
    MESON_ARGS += -v
endif

ifneq (,$(AS))
    MESON_OPTIONS += -Dassembler=$(AS)
endif

ifneq (,$(EXTRA_C_SOURCES))
    MESON_OPTIONS += -Dextra_c_sources="$(EXTRA_C_SOURCES)"
endif

ifneq (,$(DISABLE_TESTS))
    MESON_OPTIONS += -Dtests=false
endif

ifeq (bats-test,$(MAKECMDGOALS))
    ifeq (,$(BATS_TEST))
        $(error "ERROR: Set BATS_TEST to test basename (example: 'BATS_TEST="true"')")
    else
        BATS_TEST_NAME="bats test $(BATS_TEST).bats"
    endif
endif

#---------------------------------------------------------------------

default: configure build

CORE_DEPS = clean configure build test
MOST_DEPS = $(CORE_DEPS) check
ALL_DEPS  = $(MOST_DEPS) dist

core : $(CORE_DEPS)
most : $(MOST_DEPS)
all  : $(ALL_DEPS)

.PHONY: configure build test clean

configure:
	@echo "INFO: configuring"
	meson setup $(BUILD_DIR) $(MESON_OPTIONS) $(MESON_CONFIGURE_OPTIONS)

build: configure
	@echo "INFO: building"
	meson compile -C $(BUILD_DIR) $(MESON_ARGS)

check: configure
	@echo "INFO: checking"
	ninja -C $(BUILD_DIR) check

# Run all tests
test: build
	@echo "INFO: testing"
	meson test -C $(BUILD_DIR) $(MESON_ARGS)

# Just run the utilities tests
utils-test: build
	@echo "INFO: testing (utils)"
	meson test -C $(BUILD_DIR) $(MESON_ARGS) 'utils test'

# Just run a *single* bats test
bats-test: build
	@echo "INFO: testing (bats test with name '$(BATS_TEST_NAME)')"
	meson test -C $(BUILD_DIR) $(MESON_ARGS) $(BATS_TEST_NAME)

dist: build
	@echo "INFO: dist"
	meson dist -C $(BUILD_DIR)

clean:
	@echo "INFO: cleaning"
	rm -rf $(BUILD_DIR)
