cocoa/remember/Resources/core/bin/remember-core: build/bin/remember-core
	mkdir -p cocoa/remember/Resources/core
	cp -r build/* cocoa/remember/Resources/core/

build/bin/remember-core: temp/remember-core
	mkdir -p build
	raco distribute build temp/remember-core

temp/remember-core: core/compiled/main_rkt.zo
	mkdir -p temp
	raco exe -o temp/remember-core core/main.rkt

core/compiled/main_rkt.zo: core/*.rkt

core/compiled/%_rkt.zo: core/%.rkt
	raco make $<

.PHONY: clean
clean:
	rm -fr core/compiled build temp
