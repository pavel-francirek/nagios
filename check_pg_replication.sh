#!/bin/bash

STATE='OK';
EXIT_STATUS=0;
EXIT_MSG='';

pg_stat=`psql -t -c "select client_addr, replay_lag from pg_stat_replication" | grep "|"`;
for host in "$@"
do
  line=`grep $host <<END
  $pg_stat
END`
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
