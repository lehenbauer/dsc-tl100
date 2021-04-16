

drop table if exists zone_status;

create table zone_status (
	zone integer primary key,
	state varchar,
	last_closed integer,
	last_opened integer,
	first_seen integer
);

create table message_log (
	clock integer,
	sequence integer,
	message varchar,
	primary key(clock, sequence)
);

