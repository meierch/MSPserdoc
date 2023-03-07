#!/usr/bin/ksh
#set -x
# ---------------------------------------------------------------------------
# $Id: check_change.ksh,v 1.12 2013/06/07 12:07:30 christian Exp $
# ---------------------------------------------------------------------------
# Name:         check_change.ksh
#
# Description:  this script checks system after a change 
#
# Parameters:   none
#
# Exit:         exit 0          =>      no error
#               exit 10         =>      not Super User root
#
#############################################################################

if test $# -ne 1
then
        clear
        echo ""
        echo ""
        echo "*** usage: `basename $0` { pre | post | clean } "
        echo ""
        echo ""
        exit 1
fi

if [[ -x "/usr/xpg4/bin/id" ]]; then
  ID_BIN="/usr/xpg4/bin/id"
elif [[ -x "/usr/ccs/bin/id" ]]; then
  ID_BIN="/usr/ccs/bin/id"
elif [[ -x "/usr/gnu/bin/id" ]]; then
  ID_BIN="/usr/gnu/bin/id"
else
  clear
  echo ""
  echo ""
  echo "Error could not find id Binary in:"
  echo "/usr/xpg4/bin"
  echo "/usr/ccs/bin"
  echo "/usr/gnu/bin"
  echo ""
  echo "Exiting .."
  exit 5
fi

if [ "$($ID_BIN -un)" != "root" ]; then
  clear
  echo ""
  echo ""
  echo "You're using this Script without root-priviledge !"
  echo "The Script will not be able to check File-Checksums"
  echo ""
  echo "Exiting ..."
  exit 10
fi


HOSTNAME=`/usr/bin/hostname`
TIMESTAMP=`date '+%d%m%y_%H%M'`
TODAY=`date +"%b %e"`
MNT=`date +"%b"`
DAY=`date +"%d"`
OSR=`uname -r`

DATADIR="/var/adm/check_change"
TMPFILE="/tmp/check_change.$$"

# Put here all file you need to check for cksum
CS_FILES="/etc/nodename /etc/hostname.* /etc/motd /etc/krb5.conf /etc/krb5/krb5.conf /etc/pam.conf /etc/services /etc/syslog.conf /etc/default/* /etc/inittab /etc/name_to_major /etc/name_to_sysnum /etc/vfstab /etc/system /etc/inet/hosts /etc/inet/ntp.conf /etc/sudoers /etc//etc/sudoers.d/* /usr/local/etc/sudoers /usr/local/etc/ssh_config /etc/ssh/ssh_config /usr/local/etc/sshd_config /etc/ssh/sshd_config /etc/ethers /usr/bin/dsm.* "
CS_FILES="${CS_FILES} /etc/driver_aliases /etc/driver_classes /etc/logadm.conf /etc/profile /etc/path_to_inst /etc/dumpadm.conf /etc/resolv.conf /etc/remote /etc/netmasks /etc/nsswitch.conf /etc/devlink.tab /etc/dfs/dfstab /etc/rctladm.conf /etc/TIMEZONE /etc/device.tab /kernel/drv/*.conf /etc/logadm.d/* /etc/system.d/* /etc/zones/index /etc/zones/*.xml"
# mail
CS_FILES="${CS_FILES} /etc/sendmail/* /etc/postfix/* /etc/postfix/postfix-files.d/*"
# Add VDCF specific Files
CS_FILES="${CS_FILES} /var/opt/jomasoft/vdcf/conf/*.profile /var/opt/jomasoft/vdcf/conf/*.cfg "
# Add i386 specific Files (grub)
CS_FILES="${CS_FILES} /rpool/boot/grub/* /usr/lib/grub2/bios/etc/grub.d/*"
# Add firewall/ipf specifig files
CS_FILES="${CS_FILES} /etc/ipf/* /etc/firewall/* /etc/firewall.d/*"
# Add smartmon files
CS_FILES="${CS_FILES} /etc/smartd.conf"
# Add legacy run-level scripts
CS_FILES="${CS_FILES} /etc/rc*.d/* /etc/init.d/*"

# check if datadir exists
if [ ! -d $DATADIR ]; then
   mkdir $DATADIR
fi

# set permission on datadir to 700 and owner root for security reasons
if [ -d $DATADIR ]; then
   chmod 700 $DATADIR
   chown root:root $DATADIR
fi

case $1 in
   pre )
      echo "collecting data .... (please be patient)"
      df -kl | grep -v Filesystem | awk '{print $6}' | sort -n 		> $DATADIR/filesystem.pre
      df -kl | grep -v Filesystem | awk '{print $6}' | wc -l 		> $DATADIR/filesystem_count.pre
      mount | grep remote | grep -v "^/net/" | awk '{print $1}' | sort -n > $DATADIR/remote_fs.pre
      mount | grep remote | grep -v "^/net/" | awk '{print $1}' | wc -l	> $DATADIR/remote_fs_count.pre
      /usr/sbin/share | sort -n > $DATADIR/nfs_shares.pre
      /usr/sbin/share | wc -l	> $DATADIR/nfs_shares_count.pre
      ps -fu root -o args | egrep -v "COMMAND|ps -fu root" | sort 	> $DATADIR/proc_root.pre
      ps -fu root -o args | egrep -v "COMMAND|ps -fu root" | wc -l	> $DATADIR/proc_root_count.pre
      ps -ef -o user,args | egrep -v "COMMAND|ps -ef -o user,args|root"  | sort     > $DATADIR/proc_user.pre
      ps -ef -o user,args | egrep -v "COMMAND|ps -ef -o user,args|root"  | wc -l    > $DATADIR/proc_user_count.pre
      if [[ "$(zonename)" == "global" ]]; then
        eeprom > $DATADIR/eeprom.pre
      fi
      if [ "$OSR" == "5.11" ]; then
         if [ -x "/usr/bin/pkg" ]; then
            pkg list | grep -v VERSION | awk '{print $1}' | sort     > $DATADIR/pkginfo.pre
            cat $DATADIR/pkginfo.pre   | wc -l                       > $DATADIR/pkginfo_count.pre
            pkg list | grep -v VERSION | awk '{print $1";"$2}'       > $DATADIR/pkginfo_ext.pre
            pkginfo | awk '{print $2}' | sort                        > $DATADIR/pkginfo_old.pre
            pkginfo | wc -l                                          > $DATADIR/pkginfo_old_count.pre
            cp /dev/null $DATADIR/pkginfo_old_ext.pre
            for pkg in `cat $DATADIR/pkginfo_old.pre `; do 
               /usr/bin/pkgparam -v $pkg | egrep "^PKG=|^VERSION=|^INSTDATE=" | tr "\n" ";"  >> $DATADIR/pkginfo_old_ext.pre
              echo                                                                          >> $DATADIR/pkginfo_old_ext.pre
            done
            pkg publisher                                            > $DATADIR/pkg_publ.pre
         else
            pkginfo | awk '{print $2}' | sort                        > $DATADIR/pkginfo.pre
            pkginfo | wc -l                                          > $DATADIR/pkginfo_count.pre
            cp /dev/null $DATADIR/pkginfo_ext.pre
            for pkg in `cat $DATADIR/pkginfo.pre `; do 
               /usr/bin/pkgparam -v $pkg | egrep "^PKG=|^VERSION=|^INSTDATE=" | tr "\n" ";"  >> $DATADIR/pkginfo_ext.pre
               echo "\n"                                                                     >> $DATADIR/pkginfo_ext.pre
            done
         fi
      else
         pkginfo | awk '{print $2}' | sort                        > $DATADIR/pkginfo.pre
         pkginfo | wc -l                                          > $DATADIR/pkginfo_count.pre
         cp /dev/null $DATADIR/pkginfo_ext.pre
         for pkg in `cat $DATADIR/pkginfo.pre `; do 
            /usr/bin/pkgparam -v $pkg | egrep "^PKG=|^VERSION=|^INSTDATE=" | tr "\n" ";"  >> $DATADIR/pkginfo_ext.pre
            echo "\n"                                                                     >> $DATADIR/pkginfo_ext.pre
         done
         showrev -p | sort -n                       > $DATADIR/patchinfo.pre
         showrev -p | wc -l                         > $DATADIR/patchinfo_count.pre
      fi
      if [ -x /usr/bin/svcs ]; then
         /usr/bin/svcs -o STATE,FMRI -a | sort				> $DATADIR/svcs.pre
         cat $DATADIR/svcs.pre | grep legacy_run | wc -l                > $DATADIR/svcs_legacy.pre
         cat $DATADIR/svcs.pre | grep online  | wc -l                   > $DATADIR/svcs_online.pre
         cat $DATADIR/svcs.pre | grep disabled | wc -l                  > $DATADIR/svcs_disabled.pre
         cat $DATADIR/svcs.pre | grep offline | wc -l                   > $DATADIR/svcs_offline.pre
         cat $DATADIR/svcs.pre | grep maintanance | wc -l               > $DATADIR/svcs_maint.pre
      fi
      ls -l /var/spool/cron/crontabs/* | awk '{print $5 " " $9}' | sort -n	> $DATADIR/crons.pre
      ls -l /var/spool/cron/crontabs/* | wc -l				> $DATADIR/crons_count.pre
      # To be sure the file is clean
      cp /dev/null $DATADIR/crons_cksum.pre
      for crontab in `ls /var/spool/cron/crontabs/*`; do
         crontab_file=$(echo $crontab | sed 's:/:_:g')
         /usr/bin/cksum $crontab                                       >> $DATADIR/crons_cksum.pre
         cp -p $crontab $DATADIR/crons${crontab_file}.pre
      done
      # To be sure the file is clean
      cp /dev/null $DATADIR/files_cksum.pre
      for file in $CS_FILES; do
         if [ -f $file ]; then
            file_file=$(echo $file | sed 's:/:_:g')
            /usr/bin/cksum $file                                       >> $DATADIR/files_cksum.pre
            rm -f $DATADIR/files${file_file}.pre
            cp -p $file $DATADIR/files${file_file}.pre
            #chmod u+w $DATADIR/files${file_file}.pre
	 fi
      done
      # To be sure the file is clean
      cp /dev/null $DATADIR/ifconfig.pre
      for interface in `/usr/sbin/ifconfig -a4 | grep flags | awk -F: '{ if (NF ==2) print $1} { if (NF ==3) print $1 ":" $2}'`; do
         echo "${interface}|`/usr/sbin/ifconfig ${interface} | grep inet | awk '{print $2,$4}'`" >> $DATADIR/ifconfig.pre
      done
      # To be sure the file is clean
      /usr/bin/netstat -rn | sed '1,4d' | awk '{print $1,$2,$3,$6}'  > $DATADIR/netstat.pre 

   ;;

   post )
      if [ ! -f $DATADIR/filesystem.pre ]; then
         echo "There are no *.pre Files. Script can't check the difference. Exiting"
         exit 1
      fi
      echo "collecting data .... (please be patient)"
      df -kl | grep -v Filesystem | awk '{print $6}' | sort -n          > $DATADIR/filesystem.post
      df -kl | grep -v Filesystem | awk '{print $6}' | wc -l            > $DATADIR/filesystem_count.post
      mount | grep remote | grep -v "^/net/" | awk '{print $1}' | sort -n  > $DATADIR/remote_fs.post
      mount | grep remote | grep -v "^/net/" | awk '{print $1}' | wc -l > $DATADIR/remote_fs_count.post
      /usr/sbin/share | sort -n > $DATADIR/nfs_shares.post
      /usr/sbin/share | wc -l	> $DATADIR/nfs_shares_count.post
      ps -fu root -o args | egrep -v "COMMAND|ps -fu root" | sort       > $DATADIR/proc_root.post
      diff $DATADIR/proc_root.pre $DATADIR/proc_root.post               > $DATADIR/proc_root.diff
      ps -fu root -o args | egrep -v "COMMAND|ps -fu root" | wc -l      > $DATADIR/proc_root_count.post
      ps -ef -o user,args | egrep -v "COMMAND|ps -ef -o user,args|root"  | sort     > $DATADIR/proc_user.post
      diff $DATADIR/proc_user.pre $DATADIR/proc_user.post               > $DATADIR/proc_user.diff
      ps -ef -o user,args | egrep -v "COMMAND|ps -ef -o user,args|root"  | wc -l    > $DATADIR/proc_user_count.post
      if [[ "$(zonename)" == "global" ]]; then
        eeprom > $DATADIR/eeprom.post
      fi
      if [ "$OSR" == "5.11" ]; then
         if [ -x "/usr/bin/pkg" ]; then
            pkg list | grep -v VERSION | awk '{print $1}' | sort     > $DATADIR/pkginfo.post
            cat $DATADIR/pkginfo.post  | wc -l                       > $DATADIR/pkginfo_count.post
            pkg list | grep -v VERSION | awk '{print $1";"$2}'       > $DATADIR/pkginfo_ext.post
            pkginfo | awk '{print $2}' | sort                        > $DATADIR/pkginfo_old.post
            pkginfo | wc -l                                          > $DATADIR/pkginfo_old_count.post
            cp /dev/null $DATADIR/pkginfo_old_ext.post
            for pkg in `cat $DATADIR/pkginfo_old.post `; do 
               /usr/bin/pkgparam -v $pkg | egrep "^PKG=|^VERSION=|^INSTDATE=" | tr "\n" ";"  >> $DATADIR/pkginfo_old_ext.post
               echo                                                                          >> $DATADIR/pkginfo_old_ext.post
            done
            pkg publisher                                            > $DATADIR/pkg_publ.post
         else
            pkginfo | awk '{print $2}' | sort                        > $DATADIR/pkginfo.post
            pkginfo | wc -l                                          > $DATADIR/pkginfo_count.post
            cp /dev/null $DATADIR/pkginfo_ext.post
            for pkg in `cat $DATADIR/pkginfo.post `; do 
               /usr/bin/pkgparam -v $pkg | egrep "^PKG=|^VERSION=|^INSTDATE=" | tr "\n" ";"  >> $DATADIR/pkginfo_ext.post
               echo "\n"                                                                     >> $DATADIR/pkginfo_ext.post
            done
         fi
      else
         pkginfo | awk '{print $2}' | sort                        > $DATADIR/pkginfo.post
         pkginfo | wc -l                                          > $DATADIR/pkginfo_count.post
         cp /dev/null $DATADIR/pkginfo_ext.post
         for pkg in `cat $DATADIR/pkginfo.post `; do 
            /usr/bin/pkgparam -v $pkg | egrep "^PKG=|^VERSION=|^INSTDATE=" | tr "\n" ";"  >> $DATADIR/pkginfo_ext.post
            echo "\n"                                                                     >> $DATADIR/pkginfo_ext.post
         done
         showrev -p | sort -n                       > $DATADIR/patchinfo.post
         showrev -p | wc -l                         > $DATADIR/patchinfo_count.post
      fi
      if [ -x /usr/bin/svcs ]; then
         /usr/bin/svcs -o STATE,FMRI -a | sort  	                > $DATADIR/svcs.post
         cat $DATADIR/svcs.post | grep legacy_run | wc -l               > $DATADIR/svcs_legacy.post
         cat $DATADIR/svcs.post | grep online | wc -l                   > $DATADIR/svcs_online.post
         cat $DATADIR/svcs.post | grep disabled | wc -l                 > $DATADIR/svcs_disabled.post
         cat $DATADIR/svcs.post | grep offline | wc -l                  > $DATADIR/svcs_offline.post
         cat $DATADIR/svcs.post | grep maintanance | wc -l              > $DATADIR/svcs_maint.post
      fi
      ls -l /var/spool/cron/crontabs/* | awk '{print $5 " " $9}' | sort -n   > $DATADIR/crons.post
      ls -l /var/spool/cron/crontabs/* | wc -l                          > $DATADIR/crons_count.post
      # To be sure the file is clean
      cp /dev/null $DATADIR/crons_cksum.post
      for crontab in `ls /var/spool/cron/crontabs/*`; do
         crontab_file=$(echo $crontab | sed 's:/:_:g')
         /usr/bin/cksum $crontab                                       >> $DATADIR/crons_cksum.post
         cp -p $crontab $DATADIR/crons${crontab_file}.post
      done
      # To be sure the file is clean
      cp /dev/null $DATADIR/files_cksum.post
      for file in $CS_FILES; do
         if [ -f $file ]; then
            file_file=$(echo $file | sed 's:/:_:g')
            /usr/bin/cksum $file                                       >> $DATADIR/files_cksum.post
            rm -f $DATADIR/files${file_file}.post
            cp -p $file $DATADIR/files${file_file}.post
            #chmod u+w $DATADIR/files${file_file}.post
	 fi
      done
      # To be sure the file is clean
      cp /dev/null $DATADIR/ifconfig.post
      for interface in `/usr/sbin/ifconfig -a4 | grep flags | awk -F: '{ if (NF ==2) print $1} { if (NF ==3) print $1 ":" $2}'`; do
         echo "${interface}|`/usr/sbin/ifconfig ${interface} | grep inet | awk '{print $2,$4}'`" >> $DATADIR/ifconfig.post
      done
      # To be sure the file is clean
      /usr/bin/netstat -rn | sed '1,4d' | awk '{print $1,$2,$3,$6}' > $DATADIR/netstat.post

      echo "=========================================================================================="
      echo "Filesystem changes: "
      echo "pre_count: $(cat $DATADIR/filesystem_count.pre) post_count: $(cat $DATADIR/filesystem_count.post)"
      diff $DATADIR/filesystem.pre $DATADIR/filesystem.post
      echo "------------------------------------------------------------------------------------------"
      echo "Remote Filesystem changes: "
      echo "pre_count: $(cat $DATADIR/remote_fs_count.pre) post_count: $(cat $DATADIR/remote_fs_count.post)"
      diff $DATADIR/remote_fs.pre $DATADIR/remote_fs.post
      echo "------------------------------------------------------------------------------------------"
      if [ $(cat $DATADIR/nfs_shares_count.pre) -gt 0 -o $(cat $DATADIR/nfs_shares_count.post) -gt 0 ]; then
         echo "NFS Shares: "
         echo "pre_count: $(cat $DATADIR/nfs_shares_count.pre) post_count: $(cat $DATADIR/nfs_shares_count.post)"
         diff $DATADIR/nfs_shares.pre $DATADIR/nfs_shares.post > /dev/null 2>&1
         if [ $? -ne 0 ]; then
            echo "diff $DATADIR/nfs_shares.pre $DATADIR/nfs_shares.post"
            diff $DATADIR/nfs_shares.pre $DATADIR/nfs_shares.post
         fi
         echo "------------------------------------------------------------------------------------------"
      fi
      echo "root-Process changes: "
      echo "pre_count: `cat $DATADIR/proc_root_count.pre` post_count: `cat $DATADIR/proc_root_count.post`"
      echo "If there are more then 10-15% difference consult <$DATADIR/proc_root.pre>"
      echo "The diff's are saved in <$DATADIR/proc_root.diff>"
      echo "------------------------------------------------------------------------------------------"
      echo "non-user-Process changes: "
      echo "pre_count: `cat $DATADIR/proc_user_count.pre` post_count: `cat $DATADIR/proc_user_count.post`"
      echo "If there are more then 10-15% difference consult <$DATADIR/proc_user.pre>"
      echo "The diff's are saved in <$DATADIR/proc_user.diff>"
      echo "------------------------------------------------------------------------------------------"
      echo "Installed Package changes: "
      echo "pre_count: `cat $DATADIR/pkginfo_count.pre` post_count: `cat $DATADIR/pkginfo_count.post`"
      diff $DATADIR/pkginfo.pre $DATADIR/pkginfo.post > /dev/null 2>&1
      if [ $? -ne 0 ]; then
         echo "diff $DATADIR/pkginfo.pre $DATADIR/pkginfo.post"
         diff $DATADIR/pkginfo.pre $DATADIR/pkginfo.post
         echo
      fi
      diff $DATADIR/pkginfo_ext.pre $DATADIR/pkginfo_ext.post > /dev/null 2>&1
      if [ $? -ne 0 ]; then
         echo "diff $DATADIR/pkginfo_ext.pre $DATADIR/pkginfo_ext.post"
         diff $DATADIR/pkginfo_ext.pre $DATADIR/pkginfo_ext.post
         echo
      fi
      echo "------------------------------------------------------------------------------------------"
      if [ "$OSR" == "5.11" ]; then
         if [ -x "/usr/bin/pkg" ]; then
            echo "Installed Package changes (old PKG Format): "
            echo "pre_count: `cat $DATADIR/pkginfo_old_count.pre` post_count: `cat $DATADIR/pkginfo_old_count.post`"
            echo
            diff $DATADIR/pkginfo_old.pre $DATADIR/pkginfo_old.post > /dev/null 2>&1
            if [ $? -ne 0 ]; then
               echo "diff $DATADIR/pkginfo_old.pre $DATADIR/pkginfo_old.post"
               diff $DATADIR/pkginfo_old.pre $DATADIR/pkginfo_old.post
               echo 
            fi
            diff $DATADIR/pkginfo_old_ext.pre $DATADIR/pkginfo_old_ext.post > /dev/null 2>&1
            if [ $? -ne 0 ]; then
               echo "diff $DATADIR/pkginfo_old_ext.pre $DATADIR/pkginfo_old_ext.post"
               diff $DATADIR/pkginfo_old_ext.pre $DATADIR/pkginfo_old_ext.post
               echo
            fi
            echo "------------------------------------------------------------------------------------------"
            echo "Package Publisher:"
            echo            
            echo "Actual Package Publisher:"
            cat $DATADIR/pkg_publ.post
            echo
            diff $DATADIR/pkg_publ.pre $DATADIR/pkg_publ.post > /dev/null 2>&1
            if [ $? -ne 0 ]; then
               echo "diff $DATADIR/pkg_publ.pre $DATADIR/pkg_publ.post"
               diff $DATADIR/pkg_publ.pre $DATADIR/pkg_publ.post
               echo "------------------------------------------------------------------------------------------"
            fi
         fi
      else
         echo "------------------------------------------------------------------------------------------"
         echo "Installed Patch changes: "
         echo "pre_count: `cat $DATADIR/patchinfo_count.pre` post_count: `cat $DATADIR/patchinfo_count.post`"
         diff $DATADIR/patchinfo.pre $DATADIR/patchinfo.post > /dev/null 2>&1
         if [ $? -ne 0 ]; then
            echo "diff $DATADIR/patchinfo.pre $DATADIR/patchinfo.post"
            diff $DATADIR/patchinfo.pre $DATADIR/patchinfo.post
         fi
         echo "------------------------------------------------------------------------------------------"
      fi
      if [ -x /usr/bin/svcs ]; then
         echo "------------------------------------------------------------------------------------------"
         echo "Status of Services (svcs): "
         echo "legacy_run : pre (`cat $DATADIR/svcs_legacy.pre`) post (`cat $DATADIR/svcs_legacy.post`)"
         echo "online     : pre (`cat $DATADIR/svcs_online.pre`) post (`cat $DATADIR/svcs_online.post`)"
         echo "offline    : pre (`cat $DATADIR/svcs_offline.pre`) post (`cat $DATADIR/svcs_offline.post`)"
         echo "disabled   : pre (`cat $DATADIR/svcs_disabled.pre`) post (`cat $DATADIR/svcs_disabled.post`)"
         echo "maintanance: pre (`cat $DATADIR/svcs_maint.pre`) post (`cat $DATADIR/svcs_maint.post`)"
         diff $DATADIR/svcs.pre $DATADIR/svcs.post > /dev/null 2>&1
         if [ $? -ne 0 ]; then
            echo "diff $DATADIR/svcs.pre $DATADIR/svcs.post"
            diff $DATADIR/svcs.pre $DATADIR/svcs.post
         fi
         echo "------------------------------------------------------------------------------------------"
      fi 
      echo "Installed crontabs: "
      echo "pre (size, crontab): "
      cat $DATADIR/crons.pre
      echo "post (size, crontab): "
      cat $DATADIR/crons.post
      for crontab in `cat $DATADIR/crons_cksum.post | awk '{print $3}'`; do
         crontab_file=$(echo $crontab | sed 's:/:_:g' )
         crontab_cs_pre=`cat $DATADIR/crons_cksum.pre | grep "${crontab}$" | awk '{print $1}'`
	     crontab_cs_post=`cat $DATADIR/crons_cksum.post | grep "${crontab}$" | awk '{print $1}'`
	 if [ "$crontab_cs_pre" -ne "$crontab_cs_post" ]; then
	    echo "crontab: <$crontab> has been changed ! pre cksum: <$crontab_cs_pre> post cksum: <$crontab_cs_post>"
	    echo "diff $DATADIR/crons${crontab_file}.pre $DATADIR/crons${crontab_file}.post"
        diff $DATADIR/crons${crontab_file}.pre $DATADIR/crons${crontab_file}.post
	 fi
      done
      echo "------------------------------------------------------------------------------------------"
      echo "Config-Files: "
      for file in $CS_FILES; do
         if [ -f $file ]; then
            file_file=$(echo $file| sed 's:/:_:g' )
            files_cs_pre=`cat $DATADIR/files_cksum.pre | grep "${file}$" | awk '{print $1}'`
            files_cs_post=`cat $DATADIR/files_cksum.post | grep "${file}$" | awk '{print $1}'`
            if [ "$files_cs_pre" -ne "$files_cs_post" ]; then
               echo "File: <$file> has been changed ! pre cksum: <$files_cs_pre> post cksum: <$files_cs_post>"
               echo "diff $DATADIR/files${file_file}.pre $DATADIR/files${file_file}.post"
               diff $DATADIR/files${file_file}.pre $DATADIR/files${file_file}.post
            else
               echo "File: <$file> hasn't changed"
            fi
         fi
      done
      echo "------------------------------------------------------------------------------------------"
      echo "OBP-Settings: "
      echo 
      if [[ -f $DATADIR/eeprom.pre ]] && [[ -f $DATADIR/eeprom.post ]]; then
         diff $DATADIR/eeprom.pre $DATADIR/eeprom.post > /dev/null 2>&1
         if [ $? -ne 0 ]; then
            echo "OBP-Settings has been changed!"
            echo "diff $DATADIR/eeprom.pre $DATADIR/eeprom.post"
            diff $DATADIR/eeprom.pre $DATADIR/eeprom.post
         else
            echo "OBP-Settings not changed"
         fi
      fi
      echo "------------------------------------------------------------------------------------------"
      echo "Network: "
      echo 
      echo "Interface Info:"
      diff $DATADIR/ifconfig.pre $DATADIR/ifconfig.post > /dev/null 2>&1
      if [ $? -ne 0 ]; then
         echo "Interface status not the same !"
         echo "$DATADIR/ifconfig.pre:"
         cat $DATADIR/ifconfig.pre
         echo "---------------------------------------------------------------"
         echo "$DATADIR/ifconfig.post:"
         cat $DATADIR/ifconfig.post
         echo "---------------------------------------------------------------"
         echo "diff $DATADIR/ifconfig.pre $DATADIR/ifconfig.post"
         diff $DATADIR/ifconfig.pre $DATADIR/ifconfig.post
         echo "Please check if all Interfaces are configured correctly"
      else
         echo "Interface status ok"
      fi
      echo
      echo "Routing table Info (ignoring flags: Ref and Use):"
      diff $DATADIR/netstat.pre $DATADIR/netstat.post > /dev/null 2>&1
      if [ $? -ne 0 ]; then
         echo "Routing table not the same !"
         echo "$DATADIR/netstat.pre:"
         cat $DATADIR/netstat.pre
         echo "---------------------------------------------------------------"
         echo "$DATADIR/netstat.post:"
         cat $DATADIR/netstat.post
         echo "---------------------------------------------------------------"
         echo "diff $DATADIR/netstat.pre $DATADIR/netstat.post"
         diff $DATADIR/netstat.pre $DATADIR/netstat.post
         echo "Please check the routing table, configuration"
      else
         echo "Routing table ok"
      fi
      echo "=========================================================================================="

   ;;

   clean )
      echo "cleanup collected data ....."
      for file in $(ls $DATADIR/*); do
         echo "cleanup file <$file>."
         rm -f $file
      done

   ;;

   * )
      clear
      echo ""
      echo ""
      echo "*** usage: `basename $0` { pre | post | clean } "
      echo ""
      echo ""
      exit 1
esac
