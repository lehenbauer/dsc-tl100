

set timezone "CST6CDT"

array set errorCodes {
	017 "Keybus Busy - Installer Mode"
	021  "Requested Partition is out of Range"
	023  "Partition is not Armed"
	024  "Partition is not Ready to Arm"
	026  "User Code Not Required"
	028  "Virtual Keypad is Disabled"
	029  "Not Valid Parameter"
	030  "Keypad Does Not Come Out of Blank Mode"
	031  "IT-100 is already in Thermostat Menu"
	032  "IT-100 is NOT in Thermostat Menu"
	033  "No response from thermostat or Escort™ module"
}

proc open_serial_port {} {
	set ::comm [open /dev/ttyUSB0]
	fconfigure $::comm -mode 115200,n,8,1 -translation crlf
	return $::comm
}

proc calc_checksum {string} {
	set sum 0
	foreach char [split $string ""] {
		incr sum [scan $char %c]
	}
	set sum [expr {$sum & 0xff}]
	return [format %02X $sum]
}

proc send {string} {
	puts $::comm "$string[calc_checksum $string]"

}

proc poll {} {
	send "000"
}

proc status_request {} {
	send "001"
}

proc labels_request {} {
	send "002"
}

proc set_time_and_date {} {
	set clock [clock format [clock seconds] -format "%H%M%m%d%y" -timezone $::timezone]
	send "010$clock"
}

proc partition_check {partition} {
	if {$partition < 1 || $partition > 8} {
		error "partition must be between 1 and 8"
	}
}

proc command_output_control {partition program} {
	partition_check $partition

	if {$program < 1 || $program > 4} {
		error "program must be between 1 and 4"
	}

	send "020$partition$program"
}

proc partition_arm_control_away {partition} {
	partition_check $partition

	send "030$partition"
}

proc partition_arm_control_stay {partition} {
	partition_check $partition

	send "031$partition"
}

package provide tl100 0.0
