#
# Makefile for vrms-rpm
# Copyright (C) 2017 Marcin "dextero" Radomski
# Copyright (C) 2018 Artur "suve" Iwicki
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 3,
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program (LICENCE.txt). If not, see <http://www.gnu.org/licenses/>.
#

DEFAULT_LICENCE_LIST ?= tweaked
DESTDIR ?=
PREFIX ?= /usr/local

CFLAGS += -std=c11 -iquote ./ -Wall -Wextra -D_POSIX_C_SOURCE=200112L
CWARNS := -Wfloat-equal -Wparentheses
CERRORS := -Werror=incompatible-pointer-types -Werror=discarded-qualifiers -Werror=int-conversion -Werror=div-by-zero -Werror=sequence-point -Werror=uninitialized -Werror=duplicated-cond

LICENCE_FILENAMES := $(basename $(notdir $(shell ls licences/*.txt)))
LICENCE_FILES := $(addprefix build/, $(shell ls licences/*.txt))

PO_FILES := $(shell ls lang/*.po)
MO_FILES := $(PO_FILES:lang/%.po=build/locale/%/LC_MESSAGES/vrms-rpm.mo)

MANS := $(shell ls man/*.man)
MAN_LANGS := $(MANS:man/%.man=%)
NON_EN_MAN_LANGS := $(filter-out en, $(MAN_LANGS))
MAN_FILES := $(MANS:man/%.man=build/man/%.man)

IMAGES := $(shell ls images/*)

SOURCES := $(shell ls src/*.c)
OBJECTS := $(SOURCES:src/%.c=build/%.o)

.PHONY: config build clean install remove

help:
	@echo "TARGETS:"
	@echo "    build - compile project"
	@echo "    clean - remove compiled artifacts"
	@echo "    install - compile & install project"
	@echo "    remove - uninstall project"
	@echo ""
	@echo "VARIABLES:"
	@echo "    DEFAULT_LICENCE_LIST"
	@echo "        default list of good licences to use (default: tweaked)"
	@echo "        changed at run-time using --licence-list"
	@echo "        possible values: $(LICENCE_FILENAMES)"
	@echo "    DESTDIR"
	@echo "        installation destination (default: empty)"
	@echo "        helpful when packaging the application"
	@echo "    PREFIX"
	@echo "        installation prefix (default: /usr/local)"
	@echo "        used during config to set up file paths"

src/config.h: src/generate-config.sh
	src/generate-config.sh -d '$(DEFAULT_LICENCE_LIST)' -l '$(LICENCE_FILENAMES)' -p '$(PREFIX)' > "$@"

build: src/config.h $(MAN_FILES) $(MO_FILES) $(LICENCE_FILES) build/bash-completion.sh build/vrms-rpm

build/bash-completion.sh: src/bash-completion.sh
	mkdir -p "$(shell dirname "$@")"
	sed -e 's|__LICENCE_LIST__|$(LICENCE_FILENAMES)|' < "$<" > "$@"

build/man/%.man: man/%.man
	mkdir -p "$(shell dirname "$@")"
	cp "$<" "$@"
	src/convert-man.sh -d '$(DEFAULT_LICENCE_LIST)' -l '$(LICENCE_FILENAMES)' -p '$(PREFIX)' -f "$@"

build/locale/%/LC_MESSAGES/vrms-rpm.mo: lang/%.po
	mkdir -p "$(shell dirname "$@")"
	msgfmt --check -o "$@" "$<"

build/licences/%.txt: licences/%.txt
	mkdir -p "$(shell dirname "$@")"
	cat "$<" | LC_COLLATE=C sort --ignore-case | uniq > "$@"

build/%.o: src/%.c
	$(CC) $(CFLAGS) $(CWARNS) $(CERRORS) -c -o "$@" "$<"

build/vrms-rpm: $(OBJECTS)
	$(CC) $(CFLAGS) $(CWARNS) $(CERRORS) -o "$@" $^

clean:
	rm src/config.h
	rm -rf build

install/bin/vrms-rpm: build/vrms-rpm
	install -vD -p -m 755 "$<" "$@"

install/share/suve/vrms-rpm/images/%: images/%
	install -vD -m 644 "$<" "$@"

install/share/suve/vrms-rpm/licences/%.txt: build/licences/%.txt
	install -vD -m 644 "$<" "$@"

install/share/man/man1/vrms-rpm.1: build/man/en.man
	install -vD -p -m 644 "$<" "$@"

install/share/man/%/man1/vrms-rpm.1: build/man/%.man
	install -vD -p -m 644 "$<" "$@"

install/share/locale/%: build/locale/%
	install -vD -p -m 644 "$<" "$@"

install/prepare: build
install/prepare: install/bin/vrms-rpm
install/prepare: install/share/man/man1/vrms-rpm.1
install/prepare: $(NON_EN_MAN_LANGS:%=install/share/man/%/man1/vrms-rpm.1)
install/prepare: $(MO_FILES:build/%=install/share/%)
install/prepare: $(LICENCE_FILES:build/%=install/share/suve/vrms-rpm/%)
install/prepare: $(IMAGES:%=install/share/suve/vrms-rpm/%)

install: install/prepare
	mkdir -p "$(DESTDIR)$(PREFIX)"
	cp -a install/* "$(DESTDIR)$(PREFIX)"
	install -vD -m 644 build/bash-completion.sh $(DESTDIR)/etc/bash_completion.d/vrms-rpm
	rm -rf install

remove: install/prepare
	find install -type f | sed -e 's|^install|$(DESTDIR)$(PREFIX)|' | xargs rm -vf
	find install -depth -type d | sed -e 's|^install|$(DESTDIR)$(PREFIX)|' | xargs rmdir -v --ignore-fail-on-non-empty
	rm $(DESTDIR)/etc/bash_completion.d/vrms-rpm
	rm -rf install
