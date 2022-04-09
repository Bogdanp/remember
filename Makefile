TEMP_DIR=temp
BUILD_DIR=build

COCOA_MAN_DIR=cocoa/remember/Resources/manual
COCOA_CORE_DIR=cocoa/remember/Resources/core/$(shell uname -m)

.PHONY: all
all: $(COCOA_CORE_DIR)/bin/remember-core $(COCOA_MAN_DIR)/index.html


## Core ################################################################

CORE_SRC_DIR=core
CORE_OBJ_DIR=core/compiled

$(COCOA_CORE_DIR)/bin/remember-core: $(BUILD_DIR)/bin/remember-core
	rm -fr $(COCOA_CORE_DIR) && mkdir -p $(COCOA_CORE_DIR)
	cp -r $(BUILD_DIR)/* $(COCOA_CORE_DIR)/

$(BUILD_DIR)/bin/remember-core: $(TEMP_DIR)/remember-core
	rm -fr $(BUILD_DIR) && mkdir -p $(BUILD_DIR)
	raco distribute $(BUILD_DIR) $(TEMP_DIR)/remember-core

$(TEMP_DIR)/remember-core: $(CORE_OBJ_DIR)/main_rkt.zo migrations/*.sql
	rm -fr $(TEMP_DIR) && mkdir -p $(TEMP_DIR)
	raco exe -o $(TEMP_DIR)/remember-core core/main.rkt

$(CORE_OBJ_DIR)/main_rkt.zo: core/*.rkt

$(CORE_OBJ_DIR)/%_rkt.zo: core/%.rkt
	raco make -j $(shell nproc || echo 16) -v $<


## Phony ###############################################################

.PHONY: clean
clean:
	rm -fr $(CORE_OBJ_DIR) $(COCOA_CORE_DIR) $(BUILD_DIR) $(TEMP_DIR)


## Manual ##############################################################

$(COCOA_MAN_DIR)/index.html: manual/*.scrbl
	raco scribble --html --dest $(COCOA_MAN_DIR) +m manual/index.scrbl

website/manual/index.html: manual/*.scrbl
	raco scribble --html --dest website/manual +m manual/index.scrbl
