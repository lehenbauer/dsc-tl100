

## dsc-tl100 - Do things with a DSC alarm system from a Raspberry Pi using the TL-100 serial interface

The TL-100 is a serial port interface for a DSC alarm system.  To the DSC system I think it basically looks like a keypad.  The TL-100 spec allows you to send keypresses and commands to the DSC, and to receive messages from the DSC.

The DSC will send you data to put on your 2 x 10 character LCD or whatever the keypad has, as if the TL-100 is a keypad.

You can arm stay, arm away, disarm, find out the status of all your zones, set the time and date, etc.  Everything, I'm sure.  You can find out all the deets in the IT-100 Data Interface Module v1.0 Developer’s Guide at https://cms.dsc.com/download.php?t=1&id=16238

The code is pretty rough for right now.

Edit package/tl100.tcl and set your serial port device name (default /dev/ttyUSB0), your baudrate (default 115200 yet the unprogrammed TL-100 default is 9600) and your timezone (default US Central).

Have tclreadline installed so that the event loop is alive even though you're using Tcl's command prompt.

Run Tcl and source the tl100.tcl file.

Invoke open_serial_port

or run tclsh and source the go.tcl file.  it'll connect and do a status request and set the DSC date and time to match the system time from your computer.

You can now send commands to the DSC alarm system through the TL-100

* poll - send a poll command.  The resonse is a commmand acknowledge for command 000, the poll command.
* status_request - request status.  You get a bunch of stuff back, like the software version, partitions that aren't ready or are busy, trouble codes, LED status for all the LEDs that would be on one of the keypads.
* labels_request - send a labels request command.  this gets all the labels on all the zones and partitions and commands.
* set_time_and_date - this will set the time and date from the UNIX/Linux system time
* command_output_control - send a command output control command for the specified partition and program.  i don't know what this actually does.
* partition_arm_control_away - arm the specified partition into away mode
* partition_arm_control_stay - arm the specified partition into stay mode
* partition_arm_control_armed_no_entry_delay - arm the specified partition with no entry delay
* partition_arm_control_with_code - arm the specified partition with the specified code
* partition_disarm_control_with_code - disarm the specified partition with the specified code
* timestamp_control
* time_date_broadcast_control
* temperature_broadcast_control
* virtual_keypad_control
* trigger_panic_alarm
* key_pressed - see sending key presses, below
* baud_rate_change
* get_temperature_set_point
* temperature_change
* save_temperature_setting
* code_send

### sending key presses

Most stuff you can do with commands, but you can also send keypresses as if from a remote keypad.  Send a key press using the key_pressed command with the key for an argument.

The key can be
* ASCII numeric 0-9 for the numeric pad.
* F, A, or P, to press the fire, ambulance, and panic keys.
* a, b, c, d or e for the function keys 1 - 5
* Arrow keys "<" and ">"
* Both arrow keys by sending "="
* The break key by sending "^"

If you need to hold a key down for, say, two seconds, then you need to arrange to send the key and then two seconds later send the break key by invoking `key_pressed ^`.

### decoding TL-100 messages

Messages from the TL-100 are decoded into a TCL list containing information about the message.

Each message is annotated with the Unix system clock of the host running our software, in epoch format.

Next will be a message type, "message", and then zero or more additional key-value pairs specifying things like the partition, zone, number of beeps, etc.

Soon these messages will be encoded into JSON or something.

The messages are decoded and currently emitted to stdout, but a callback mechanism will soon be provided.

