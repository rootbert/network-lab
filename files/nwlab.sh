#!/bin/bash
#title           :nwlab.sh
#description     :This script starts a small network testing environment,
#                :For additional Infos see the file  network-lab.odg
#author		 :Robert Gierzinger
#date            :2015-09-09
#version         :1.0    
#usage		 :bash nwlab.sh
#notes           :this should be run as root
#==============================================================================
#Copyright (C) 2015 Robert Gierzinger
#
#This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#
#This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.


# just comment or uncomment
#debug=true

# at least some info
info=1

# really want so much output?
#[[ $debug ]] && set -x

#time between start of the vms in seconds
timer=5

# define public bridges:
pb1=br13
pb2=br12
pb3=br10
# define dmz bridges:
db1=br14
db2=br11
db3=br16
# define internal bridges:
ib1=br15
#which is the bridge to the hosts network? - this one wont be created or deleted:
hb1=br0


# tap interfaces - naming conventions: first 2 chars are the host, second pair is eth interface number
# so e.g. 0301 is host nwlab03 - interface eth1
tapinterfaces="0100   0101   0102   0103   0200   0201   0202   0300   0301   0400   0401   0500   0600   0700   0800   0900   1000   1100   1200"
interfacemaps=("$hb1" "$pb2" "$pb3" "$pb1" "$ib1" "$pb1" "$db1" "$db2" "$pb2" "$db3" "$pb3" "$ib1" "$db1" "$db2" "$db2" "$db2" "$db3" "$db3" "$db3")

act() {
  if [[ $debug ]] ; then
    "$@"
  else
    "$@" &>/dev/null
  fi
}

prepare() {
# we need libvirt-bin, uml-utilities and bridge-utils for the commands virsh, tunctl and brctl
for i in libvirt-bin uml-utilities bridge-utils; do
	PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $i|grep "install ok installed")
	echo Checking for $i : $PKG_OK
	if [ "" == "$PKG_OK" ]; then
	  echo "No $i - installing"
	  apt-get install $i
	fi
done

for i in $pb1 $pb2 $pb3 $db1 $db2 $db3 $ib1; do
		act brctl addbr $i
		act ifconfig $i up
        done

j=0

for i in $tapinterfaces; do
	hostn=${i::2}
	iface=${i:2:2}
	mappedbridge=${interfacemaps[j]}
	act echo "host: $hostn - interface: $iface maps to $mappedbridge"
	act echo "tunctl -t tap$i && ifconfig tap$i up && brctl addif $mappedbridge tap$i"
	act tunctl -t tap$i
	act brctl addif $mappedbridge tap$i
	act ifconfig tap$i up
	j=$((j+1))	
done

}

startleafes() {
#start simple hosts (all with same config and only one interface)
for i in 05 06 07 08 09 10 11 12 ; do
	act echo "virsh start nwlab""$i"
	act virsh start nwlab$i
	retval=$?
        [ $info == 1 ] && [ $retval == 0 ] && echo "startup of nwlab"$i" successful"
	sleep $timer
done
}

startrouter() {
	act echo "starting nwlab01 ..."
	act virsh start nwlab01
	retval=$?
        [ $info == 1 ] && [ $retval == 0 ] && echo "startup of nwlab01 successful"
	sleep $timer 

}

startswitches() {
	for i in nwlab02 nwlab03 nwlab04; do
		act echo "starting nwlab02 ..."
	        act virsh start $i
		retval=$?
		[ $info == 1 ] && [ $retval == 0 ] && echo "startup of "$i" successful"
		sleep $timer
	done

}

stop() {
	for i in {1..12}; do
		if [ $i -le 9 ]
			then
			act echo "stopping nwlab0""$i"
		        act virsh shutdown nwlab0$i
			retval=$?
			[ $info == 1 ] && [ $retval == 0 ] && echo "shutdown of nwlab""$i"" successful"
			else
			act echo "stoppint nwlab""$i"
                        act virsh shutdown nwlab$i
			retval=$?
			[ $info == 1 ] && [ $retval == 0 ] && echo "shutdown of nwlab""$i"" successful"
		fi
	done
	k=1
	for i in $tapinterfaces; do
        	hostn=${i::2}
        	iface=${i:2:2}
	        mappedbridge=${interfacemaps[k]}
        	act echo "nwlab""$hostn"" - interface: ""$iface"" maps to ""$mappedbridge"
	        act echo "ifconfig tap"$i" down; brctl delif "$mappedbridge" tap"$i"; tunctl -d tap"$i""
	
		act ifconfig tap$i down
		act brctl delif $mappedbridge tap$i
	        act tunctl -d tap$i

	        k=$((k+1))
	done
	for i in $pb1 $pb2 $pb3 $db1 $db2 $db3 $ib1; do
		act ifconfig $i down
                act brctl delbr $i
	done
}

case "$1" in
start)
	prepare
	startleafes
	startrouter
	startswitches
	;;
router)
	prepare
	startrouter
	;;
prepare)
	prepare
	;;
stop)
	stop
	;;
status)
	for i in $pb1 $pb2 $pb3 $db1 $db2 $db3 $ib1; do
		ifconfig | grep "$i" > /dev/null
		[ $? == 1 ] && echo "interface ""$i"" not up!"
        done
	retval=`virsh list | grep nwlab`
	run=$?
	[ $run == 1 ] && echo "No nwlab VM running"
	[ $run == 0 ] && echo $retval | awk '{ print $2 " " $3 }'
	;;
*)
        echo "Usage: $0 [stop|start|status|router|prepare]"
	echo ""
	echo "stop - stops all machines, removes the tap devices and bridges"
	echo "status - print status about bridges + vms"
	echo "router - only start router for testing which should be reachable from the host"
	echo "prepare - just prepare the bridges, you have to start the vms manually"
        exit 1;
        ;;
esac
