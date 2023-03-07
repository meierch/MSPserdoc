#!/bin/bash
#
# check tcp connections of defined port(s)
#
#PORTS="22 6787 5555"
PORTS=22

if test $# -eq 0
then
        clear
        echo ""
        echo ""
        echo "*** usage: `basename $0` PORT1 PORT2 PORTn "
        echo ""
        echo "    different ports can be defined to check"
        echo "    no port is defined use default: $PORTS"
        echo ""
        echo "sleep 5 seconds, press <ctrl> + <c> to cancel" 
        sleep 5
else
        PORTS="$*"
        # check if defined Ports are nummeric
        for PORT in $PORTS ; do
          if ! [[ "$PORT" =~ ^[0-9]+$ ]] ; then
            echo "ERROR: requested port $PORT is not a number!"
            exit 1
          fi
        done
fi

for PORT in $PORTS ; do
  echo "TCP summary for Port $PORT"
  LOGFILE=/var/tmp/port_stat_PORT_${PORT}.out
  LOGFILE_CLIENT=/var/tmp/port_client_stat_PORT_${PORT}.out

  # get netstat values
  netstat_esta=$(netstat -an | grep "\.${PORT} " | grep ESTA | wc -l)
  netstat_timew=$(netstat -an | grep "\.${PORT} " | grep TIME_ | wc -l)
  tcpListenDrop=$(netstat -s | grep tcpListenDrop | sed s/'='/:/g )
  echo "$(date): hostname: $(hostname) Port ${PORT} Established: $netstat_esta TIME_WAIT: $netstat_timew $tcpListenDrop" | tee -a $LOGFILE

  # get client statistics
  netstat -an | grep "\.${PORT} " > /tmp/check_port.connection.$PORT
  for port_client in $(grep ${PORT} /tmp/check_port.connection.$PORT | egrep "ESTA|TIME_WAIT" | awk '{print $2}' | cut -d. -f1-4 | sort -u); do
    port_client_dns=$(getent hosts $port_client | awk '{print $2}')
    if [[ -n "$port_client_dns" ]]; then
      port_client_dns_txt="(DNS: $port_client_dns)"
    else
      port_client_dns_txt="(DNS: n/a)"
    fi
    echo "$(date): hostname: $(hostname) Port ${PORT} Client $port_client $port_client_dns_txt open connections: $(grep $port_client /tmp/check_port.connection.$PORT | grep ESTA | wc -l), TIME_WAIT: $(grep $port_client /tmp/check_port.connection.$PORT | grep TIME_WAIT | wc -l)" | tee -a $LOGFILE_CLIENT
  done
  # cleanup 
  rm -f /tmp/check_port.connection.$PORT
done
