
package require yajltcl
package require Tclx

set timezone "CST6CDT"
set serialPort "/dev/ttyUSB0"
set baudRate 115200
set maxZone 8

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

#
# comm_callback - called when data is available from TL-100
#
proc comm_callback {} {
	if {[gets $::comm line] >= 0} {
		#puts "'$line'"
		set decoded [decode_tl100_message $line]
		if {[llength $decoded] == 0} {
			# an empty list means skip reporting the message
			return
		}
		log_message $decoded
		puts [message_to_json $decoded]
	}
}

#
# open_serial_port - connect to TL-100 at the configured device
#  name and baud rate.  set up for correct translation and
#  buffering and arrange for callbacks when complete lines have
#  been read
#
proc open_serial_port {} {
	set ::comm [open $::serialPort r+]
	fconfigure $::comm -mode $::baudRate,n,8,1 -translation crlf -blocking 0 -buffering line
	fileevent $::comm readable comm_callback
	return $::comm
}

#
# calc_checksum - given a string, return the checksum by DSC's algorithm
#
proc calc_checksum {string} {
	set sum 0
	foreach char [split $string ""] {
		incr sum [scan $char %c]
	}
	set sum [expr {$sum & 0xff}]
	return [format %02X $sum]
}

#
# verify_checksum - given a string received from TL-100, verify its checksum
#
proc verify_checksum {string} {
	set checksum [string range $string end-1 end]
	set string [string range $string 0 end-2]

	return [expr {$checksum eq [calc_checksum $string]}]
}

#
# strip_leading_zeros - return the number stripped of leading zeros
#
proc strip_leading_zeros {num} {
	scan $num %d num
	return $num
}

#
# format_zone - return the zone stripped of leading zeros
#
proc format_zone {zone} {
	return [strip_leading_zeros $zone]
}


#
# send - send a string to the TL-100 with a calculated checksum and CRLF
#
proc send {string} {
	puts $::comm "$string[calc_checksum $string]"

}

#
# poll - send a poll command
#
proc poll {} {
	send "000"
}

#
# status_request - send a status request command
#
proc status_request {} {
	send "001"
}

#
# labels_request - send a labels request command
#
proc labels_request {} {
	send "002"
}

#
# set_time_and_date - send a command to set time and date
#   from the system time
#
proc set_time_and_date {} {
	set clock [clock format [clock seconds] -format "%H%M%m%d%y" -timezone $::timezone]
	send "010$clock"
}

#
# partition_check - verify a partition number is between 1 and 8 or error out
#
proc partition_check {partition} {
	if {$partition < 1 || $partition > 8} {
		error "partition must be between 1 and 8"
	}
}

#
# code_check - verify a code number is numeric and 4 or 6 digits
#
proc code_check {code} {
	if {![string is digit $code]} {
		error "code '$code' isn't all digits"
	}

	if {[string length $code] == 6} {
		return $code
	}

	if {[string length $code] != 4} {
		error "code is not 4 or 6 digits long"
	}

	return "${code}00"
}

#
# command_output_control - send a command output control command
#  for the specified partition and program
#
proc command_output_control {partition program} {
	partition_check $partition

	if {$program < 1 || $program > 4} {
		error "program must be between 1 and 4"
	}

	send "020$partition$program"
}

#
# partition_arm_control_away - arm the specified partition into away mode
#
proc partition_arm_control_away {partition} {
	partition_check $partition

	send "030$partition"
}

#
# partition_arm_control_stay - arm the specified partition into stay mode
#
proc partition_arm_control_stay {partition} {
	partition_check $partition

	send "031$partition"
}

#
# partition_arm_control_armed_no_entry_delay - arm the specified partition with no entry delay
#
proc partition_arm_control_armed_no_entry_delay {partition} {
	partition_check $partition

	send "032$partition"
}

#
# partition_arm_control_with_code - arm the specified partition with the specified code
#
proc partition_arm_control_with_code {partition code} {
	partition_check $partition

	set code [code_check $code]
	send "033$partition$code"
}

#
# partition_disarm_control_with_code - disarm the specified partition with the specified code
#
proc partition_disarm_control_with_code {partition code} {
	partition_check $partition
	set code [code_check $code]

	send "040$partition$code"
}

proc timestamp_control {state} {
	send "055$state"
}

proc time_date_broadcast_control {state} {
	send "056$state"
}

proc temperature_broadcast_control {state} {
	send "057$state"
}

proc virtual_keypad_control {state} {
	send "058$state"
}

proc trigger_panic_alarm {state} {
	# state must be F, A or P for fire, ambulance or Panic
	send "060$state"
}

#
# key_pressed - simulate pressing a key on a remote
#
proc key_pressed {key} {
	# key can be ascii numeric 0 - 9
	# F, A, P for fire, ambulance, panic keys
	# a, b, c, d, e for function keys 1 - 5
	# arrow keys "<" ">"
	# both arrow keys "="
	# break key "^"
	send "070$key"
}

proc baud_rate_change {val} {
	# 0 = 9600, 1 = 19200, 2 = 38400, 3 = 57600, 4 = 115200
	send "080$val"
}

proc get_temperature_set_point {val} {
	# val can be 1, 2, 3 or 4 for the thermostat to change
	send "095$val"
}

proc temperature_change {} {
}

proc save_temperature_setting {} {
}

#
# code_send - send the 4 or 6 digit code
#
proc code_send {code} {
	set code [code_check $code]
	send "200$code"
}

#
# set_time_to_the_second - calculate how many seconds until the
#  system clock, which we assume is NTP-synced, rolls over to the
#  next minute, and send the DSC a command to set the time in
#  that many seconds
#
proc set_time_to_the_second {} {
	set now [clock seconds]
	set nextMinute [expr {($now / 60) * 60 + 60}]
	set secs [expr {$nextMinute - $now}]
	after [expr {$secs * 1000}] set_time_and_date
	log_message "setting time in $secs seconds"
}

#
# format_message - return a DSC message formatted as a TCL list of
#   key-value pairs
#
proc format_message {code messageType args} {
	return [list clock [clock seconds] code $code message $messageType {*}$args]
}

#
# format_partition_zone - return a DSC message that happens to comprise
#   a message type, partition and zone
#
proc format_partition_zone {code messageType body} {
	return [format_message $code $messageType partition [string index $body 0] zone [format_zone [string range $body 1 end]]]
}

#
# decode_tl100_message - given a message received from a TL-100, return a TCL list containing
#  information about the message
#
proc decode_tl100_message {message} {
	set code [string range $message 0 2]
	set body [string range $message 3 end-2]

	switch $code {
		500 {return [format_message $code command_acknowledge command $body]}
		501 {return [format_message $code command_error]}

		502 {
			set errorcode $body
			set result [format_message $code system_error error $errorcode]
			if {[info exists ::errorCodes($errorcode)]} {
				lappend result description $::errorCodes($errorcode)
			}
			return $result
		}

		550 {return [format_message $code time_date_broadcast timedate $body]}
		560 {return [format_message $code ring_detected timedate $body]}
		561 {return [format_message $code indoor_temperature_broadcast temperature $body]}
		562 {return [format_message $code outdoor_temperature_broadcast temperature $body]}
		563 {return [format_message $code thermostat_set_points $body]}
		570 {
			set labelNumber [string range $body 0 2]
			set label [string range $body 3 end]
			return [format_message $code broadcast_labels label_number $labelNumber label $label]
		}
		580 {return [format_message $code baud_rate_set baud $body]}
		601 {return [format_partition_zone $code zone_alarm $body]}
		602 {return [format_partition_zone $code zone_alarm_restore $body]}
		603 {return [format_partition_zone $code zone_tamper $body]}
		604 {return [format_partition_zone $code zone_tamper_restore $body]}
		605 {return [format_message $code zone_fault zone [format_zone $body]]}
		606 {return [format_message $code zone_fault_restore zone [format_zone $body]]}

		609 {
			set zone [format_zone $body]
			set_zone_status $zone open
			return [format_message $code zone_open zone $zone]
		}

		610 {
			set zone [format_zone $body]
			if {$zone > $::maxZone} {
				return [list]
			}
			set_zone_status $zone closed
			return [format_message $code zone_restored zone $zone]
		}

		620 {return [format_message $code duress_alarm code $body]}
		621 {return [format_message $code fire_key_alarm]}
		622 {return [format_message $code fire_key_alarm_restored]}
		623 {return [format_message $code auxiliary_key_alarm]}
		624 {return [format_message $code auxiliary_key_alarm_restored]}
		625 {return [format_message $code panic_key_alarm]}
		626 {return [format_message $code panic_key_alarm_restored]}

		631 {return [format_message $code auxiliary_input_alarm]}
		632 {return [format_message $code auxiliary_input_alarm_restored]}

		650 {return [format_message $code partition_ready partition $body]}
		651 {return [format_message $code partition_not_ready partition $body]}

		652 {
			set partition [string index $body 0]
			set mode [string index $body 1]
			switch $mode {
				0 {set mode away}
				1 {set mode stay}
				2 {set mode away_no_delay}
				3 {set mode stay_o_delay}
			}
			return [format_message $code partition_armed_descriptive_mode partition $partition mode $mode]
		}

		653 {return [format_message $code partition_in_ready_to_force_arm partition $body]}
		654 {return [format_message $code partition_in_alarm partition $body]}
		655 {return [format_message $code partition_disarmed partition $body]}
		656 {return [format_message $code exit_delay_in_progress partition $body]}
		657 {return [format_message $code entry_delay_in_progress partition $body]}
		658 {return [format_message $code keypad_lockout partition $body]}
		659 {return [format_message $code keypad_blanking partition $body]}
		660 {return [format_message $code command_output_in_progress partition $body]}

		670 {return [format_message $code invalid_access_code partition $body]}
		671 {return [format_message $code function_not_available partition $body]}
		672 {return [format_message $code fail_to_arm partition $body]}
		673 {return [format_message $code partition_busy partition $body]}

		700 {return [format_message $code user_closing partition [string index $body 0] user_code [string range $body 1 end]]}
		701 {return [format_message $code special_closing partition $body]}
		702 {return [format_message $code partial_closing partition $body]}

		750 {return [format_message $code user_opening partition [string index $body 0] user_code [string range $body 1 end]]}
		751 {return [format_message $code special_opening partitioning $body]}

		800 {return [format_message $code panel_battery_trouble]}
		801 {return [format_message $code panel_battery_trouble_restore]}
		802 {return [format_message $code panel_ac_trouble]}
		803 {return [format_message $code panel_ac_restore]}

		806 {return [format_message $code system_bell_trouble]}
		807 {return [format_message $code system_bell_trouble_restoral]}

		810 {return [format_message $code tlm_line_1_trouble]}
		811 {return [format_message $code tlm_line_1_trouble_restored]}
		812 {return [format_message $code tlm_line_2_trouble]}
		813 {return [format_message $code tlm_line_2_trouble_restored]}
		814 {return [format_message $code failure_to_communicate_trouble]}

		816 {return [format_message $code buffer_near_full]}

		821 {return [format_message $code general_device_low_battery zone $body]}
		822 {return [format_message $code general_device_low_battery_restore zone $body]}

		825 {return [format_message $code wireless_key_low_battery_trouble key $body]}
		826 {return [format_message $code wireless_key_low_battery_trouble_restore key $body]}
		827 {return [format_message $code handheld_keypad_low_battery_trouble keypad $body]}
		828 {return [format_message $code handheld_keypad_low_battery_trouble_restore keypad $body]}
		829 {return [format_message $code general_system_tamper]}
		830 {return [format_message $code general_system_tamper_restore]}
		831 {return [format_message $code escort_5580_module_trouble]}
		832 {return [format_message $code escort_5580_module_trouble_restore]}

		840 {return [format_message $code trouble_status partition $body]}
		841 {return [format_message $code trouble_status_restore partition $body]}
		842 {return [format_message $code fire_trouble_alarm]}
		843 {return [format_message $code fire_trouble_alarm_restore]}

		896 {return [format_message $code keybus_fault]}
		897 {return [format_message $code keybus_restored]}

		900 {return [format_message $code code_required partition [string index $body 0] notsure [string range $body 1 end]]}

		901 {
			set line [string index $body 0]
			set column [strip_leading_zeros [string range $body 1 2]]
			set nChar [strip_leading_zeros [string range $body 3 4]]
			set data [string range $body 5 end]
			return [format_message $code lcd_update line $line column $column n_chars $nChar data $data]
		}

		902 {
			switch [string index $body 0] {
				"0" {set type off}
				"1" {set type normal}
				"2" {set type block}
				default {set type unknown}
			}

			set line [string index $body 1]
			set column [strip_leading_zeros [string range $body 2 end]]
			return [format_message $code lcd_cursor type $type line $line column $column]
		}

		903 {
			set led [string index $body 0]
			set status [string index $body 1]
			switch $led {
				"1" {set led "ready"}
				"2" {set led "armed"}
				"3" {set led "memory"}
				"4" {set led "bypass"}
				"5" {set led "trouble"}
				"6" {set led "program"}
				"7" {set led "fire"}
				"8" {set led "backlight"}
				"9" {set led "AC"}
			}

			switch $status {
				"0" {set status "off"}
				"1" {set status "on"}
				"2" {set status "flashing"}
			}

			return [format_message $code led_status led $led status $status]
		}

		904 {return [format_message $code beep_status beeps [strip_leading_zeros $body]]}

		905 {
			set tone [string index $body 0]
			set beeps [string index $body 1]
			set interval [string range $body 2 end]
			return [format_message $code tone_status tone_control $tone n_beeps $beeps interval $interval]
		}

		906 {return [format_message $code buzzer_status seconds $body]}
		907 {return [format_message $code door_chime_status]}

		908 {
			return [format_message $code software_version version [strip_leading_zeros [string range $body 0 1]] sub_version [strip_leading_zeros [string range $body 2 3]] future_use [strip_leading_zeros [string range $body 4 5]]]
		}

		default {
			return [format_message $code unrecognized_message_type code $code body $body]
		}
	}

	error "software error - should not have gotten here"
}

proc go {} {
	sqlite_init
	open_serial_port
	status_request
	set_time_to_the_second
	puts "ready"
}

package provide tl100 1.0.0


