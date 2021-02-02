

set timezone "CST6CDT"
set serialPort "/dev/ttuUSB0"

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

proc comm_callback {} {
	if {[gets $::comm line] >= 0} {
		puts "'$line'"
		set decoded [decode $line]
		if {$decoded != ""} {
			puts $decoded
		}
	}
}

proc open_serial_port {} {
	set ::comm [open $::serialPort r+]
	fconfigure $::comm -mode 115200,n,8,1 -translation crlf -blocking 0 -buffering line
	fileevent $::comm readable comm_callback
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

proc partition_arm_control_armed_no_entry_delay {partition} {
	partition_check $partition

	send "032$partition"
}

proc partition_arm_control_with_code {partition code} {
	partition_check $partition
	set code [code_check $code]

	send "033$partition$code"
}

proc partition_disarm_control_with_code {partition code} {
	partition_check $partition
	set code [code_check $code]

	send "040$partition$code"
}






proc decode {message} {
	set code [string range $message 0 2]
	set body [string range $message 3 end-2]

	switch $code {
		500 {
			return [list command_acknowledge $body]
		}

		501 {
			return [list command_error $body]
		}

		502 {
			set errorcode $body
			set result [list system_error $errorcode]
			if {[info exists ::errorCodes($errorcode)]} {
				lappend result $::errorCodes($errorcode)
			}
			return $result
		}

		550 {
			return [list time_date_broadcast $body]
		}

		560 {
			return [list ring_detected $body]
		}

		561 {
			return [list indoor_temperature_broadcast $body]
		}

		562 {
			return [list outdoor_temperature_broadcast $body]
		}

		563 {
			return [list thermostat_set_points $body]
		}

		570 {
			set labelNumber [string range $body 0 2]
			set label [string range $body 3 end]
			return [list broadcast_labels $labelNumber $label]
		}

		580 {
			return [list baud_rate_set $body]
		}

		601 {
			return [list zone_alarm [string index $body 0] [string range $body 1 end]]
		}

		602 {
			return [list zone_alarm_restore [string index $body 0] [string range $body 1 end]]
		}

		603 {
			return [list zone_tamper [string index $body 0] [string range $body 1 end]]
		}

		604 {
			return [list zone_tamper_restore [string index $body 0] [string range $body 1 end]]
		}

		605 {
			return [list zone_fault $body]
		}

		606 {
			return [list zone_fault_restore $body]
		}

		609 {
			return [list zone_open $body]
		}

		610 {
			return [list zone_restored $body]
		}

		620 {
			return [list duress_alarm $body]
		}

		621 {
			return [list fire_key_alarm]
		}

		622 {
			return [list fire_key_alarm_restored]
		}

		623 {
			return [list auxiliary_key_alarm]
		}

		624 {
			return [list auxiliary_key_alarm_restored]
		}

		625 {
			return [list panic_key_alarm]
		}

		626 {
			if {$body == ""} {
				return [list panic_key_alarm_restored]
			} else {
				return [list partition_ready $body]
			}
		}

		631 {
			return [list auxiliary_input_alarm]
		}

		632 {
			return [list auxiliary_input_alarm_restored]
		}

		651 {
			return [list partition_not_ready $body]
		}

		652 {
			set partition [string index $body 0]
			set mode [string index $body 1]
			switch $mode {
				0 {
					set mode away
				}

				1 {
					set mode stay
				}

				2 {
					set mode away_no_delay
				}

				3 {
					set mode stay_o_delay
				}
			}
			return [list partition_armed_descriptive_mode $partition $mode]
		}

		653 {
			return [list partition_in_ready_to_force_arm $body]
		}

		654 {
			return [list partition_in_alarm $body]
		}

		655 {
			return [list partition_disarmed $body]
		}

		656 {
			return [list exit_delay_in_progress $body]
		}

		657 {
			return [list entry_delay_in_progress $body]
		}

		658 {
			return [list keypad_lockout $body]
		}

		659 {
			return [list keypad_blanking $body]
		}

		660 {
			return [list command_output_in_progress $body]
		}

		670 {
			return [list invalid_access_code $body]
		}

		671 {
			return [list function_not_available $body]
		}

		672 {
			return [list fail_to_arm $body]
		}

		673 {
			return [list partition_busy $body]
		}

		700 {
			return [list user_closing [string index $body 0] [string range $body 1 end]]
		}

		701 {
			return [list special_closing $body]
		}

		702 {
			return [list partial_closing $body]
		}

		750 {
			return [list user_opening [string index $body 0] [string range $body 1 end]]
		}

		751 {
			return [list special_opening $body]
		}

		800 {
			return [list panel_battery_trouble]
		}

		801 {
			return [list panel_battery_trouble_restore]
		}

		802 {
			return [list panel_ac_trouble]
		}

		803 {
			return [list panel_ac_restore]
		}

		806 {
			return [list system_bell_trouble]
		}

		807 {
			return [list system_bell_trouble_restoral]
		}

		810 {
			return [list tlm_line_1_trouble]
		}

		811 {
			return [list tlm_line_1_trouble_restored]
		}

		812 {
			return [list tlm_line_2_trouble]
		}

		813 {
			return [list tlm_line_2_trouble_restored]
		}

		814 {
			return [list failure_to_communicate_trouble]
		}

		816 {
			return [list buffer_near_full]
		}

		821 {
			return [list general_device_low_battery $body]
		}

		822 {
			return [list general_device_low_battery_restore $body]
		}

		825 {
			return [list wireless_key_low_battery_trouble $body]
		}

		826 {
			return [list wireless_key_low_battery_trouble_restore $body]
		}

		827 {
			return [list handheld_keypad_low_battery_trouble $body]
		}

		828 {
			return [list handheld_keypad_low_battery_trouble_restore $body]
		}

		829 {
			return [list general_system_tamper]
		}

		830 {
			return [list general_system_tamper_restore]
		}

		831 {
			return [list escort_5580_module_trouble]
		}

		832 {
			return [list escort_5580_module_trouble_restore]
		}

		840 {
			return [list trouble_status $body]
		}

		841 {
			return [list trouble_status_restore $body]
		}

		842 {
			return [list fire_trouble_alarm]
		}

		843 {
			return [list fire_trouble_alarm_restore]
		}

		900 {
			return [list code_required [string index $body 0] [string range $body 1 end]]
		}

		901 {
			set line [string index $body 0]
			set column [string range $body 1 2]
			set nChar [string range $body 3 2]
			set data [string range $body 5 end]
			return [list lcd_update $line $column $nChar $data]
		}

		902 {
			switch [string index $body 0] {
				"0" {
					set type off
				}

				"1" {
					set type normal
				}

				"2" {
					set type block
				}

				default {
					set type unknown
				}
			}

			set line [string index $body 1]
			set column [string range $body 2 end]
			return [list lcd_cursor $type $line $column]
		}

		903 {
			set led [string index $body 0]
			set status [string index $body 1]
			switch $led {
				"1" {
					set led "ready"
				}

				"2" {
					set led "armed"
				}

				"3" {
					set led "memory"
				}

				"4" {
					set led "bypass"
				}

				"5" {
					set led "trouble"
				}

				"6" {
					set led "program"
				}

				"7" {
					set led "fire"
				}

				"8" {
					set led "backlight"
				}

				"9" {
					set led "AC"
				}
			}

			switch $status {
				"0" {
					set status "off"
				}

				"1" {
					set status "on"
				}

				"2" {
					set status "flashing"
				}
			}

			return [list led_status $led $status]
		}

		904 {
			return [list beep_status $body]
		}

		905 {
			set tone [string index $body 0]
			set beeps [string index $body 1]
			set interval [string index $body 2 end]
			return [list tone_status $tone $beeps $interval]
		}

		906 {
			return [list buzzer_status $body]
		}

		907 {
			return [list door_chime_status]
		}

		908 {
			return [list software_version [string range $body 0 1] [string range $body 2 3] [string range $body 4 5]]
		}
	}

	return [list]
}

package provide tl100 0.0
