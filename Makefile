TEMP_DIR=temp
BUILD_DIR=build

CORE_SRC_DIR=core
CORE_OBJ_DIR=core/compiled

COCOA_OBJ_DIR=cocoa/remember/Resources/core

$(COCOA_OBJ_DIR)/bin/remember-core: $(BUILD_DIR)/bin/remember-core
	rm -fr $(COCOA_OBJ_DIR) && mkdir -p $(COCOA_OBJ_DIR)
	cp -r $(BUILD_DIR)/* $(COCOA_OBJ_DIR)/

$(BUILD_DIR)/bin/remember-core: $(TEMP_DIR)/remember-core
	rm -fr $(BUILD_DIR) && mkdir -p $(BUILD_DIR)
	raco distribute $(BUILD_DIR) $(TEMP_DIR)/remember-core

$(TEMP_DIR)/remember-core: $(CORE_OBJ_DIR)/main_rkt.zo migrations/*.sql
	rm -fr $(TEMP_DIR) && mkdir -p $(TEMP_DIR)
	raco exe -o $(TEMP_DIR)/remember-core core/main.rkt

$(CORE_OBJ_DIR)/main_rkt.zo: core/*.rkt

$(CORE_OBJ_DIR)/%_rkt.zo: core/%.rkt
	raco make $<

.PHONY: clean
clean:
	rm -fr $(CORE_OBJ_DIR) $(COCOA_OBJ_DIR) $(BUILD_DIR) $(TEMP_DIR)
