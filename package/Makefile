
TCLFILES=json.tcl sql.tcl tl100.tcl

TCLSH ?= tclsh
PREFIX ?= /usr
LIB ?= $(PREFIX)/lib

GROUP ?= daemon

PACKAGE=tl100
TARGET=$(LIB)/$(PACKAGE)
FILES=$(TCLFILES) tables.sql pkgIndex.tcl
DBDIR=/var/db/dsc

all: pkgIndex.tcl
	@echo "'make install' to install"

install: pkgIndex.tcl
	install -o root -g $(GROUP) -m 0755 -d $(TARGET)
	install -o root -g $(GROUP) -m 0644 $(FILES) $(TARGET)/
	mkdir -p $(TARGET)/db
	chmod a+rwx $(TARGET)/db
	@echo "installed $(PACKAGE) to $(LIB)"

full-install: delete-database install

# use if schema has changed
delete-database:
	rm -f $(DBDIR)/*.sqlite*


pkgIndex.tcl:	$(TCLFILES)
	echo "pkg_mkIndex ." | $(TCLSH)
