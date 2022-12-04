#!/bin/sh

#
# Copyright 2020 Tom van den Berg (TNO, The Netherlands).
# SPDX-License-Identifier: Apache-2.0
#

if [ -n "${LRC_DEBUG}" ]; then
	echo "LRC: Update Portico LRC Settings ..."
fi

initPorticoSettings() {
	# We are in this directory
	PORTICO_SCRIPTS_HOME=$(dirname $0)/portico

	# Find the RID, check:
	# (1) ${PORTICO_RTI_RID_FILE}
	# (2) ${PORTICO_SCRIPTS_HOME}/RTI.rid
	
	if [ -n "$PORTICO_RTI_RID_FILE"	]; then
		RID_FILE=${PORTICO_RTI_RID_FILE}
	else
		RID_FILE=${PORTICO_SCRIPTS_HOME}/RTI.rid
	fi
	
	if [ ! -f $RID_FILE ]; then
		echo "LRC: ERROR - RID ${RID_FILE} does not exist"
		return;
	fi

	if [ -n "${LRC_DEBUG}" ]; then
		echo "LRC: Found RID ${RID_FILE}"
	fi

	if [ "$(realpath ${RID_FILE})" != "$(pwd)/RTI.rid" ]; then
		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Copy RID ${RID_FILE} to $(pwd)/RTI.rid"
		fi
		cp ${RID_FILE} $(pwd)/RTI.rid
	fi

	# Set the file to be used for updating the RID settings
	RID_FILE=$(pwd)/RTI.rid
}

initPorticoSettings

# Change settings in config file
if [ -f "${RID_FILE}" ]; then

	# PORTICO_LRCADAPTER is an alternative way to set the bindaddress (which appears only to work with IP address)
	if [ -n "$PORTICO_LRCADAPTER" ]; then
		# Use command ip to determine ip address
		PORTICO_JGROUPS_UDP_BINDADDRESS=`ip addr show $PORTICO_LRCADAPTER | grep 'inet ' | awk '{ print $2}' | cut -d '/' -f1`
	fi

	if [ -n "$PORTICO_LOGLEVEL" ]; then
		sed -i "s/^.*portico.loglevel.*/portico.loglevel = $PORTICO_LOGLEVEL/" $RID_FILE
	fi

	if [ -n "$PORTICO_JGROUPS_LOGLEVEL" ]; then
		sed -i "s/^.*portico.jgroups.loglevel.*/portico.jgroups.loglevel = $PORTICO_JGROUPS_LOGLEVEL/" $RID_FILE
	fi

	if [ -n "$PORTICO_UNIQUEFEDERATENAMES" ]; then
		sed -i "s/^.*portico.uniqueFederateNames.*/portico.uniqueFederateNames = $PORTICO_UNIQUEFEDERATENAMES/" $RID_FILE
	fi
	
	if [ -n "$PORTICO_JGROUPS_UDP_ADDRESS" ]; then
		sed -i "s/^.*portico.jgroups.udp.address.*/portico.jgroups.udp.address = $PORTICO_JGROUPS_UDP_ADDRESS/" $RID_FILE
	fi

	if [ -n "$PORTICO_JGROUPS_UDP_PORT" ]; then
		sed -i "s/^.*portico.jgroups.udp.port.*/portico.jgroups.udp.port = $PORTICO_JGROUPS_UDP_PORT/" $RID_FILE
	fi

	if [ -n "$PORTICO_JGROUPS_UDP_BINDADDRESS" ]; then
		sed -i "s/^.*portico.jgroups.udp.bindAddress.*/portico.jgroups.udp.bindAddress = $PORTICO_JGROUPS_UDP_BINDADDRESS/" $RID_FILE
	fi
fi
