bin/remember: core/compiled/main_rkt.zo
	raco exe -o bin/remember core/main.rkt

core/compiled/main_rkt.zo: core/*.rkt

core/compiled/%_rkt.zo: core/%.rkt
	raco make $<

.PHONY:clean
clean:
	rm -fr core/compiled bin/remember
