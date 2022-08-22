# LRC Launch Script

This repository provides a Local RTI Component (LRC) launch script for the following HLA-RTI implementations: `VTMaK`, `Pitch`, and `Portico`. A launch script is a helper script to prepare the configuration of the LRC and to launch the application with this configuration. 

Example to launch an application:

````
${SCRIPTS_HOME}/launch.sh /root/application/start.sh
````

Where `${SCRIPTS_HOME}` is the directory where the launch script `launch.sh` is located, and where `start.sh` is the script to start the application.

The launch script `launch.sh`:

- Creates RTI Initialization Data (RID) files for the listed HLA-RTI implementations based on environment variables.
- Copies these files to the working directory of the application, in this example `/root/application`.
- Launches the application with the provided application start script. Any additional arguments provided to the launch script are passed on as command line arguments to the application start script.

The LRC will use the RID files for its internal configuration, provided that these files are located in the working directory of the application that connects to the RTI. In the example above, this must be the directory `/root/application`.

## Use launch script in Docker container

The following example illustrates the use of the launch script in a Dockerfile for the creation of a HLA application image.

- The launch script is provided by the container image `hlacontainers/lrc-scripts`.
- It is assumed that the (Java) application includes all required LRC libraries. For instance the Portico JAR.
- The Java Run Time Environment required to run the application is provided by the container image `openjdk`.

````
FROM hlacontainers/lrc-scripts as scripts

FROM openjdk:17-buster

# Get application launch script
COPY --from=scripts /scripts /scripts/

# Install HLA federate application and ensure start script is executable
COPY ./application /root/application/
RUN chmod +x /root/application/start.sh

# Launch the application
CMD /scripts/launch.sh /root/application/start.sh
````

## LRC environment variables

LRC environment variables are used to create the RID files. There are general environment variables applicable to any HLA-RTI implementation, and HLA-RTI specific variables.

### General environment variables

All environment variables are optional.

| Environment variable | Description                                                  | Default if not specified                         |
| -------------------- | ------------------------------------------------------------ | ------------------------------------------------ |
| `LRC_ENTRYPOINT`     | Reference to the shell script to start the federate application. | First argument of the launch script, if provided |
| `LRC_MASTERADDRESS`  | Master hostname and port number as `<hostname>:<port>`.      | No master address                                |
| `LRC_SLEEPPERIOD`    | Sleep period in seconds before starting the federate application; format `<min>[:<max>]`. If a max is specified then a random value between min and max is used as actual sleep period. | No sleep period                                  |
| `LRC_DEBUG`          | Print debug information. Set to a non-empty value to enable. | No debug                                         |
| `LRC_VERSION`        | If set, the version value is printed when starting the launch script. | Nothing printed                                  |

The reference to the start script to launch the federate application can be provided as first argument to the launch script, or can be provided via `LRC_ENTRYPOINT`. If neither is provided then the launch script does not launch anything and merely returns to hand back control to the caller. The caller may instead launch the application, from the application working directory.

If `LRC_MASTERADDRESS` is set to a non-empty string (in the format specified) then the launch script will only proceed if the port at the given master hostname is open. For the Pitch LRC the Pitch CRC can serve as the master; for the VTMaK LRC the RTI Executable can serve as master. If `LRC_MASTERADDRESS` is unset or is set to an empty string then no attempt is made to check the port; the latter is the default behavior.

The sleep period introduces a sleep time (in seconds) before launching the application. The sleep period applies from the point in time where the master port is open (if the master address is set), or from the point in time when the launch script was started (if the master address is unset or empty).

### Pitch environment variable

All environment variables are optional.

| Environment variable              | Description                                                  | Default if not specified                      |
| --------------------------------- | ------------------------------------------------------------ | --------------------------------------------- |
| `PITCH_RTI_RID_FILE`              | File system path to Pitch RID file to use as template for creating the alternate RID file for the LRC. | `${SCRIPTS_HOME}/pitch/prti1516eLRC.settings` |
| `PITCH_CRCADDRESS`                | CRC address in the format of `<host>:<port>` (direct mode) or `<crc-nickname>@<boost host>:<boost port>` (booster mode). | `crc:8989`                                    |
| `PITCH_LRCADAPTER`                | Applies to direct mode. The network adapter that the LRC should use. | Use IP route to CRC to determine adapter      |
| `PITCH_BOOSTADAPTER`              | Applies to booster mode. The network adapter that the LRC should use for the Booster network. | Use IP route to booster to determine adapter  |
| `PITCH_ADVERTISE_ADDRESS`         | Applies to direct mode. Use this address to advertise the LRC. The format is `[<host address>][:[<mintcpport>]-[<maxtcpport>][:[<minudpport>]-[<maxudpport>]]]` | TCP range `6000-6999`, UDP range `5000-5999`  |
| `PITCH_BOOSTER_ADVERTISE_ADDRESS` | Applies to booster mode. Use this address to advertise the LRC to Booster. The format is `[<host address>][:[<mintcpport>]-[<maxtcpport>][:[<minudpport>]-[<maxudpport>]]]` | TCP range `6000-6999`, UDP range `5000-5999`  |
| `PITCH_ENABLETRACE`               | Set to any value to enable. Enable RTI and Federate Ambassador tracing to console. | Not enabled                                   |

**Notes on the advertise address**

There is a Pitch LRC limitation on the UDP port range:

- When using JRE 6 or lower: the LRC selects odd-numbered UDP ports.
- When using JRE 7 or higher: the LRC selects even-numbered UDP ports. For example, UDP port range `30001-30001` is invalid for JRE 8.

This restriction can be disabled by adding`se.pitch.prti1516e.disablePortRestrictions=true` to the LRC settings file.

### Portico environment variables

All environment variables are optional.

| Environment variable          | Description                                                  | Default if not specified          |
| ----------------------------- | ------------------------------------------------------------ | --------------------------------- |
| `PORTICO_RTI_RID_FILE`        | File system path to Portico RID file to use as template for creating the alternate RID file for the LRC. | `${SCRIPTS_HOME}/portico/RTI.rid` |
| `PORTICO_LRCADAPTER`          | The network adapter (network interface) that the LRC should use. The name must be an exact match. | RID file default                  |
| `PORTICO_LOGLEVEL`            | Specify the level that Portico will log at. Valid values are: TRACE, DEBUG, INFO, WARN, ERROR, FATAL, OFF. | RID file default (WARN)           |
| `PORTICO_UNIQUEFEDERATENAMES` | Ensure that all federates in a federation have unique names. When  false, Portico will change the requested name from "name" to "name  (handle)" thus making it Unique. Valid values are: true, false. | RID file default (true)           |

### VTMAK environment variables

All environment variables are optional.

| Environment variable            | Description                                                  | Default if not specified                                     |
| ------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| `MAK_RTI_RID_FILE`              | File system path to VTMaK RID file to use as template for creating the alternate RID file for the LRC. | `${SCRIPTS_HOME}/vtmak/rid.mtl`                              |
| `MAK_RTIEXECADDRESS`            | RTI Exec address in the format of `<host>:<port>`.           | `rtiexec:4000`                                               |
| `MAK_LRCADAPTER`                | Network interface address to use for the TCP Forwarder       | `0.0.0.0`, i.e. first available non-localhost interface address |
| `MAK_RTI_NOTIFY_LEVEL`          | Change the level of logging detail generated by the LRC. Values in  the range 0--4 are valid with 0 being no logging and 4 being the most  detailed | 2                                                            |
| `MAK_RTI_LOG_FILE_DIRECTORY`    | Specify a directory into which LRC log files will be written. This  is most useful if it is a volume mount so that the log file becomes  visible on the host system | Working directory of the federate                            |
| `MAK_RTI_RTIEXEC_LOG_FILE_NAME` | The name of the log file to be written by the LRC. The file is written into `MAK_LOGFILE_DIR`. Logging to file is not enabled unless this environment variable is set. | Not set                                                      |
| `RTI_ASSISTANT_DISABLE`         | Applicable to the LRC image that includes the RTI Assistant. To  disable the RTI Assistant, set this environment to any value. If unset,  set DISPLAY to an X Server display. | Enabled                                                      |
| `MAK_RTI_JAVA_RTIAMB_BUFLEN`    | Set the size of the RTI Ambassador buffer (in bytes) to allow the  Java federate to send a large parameter or attribute value as per case  [#MAK40782]. Also ensure that `RTI_use32BitsForValueSize` is set to 1 in the RID file to be able to represent this size. | `1000000`                                                    |
| `MAK_RTI_JAVA_FEDAMB_BUFLEN`    | Set the size of the Federate Ambassador buffer (in bytes) to allow  the Java federate to receive a large parameter or attribute value as per case [#MAK42276]. Also ensure that `RTI_use32BitsForValueSize` is set to 1 in the RID file to be able to represent this size. | `1000000`                                                    |

