#!/bin/sh

#
# Copyright 2020 Tom van den Berg (TNO, The Netherlands).
# SPDX-License-Identifier: Apache-2.0
#

if [ -n "${LRC_DEBUG}" ]; then
	echo "LRC: Update Pitch LRC Settings ..."
fi

SplitAdvertisedAddress() {
	#split address
	#Format: <HOST> [:<TCPMIN>[-<TCPMAX>] [: <UDPMIN>[-<UDPMAX>] ] ]
	OLDIFS=$IFS
	PITCH_ADV_ADDRESS=$1
	IFS=:
	set -- $PITCH_ADV_ADDRESS
	PITCH_ADV_HOST=$1
	PITCH_ADV_TCPPORTRANGE=$2
	PITCH_ADV_UDPPORTRANGE=$3
	IFS=-
	set -- $PITCH_ADV_TCPPORTRANGE
	PITCH_ADV_TCPMIN=$1
	PITCH_ADV_TCPMAX=$2
	set -- $PITCH_ADV_UDPPORTRANGE
	PITCH_ADV_UDPMIN=$1
	PITCH_ADV_UDPMAX=$2
	IFS=$OLDIFS
	
	# Set defaults
	X=${PITCH_ADV_TCPMIN:=6000}
	X=${PITCH_ADV_TCPMAX:=$((PITCH_ADV_TCPMIN))}
	X=${PITCH_ADV_UDPMIN:=5000}
	X=${PITCH_ADV_UDPMAX:=$((PITCH_ADV_UDPMIN+PITCH_ADV_TCPMAX-PITCH_ADV_TCPMIN))}
}

GetNetworkInterface() {
	# host we want to "reach"
	HOSTNAME=$1
	
	# if host is an ip address then do not use DNS
	if expr "$HOSTNAME" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then
		HOSTIP=$HOSTNAME
	else
		# resolve hostname (works with dns and /etc/hosts).
		HOSTIP=$(getent hosts "$HOSTNAME" | awk '{print $1; exit}')
	fi
				
	if [ -z "$HOSTIP" ]; then
		# get the interface used to reach an arbitrary host/IP.
		NETIF=$(ip route get 8.8.8.8 | head -1 | sed -e 's/^.* src \([^ ]*\) .*$/\1/')
		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: No DNS entry found for host $HOSTNAME, using $NETIF of external gateway"
		fi
	else
		# get the interface used to reach the specific host/IP.
		NETIF=$(ip route get "$HOSTIP" | head -1 | sed -e 's/^.* src \([^ ]*\) .*$/\1/')
		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Found interface $NETIF for host $HOSTNAME with IP address $HOSTIP"	
		fi
	fi
}

SplitCRCAddress() {
	#split address
	#format: <CRCHOST>:<CRCPORT>@<BOOSTERHOST>:<BOOSTERPORT>
	OLDIFS=$IFS
	ADDRESS=$1
	IFS=@
	set -- $ADDRESS
	PITCH_CRCHOSTPORT=$1
	PITCH_BOOSTHOSTPORT=$2
	IFS=:
	set -- $PITCH_CRCHOSTPORT
	PITCH_CRCHOST=$1
	PITCH_CRCPORT=$2
	set -- $PITCH_BOOSTHOSTPORT
	PITCH_BOOSTHOST=$1
	PITCH_BOOSTPORT=$2
	IFS=$OLDIFS
}

initEnvironmentVars() {
	# we are in this directory
	PITCH_SCRIPTS_HOME=$(dirname $0)/pitch
		
	if [ -z "$PITCH_RTI_RID_FILE" ]; then
		PITCH_RTI_RID_FILE=${PITCH_SCRIPTS_HOME}/prti1516eLRC.settings
	else
		if [ ! -f "$PITCH_RTI_RID_FILE" ]; then
			if [ -n "${LRC_DEBUG}" ]; then
				echo "LRC: RID ${PITCH_RTI_RID_FILE} does not exist, using default"
			fi

			PITCH_RTI_RID_FILE=${PITCH_SCRIPTS_HOME}/prti1516eLRC.settings		
		fi
	fi
	
	PITCH_ALTERNATE_RTI_RID_FILE=$(pwd)/alternate.lsd
	
	# If there is no RID file in the PWD then copy this RID file
	# to the PWD, where it can be picked up by the RTI.
	if [ ! -f "${PITCH_ALTERNATE_RTI_RID_FILE}" ] ; then
		cp ${PITCH_RTI_RID_FILE} ${PITCH_ALTERNATE_RTI_RID_FILE}
		
		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Copied RID ${PITCH_RTI_RID_FILE} to workdir as ${PITCH_ALTERNATE_RTI_RID_FILE}"
		fi

		PITCH_RTI_RID_FILE=${PITCH_ALTERNATE_RTI_RID_FILE}
	else
		PITCH_RTI_RID_FILE=""

		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Found and kept existing RID ${PITCH_ALTERNATE_RTI_RID_FILE} in workdir"
		fi
	fi
	
	# Set up log settings file in homedir where Pitch expects the file.
	if [ -z "$HOME" ]; then
		PITCH_HOME=/root/prti1516e
	else
		PITCH_HOME=$HOME/prti1516e
	fi

	mkdir -p $PITCH_HOME

	PITCH_LRC_LOGGING_FILE=${PITCH_HOME}/prti1516e.logging
	if [ ! -f "${PITCH_LRC_LOGGING_FILE}" ]; then
		cp ${PITCH_SCRIPTS_HOME}/prti1516e.logging ${PITCH_LRC_LOGGING_FILE}

		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Copied log settings file to ${PITCH_LRC_LOGGING_FILE}"
		fi
	fi
}

initEnvironmentVars

# Change settings in config file
if [ -n "${PITCH_RTI_RID_FILE}" ]; then
	SplitCRCAddress $PITCH_CRCADDRESS

	if [ -n "$PITCH_BOOSTHOST" ]; then
		if [ -z "$PITCH_CRCHOST" ]; then
			PITCH_CRCHOST="crc"
		fi		
		if [ -z "$PITCH_BOOSTPORT" ]; then
			PITCH_BOOSTPORT="8688"
		fi
		PITCH_CRCADDRESS=${PITCH_CRCHOST}@${PITCH_BOOSTHOST}:${PITCH_BOOSTPORT}

		if [ -z "$PITCH_LRCADAPTER" ]; then
			# Determine network PITCH_BOOSTHOST to RTI Exec
			GetNetworkInterface $PITCH_CRCHOST
			PITCH_LRCADAPTER=$NETIF
		fi
	else
		if [ -z "$PITCH_CRCHOST" ]; then
			PITCH_CRCHOST="crc"
		fi		
		if [ -z "$PITCH_CRCPORT" ]; then
			PITCH_CRCPORT="8989"
		fi
		PITCH_CRCADDRESS=${PITCH_CRCHOST}:${PITCH_CRCPORT}
		
		if [ -z "$PITCH_LRCADAPTER" ]; then
			# Determine network interface to RTI Exec
			GetNetworkInterface $PITCH_CRCHOST
			PITCH_LRCADAPTER=$NETIF
		fi
	fi

	if [ -n "${LRC_DEBUG}" ]; then
		echo "LRC: Set crcAddress to ${PITCH_CRCADDRESS}"
	fi

	# Set the CRC address 
	sed -i "s/crcAddress.*/crcAddress=$PITCH_CRCADDRESS/" $PITCH_RTI_RID_FILE

	# Set the LRC Adapter 
	if [ -n "$PITCH_LRCADAPTER" ]; then
		sed -i "s/LRC.adapter.*/LRC.adapter=$PITCH_LRCADAPTER/" $PITCH_RTI_RID_FILE

		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Set LRC.adapter to ${PITCH_LRCADAPTER}"
		fi
	fi

	# Set the Booster Adapter 
	if [ -n "$PITCH_BOOSTERADAPTER" ]; then
		sed -i "s/Booster.adapter.*/Booster.adapter=$PITCH_BOOSTERADAPTER/" $PITCH_RTI_RID_FILE

		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Set Booster.adapter to ${PITCH_BOOSTERADAPTER}"
		fi
	fi

	# Set the LRC advertise address 
	if [ -n "${PITCH_ADVERTISE_ADDRESS}" ]; then
		SplitAdvertisedAddress $PITCH_RTI_RID_FILE
		
		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Set advertise host and port ranges to ${PITCH_ADV_HOST}:${PITCH_ADV_TCPMIN}-${PITCH_ADV_TCPMAX}:${PITCH_ADV_UDPMIN}-${PITCH_ADV_UDPMAX}"
		fi
	
		if [ -n "$PITCH_ADV_HOST" ]; then
			sed -i "s/LRC.TCP.advertise.mode.*/LRC.TCP.advertise.mode=User/" $PITCH_RTI_RID_FILE
			sed -i "s/LRC.TCP.advertise.address.*/LRC.TCP.advertise.address=$PITCH_ADV_HOST/" $PITCH_RTI_RID_FILE
		fi
	
		if [ -n "$PITCH_ADV_TCPMIN" ]; then
			sed -i "s/LRC.TCP.port-range.start.*/LRC.TCP.port-range.start=$PITCH_ADV_TCPMIN/" $PITCH_RTI_RID_FILE
		fi
	
		if [ -n "$PITCH_ADV_TCPMAX" ]; then
			sed -i "s/LRC.TCP.port-range.end.*/LRC.TCP.port-range.end=$PITCH_ADV_TCPMAX/" $PITCH_RTI_RID_FILE
		fi

		if [ -n "$PITCH_ADV_UDPMIN" ]; then
			sed -i "s/LRC.UDP.port-range.start.*/LRC.UDP.port-range.start=$PITCH_ADV_UDPMIN/" $PITCH_RTI_RID_FILE
		fi
	
		if [ -n "$PITCH_ADV_UDPMAX" ]; then
			sed -i "s/LRC.UDP.port-range.end.*/LRC.UDP.port-range.end=$PITCH_ADV_UDPMAX/" $PITCH_RTI_RID_FILE
		fi
	fi

	# Set the Booster advertise address 
	if [ -n "${PITCH_BOOSTER_ADVERTISE_ADDRESS}" ]; then
		SplitAdvertisedAddress $PITCH_BOOSTER_ADVERTISE_ADDRESS
	
		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Set advertise data to ${PITCH_ADV_HOST}:${PITCH_ADV_TCPMIN}-${PITCH_ADV_TCPMAX}:${PITCH_ADV_UDPMIN}-${PITCH_ADV_UDPMAX}"
		fi

		if [ -n "$PITCH_ADV_HOST" ]; then
			sed -i "s/LRC.booster.advertise.mode.*/LRC.booster.advertise.mode=User/" $PITCH_RTI_RID_FILE
			sed -i "s/LRC.booster.advertise.address.*/LRC.booster.advertise.address=$PITCH_ADV_HOST/" $PITCH_RTI_RID_FILE
		fi
	
		if [ -n "$PITCH_ADV_TCPMIN" ]; then
			sed -i "s/LRC.booster.tcp.port-range.start.*/LRC.booster.tcp.port-range.start=$PITCH_ADV_TCPMIN/" $PITCH_RTI_RID_FILE
		fi
	
		if [ -n "$PITCH_ADV_TCPMAX" ]; then
			sed -i "s/LRC.booster.tcp.port-range.end.*/LRC.booster.tcp.port-range.end=$PITCH_ADV_TCPMAX/" $PITCH_RTI_RID_FILE
		fi

		if [ -n "$PITCH_ADV_UDPMIN" ]; then
			sed -i "s/LRC.booster.udp.port-range.start.*/LRC.booster.udp.port-range.start=$PITCH_ADV_UDPMIN/" $PITCH_RTI_RID_FILE
		fi
	
		if [ -n "$PITCH_ADV_UDPMAX" ]; then
			sed -i "s/LRC.booster.udp.port-range.end.*/LRC.booster.udp.port-range.end=$PITCH_ADV_UDPMAX/" $PITCH_RTI_RID_FILE
		fi
	fi	
fi

# Change settings in config file
if [ -f "$PITCH_LRC_LOGGING_FILE" ]; then
	if [ -n "$PITCH_ENABLETRACE" ]; then
		sed -i "s/traceRTIambassador=.*/traceRTIambassador=true/" $PITCH_LRC_LOGGING_FILE
		sed -i "s/traceFederateAmbassador=.*/traceFederateAmbassador=true/" $PITCH_LRC_LOGGING_FILE
		sed -i "s/traceToConsole=.*/traceToConsole=true/" $PITCH_LRC_LOGGING_FILE

		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Set RTI logging to true"
		fi
	fi
fi
