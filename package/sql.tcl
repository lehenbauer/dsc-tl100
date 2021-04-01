
package require sqlite3

global sqliteInited
set sqliteInited 0

#
# sqlite_init - open and set up the sqlite database
#
# if we created it, run what's in our tables.sql to set it up
#
proc sqlite_init {} {
	if {$::sqliteInited} return

	set dir [find_package_dir tl100]

	set dbFile "/var/db/dsc/dsc.sqlite3"
	set exists [file exists $dbFile]

	sqlite3 db $dbFile
	do_rw_pragmas db
	do_ro_pragmas db
	chmod a+rwx $dbFile

	if {!$exists} {
		db eval [read_file [file join $dir tables.sql]]
	}
}

#
# do_rw_pragmas - do sqlite setup pragmas that actually
#   alter the database
#
proc do_rw_pragmas {handle} {
	$handle eval "PRAGMA application_id = 19276;"
	$handle eval "PRAGMA journal_mode = WAL;"
}

#
# do_ro_pragmas - do sqlite setup pragmas that are for
#   readers
#
proc do_ro_pragmas {handle} {
	$handle timeout 5000
	$handle eval "PRAGMA cache_size = 100;"
	$handle eval "PRAGMA synchronous = OFF;"
	$handle eval "PRAGMA mmap_size=2000000;"
	$handle eval "pragma temp_store = memory"
}

#
# find_package_dir - figure what directory a package is loaded from
#
# this should be in a package somewhere -- it's pretty generic
#
proc find_package_dir {package} {
	package require $package
	foreach version [lsort -decreasing [package versions $package]] {
		foreach line [split [package ifneeded $package $version] "\n"] {
			if {[regexp {^source (.*)} $line dummy file]} {
				return [file dirname $file]
			} elseif {[regexp {^load (.*)} $line dummy file]} {
				return [file dirname $file]
			}
		}
	}
	error "couldn't find package dir for package $package"
}

#
# state_to_clockvar - translate between a state ("open", "closed") to
#   a clock variable name ("last_opened", "last_closed")
#
proc state_to_clockvar {state} {
	return [expr {$state eq "open" ? "last_opened" : "last_closed"}]
}

#
# foormat_clock - format a clock as YY/MM/DD HH:MM:SS
#
proc format_clock {clock} {
	if {$clock eq ""} {
		return never
	} else {
		return [clock format $clock -format "%D %T"]
	}
}

#
# set_zone_status - given a zone and a zone state, if the zone is in a different
# state than the last state read from the database, update the database and
# log the state change.
#
# if seeing the zone for the first time, insert it into the database.
#
proc set_zone_status {zone state} {
	if {$state != "closed" && $state != "open"} {
		error "state '$state' must be closed or open"
	}
	db eval "select * from zone_status where zone = :zone" row {
		if {[info exists row(state)] && $row(state) eq $state} {
			puts "zone $zone already in state $state"
			return
		}

		db eval "update zone_status set state = :state, [state_to_clockvar $state] = [clock seconds] where zone = :zone"
		puts "zone $zone changed from $row(state) to $state, last opened [format_clock $row(last_opened)], last closed [format_clock $row(last_closed)]"
		return
	}
	set now [clock seconds]
	db eval "insert into zone_status (zone, state, first_seen, [state_to_clockvar $state]) values (:zone, :state, $now, $now)"
	puts "saw zone $zone for the first time, state $state"
}

package provide tl100 0.0

