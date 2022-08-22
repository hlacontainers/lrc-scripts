#!/bin/sh

#
# Copyright 2020 Tom van den Berg (TNO, The Netherlands).
# SPDX-License-Identifier: Apache-2.0
#

if [ -n "${LRC_DEBUG}" ]; then
	echo "LRC: Update Portico LRC Settings ..."
fi

initEnvironmentVars() {
	# we are in this directory
	PORTICO_SCRIPTS_HOME=$(dirname $0)/portico

	if [ -z "$PORTICO_RTI_RID_FILE"	]; then
		PORTICO_RTI_RID_FILE=${PORTICO_SCRIPTS_HOME}/RTI.rid
	else
		if [ ! -f "$PORTICO_RTI_RID_FILE" ]; then
			if [ -n "${LRC_DEBUG}" ]; then
				echo "LRC: RID ${PORTICO_RTI_RID_FILE} does not exist, using default"
			fi

			PORTICO_RTI_RID_FILE=${PORTICO_SCRIPTS_HOME}/RTI.rid
		fi
	fi
	
	PORTICO_ALTERNATE_RTI_RID_FILE=$(pwd)/RTI.rid
	
	# If there is no RID file in the PWD then copy this RID file
	# to the PWD, where it can be picked up by the RTI.
	if [ ! -f "${PORTICO_ALTERNATE_RTI_RID_FILE}" ] ; then
		cp ${PORTICO_RTI_RID_FILE} ${PORTICO_ALTERNATE_RTI_RID_FILE}
		
		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Copied RID ${PORTICO_RTI_RID_FILE} to workdir as ${PORTICO_ALTERNATE_RTI_RID_FILE}"
		fi

		PORTICO_RTI_RID_FILE=${PORTICO_ALTERNATE_RTI_RID_FILE}
	else
		PORTICO_RTI_RID_FILE=""

		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Found and kept existing RID ${PORTICO_ALTERNATE_RTI_RID_FILE} in workdir"
		fi
	fi
}

initEnvironmentVars

# Change settings in config file
if [ -n "${PORTICO_RTI_RID_FILE}" ]; then

	# PORTICO_LRCADAPTER is an alternative way to set the bindaddress (which appears only to work with IP address)
	if [ -n "$PORTICO_LRCADAPTER" ]; then
		# Use command ip to determine ip address
		PORTICO_JGROUPS_UDP_BINDADDRESS=`ip addr show $PORTICO_LRCADAPTER | grep 'inet ' | awk '{ print $2}' | cut -d '/' -f1`
	fi

	if [ -n "$PORTICO_LOGLEVEL" ]; then
		sed -i "s/^.*portico.loglevel.*/portico.loglevel = $PORTICO_LOGLEVEL/" $PORTICO_RTI_RID_FILE
	fi

	if [ -n "$PORTICO_JGROUPS_LOGLEVEL" ]; then
		sed -i "s/^.*portico.jgroups.loglevel.*/portico.jgroups.loglevel = $PORTICO_JGROUPS_LOGLEVEL/" $PORTICO_RTI_RID_FILE
	fi

	if [ -n "$PORTICO_UNIQUEFEDERATENAMES" ]; then
		sed -i "s/^.*portico.uniqueFederateNames.*/portico.uniqueFederateNames = $PORTICO_UNIQUEFEDERATENAMES/" $PORTICO_RTI_RID_FILE
	fi
	
	if [ -n "$PORTICO_JGROUPS_UDP_ADDRESS" ]; then
		sed -i "s/^.*portico.jgroups.udp.address.*/portico.jgroups.udp.address = $PORTICO_JGROUPS_UDP_ADDRESS/" $PORTICO_RTI_RID_FILE
	fi

	if [ -n "$PORTICO_JGROUPS_UDP_PORT" ]; then
		sed -i "s/^.*portico.jgroups.udp.port.*/portico.jgroups.udp.port = $PORTICO_JGROUPS_UDP_PORT/" $PORTICO_RTI_RID_FILE
	fi

	if [ -n "$PORTICO_JGROUPS_UDP_BINDADDRESS" ]; then
		sed -i "s/^.*portico.jgroups.udp.bindAddress.*/portico.jgroups.udp.bindAddress = $PORTICO_JGROUPS_UDP_BINDADDRESS/" $PORTICO_RTI_RID_FILE
	fi
fi
