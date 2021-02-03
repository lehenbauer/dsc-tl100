

## dsc-tl100 - Do things with a DSC alarm system from a Raspberry Pi using the TL-100 serial interface

The TL-100 is a serial port interface for a DSC alarm system.  To the DSC system I think it basically looks like a keypad.  The TL-100 spec allows you to send keypresses and commands to the DSC, and to receive messages from the DSC.

The DSC will send you data to put on your 2 x 10 character LCD or whatever the keypad has, as if the TL-100 is a keypad.

You can arm stay, arm away, disarm, find out the status of all your zones, set the time and date, etc.  Everything, I'm sure.  You can find out all the deets in the IT-100 Data Interface Module v1.0 Developer’s Guide at https://cms.dsc.com/download.php?t=1&id=16238

The code is pretty rough for right now.

Edit package/tl100.tcl and set your serial port device name (default /dev/ttyUSB0), your baudrate (default 115200 yet the unprogrammed TL-100 default is 9600) and your timezone (default US Central).

Have tclreadline installed so that the event loop is alive even though you're using Tcl's command prompt.

Run Tcl and source the tl100.tcl file.

Invoke open_serial_port

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

Messages from the TL-100 are decoded into a TCL list containing information about the message.

