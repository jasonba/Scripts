#!/usr/bin/bash
#
# Program       : cfgadm.sh
# Author        : Jason.Banham@Nexenta.COM
# Date          : 2014-10-21
# Version       : 0.02
# Usage         : cfgadm <cfgadm_options>
# Purpose       : Workaround for Nexenta issue NEX-2074
# Legal         : Copyright 2014, Nexenta Systems, Inc. 
#
# Notes		: Based on the workaround script written by Kirill.Davydychev@Nexenta.com
#		  Replace /usr/sbin/cfgadm with this script; move original cfgadm to cfgadm.orig
#		
# History       : 0.01 - Initial version, rewritten to use case statements
#		  0.02 - Enhanced to avoid running a configure for an fc-fabric that is in a configured state
#

CFGADM="/usr/sbin/cfgadm.orig"
LOG_FILE="/var/log/cfgadm_workaround.log"
LC_TIME=C
TSTAMP="`date +%Y-%m-%d\ %H:%M:%S`:"

if [ ! -r $CFGADM ]; then
    echo "Something has gone wrong, I can't find the $CFGADM binary, must exit!"
    exit 1
fi

if [ "$1" == "-c" ]; then
	case "$2" in 
		unconfigure )
			c_line="`$CFGADM $3 | tr -s " " | tail -1`"
                        c_type="`echo $c_line | cut -d " " -f 2`"
			case $c_type in
				fc-fabric | fc-public | raid/hp )
					echo "${TSTAMP} Would've unconfigured $c_type device $3" >> $LOG_FILE
					echo "${TSTAMP} Running cfgadm -al instead" >> $LOG_FILE
					$CFGADM -al > /dev/null 2>&1
					;;
				* )
					echo "${TSTAMP} Running $CFGADM $*" >> $LOG_FILE	
					$CFGADM $1 $2 $3 $4
					;;
			esac
			;;

		configure )
			c_line="`$CFGADM $3 | tr -s " " | tail -1`"
                        c_type="`echo $c_line | cut -d " " -f 2`"
			c_state="`echo $c_line | cut -d " " -f 4`"
			case $c_type in 
				fc-fabric | fc-public | raid/hp )
				
                        		if [ "$c_state" == "configured" ]; then
                                		echo "${TSTAMP} Would've attempted to configured $c_type device $3 in a configured state" >> $LOG_FILE
						echo "${TSTAMP} Running cfgadm -al instead" >> $LOG_FILE
						$CFGADM -al > /dev/null 2>&1
					else
						echo "${TSTAMP} Running $CFGADM $*" >> $LOG_FILE	
						$CFGADM $1 $2 $3 $4
					fi
					;;
				* )
					echo "${TSTAMP} Running $CFGADM $*" >> $LOG_FILE	
					$CFGADM $1 $2 $3 $4
					;;
			esac
			;;
		* )
			echo "${TSTAMP} Running $CFGADM $*" >> $LOG_FILE	
			$CFGADM $1 $2 $3 $4
			;;
	esac
else
	echo "${TSTAMP} Running $CFGADM $*" >> $LOG_FILE	
	$CFGADM $1 $2 $3 $4
fi
