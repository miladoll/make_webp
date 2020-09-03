# .PHONY: default
# default: build run

CUR_DIR=$(dir $(realpath $(firstword $(MAKEFILE_LIST))))
NAME=$(shell basename $(CUR_DIR))

do:
	@echo $(NAME)
	@echo $(CUR_DIR)

DIR_SYSTEMD_UNITS=/etc/systemd/system
DIR_OPENRC_LOCALD=/etc/local.d

setup_openrc:
	cp $(CUR_DIR)/make_webp.start $(DIR_OPENRC_LOCALD) ; \
	sed \
		-e 's|%%CUR_DIR%%|$(CUR_DIR)|' \
			$(DIR_OPENRC_LOCALD)/make_webp.start \
	; \
	chmod +x $(DIR_OPENRC_LOCALD)/make_webp.start ; \

setup_systemd:
	cp $(CUR_DIR)/make_webp.service $(DIR_SYSTEMD_UNITS) ; \
	sed \
		-e 's|%%CUR_DIR%%|$(CUR_DIR)|' \
			$(DIR_SYSTEMD_UNITS)/make_webp.service \
	; \
	systemctl list-unit-files --type=service | grep make_webp ; \
	systemctl is-active make_webp ; \
	systemctl is-enabled make_webp ;
