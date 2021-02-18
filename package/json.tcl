

proc message_to_json {message} {
	set json [yajl create #auto -beautify 0]
	$json map_open
	foreach "key value" $message {
		$json string $key

		if {$key eq "code" || $key eq "command"} {
			$json string $value
			continue
		}

		if {[string is integer $value] && [strip_leading_zeros $value] eq $value} {
			$json number $value
			continue
		}

		$json string $value
	}
	$json map_close
	set val [$json get]
	$json delete
	return  $val
}
