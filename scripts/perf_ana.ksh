#!/bin/ksh 
# ----------------------------------------------------------
# $Id: perf_ana.ksh,v 1.3 2012/08/21 17:17:24 christian Exp $
# ----------------------------------------------------------
# Name: perf_ana.ksh
#
# Description: this script analyse the system for performance
# issues or bottelnecks
#
# available tools ....
# iostat, vmstat, mpstat, netstat, kstat, metastat, busstat, ps, swap, df
#
#############################################################

TMPFILE="/tmp/perf_ana/perf_ana.$$"
if [ ! -d /tmp/perf_ana ]; then
    mkdir /tmp/perf_ana
    touch $TMPFILE
else
    touch $TMPFILE
fi

clear
if [[ -d /tmp/perf_ana/ ]]; then
  echo "Cleanup old temp, iousage files from /tmp/perf_ana/ older than 14 days"
  find /tmp/perf_ana/ -type f -name "perf_ana.*" -mtime +14 -print
  find /tmp/perf_ana/ -type f -name "perf_ana.*" -mtime +14 -exec rm -f {} \;
  sleep 2
fi

if [ ! -w $TMPFILE ]; then
   id=`/usr/bin/id | awk '{print $1}' | awk -F\( '{print $2}' | awk -F\) '{print $1}'`
   TMPFILENEW="/tmp/perf_ana_${id}/perf_ana.$$"
   echo "WARN: $TMPFILE not writable. Set TMPFILE to $TMPFILENEW"
   mkdir /tmp/perf_ana_${id}
   touch $TMPFILENEW
   TMPFILE=$TMPFILENEW
   echo "Cleanup old temp, iousage files from /tmp/perf_ana_${id}/ older than 14 days"
   find /tmp/perf_ana_${id}/ -type f -name "perf_ana.*" -mtime +14 -print
   find /tmp/perf_ana_${id}/ -type f -name "perf_ana.*" -mtime +14 -exec rm -f {} \;
   sleep 2
fi

TODAY=`date +"%b %e"`
HOSTNAME=`/usr/bin/hostname`
#exec 2> devnull
#trap 'print "$0 has a Problem. I hope your system is still up and running ...\n"' ERR

clear
echo

echo "collecting data (vm and io)"
echo "Collecting VMSTAT Information, please wait .... (30 sec)"
# r:b:w:sr:us:sy:id
/usr/bin/vmstat | sed '1,2d' | awk '{print "vmsum:" $1 ":" $2 ":" $3 ":" $12 ":" $20 ":" $21 ":" $22}' >> $TMPFILE
/usr/bin/vmstat 2 15 | sed '1,3d' | awk '{print "vmact:" $1 ":" $2 ":" $3 ":" $12 ":" $20 ":" $21 ":" $22}' >> $TMPFILE
echo "Collecting IOSTAT Information, please wait .... (60 sec)"
# iosum/act:device:%w:%b:s/w:h/w:trn:tot:wait:actv:wsvc_t:asvc_t
/usr/bin/iostat -xnmez | sed '1,2d' | awk '{print "iosum:" $15 ":" $9 ":" $10 ":" $11 ":" $12 ":" $13 ":" $14 ":" $5 ":" $6 ":" $7 ":" $8 ":" $1 ":" $3 ":" $2 ":" $4 }' | egrep -v "vold|:*:/" >> $TMPFILE
/usr/bin/iostat -xnmez 2 15 | sed '1,2d' | awk '{print "ioact:" $15 ":" $9 ":" $10 ":" $11 ":" $12 ":" $13 ":" $14 ":" $5 ":" $6 ":" $7 ":" $8 ":" $1 ":" $3 ":" $2 ":" $4 }' | sort -n | egrep -v "vold|:*:/" >> $TMPFILE
/usr/bin/iostat -xnpmCz | grep " c[0-9]" | grep -v ":\/" | awk '{print "iosum:" $10 ":" $9 ":" $11 ":" $12}'  >> ${TMPFILE}.iousage
/usr/bin/iostat -xnpmCz 2 15 | grep " c[0-9]" | grep -v ":\/" | awk '{print "ioact:" $10 ":" $9 ":" $11 ":" $12}'  >> ${TMPFILE}.iousage 
echo

sleep 2
clear
echo

if [ -x "/opt/MSP/serverdocu/bin/uptime.pl" ]; then
	uptime=`/opt/MSP/serverdocu/bin/uptime.pl | awk '{print $7}'`
else
	uptime=`/usr/bin/uptime | awk '{print $3}'`
fi

echo 
echo "Systeminformations:"
echo "==================="
echo
echo "Hostname: <$HOSTNAME> , IP-Address: <`/usr/bin/getent hosts $HOSTNAME | awk '{print $1}'`>"
if [ -x /opt/MSP/serverdocu/bin/memconf.pl ]; then
   /opt/MSP/serverdocu/bin/memconf.pl -v | egrep "model:|memory |bit"
fi
echo "Installed SUNW-Packages:     <`/usr/bin/pkginfo | grep SUNW | wc -l`>"
echo "Installed non SUNW-Packages: <`/usr/bin/pkginfo | grep -v SUNW | wc -l`>"
echo "Failed installed Packages:"
/usr/bin/pkginfo -p
echo "--------------------"

if [ $uptime -gt 50 ]; then
	echo "Your System is more than 50 Days up. Uptime : <$uptime> Days "
	factor=1
        echo "set uptime factor to: ${factor}"
elif [ $uptime -gt 100 ]; then
	echo "Your System is more than 100 Days up. Uptime : <$uptime> Days "
	factor=1.5
        echo "set uptime factor to: ${factor}"
elif [ $uptime -gt 200 ]; then
	echo "Your System is more than 200 Days up. Uptime : <$uptime> Days "
	factor=2
        echo "set uptime factor to: ${factor}"
elif [ $uptime -gt 300 ]; then
	echo "Your System is more than 300 Days up. Uptime : <$uptime> Days "
	factor=3
        echo "set uptime factor to: ${factor}"
elif [ $uptime -gt 400 ]; then
	echo "Your System is more than 400 Days up. Uptime : <$uptime> Days "
	factor=4
        echo "set uptime factor to: ${factor}"
else
	echo "Your Systemuptime is less than 50 days. Uptime : <$uptime> Days "
	factor=1
        echo "set uptime factor to: ${factor}"
fi

echo
echo "------------------------------------------------------------------------"
echo "Analyse Network (without lo0) :"

/usr/bin/netstat -i | egrep -v "Address|^$|lo0" | awk '{print $1 ":" $6 ":" $8 ":" $9 ":" $10 ":" $5 ":" $7}' >> $TMPFILE

tcpListenDrop=`/usr/bin/netstat -s | grep tcpListenDrop | awk -F= '{print $2}' | awk '{print $1}'`
tcpListenDropQ0=`/usr/bin/netstat -s | grep tcpListenDrop | awk -F= '{print $3}' | awk '{print $1}'`

echo "tcpListen:$tcpListenDrop:$tcpListenDropQ0" >> $TMPFILE

if [ $tcpListenDrop -gt $(( 5 * ${factor} )) ] ; then
	echo
	echo "WARN: tcpListenDrop detected, count: <$tcpListenDrop>"
	echo
	echo "The current parameter describes the maximum number of pending connection "
	echo "requests queued for a listening endpoint in the completed connection queue. "
	echo "The queue can only save the specified finite number of requests. If a queue "
	echo "overflows, nothing is sent back. The client will time out and (hopefully) retransmit."
	echo
        echo "INFO: History-Data:"
        for file in `grep -w tcpListen /tmp/perf_ana/perf_ana.* | awk -F: '{print $1}' | sort -u | tail -20`; do
           echo "File: <$file>, tcpListenDrop: <`cat $file | grep -w tcpListen | awk -F: '{ print $2}'`>"
        done
else
	echo
	echo "INFO: tcpListenDrop count: <$tcpListenDrop>"
        echo
fi

if [ $tcpListenDropQ0 -gt $(( 5 * ${factor} )) ] ; then
	echo
	echo "WARN: tcpListenDropQ0 detected, count: <$tcpListenDropQ0>"
	echo
	echo "The connections in this queue are just being instantiated. A SYN was just received "
	echo "from the client, thus the connection is in the TCP SYN_RCVD state. The connection "
	echo "cannot be accepted until the handshake is complete, even if the eager listening is active."
	echo
        echo "INFO: History-Data:"
        for file in `grep -w tcpListen /tmp/perf_ana/perf_ana.* | awk -F: '{print $1}' | sort -u | tail -20`; do
           echo "File: <$file>, tcpListenDropQ0: <`cat $file | grep -w tcpListen | awk -F: '{ print $3}'`>"
        done
else
	echo
	echo "INFO: tcpListenDropQ0 count: <$tcpListenDropQ0>"
        echo
fi

for interface in `/usr/bin/netstat -i | egrep -v "Address|^$|lo0" | awk '{print $1}'|sort -u`; do
        echo "------------------------------------------------------------------------"
        echo "Summary Interface: <$interface>"
        # set variables
        Ipkts=`cat $TMPFILE | grep -w $interface | head -1 |awk -F: '{ print $6}'`
        Opkts=`cat $TMPFILE | grep -w $interface | head -1 |awk -F: '{ print $7}'`
        Ierrs=`cat $TMPFILE | grep -w $interface | head -1 |awk -F: '{ print $2}'`
        Oerrs=`cat $TMPFILE | grep -w $interface | head -1 |awk -F: '{ print $3}'`
        Collis=`cat $TMPFILE | grep -w $interface | head -1 |awk -F: '{ print $4}'`
        Queue=`cat $TMPFILE | grep -w $interface | head -1 |awk -F: '{ print $5}'`
			

        # check collisionrate
        Crate=$(( $Opkts / 10 ))
        Cratei=$(( $Ipkts / 10 ))
        if [ $Opkts -eq 0 ]; then
          echo "INFO: Output Packages for <$interface> is Zero"
          Opkts=1
        fi
        if [ $Ipkts -eq 0 ]; then
          echo "INFO: Input Packages for <$interface> is Zero"
          Ipkts=1
        fi
	if [ $Crate -lt $Collis ]; then
		Crate_pro=$(( $Collis / $Opkts * 100 ))
		echo "WARN: Collisionrate grather than 10 % (Output-Pkts) : alert value: <$Crate>, collisions: <$Collis> ($Crate_pro %), Opkg: <$Opkts>, Ipkg: <$Ipkts>"
		echo "INFO: History-Data about the last 20 days / runs"
		# get variables for the last 20 days
		for file in `ls -ltr /tmp/perf_ana/perf_ana.* | grep -v iousage | tail -20 | awk '{print $9}'`; do
			echo "File: <$file>, collisions: <`cat $file | grep -w $interface | awk -F: '{ print $4}'`>"
		done
        elif [ $Cratei -lt $Collis ]; then
		Crate_pro=$(( $Collis / $Ipkts * 100 ))
                echo "WARN: Collisionrate grather than 10 % (Input-Pkts) : alert value: <$Crate>, collisions: <$Collis> ($Crate_pro %), Opkg: <$Opkts>, Ipkg: <$Ipkts>"
                echo "INFO: History-Data about the last 20 days / runs"
                # get variables for the last 20 days
                for file in `ls -ltr /tmp/perf_ana/perf_ana.* | grep -v iousage | tail -20 | awk '{print $9}'`; do
                        echo "File: <$file>, collisions: <`cat $file | grep -w $interface | awk -F: '{ print $4}'`>"
                done
	else
		echo "INFO: Collisionrate ok: alert value: <$Crate>(10% Opkts) / <$Cratei> (10% Ipkts), collisions: <$Collis>, Opkg: <$Opkts>, Ipkg: <$Ipkts>"
	fi

	# check outputerror rate
	Orate=$(( $Opkts / 20 ))
	if [ $Orate -lt $Oerrs ]; then
		if [ $Orate -gt 0 ]; then
			echo "WARN: Output error rate grather than 5 % : alert value: <$Orate>, Output error: <$Oerrs>, Opkg: <$Opkts> "
			echo "INFO: History-Data about the last 20 days / runs"
			# get variables for the last 20 days
			for file in `ls -ltr /tmp/perf_ana/perf_ana.* | grep -v iousage | tail -20 | awk '{print $9}'`; do
				echo "File: <$file>, package out error: <`cat $file | grep -w $interface | awk -F: '{ print $3}'`>"
			done
		fi
	else
		echo "INFO: Output error rate ok: alert value: <$Orate>(5%), Output error: <$Oerrs>, Opkg: <$Opkts>"
	fi

	# check inputerror rate
	Irate=$(( $Ipkts / 20 ))
	if [ $Irate -lt $Ierrs ]; then
		if [ $Irate -gt 0 ]; then
			echo "WARN: Input error rate grather than 5 % : alert value: <$Irate>, Input error: <$Ierrs>, Ipkg: <$Ipkts>"
			echo "INFO: History-Data about the last 20 days / runs"
			# get variables for the last 20 days
			for file in `ls -ltr /tmp/perf_ana/perf_ana.* | grep -v iousage | tail -20 | awk '{print $9}'`; do
				echo "File: <$file>, package in error: <`cat $file | grep -w $interface | awk -F: '{ print $2}'`>"
			done
		fi
	else
		echo "INFO: Input error rate ok: alert value: <$Irate>(5%), Input error: <$Ierrs>, Ipkg: <$Ipkts>"
	fi
	echo "------------------------------------------------------------------------"
done
# check for link down messages
COUNTOFF=`/usr/sbin/dmesg | grep "$TODAY" | egrep -i " ce| qfe| hme| eri| dfe| bge| rtls| iprb| e1000| pcn" | grep -i "link down" | wc -l`
COUNTON=`/usr/sbin/dmesg | grep "$TODAY" | egrep -i " ce| qfe| hme| eri| dfe| bge| rtls| iprb| e1000| pcn" | grep -i "link up" | wc -l`
if [ ${COUNTOFF} -gt ${COUNTON} ]; then
	echo "WARN: Network-Link down-Messages detected, we have <${COUNTOFF}> DOWN and <${COUNTON}> UP events, please check as soon as possible"
fi
if [ ${COUNTOFF} != 0 ]; then
	if [ ${COUNTOFF} -eq ${COUNTON} ]; then
		echo "INFO: Network-Link Messages detected. All Interfaces should be up, we had <${COUNTOFF}> down/up messages, please check as soon as possible"
	fi
fi

# check for IP warnings
COUNT=`/usr/sbin/dmesg | grep "$TODAY" | grep -i "WARNING: IP: Hardware address" | wc -l`
if [ ${COUNT} != 0 ]; then
   echo 
   if [ ${COUNT} -lt 3 ]; then
      echo "WARN: IP Warnings (< 3 ), count today=<${COUNT}>, please check as soon as possible"
      echo "------------------------------------------------------------------------"
      /usr/sbin/dmesg | grep "$TODAY" | grep -i "WARNING: IP: Hardware address"
      echo "------------------------------------------------------------------------"
   elif [ ${COUNT} -lt 7 ]; then
      echo "WARN: IP Warnings (< 7 ), count today=<${COUNT}>, please check as soon as possible"
      echo "------------------------------------------------------------------------"
      /usr/sbin/dmesg | grep "$TODAY" | grep -i "WARNING: IP: Hardware address"
      echo "------------------------------------------------------------------------"
   elif [ ${COUNT} -lt 10 ]; then
      echo "WARN: IP Warnings (< 10 ), count today=<${COUNT}>, please check as soon as possible"
      echo "------------------------------------------------------------------------"
      /usr/sbin/dmesg | grep "$TODAY" | grep -i "WARNING: IP: Hardware address"
      echo "------------------------------------------------------------------------"
   elif [ ${COUNT} -gt 10 ]; then
      echo "WARN: IP Warnings (> 10, hacking/misconfiguration !!?? ), count today=<${COUNT}>, please check as soon as possible"
      echo "------------------------------------------------------------------------"
      /usr/sbin/dmesg | grep "$TODAY" | grep -i "WARNING: IP: Hardware address"
      echo "------------------------------------------------------------------------"
   fi
fi



echo
echo "------------------------------------------------------------------------"
echo "Analyse Swap :"
swapb=0
swapf=0
for swapdevice in $(/usr/sbin/swap -l | grep "^/" | awk '{print $1}'); do
   swap_usage=$(/usr/sbin/swap -l | grep "^$swapdevice " | awk '{print $4 ":" $5 }')
   swapb=$(( $swapb + `echo $swap_usage | awk -F: '{print $1}'` ))
   swapf=$(( $swapf + `echo $swap_usage | awk -F: '{print $2}'` ))
done

swaprate=$(( $swapb / 5 ))
if [ $swaprate -ge $swapf ]; then
   echo "WARN: Swap shortage less than 20 % free (Output in 512kb blocks): "
   echo "WARN: Alert value: <$swaprate> swap free <$swapf>"
   echo "WARN: Alert value: <$(echo "scale=2; $swaprate/2048" | bc)MB> swap free <$(echo "scale=2; $swapf/2048" | bc)MB>"
   echo "WARN: Alert value: <$(echo "scale=2; $swaprate/2048/1024" | bc)GB> swap free <$(echo "scale=2; $swapf/2048/1024" | bc)GB>"
else
   echo "INFO: Swap is ok: alert value: <$swaprate> (20%) swap free $swapf of $swapb"
   echo "INFO: Swap is ok: alert value: <$(echo "scale=2; $swaprate/2048" | bc)MB> (20%) swap free $(echo "scale=2; $swapf/2048" | bc)MB of $(echo "scale=2; $swapb/2048" | bc)MB"
   echo "INFO: Swap is ok: alert value: <$(echo "scale=2; $swaprate/2048/1024" | bc)GB> (20%) swap free $(echo "scale=2; $swapf/2048/1024" | bc)GB of $(echo "scale=2; $swapb/2048/1024" | bc)GB"
fi

echo
COUNT=`/usr/sbin/dmesg | grep "$TODAY" | grep -i "no swap space" | wc -l`
if [ ${COUNT} != 0 ]; then
   echo "WARN: Swapspace Warning(s), count today=<${COUNT}>"
   echo "Errormessages with Linenumber from /var/adm/messages:"
   grep -ni "no swap space" /var/adm/messages
fi
if [ -f /opt/MSP/serverdocu/bin/swapf.pl ] ; then
   echo "Information from </opt/MSP/serverdocu/bin/swapf.pl>"
   echo "-------------------------------------------------------"
   /opt/MSP/serverdocu/bin/swapf.pl
   echo "-------------------------------------------------------"
fi
echo "Information from swap-command"
echo "-------------------------------------------------------"
/usr/sbin/swap -l
echo
COUNT=`/usr/sbin/dmesg | grep "$TODAY" | grep -i "no swap space" | wc -l`
if [ ${COUNT} != 0 ]; then
	echo "WARN: No swapspace Warning, count today=<${COUNT}>, please check"
	echo "Errormessages with Linenumber from /var/adm/messages:"
	grep -ni "no swap space" /var/adm/messages
	echo
fi
COUNT=`/usr/sbin/dmesg | grep "$TODAY" | grep -i "out of memory" | wc -l`
if [ ${COUNT} != 0 ]; then
	echo "WARN: No memory Error (FATAL), count today=<${COUNT}>, please check"
	echo "Errormessages with Linenumber from /var/adm/messages:"
	grep -ni "out of memory" /var/adm/messages
	echo
fi
echo "------------------------------------------------------------------------"


echo
echo "------------------------------------------------------------------------"
echo "Analyse VMSTAT :"

echo
echo "VMSTAT Summary:"
procrs=`cat $TMPFILE | grep -w vmsum | awk -F: '{print $2}'`
procbs=`cat $TMPFILE | grep -w vmsum | awk -F: '{print $3}'`
procws=`cat $TMPFILE | grep -w vmsum | awk -F: '{print $4}'`

if [ $procrs -gt 10 -o $procbs -gt 10 -o $procws -gt 10 ]; then
	echo
	echo "Since boot ($uptime days) we have the following process summary:"
	echo "in run queue : <$procrs>"
	echo "blocked for resources I/O, paging, and so forth: <$procbs>"
	echo "swapped : <$procws>"
	echo
else
	echo
	echo "Nothing special detected"
fi
echo "------------------------------------------------------------------------"
echo
# checking scanrate
SCCOUNT=`cat $TMPFILE | grep -w vmact | awk -F: '{ print $5}' | grep -v "^0$" | wc -l`
if [ $SCCOUNT -gt 0 ]; then
	echo
	echo "We had <$SCCOUNT> Scanrateactivity with value grather 0"
	for SCR in `cat $TMPFILE | grep -w vmact | awk -F: '{ print $5}'`; do
		if [ $SCR -gt 0 ]; then
			if [ $SCR -gt 150 ]; then
				echo "WARN: Detected Scanrate over 150. Value <$SCR>"
			else
				echo "WARN: Detected Scanrate over 0 and below 150. Value: <$SCR>"
			fi
		fi
	done
fi

procrun=`cat $TMPFILE | grep -w vmact | awk -F: '{ print $2}' | grep -v "^0$" | wc -l`
procblo=`cat $TMPFILE | grep -w vmact | awk -F: '{ print $3}' | grep -v "^0$" | wc -l`
procswa=`cat $TMPFILE | grep -w vmact | awk -F: '{ print $4}' | grep -v "^0$" | wc -l`

if [ $procrun -gt 5 -o $procblo -gt 5 -o $procswa -gt 5 ]; then
	echo
	echo "There seams to be load on the system, analyse it ..."
	echo
	echo "Kernel-Threads Statistics:"
	echo " r the number of kernel threads in run queue"
	echo
	echo " b the number of blocked kernel threads that are"
	echo " waiting for resources I/O, paging, and so forth"
	echo
	echo " w the number of swapped out lightweight processes (LWPs)"
	echo " that are waiting for processing resources to finish"
	echo
	echo "CPU Statistics:"
	echo " usr user time"
	echo " sys system time"
	echo " idl idle time"
	echo
	echo "Summary Processes in Runqueue: "
	echo "------------------------------------------------------------------------"
	echo "r    b    w    usr  sys  idl"
	cat $TMPFILE | grep -w vmact | awk -F: '{ printf "%-4d %-4d %-4d %-3d %-3d %-3d\n", $2,$3,$4,$6,$7,$8}'
	echo "------------------------------------------------------------------------"
	echo
fi

echo "------------------------------------------------------------------------"
echo

echo
echo "------------------------------------------------------------------------"
echo "Analyse semaphores, shared memory and message queue:"
ipcs_sm=`/usr/bin/ipcs -ma | wc -l | awk '{print $1}'`
ipcs_se=`/usr/bin/ipcs -sa | wc -l | awk '{print $1}'`
ipcs_mq=`/usr/bin/ipcs -qa | wc -l | awk '{print $1}'`

if [ $ipcs_sm -gt 3 ]; then
  ipcs_sm=$(( $ipcs_sm -3 ))
  echo "There are <$ipcs_sm> shared Memory Segments in use"
else
  echo "No Shared Memory in use."
fi

if [ $ipcs_se -gt 3 ]; then
  ipcs_se=$(( $ipcs_se -3 ))
  echo "There are <$ipcs_se> Semaphores in use"
else
  echo "No Semaphores in use"
fi

if [ $ipcs_mq -gt 3 ]; then
  ipcs_mq=$(( $ipcs_mq -3 ))
  echo "There are <$ipcs_mq> Message Queues in use"
else
  echo "No Message Queues"
fi

echo
echo "------------------------------------------------------------------------"
echo "Analyse Processes :"

ps -efl -o pid,pcpu,pmem,vsz,rss,time,user,s,args | sed '1d' | sort -n | nawk 'BEGIN { OFS="|" } {print "procinfo|" $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13}' >> $TMPFILE
topproc=`cat $TMPFILE | grep -w procinfo | awk -F\| '{print $3,$2}' | sort -nr | sed '16,$d' | awk '{print $2}'`
topmem=`cat $TMPFILE | grep -w procinfo | awk -F\| '{print $4,$2}' | sort -nr | sed '16,$d' | awk '{print $2}'`

echo "Legend: "
echo "State: O Process is running on a processor."
echo " S Sleeping: process is waiting for an event to complete."
echo " R Runnable: process is on run queue."
echo " Z Zombie state: process terminated and parent not waiting."
echo " T Process is stopped, either by a job control signal or because it is being traced."
echo


echo "the following pid's are in the top 15 (CPU USage)"
echo "PID      %CPU   %MEM  VSZ       RSS      TIME   USER      State  COMMAND"
for ps in $topproc; do
	grep -w procinfo $TMPFILE | grep "|$ps|" | awk -F\| '{printf "%-8d %-6s %-6s %-9d %-9d %-6s %-9s %-6s %-25s\n", $2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13}'
done

echo
echo "the following pid's are in the top 15 (Memory USage)"
echo "PID      %CPU   %MEM  VSZ      RSS       TIME   USER      State   COMMAND"
for ps in $topmem; do
	grep -w procinfo $TMPFILE | grep "|$ps|" | awk -F\| '{printf "%-8d %-6s %-6s %-9d %-9d %-6s %-9s %-6s %-25s\n", $2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13}'
done

echo
echo "------------------------------------------------------------------------"
echo "Analyse DISKSPACE :"

df -hl | egrep -v "/proc|mnttab|fd" | sed '1d' | sed  -e 's/:/,/' | awk '{print "fsmon:" $1 ":" $2 ":" $3 ":" $4 ":" $5 ":" $6}'  >> $TMPFILE

echo
echo "Filesystemusage:"

for filesystem in `cat $TMPFILE | grep -w fsmon | awk -F: '{print $7}'`; do
	usage=`cat $TMPFILE | grep ":$filesystem$" | awk -F: '{print $6}' | awk -F% '{print $1}'`
        space=`cat $TMPFILE | grep ":$filesystem$" | awk -F: '{print $5}'`
	if [ $usage -gt 80 -a $usage -le 90 ]; then
		echo "WARN: Filesystem: <$filesystem> is over 80% used. Usage: <$usage>%, Freespace: <$space>"
	elif [ $usage -gt 90 ]; then
		echo "CRITICAL WARN: Filesystem: <$filesystem> is over 90% used. Usage: <$usage>%, Freespace: <$space>"
	else
                if [ $usage -eq 80 ]; then
                   echo "WARN: Filesystem: <$filesystem> is 80% used. Usage: <$usage>%, Freespace: <$space>"
                else
		   echo "INFO: Filesystem: <$filesystem> ok. Usage below 80% <$usage>% used, Freespace: <$space>"
                fi
	fi
done

echo
COUNT=`/usr/sbin/dmesg | grep "$TODAY" | grep -i "File system full" | wc -l`
if [ ${COUNT} != 0 ]; then
	echo "CRITICAL WARN: Filesystem full Warning(s), count today=<${COUNT}>"
	echo "Errormessages with Linenumber from /var/adm/messages:"
	grep -ni "File system full" /var/adm/messages
fi

echo
echo "------------------------------------------------------------------------"
echo "Analyse IOSTAT :"

# check for :c*
ccount=`cat $TMPFILE | grep -w iosum | egrep ":c" | wc -l`
ssdcount=`cat $TMPFILE | grep -w iosum | egrep ":ssd" | wc -l`
sdcount=`cat $TMPFILE | grep -w iosum | egrep ":sd" | wc -l`
mdcount=`cat $TMPFILE | grep -w iosum | egrep ":md" | wc -l`

if [ -x /usr/bin/zonename ]; then
	if [ `/usr/bin/zonename` = "global" ]; then
		if [ ${ccount} -gt 0 ]; then
			echo "found c*-Disks <${ccount}>,  analyze them"
			grepdisk=":c"
		elif [ ${ssdcount} -gt 0 ]; then
			echo "found ssd*-Disks <${ssdcount}>, analyze them"
			grepdisk=":ssd"
		elif [ ${sdcount} -gt 0 ]; then
                        echo "found sd*-Disks <${sdcount}>, analyze them"
                        grepdisk=":sd"
		elif [ ${mdcount} -gt 0 ]; then
			echo "found md*-Devices <${mdcount}> in zone, analyze them"
			grepdisk=":md"
		fi
	else 
		if [ ${ccount} -gt 0 ]; then
			echo "found c*-Disks <${ccount}> in zone,  analyze them"
			grepdisk=":c"
		elif [ ${ssdcount} -gt 0 ]; then
			echo "found ssd*-Disks <${ssdcount}> in zone, analyze them"
			grepdisk=":ssd"
		elif [ ${sdcount} -gt 0 ]; then
                        echo "found sd*-Disks <${sdcount}>, analyze them"
                        grepdisk=":sd"
		elif [ ${mdcount} -gt 0 ]; then
			echo "found md*-Devices <${mdcount}> in zone, analyze them"
			grepdisk=":md"
		fi
	fi
else
        if [ ${ccount} -gt 0 ]; then
             echo "found c*-Disks <${ccount}>,  analyze them"
             grepdisk=":c"
         elif [ ${ssdcount} -gt 0 ]; then
             echo "found ssd*-Disks <${ssdcount}>, analyze them"
             grepdisk=":ssd"
	 elif [ ${sdcount} -gt 0 ]; then
             echo "found sd*-Disks <${sdcount}>, analyze them"
             grepdisk=":sd"
         elif [ ${mdcount} -gt 0 ]; then
            echo "found md*-Devices <${mdcount}> in zone, analyze them"
            grepdisk=":md"
         fi
fi

# Check IOSTAT Summary for controller Usage
if [[ -s ${TMPFILE}.iousage ]]; then
	echo
	echo "Display only Controller with a usage not equal to 0"
	echo "Checking Usage of controller since boot:"
	for ious in `cat ${TMPFILE}.iousage | grep -w iosum | awk -F: '{print $2,$3,$4}' | grep -v "^0" |  sort -nr | head -10 | grep -v "t" | awk '{print $3}'`; do
		echo "------------------------------------------------------------------------------------"
		echo "Usage ${ious} summary:"
		grep -w ${ious} ${TMPFILE}.iousage | grep -w iosum | awk -F: '{print "%b: " $2 "% ,%w: " $3 "% ,Controller: " $4 }' 
        	echo "------------------------------------------------------------------------------------"
	done

	echo "Checking Usage of controller now:"
	for ious in `cat ${TMPFILE}.iousage | grep -w ioact | awk -F: '{print $2,$3,$4}' | grep -v "^0" |  sort -nr | head -10 | awk '{print $3}' | sort -u | grep -v "t"`; do
        	echo "------------------------------------------------------------------------------------"
        	echo "Usage ${ious} actual:"
        	grep -w ${ious} ${TMPFILE}.iousage | grep -w ioact | awk -F: '{print "%b: " $2 "% ,%w: " $3 "% ,Controller: " $4 }'
        	echo "------------------------------------------------------------------------------------"
	done
	echo
fi
        
# Check IOSTAT Summary for wait and busy
for disk in `cat $TMPFILE | grep -w iosum | egrep "${grepdisk}" | awk -F: '{print $2}' | sort -u`; do
	diskw=`cat $TMPFILE | grep -w iosum | grep -w $disk | awk -F: '{print $3}'`
	diskb=`cat $TMPFILE | grep -w iosum | grep -w $disk | awk -F: '{print $4}'`
	if [ ${diskb} -gt 60 -o ${diskw} -gt 40 ]; then
		echo "CRITICAL WARN: Disksummary <$disk> shows load, % trans. waiting: <$diskw %> , % of time disk busy <$diskb %>"
        elif [ ${diskb} -gt 30 -o ${diskw} -gt 20 ]; then
                echo "WARN: Disksummary <$disk> shows load, % trans. waiting: <$diskw %> , % of time disk busy <$diskb %>"
	fi
done

for disk in `cat $TMPFILE | grep -w iosum | egrep "${grepdisk}" | awk -F: '{print $2}' | sort -u`; do
   wait=`cat $TMPFILE | grep -w iosum | grep -w $disk | awk -F: '{print $9}'`
   actv=`cat $TMPFILE | grep -w iosum | grep -w $disk | awk -F: '{print $10}'`
   wait=`echo $wait | awk -F. '{print $1}'`
   actv=`echo $actv | awk -F. '{print $1}'`
   if [ ${wait} -gt 30 -o ${actv} -gt 30 ]; then
      echo "INFO: wait => average number of transactions waiting for service (queue length)"
      echo "              This is the number of I/O operations held in the device driver queue"
      echo "INFO: actv => This is the number of I/O operations accepted, but not yet serviced, by the device"
      echo "WARN: Disksummary <$disk> shows wait greater than 30, wait: <$wait> , actv <$actv>"
   elif [ ${wait} -gt 20 -o ${actv} -gt 20 ]; then
      echo "INFO: wait => average number of transactions waiting for service (queue length)"
      echo "              This is the number of I/O operations held in the device driver queue"
      echo "INFO: actv => This is the number of I/O operations accepted, but not yet serviced, by the device"
      echo "WARN: Disksummary <$disk> shows wait greater than 20, wait: <$wait> , actv <$actv>"
   elif [ ${wait} -gt 10 -o ${actv} -gt 10 ]; then
      echo "INFO: wait => average number of transactions waiting for service (queue length)"
      echo "              This is the number of I/O operations held in the device driver queue"
      echo "INFO: actv => This is the number of I/O operations accepted, but not yet serviced, by the device"
      echo "WARN: Disksummary <$disk> shows wait greater than 10, wait: <$wait> , actv <$actv>"
   fi
done

# Check IOSTAT Summary for Service time
for disk in `cat $TMPFILE | grep -w iosum | egrep "${grepdisk}" | awk -F: '{print $2}' | sort -u`; do
   wsvc_t=`cat $TMPFILE | grep -w iosum | grep -w $disk | awk -F: '{print $11}'`
   asvc_t=`cat $TMPFILE | grep -w iosum | grep -w $disk | awk -F: '{print $12}'`
   wsvc_t=`echo $wsvc_t | awk -F. '{print $1}'`
   asvc_t=`echo $asvc_t | awk -F. '{print $1}'`
   if [ "${wsvc_t}" -gt 30 -o "${asvc_t}" -gt 30 ]; then
      echo "INFO: wsvc_t => average service time in wait queue in milliseconds"
      echo "INFO: asvc_t => average service time of active transactions in milliseconds"
      echo "WARN: Disksummary <$disk> shows service time greater than 30 ms, wsvc_t: <$wsvc_t ms> , asvc_t <$asvc_t ms>"
   elif [ "${wsvc_t}" -gt 15 -o "${asvc_t}" -gt 15 ]; then
      echo "INFO: wsvc_t => average service time in wait queue in milliseconds"
      echo "INFO: asvc_t => average service time of active transactions in milliseconds"
      echo "WARN: Disksummary <$disk> shows service time greater than 15 ms, wsvc_t: <$wsvc_t ms> , asvc_t <$asvc_t ms>"
   fi
done

# Check IOSTAT Summary for errors
for disk in `cat $TMPFILE | grep -w iosum | egrep "${grepdisk}" | awk -F: '{print $2}' | sort -u`; do
   se=`cat $TMPFILE | grep -w iosum | grep -w $disk | awk -F: '{print $5}'`
   he=`cat $TMPFILE | grep -w iosum | grep -w $disk | awk -F: '{print $6}'`
   te=`cat $TMPFILE | grep -w iosum | grep -w $disk | awk -F: '{print $7}'`
   tote=`cat $TMPFILE | grep -w iosum | grep -w $disk | awk -F: '{print $8}'`
   if [ ${se} -gt 10 -o ${he} -gt 5 -o ${te} -gt 15 -o ${tote} -gt 30 ]; then
      echo "WARN: Disksummary <$disk> shows Errors: Total: <${tote}>, SoftE: <${se}>, HardE: <${he}>, TranspE: <${te}>"
   fi
done

diskwflag=0
diskbflag=0
# Check IOSTAT actual
for disk in `cat $TMPFILE | grep -w ioact | egrep "${grepdisk}" | awk -F: '{print $2}' | sort -u`; do
   # iostat io queue
   wait=`cat $TMPFILE | grep -w ioact | grep -w $disk | awk -F: '{print $9}'`
   actv=`cat $TMPFILE | grep -w ioact | grep -w $disk | awk -F: '{print $10}'`
   wait=`echo $wait | awk -F. '{print $1}'`
   actv=`echo $actv | awk -F. '{print $1}'`
   if [ ${wait} -gt 15 -o ${actv} -gt 15 ]; then
      echo "INFO: wait => average number of transactions waiting for service (queue length)"
      echo "              This is the number of I/O operations held in the device driver queue"
      echo "INFO: actv => This is the number of I/O operations accepted, but not yet serviced, by the device"
      echo "WARN: Disk <$disk> shows wait greater than 15, wait: <$wait> , actv <$actv> now"
   elif [ ${wait} -gt 5 -o ${actv} -gt 5 ]; then
      echo "INFO: wait => average number of transactions waiting for service (queue length)"
      echo "              This is the number of I/O operations held in the device driver queue"
      echo "INFO: actv => This is the number of I/O operations accepted, but not yet serviced, by the device"
      echo "WARN: Disk <$disk> shows wait greater than 5, wait: <$wait> , actv <$actv> now"
   fi

   #iostat % busy and wait
   for diskw in `cat $TMPFILE | grep -w ioact | grep -w $disk | awk -F: '{print $3}'`; do
      if [ ${diskw} -gt 60 ]; then
         diskwflag=1
      fi
   done
   for diskb in `cat $TMPFILE | grep -w ioact | grep -w $disk | awk -F: '{print $4}'`; do
      if [ ${diskb} -gt 70 ]; then
         diskbflag=1
      fi
   done
   if [ ${diskwflag} != 0 ]; then
      echo "WARN: Disk <$disk> shows load (wait) now"
      cat $TMPFILE | grep -w ioact | grep -w $disk | awk -F: '{print $2 ": %w :" $3 ", %b :" $4}'
      echo "------------------------------------------------------------------------"
   fi
   if [ ${diskbflag} != 0 ]; then
      echo "WARN: Disk <$disk> shows load (busy) now"
      cat $TMPFILE | grep -w ioact | grep -w $disk | awk -F: '{print $2 ": %w :" $3 ", %b :" $4}'
      echo "------------------------------------------------------------------------"
   fi
   diskwflag=0
   diskbflag=0

   # iostat service time
   wsvc_t=`cat $TMPFILE | grep -w ioact | grep -w $disk | awk -F: '{print $11}'`
   asvc_t=`cat $TMPFILE | grep -w ioact | grep -w $disk | awk -F: '{print $12}'`
   wsvc_t=`echo $wsvc_t | awk -F. '{print $1}'`
   asvc_t=`echo $asvc_t | awk -F. '{print $1}'`
   krs=`cat $TMPFILE | grep -w ioact | grep -w $disk | awk -F: '{print $14}' | sort -nr | head -1 | awk -F. '{print $1}'`
   rs=`cat $TMPFILE | grep -w ioact | grep -w $disk | grep $krs | awk -F: '{print $13}' | sort -nr | head -1 | awk -F. '{print $1}'`
   kws=`cat $TMPFILE | grep -w ioact | grep -w $disk | awk -F: '{print $16}' | sort -nr | head -1 | awk -F. '{print $1}'`
   ws=`cat $TMPFILE | grep -w ioact | grep -w $disk | grep $kws | awk -F: '{print $15}' | sort -nr | head -1 | awk -F. '{print $1}'`
   if [ "${krs}" -gt 0 -a "${rs}" -gt 0 ]; then
      kr=$(( ${krs} / ${rs} ))
   else
      kr="not calculated"
   fi
   if [ "${kws}" -gt 0 -a "${ws}" -gt 0 ]; then
      kw=$(( ${kws} / ${ws} ))
   else
      kw="not calculated"
   fi

   if [ "${wsvc_t}" -gt 150 -o "${asvc_t}" -gt 150 ]; then
      echo "INFO: wsvc_t => average service time in wait queue in milliseconds"
      echo "INFO: asvc_t => average service time of active transactions in milliseconds"
      echo "WARN: Disk <$disk> shows service time greater than 150 ms now (poor service time !!), wsvc_t: <$wsvc_t ms> , asvc_t <$asvc_t ms>"
   elif [ "${wsvc_t}" -gt 100 -o "${asvc_t}" -gt 100 ]; then
      echo "INFO: wsvc_t => average service time in wait queue in milliseconds"
      echo "INFO: asvc_t => average service time of active transactions in milliseconds"
      echo "WARN: Disk <$disk> shows service time greater than 100 ms now (red alert), wsvc_t: <$wsvc_t ms> , asvc_t <$asvc_t ms>"
   elif [ "${wsvc_t}" -gt 50 -o "${asvc_t}" -gt 50 ]; then
      echo "INFO: wsvc_t => average service time in wait queue in milliseconds"
      echo "INFO: asvc_t => average service time of active transactions in milliseconds"
      echo "WARN: Disk <$disk> shows service time greater than 50 ms now (yellow alert), wsvc_t: <$wsvc_t ms> , asvc_t <$asvc_t ms>"
   fi

   # IOSTAT DISK Statistics (actual)
   echo
   echo "------------------------------------------------------------------------"
   echo "Actual statistics from disk <$disk>"
   echo "Utilisation           : <${diskw} %> wait , <${diskb} %> busy"
   echo "Controller Servicetime: <$wsvc_t> , Disksubsystem Servicetime: <$asvc_t>"
   echo "Throughput READ       : kb(read)/s ($krs) / #r/s ($rs) = $kr kb per IOP"
   echo "Throughput WRITE      : kb(write)/s ($kws) / #w/s ($ws) = $kw kb per IOP"
   echo "------------------------------------------------------------------------"
done


# Check IOSTAT actual for errors
for disk in `cat $TMPFILE | grep -w ioact | egrep "${grepdisk}" | awk -F: '{print $2}' | sort -u`; do
   se=`cat $TMPFILE | grep -w ioact | grep -w $disk | awk -F: '{print $5}' | sort -n | tail -1`
   he=`cat $TMPFILE | grep -w ioact | grep -w $disk | awk -F: '{print $6}' | sort -n | tail -1`
   te=`cat $TMPFILE | grep -w ioact | grep -w $disk | awk -F: '{print $7}' | sort -n | tail -1`
   tote=`cat $TMPFILE | grep -w ioact | grep -w $disk | awk -F: '{print $8}' | sort -n | tail -1`
   if [ ${se} -gt 2 -o ${he} -gt 0 -o ${te} -gt 3 -o ${tote} -gt 5 ]; then
      echo "WARN: Disk <$disk> shows Errors: Total: <${tote}>, SoftE: <${se}>, HardE: <${he}>, TranspE: <${te}>"
   fi
done

echo "The TMPFILE with the processed values : ${TMPFILE} , ${TMPFILE}.iousage"
exit 0
