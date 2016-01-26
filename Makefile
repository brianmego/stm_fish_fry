#########################################################################################
# The name of this project. Will be used as the tag for the container, if one is created
#########################################################################################
ME := stm_fish_fry
CWD := $(CURDIR)
pfx := $(CWD)/$(ME)_server

#########################################################################################
# You shouldnt need change things here
#########################################################################################

SHASUM := sha1sum
ROOT:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
THISDIR = $(shell basename $(ROOT))
BUILDDIR := $(ROOT)/build
VERSION := $(shell grep version setup.py | awk -F\' '{ print $$2 }')
NONDISTSRC := setup.py setup.cfg

#########################################################################################
# This project's specific Variables
#########################################################################################
SRC := $($(shell find $(ME) -name "*.py" -type f))
CFGSRC := $(wildcard config/*)
CONFIG := $(addprefix $(pfx)/, $(CFGSRC))
SUPERVISOR := $(addprefix $(pfx)/, $(wildcard supervisor/*.conf))
EXTRAS := $(pfx)/etc/logrotate.d/$(ME)

################################################################################
# Python flags for Virtualenv
################################################################################

SHELL := bash
VENVDIR := $(pfx)
VPYTHON := $(VENVDIR)/bin/python2.7
ACTIVATE := source env.sh
PYTHONUSERBASE=$(VENVDIR)
PIP := $(pfx)/bin/pip
PYUSERFLAGS :=
PIPUSERFLAGS := --cache-dir $(HOME)/.pipcache
# Enabling python wheels will cause problems since we build our
# dedicated python interpreters without --enable-shared. Since wheel
# files are dynamically linked with libpython.so, any shared objects
# from wheels will wind up linking with /usr/local/lib/libpython.so,
# the symbols for which are already in our python binary.
PIPFLAGS := $(PIPUSERFLAGS) --no-binary :all:
PEP8 := $(pfx)/bin/pep8
PYLINT := $(pfx)/bin/pylint
COVERAGE := $(pfx)/bin/coverage


################################################################################
# Targets
################################################################################

all: .install.ts lint r2.deps build/ENV/bin/activate

build/ENV/bin/activate: env.sh
	mkdir -p $(@D) && \
	ln -s $(CWD)/$^ $@

installdeps: build.deps
	cat build.deps | sudo xargs yum -y install

.testdeps.ts: build.deps
	cat build.deps | xargs rpm -q && \
	touch $@

$(PEP8): .installpackages.ts

$(COVERAGE): .installpackages.ts

$(VENVBIN): bootstrap/$(VENVDIST)
	cd bootstrap && \
	tar xf $(VENVDIST) && \
	cd $(VENVDISTDIR) && patch -p1 < ../../patches/virtualenv-change-prefix.patch && \
	cd .. && \
	chmod 755 $@ && \
	touch $@

$(VPYTHON): .python27.install

$(PYLINT): .installpackages.ts
$(PIP): .pip.install
$(PEP8): .installpackages.ts
$(NOSETESTS): .installpackages.ts

.installpackages.ts: $(PIP) requirements.txt env.sh
	$(ACTIVATE) && \
	export PKG_CONFIG_PATH=$(pfx)/lib/pkgconfig && \
	$(PIP) install $(PYPIURL) -r requirements.txt --upgrade $(PIPFLAGS) && \
	touch $@

.install.ts: $(PIP) .installpackages.ts
	$(ACTIVATE) && \
	$(PIP) install . --upgrade && \
	touch $@

.pep8.ts: $(PEP8) $(NONDISTSRC)
.pep8.ts: $(SRC)
	$(ACTIVATE) && \
	$(PEP8) $(filter %.py, $?) && \
	touch $@

.pylint.ts: $(PYLINT) $(NONDISTSRC) .installpackages.ts
.pylint.ts: $(SRC)
	@$(ACTIVATE) && \
	echo $(PYLINT) --rcfile=pylintrc $(filter %.py, $?) && \
	touch $@

lint: .pep8.ts .pylint.ts

test: .tests.ts

clean:
	@rm -f .*.ts env.sh && \
	find . -name "*.pyc" -delete

distclean: $(GLOBAL_CLEAN) clean
	rm -fv .*.{config,make,fetch,install,unpack,patch}
	rm -rf $(pfx)
	rm -rf $(BUILDDIR) dist
	rm -f submakes/*.mak config.m4


$(pfx)/config/%: config/%
	mkdir -p $(@D)
	cp $< $@


$(pfx)/supervisor/%.conf: supervisor/%.conf
	mkdir -p $(@D)
	cp $< $@

$(pfx)/etc/logrotate.d/$(ME): logrotate.d/$(ME)
	mkdir -p $(@D)
	cp $< $@

$(ME).tar.gz: MANIFEST.sha1
	tar cvzf $@ $(pfx)

MANIFEST.sha1: all
	find $(pfx) -type f -exec $(SHASUM) {} \; > $@

release: all $(ME).tar.gz

#########################################################################################
# Submakes
#########################################################################################
DEST :=
SUBMAKES := $(wildcard submakes/*.mak.in)

include $(SUBMAKES:mak.in=mak)

LD_LIBRARY_PATH := $(pfx)/lib
PKG_CONFIG_PATH := $(pfx)/lib/pkgconfig
PATH := $(pfx)/bin:$(PATH)
OS := $(shell uname)

ifeq "$(OS)" "Darwin"
DYLD_LIBRARY_PATH := $(pfx)/lib
SHASUM := shasum
PATH := $(pfx)/bin:/usr/local/opt:$(PATH)
LDSHARED='$(CC) $(ARCHFLAGS) -dynamiclib -undefined suppress -flat_namespace'
endif

CFLAGS := -I$(pfx)/include $(ARCHFLAGS)
CPPFLAGS := -I$(pfx)/include $(ARCHFLAGS)
CXXFLAGS := -I$(pfx)/include $(ARCHFLAGS)
LDFLAGS := -L$(pfx)/lib $(ARCHFLAGS)

%.mak: %.mak.in r2.m4
	m4 $< > $@

%/.exist:
	mkdir -p $(@D)
	chmod 755 $(@D)
	touch $@

r2.deps: dists/.exist build/.exist $(OSDEPS) env.sh

env.sh: config.m4 env.sh.in
	m4 $^ > $@
	chmod 755 $@

config.m4:
	echo "define(\`ROOT', \`$(PWD)')" > $@
	echo "define(\`DYLD_VALUE', \`$(DYLD_LIBRARY_PATH)')" >> $@

m4deps :=
ifeq "$(OS)" "Darwin"
	SHASUM := shasum
	m4deps :=
else
	SHASUM := sha1sum
endif

%.sh: config.m4 %.sh.in
	m4 $^ > $@
	chmod +x $@
