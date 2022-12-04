#!/bin/sh

#
# Copyright 2020 Tom van den Berg (TNO, The Netherlands).
# SPDX-License-Identifier: Apache-2.0
#

echo "LRC: Launch $0 $@"

if [ -n "$LRC_VERSION" ]; then
	echo "LRC: Version:" $LRC_VERSION
fi

WaitForMaster() {
	master=$1

	# remove surrounding quotes, if any
	master="${master%\"}"
	master="${master#\"}"

	#split address
	_OLDIFS=$IFS
	IFS=:
	set -- $master
	master_host=$1
	master_port=$2
	IFS=$_OLDIFS

	if [ -z "$master_host" ]; then
		return
	fi

	if [ -z "$master_port" ]; then
		return
	fi
	
	down=1
	while [ $down -ne 0 ]; do
		echo "LRC: Wait for master at "$master
		
		# Check if the port is open
		down=$(nc -z $master_host $master_port < /dev/null > /dev/null; echo $?)
				
		# Sleep for the next attempt
		sleep 1
	done
			
	echo "LRC: Master at $master is up"
}

PerformSleep () {
	period=$1
	
	# remove surrounding quotes, if any
	period="${period%\"}"
	period="${period#\"}"
	
	#split value
	_OLDIFS=$IFS
	IFS=':'
	set -- $period
	minsleep=$1
	maxsleep=$2
	IFS=$_OLDIFS
	
	# Set minsleep
	if [ -z "$minsleep" ]; then
		minsleep=0
	fi

	# Check value
	if [ "$minsleep" -lt "0" ]; then
		minsleep=0
	fi

	# Set maxsleep
	if [ -z "$maxsleep" ]; then
		maxsleep=$minsleep
	fi

	delta=$((maxsleep - minsleep))
	if [ "$delta" -gt "0" ]; then
		randomsleep=$((minsleep + RANDOM % delta))
	else
		randomsleep=$minsleep
	fi

	if [ "$randomsleep" -gt "0" ]; then
		echo "LRC: Sleep:" $randomsleep
		sleep $randomsleep
	else
		echo "LRC: Sleep: 0"
	fi
}

# Wait for master port to open
if [ -n "$LRC_MASTERADDRESS" ]; then
	WaitForMaster ${LRC_MASTERADDRESS}
fi

# Sleep
if [ -n "$LRC_SLEEPPERIOD" ]; then
	PerformSleep ${LRC_SLEEPPERIOD}
fi

# Set the entrypoint
# If LRC_ENTRYPOINT is not set then use the command line argument
if [ -z "$LRC_ENTRYPOINT" ]; then
	if [ -n "$1" ]; then
		LRC_ENTRYPOINT=$1
		shift
		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Set LRC_ENTRYPOINT to: ${LRC_ENTRYPOINT}"
		fi
	else
		echo "LRC: No entrypoint provided; consider setting ENV LRC_ENTRYPOINT or providing a commandline argument to the launch script"	
	fi
else
	if [ -n "${LRC_DEBUG}" ]; then
		echo "LRC: LRC_ENTRYPOINT is already set to: ${LRC_ENTRYPOINT}"
	fi
fi

# Set the working directory to where the entrypoint is located.
if [ -n "$LRC_ENTRYPOINT" ]; then
	if [ -n "${LRC_DEBUG}" ]; then
		echo "LRC: Set workdir to: $(dirname ${LRC_ENTRYPOINT})"
	fi
	cd $(dirname ${LRC_ENTRYPOINT})
else
	if [ -n "${LRC_DEBUG}" ]; then
		echo "LRC: No entrypoint provided, workdir remains: $(pwd)"
	fi
fi

# Perform RTI specific initialization
if [ -n "$LRC_RTINAME" ]; then
	if [ ! -f $(dirname $0)/$LRC_RTINAME/init.sh ]; then
		echo "LRC: ERROR - file $(dirname $0)/$LRC_RTINAME/init.sh does not exist"
	else
		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Source $(dirname $0)/$LRC_RTINAME/init.sh"
		fi
. $(dirname $0)/$LRC_RTINAME/init.sh
	fi
else
	for name in $(ls $(dirname $0)/*/init.sh); do
		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Source $name"
		fi
. $name
	done
fi

# Start the application, if any
if [ -n "$LRC_ENTRYPOINT" ]; then
	echo "LRC: Exec:" ${LRC_ENTRYPOINT} $@
	exec ${LRC_ENTRYPOINT} $@
fi
