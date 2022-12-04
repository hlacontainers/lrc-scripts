#!/bin/sh

#
# Copyright 2020 Tom van den Berg (TNO, The Netherlands).
# SPDX-License-Identifier: Apache-2.0
#

if [ -n "${LRC_DEBUG}" ]; then
	echo "LRC: Update VTMaK LRC Settings ..."
fi

SplitMakAddress() {
	#split address
	#format: <HOST>:<PORT>
	OLDIFS=$IFS
	ADDRESS=$1
	IFS=:
	set -- $ADDRESS
	MAK_RTIEXECHOST=$1
	MAK_RTIEXECPORT=$2
	IFS=$OLDIFS
}

GetMakNetworkInterface() {
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

initMakSettings() {
	# We are in this directory
	MAK_SCRIPTS_HOME=$(dirname $0)/vtmak
	
	# Find the RID, check:
	# (1) ${MAK_RTI_RID_FILE}
	# (2) ${MAK_SCRIPTS_HOME}/rid.mtl
	
	if [ -n "${MAK_RTI_RID_FILE}" ]; then
		RID_FILE=${MAK_RTI_RID_FILE}
	else
		RID_FILE=${MAK_SCRIPTS_HOME}/rid.mtl
	fi

	if [ ! -f $RID_FILE ]; then
		echo "LRC: ERROR - RID ${RID_FILE} does not exist"
		return;
	fi

	if [ -n "${LRC_DEBUG}" ]; then
		echo "LRC: Found RID ${RID_FILE}"
	fi

	if [ "$(realpath ${RID_FILE})" != "$(pwd)/rid.mtl" ]; then
		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Copy RID ${RID_FILE} to $(pwd)/rid.mtl"
		fi
		cp ${RID_FILE} $(pwd)/rid.mtl
	fi

	# Set the file to be used for updating the RID settings
	RID_FILE=$(pwd)/rid.mtl

	# Set the MAK config dir where the RTI will look for the RID in case the federate application (such as VRF) is in another directory
	export RTI_CONFIG=$(pwd)
	
	# Disable the MAK RTI Assistent
	export RTI_ASSISTANT_DISABLE=1
}

# Set defaults (same as in rtiexec)
X=${MAK_RTI_CONFIGURE_CONNECTION_WITH_RID:=1}
X=${MAK_RTI_USE_RTI_EXEC:=1}
X=${MAK_RTI_FOM_DATA_TRANSPORT_TYPE_CONTROL:=2}
X=${MAK_RTI_MOM_SERVICE_AVAILABLE:=1}
X=${MAK_RTI_THROW_EXCEPTION_CALL_NOT_ALLOWED_FROM_WITHIN_CALLBACK:=1}
X=${MAK_RTI_CHECK_FLAG:=1}
X=${MAK_RTI_ENABLE_HLA_OBJECT_NAME_PREFIX:=1}
X=${MAK_RTI_STRICT_FOM_CHECKING:=1}
X=${MAK_RTI_STRICT_NAME_RESERVATION:=1}
X=${MAK_RTI_RTIEXEC_PERFORMS_LICENSING:=1}
X=${MAK_RTI_USE_32BITS_FOR_VALUE_SIZE:=1}

initMakSettings

# Change settings in config file
if [ -f "$RID_FILE" ]; then
	SplitMakAddress $MAK_RTIEXECADDRESS

	if [ -z "$MAK_RTIEXECHOST" ]; then
		MAK_RTIEXECHOST="rtiexec"
	fi		
	if [ -z "$MAK_RTIEXECPORT" ]; then
		MAK_RTIEXECPORT="4000"
	fi

	MAK_RTIEXECADDRESS=$MAK_RTIEXECHOST:$MAK_RTIEXECPORT

	if [ -z "$MAK_LRCADAPTER" ]; then
		# Determine network interface to RTI Exec
		GetMakNetworkInterface $MAK_RTIEXECHOST
		MAK_LRCADAPTER=$NETIF
	fi

	sed -i "s/(setqb RTI_networkInterfaceAddr.*/(setqb RTI_networkInterfaceAddr \"$MAK_LRCADAPTER\")/" $RID_FILE

	sed -i "s/(setqb RTI_tcpNetworkInterfaceAddr.*/(setqb RTI_tcpNetworkInterfaceAddr \"$MAK_LRCADAPTER\")/" $RID_FILE

	sed -i "s/(setqb RTI_tcpForwarderAddr.*/(setqb RTI_tcpForwarderAddr \"$MAK_RTIEXECHOST\")/" $RID_FILE

	sed -i "s/(setqb RTI_tcpPort.*/(setqb RTI_tcpPort $MAK_RTIEXECPORT)/" $RID_FILE

	sed -i "s/(setqb RTI_udpPort.*/(setqb RTI_udpPort $MAK_RTIEXECPORT)/" $RID_FILE
	
	if [ -n "${LRC_DEBUG}" ]; then
		echo "LRC: Set RTI_networkInterfaceAddr to ${MAK_LRCADAPTER}"
		echo "LRC: Set RTI_tcpNetworkInterfaceAddr to ${MAK_LRCADAPTER}"
		echo "LRC: Set RTI_tcpForwarderAddr to ${MAK_RTIEXECHOST}"
		echo "LRC: Set RTI_tcpPort to ${MAK_RTIEXECPORT}"
		echo "LRC: Set RTI_udpPort to ${MAK_RTIEXECPORT}"
	fi

	# Set the others
	if [ -n "$MAK_RTI_CONFIGURE_CONNECTION_WITH_RID" ]; then
		sed -i "s/(setqb RTI_configureConnectionWithRid.*/(setqb RTI_configureConnectionWithRid $MAK_RTI_CONFIGURE_CONNECTION_WITH_RID)/" $RID_FILE

		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Set RTI_configureConnectionWithRid to ${MAK_RTI_CONFIGURE_CONNECTION_WITH_RID}"
		fi
	fi

	if [ -n "$MAK_RTI_USE_RTI_EXEC" ]; then
		sed -i "s/(setqb RTI_useRtiExec.*/(setqb RTI_useRtiExec $MAK_RTI_USE_RTI_EXEC)/" $RID_FILE

		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Set RTI_useRtiExec to ${MAK_RTI_USE_RTI_EXEC}"
		fi
	fi

	if [ -n "$MAK_RTI_FOM_DATA_TRANSPORT_TYPE_CONTROL" ]; then
		sed -i "s/(setqb RTI_fomDataTransportTypeControl.*/(setqb RTI_fomDataTransportTypeControl $MAK_RTI_FOM_DATA_TRANSPORT_TYPE_CONTROL)/" $RID_FILE

		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Set RTI_fomDataTransportTypeControl to ${MAK_RTI_FOM_DATA_TRANSPORT_TYPE_CONTROL}"
		fi
	fi

	if [ -n "$MAK_RTI_MOM_SERVICE_AVAILABLE" ]; then
		sed -i "s/(setqb RTI_momServiceAvailable.*/(setqb RTI_momServiceAvailable $MAK_RTI_MOM_SERVICE_AVAILABLE)/" $RID_FILE

		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Set RTI_momServiceAvailable to ${MAK_RTI_MOM_SERVICE_AVAILABLE}"
		fi
	fi

	if [ -n "$MAK_RTI_THROW_EXCEPTION_CALL_NOT_ALLOWED_FROM_WITHIN_CALLBACK" ]; then
		sed -i "s/(setqb RTI_throwExceptionCallNotAllowedFromWithinCallback.*/(setqb RTI_throwExceptionCallNotAllowedFromWithinCallback $MAK_RTI_THROW_EXCEPTION_CALL_NOT_ALLOWED_FROM_WITHIN_CALLBACK)/" $RID_FILE

		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Set RTI_throwExceptionCallNotAllowedFromWithinCallback to ${MAK_RTI_THROW_EXCEPTION_CALL_NOT_ALLOWED_FROM_WITHIN_CALLBACK}"
		fi
	fi

	if [ -n "$MAK_RTI_CHECK_FLAG" ]; then
		sed -i "s/(setqb RTI_checkFlag.*/(setqb RTI_checkFlag $MAK_RTI_CHECK_FLAG)/" $RID_FILE

		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Set RTI_checkFlag to ${MAK_RTI_CHECK_FLAG}"
		fi
	fi

	if [ -n "$MAK_RTI_ENABLE_HLA_OBJECT_NAME_PREFIX" ]; then
		sed -i "s/(setqb RTI_enableHlaObjectNamePrefix.*/(setqb RTI_enableHlaObjectNamePrefix $MAK_RTI_ENABLE_HLA_OBJECT_NAME_PREFIX)/" $RID_FILE

		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Set RTI_enableHlaObjectNamePrefix to ${MAK_RTI_ENABLE_HLA_OBJECT_NAME_PREFIX}"
		fi
	fi

	if [ -n "$MAK_RTI_STRICT_FOM_CHECKING" ]; then
		sed -i "s/(setqb RTI_strictFomChecking.*/(setqb RTI_strictFomChecking $MAK_RTI_STRICT_FOM_CHECKING)/" $RID_FILE

		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Set RTI_strictFomChecking to ${MAK_RTI_STRICT_FOM_CHECKING}"
		fi
	fi

	if [ -n "$MAK_RTI_STRICT_NAME_RESERVATION" ]; then
		sed -i "s/(setqb RTI_strictNameReservation.*/(setqb RTI_strictNameReservation $MAK_RTI_STRICT_NAME_RESERVATION)/" $RID_FILE

		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Set RTI_strictNameReservation to ${MAK_RTI_STRICT_NAME_RESERVATION}"
		fi
	fi

	if [ -n "$MAK_RTI_RTIEXEC_PERFORMS_LICENSING" ]; then
		sed -i "s/(setqb RTI_rtiExecPerformsLicensing.*/(setqb RTI_rtiExecPerformsLicensing $MAK_RTI_RTIEXEC_PERFORMS_LICENSING)/" $RID_FILE

		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Set RTI_rtiExecPerformsLicensing to ${MAK_RTI_RTIEXEC_PERFORMS_LICENSING}"
		fi
	fi

	if [ -n "$MAK_RTI_USE_32BITS_FOR_VALUE_SIZE" ]; then
		sed -i "s/(setqb RTI_use32BitsForValueSize.*/(setqb RTI_use32BitsForValueSize $MAK_RTI_USE_32BITS_FOR_VALUE_SIZE)/" $RID_FILE

		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Set RTI_use32BitsForValueSize to ${MAK_RTI_USE_32BITS_FOR_VALUE_SIZE}"
		fi
	fi

	if [ -n "$MAK_RTI_NOTIFY_LEVEL" ]; then
		sed -i "s/.*(setqb RTI_notifyLevel.*/(setqb RTI_notifyLevel $MAK_RTI_NOTIFY_LEVEL)/" $RID_FILE

		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Set RTI_notifyLevel to ${MAK_RTI_NOTIFY_LEVEL}"
		fi
	fi

	if [ -n "$MAK_RTI_LOG_FILE_DIRECTORY" ]; then
		sed -i "s:.*(setqb RTI_logFileDirectory .*):(setqb RTI_logFileDirectory \"$MAK_RTI_LOG_FILE_DIRECTORY\"):" $RID_FILE

		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Set RTI_logFileDirectory to ${MAK_RTI_LOG_FILE_DIRECTORY}"
		fi
	fi

	if [ -n "$MAK_RTI_RTIEXEC_LOG_FILE_NAME" ]; then
		sed -i "s:.*(setqb RTI_rtiExecLogFileName.*):(setqb RTI_rtiExecLogFileName \"$MAK_RTI_RTIEXEC_LOG_FILE_NAME\"):" $RID_FILE

		if [ -n "${LRC_DEBUG}" ]; then
			echo "LRC: Set RTI_rtiExecLogFileName to ${MAK_RTI_RTIEXEC_LOG_FILE_NAME}"
		fi
	fi
fi
