TEMP_DIR=temp
BUILD_DIR=build

COCOA_CORE_DIR=cocoa/remember/Resources/core

# Used when cross-compiling and should have the form:
#   /path/to/host/racket -C -G /path/to/target/racket/etc -X /path/to/target/racket/collects -l-
RACKET_PREFIX=

.PHONY: all
all: $(COCOA_CORE_DIR)/bin/remember-core

.PHONY: ios
ios:
	$(MAKE) all COCOA_CORE_DIR=ios/remember/Resources/core


## Core ################################################################

CORE_SRC_DIR=core
CORE_OBJ_DIR=core/compiled

$(COCOA_CORE_DIR)/bin/remember-core: $(BUILD_DIR)/bin/remember-core
	rm -fr $(COCOA_CORE_DIR) && mkdir -p $(COCOA_CORE_DIR)
	cp -r $(BUILD_DIR)/* $(COCOA_CORE_DIR)/

$(BUILD_DIR)/bin/remember-core: $(TEMP_DIR)/remember-core
	rm -fr $(BUILD_DIR) && mkdir -p $(BUILD_DIR)
	$(RACKET_PREFIX) raco distribute $(BUILD_DIR) $(TEMP_DIR)/remember-core

$(TEMP_DIR)/remember-core: $(CORE_OBJ_DIR)/main_rkt.zo migrations/*.sql
	rm -fr $(TEMP_DIR) && mkdir -p $(TEMP_DIR)
	$(RACKET_PREFIX) raco exe -o $(TEMP_DIR)/remember-core core/main.rkt

$(CORE_OBJ_DIR)/main_rkt.zo: core/*.rkt

$(CORE_OBJ_DIR)/%_rkt.zo: core/%.rkt
	$(RACKET_PREFIX) raco make -j $(shell nproc) -v $<


## Phony ###############################################################

.PHONY: clean
clean:
	rm -fr $(CORE_OBJ_DIR) $(COCOA_CORE_DIR) $(BUILD_DIR) $(TEMP_DIR)
