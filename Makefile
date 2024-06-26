ARCH=$(shell uname -m)

APP_SRC=remember
RKT_SRC=core
RKT_FILES=$(shell find ${RKT_SRC} -name '*.rkt')
RKT_MAIN_ZO=${RKT_SRC}/compiled/main_rkt.zo

RESOURCES_PATH=${APP_SRC}/res
RUNTIME_NAME=runtime-${ARCH}
RUNTIME_PATH=${RESOURCES_PATH}/${RUNTIME_NAME}
MANUAL_PATH=${RESOURCES_PATH}/manual

CORE_ZO=${RESOURCES_PATH}/core-${ARCH}.zo

.PHONY: all
all: ${CORE_ZO} ${APP_SRC}/Backend.swift

.PHONY: clean
clean:
	find core -type d -name compiled | xargs rm -fr
	rm -fr ${RESOURCES_PATH}

${RKT_MAIN_ZO}: ${RKT_FILES}
	raco make -j 16 -v ${RKT_SRC}/main.rkt

${CORE_ZO}: ${RKT_MAIN_ZO}
	mkdir -p ${RESOURCES_PATH}
	rm -fr ${RUNTIME_PATH}
	raco ctool \
	  --runtime ${RUNTIME_PATH} \
	  --runtime-access ${RUNTIME_NAME} \
	  --mods $@ ${RKT_SRC}/main.rkt

${APP_SRC}/Backend.swift: ${CORE_ZO}
	raco noise-serde-codegen ${RKT_SRC}/main.rkt > $@

${MANUAL_PATH}/index.html: manual/*.scrbl
	raco scribble --html --dest ${MANUAL_PATH} +m manual/index.scrbl

website/manual/index.html: manual/*.scrbl
	make -C website manual/index.html
