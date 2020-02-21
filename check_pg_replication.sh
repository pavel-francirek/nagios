#!/bin/bash
# copyright (c) 2020 Pavel Francirek

STATE='OK';
EXIT_STATUS=0;
EXIT_MSG='';

PROGNAME=`basename $0`

# set defaults
pg_host="localhost"
pg_user="icinga"
pg_pass="icinga"

print_help() {
    echo "Usage: $PROGNAME [options]"
    echo "  e.g. $PROGNAME -H localhost -u icinga -p secret -s 10.0.0.2,192.168.1.2"
    echo
    echo "Options:"
    echo -e "\t --help | -h          print help"
    echo -e "\t --host | -H [value]  master host"
    echo -e "\t --user | -u [value]  user"
    echo -e "\t --pass | -p [value]  password"
    echo -e "\t -s [slaves]          slaves' ips, comma-separated"

    echo
    echo "Requires: awk, psql client"
    echo "SQL: CREATE ROLE icinga SUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT LOGIN NOREPLICATION NOBYPASSRLS CONNECTION LIMIT 1 PASSWORD 'secret'"
    echo "note: must be SUPERUSER for Postgres < 12"
    echo
}

# put the multiple items given at the prompt to an array
form_slave_array() {
    IFS_bak="$IFS"	
    IFS=","

    local slave

    for slave in ${1}; do

        slaves[${#slaves[@]}]="$slave";
    done

    IFS="$IFS_bak"
}

main () {
    pg_stat=`PGPASSWORD=$pg_pass psql -h $pg_host -U $pg_user -t -c "select client_addr, replay_lag from pg_stat_replication" template1 | grep "|"`;
    for id in $(seq 1 1 ${#slaves[@]});
    do
    host=${slaves[$id-1]};
    line=`grep $host <<END
    $pg_stat
END
    `
    flush_lag_sec=0;
    if [ -z "$line" ]
    then
        STATE='CRITICAL';
        EXIT_MSG+=", no host '$host' found";
        EXIT_STATUS=2;
    else
        [[ $line =~ (.*)\|[[:blank:]]*(.*) ]] &&
        flush_lag="${BASH_REMATCH[2]}";
        flush_lag_sec=$(echo $flush_lag | awk -F: '{ print ($1 * 3600) + ($2 * 60) + int($3) }');
        if [ $flush_lag_sec -gt 60 ]
        then
            if [ $EXIT_STATUS -lt 2 ]
            then
            STATE='WARNING';
            EXIT_STATUS=1;
            fi
        elif [ $flush_lag_sec -gt 600 ]
        then
            STATE='CRITICAL';
            EXIT_STATUS=2;
        fi
        EXIT_MSG+=", host '$host' replication lag $flush_lag_sec sec";
    fi
    #  [[ $line =~ (.*)\|[[:blank:]]*([0-9]{2}):([0-9]{2}):([0-9]{2})(.*) ]] &&
    done;
    echo "$STATE - $EXIT_MSG";
    exit $EXIT_STATUS;
}

# parse cmd arguments
if [ "$#" -gt 0 ]; then
        while [ "$#" -gt 0 ]; do
	case "$1" in
	    '--help'|'-h')
		print_help
		exit 3
		;;
	    '-s')
		form_slave_array "$2"
		# slaves are now in $slaves[]
		shift 2
		;;
	    '-H')
		pg_host="$2"
		shift 2
		;;
	    '-u')
		pg_user="$2"
		shift 2
		;;
	    '-p')
		pg_pass="$2"
        shift 2
		;;
	    *)
		echo "Unknown option!"
		print_help
		exit 3
		;;
	esac
    done
fi


# call the main function
main
