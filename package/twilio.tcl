#!/usr/bin/env tclsh

# twilio.tcl --
#
#   This is a short demo of how to send a SMS or a MMS message from TCL/Tk
#   with the power of the Twilio APIs (and the GUI productivity of Tk!).
#   You can use the ::twilio::send_sms{} function piecemeal for your own
#   applications.
#
#   License: MIT
#
#   Installation is platform dependent; many POSIX compliant systems have TCL
#   installed, however (try 'tcl' then <tab> completing).  On recent
#   versions of OSX, for example, you can run this with:
#
# > tclsh8.6 twilio.tcl
#
# Because we are using the ttk widets, *you'll need at least TCL 8.5.*
#
# You will need to set:
#
#   TWILIO_AUTH_TOKEN
#   TWILIO_PHONE_NUMBER
#   TWILIO_ACCOUNT_SID
#
# as environment variables.  Then, merely run and fill out the Tk form
# with a destination phone number, a message body, and an optional image URL.

package require http
package require tls
package require base64

# Put all our functions into the twilio namespace
namespace eval twilio {
    # Get environment variables
    variable phone_number $::env(TWILIO_PHONE_NUMBER)
    variable account_sid $::env(TWILIO_ACCOUNT_SID)
    variable auth_token $::env(TWILIO_AUTH_TOKEN)

    # Base URL for the Twilio Messaging API
    set url \
        "https://api.twilio.com/2010-04-01/Accounts/${account_sid}/Messages"

    # twilio::build_auth_headers --
    #
    #   Use Base64 to build a Basic Authorization header.
    #
    #   Arguments:
    #       username, password which maps to ACCOUNT_SID and AUTH_TOKEN
    #   Results:
    #       A string with the Basic Authorization header

    proc build_auth_headers {username password} {
        return "Basic [base64::encode $username:$password]"
    }

    # twilio::send_sms --
    #
    #   Sends an SMS or MMS with Twilio.
    #
    #   Arguments:
    #       to - the number to send the message to
    #       body - body text to send
	#       image_url - optional
    #   Results:
    #       false if we failed, true if Twilio returns a 2XX.  Also dumps
    #       Twilio's response to standard out.

    proc send_sms {to body {image_url ""}} {
		variable phone_number
		variable account_sid
		variable auth_token

		set from $phone_number

        ::tls::init -tls1 1 -ssl3 0 -ssl2 0
        http::register https 443 [list ::tls::socket -request 1 -require 1 -cafile ./server.pem]
        #http::register https 443 [list ::tls::socket -request 1 -require 1]


        # Escape the URL characters, optionally add media
        if {[string length $image_url] == 0} {
            set html_parameters                         \
                [::http::formatQuery                    \
                    "From"  $from                       \
                    "To"    $to                         \
                    "Body"  $body                       \
                ]
        } else {
            set html_parameters                         \
                [::http::formatQuery                    \
                    "From"      $from                   \
                    "To"        $to                     \
                    "Body"      $body                   \
                    "MediaUrl"  $image_url              \
                ]
        }

        # Make a POST request to Twilio
        set tok [                                   \
            ::http::geturl $::twilio::url           \
                -query $html_parameters             \
                -headers [list                      \
                    "Authorization"                 \
                    [                               \
                        build_auth_headers          \
                        $account_sid                \
                        $auth_token                 \
                    ]                               \
                ]                                   \
        ]

        # HTTP Response: print it to command line if we failed...
        if {[string first "20" [::http::code $tok]] != -1} {
            puts [::http::code $tok]
            puts [::http::data $tok]
            return false
        } else {
            return true
        }
    }
}

