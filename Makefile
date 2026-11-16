# concha, in raz, over rzone (local time), installed in ~/.raz/lib. The program
# builds with the raz on PATH, which must be the version it is written
# for, RAZVERSION: make warns of any other. Its tarball is on raz's
# website, at download/raz-$(RAZVERSION)-linux-x86_64.tar.gz.
# A build from raz's sources after a release, 0.15.0-1-g7898828, is that
# release's.
#
#   make              build/concha
#   make modules      each module of src/ compiled on its own, while the port
#                     has no program yet
#   make test         tests/test.cn under build/concha, the examples checked,
#                     the man pages checked
#   make fmt          src/ and tests/Play.raz are laid out as raz's formatter lays them out
#   make cast         doc/demo.cast and doc/img/demo.gif made again
#   make install      the program, its manual pages and examples (PREFIX=...)
#   make uninstall    exactly what install put there

RAZ ?= raz
RAZVERSION = 0.25.0
RAZSITE = https://raz.lucela.org
# raz's tools, the formatter among them, lie beside its real path
RAZTOOLS = $(dir $(realpath $(shell command -v $(RAZ))))tools

comma := ,
ifneq "$(firstword $(subst -, ,$(subst $(comma),,$(word 2,$(shell $(RAZ) --version 2>/dev/null)))))" "$(RAZVERSION)"
$(warning concha is written for raz $(RAZVERSION), from $(RAZSITE); $(RAZ) is $(or $(shell $(RAZ) --version 2>/dev/null),not found))
endif


PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
MANDIR ?= $(PREFIX)/share/man
DATADIR ?= $(PREFIX)/share/concha
SRC = $(wildcard src/*.raz)
MAN = doc/concha.1 doc/concha-complete.5 doc/concha-tutorial.7
EXAMPLES = $(wildcard examples/*.cn) examples/concharc

all: build/concha

build/concha: $(SRC)
	@mkdir -p build
	$(RAZ) -Werror -o build/concha src/Concha.raz

modules: $(SRC)
	@mkdir -p build/modules
	@for f in $(SRC); do \
	    echo $$f; $(RAZ) -Werror -o build/modules/$$(basename $$f .raz) $$f || exit 1; \
	done

test: build/concha man
	env CONCHA=$(CURDIR)/build/concha build/concha tests/test.cn
	for f in $(EXAMPLES); do build/concha -n $$f || exit 1; done

fmt:
	@mkdir -p build
	$(RAZ) -o build/Pretty $(RAZTOOLS)/Pretty.raz
	@fail=0; for f in $(SRC) tests/Play.raz; do \
	    build/Pretty $$f | cmp -s - $$f || { echo "not formatted: $$f"; fail=1; }; \
	done; test $$fail = 0

# The pseudo-terminal player, for the cast.
build/play: tests/Play.raz
	@mkdir -p build
	$(RAZ) -Werror -o build/play tests/Play.raz

# Regenerate the asciinema cast and the demo GIF; needs tmux,
# rsvg-convert and ffmpeg, and the DejaVu Sans Mono font.
cast: build/concha build/play
	build/concha tests/cast.cn

man:
	for p in $(MAN); do groff -mdoc -ww -z $$p || exit 1; done

# lines, by rloc; a measure, not a limit
loc:
	@rloc src

install: all man
	install -d $(DESTDIR)$(BINDIR) $(DESTDIR)$(DATADIR)/examples
	install -d $(DESTDIR)$(MANDIR)/man1 $(DESTDIR)$(MANDIR)/man5 $(DESTDIR)$(MANDIR)/man7
	install -m 755 build/concha $(DESTDIR)$(BINDIR)/concha
	install -m 644 doc/concha.1 $(DESTDIR)$(MANDIR)/man1/concha.1
	install -m 644 doc/concha-complete.5 $(DESTDIR)$(MANDIR)/man5/concha-complete.5
	install -m 644 doc/concha-tutorial.7 $(DESTDIR)$(MANDIR)/man7/concha-tutorial.7
	install -m 755 $(wildcard examples/*.cn) $(DESTDIR)$(DATADIR)/examples
	install -m 644 examples/concharc $(DESTDIR)$(DATADIR)/examples

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/concha
	rm -f $(DESTDIR)$(MANDIR)/man1/concha.1 $(DESTDIR)$(MANDIR)/man5/concha-complete.5
	rm -f $(DESTDIR)$(MANDIR)/man7/concha-tutorial.7
	rm -f $(EXAMPLES:examples/%=$(DESTDIR)$(DATADIR)/examples/%)
	rmdir $(DESTDIR)$(DATADIR)/examples $(DESTDIR)$(DATADIR) 2>/dev/null || true

clean:
	rm -rf build

.PHONY: all modules test fmt cast man loc install uninstall clean
