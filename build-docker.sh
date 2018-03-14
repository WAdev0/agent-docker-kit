#!/bin/bash
####################################################################
# Licensed Materials �Property of HCL*
# 
# (c) Copyright HCL Technologies Ltd. 2017 All rights reserved.
# * Trademark of HCL Technologies Limited
####################################################################

UsageHelp()
{
cat << EOF
Usage:
  $0 OPTIONS

This script wrap the "docker build" command to build the Workload Scheduler agent image.


OPTIONS:
   -h                              Show this message
   -s,--server <server_hostname>   Specify the hostname of the Master Domain Manager.
   -p,--port <HTTPS_port>          Optionally specify the HTTPS port of the Websphere Application Server of the Master Domain Manager (default 31116).
   [-v,--agver <agent version>]    Optionally specify the version of the agent to be used to TAG the Docker image (default: 9.4.0.01)
   [-t,--imgname <image name>]     Optionally specify the name of the image you will build (default: workload-scheduler-agent)
EOF
}

badParam()
{
cat << EOF
$0: invalid option -- '$1' 
Try "$0 -h" for more information. 
EOF
exit 1 
}

SERVERHOSTNAME=
SERVERPORT=
AGVER=
IMGNAME=

shopt -s nocasematch
args=$(getopt -n $0 -l "help,agver:,server:,port:,imgname:" -o "v:s:p:ht:" -- "$@")
eval set -- "$args"
# extract options and their arguments into variables.
while true ; do
    case "$1" in
        -s|--server) SERVERHOSTNAME=$2; shift 2 ;;
        -p|--port)   SERVERPORT=$2; shift 2 ;;
        -v|--agver)  AGVER=$2; shift 2 ;;
        -t|--imgname)  IMGNAME=$2; shift 2 ;;
        -h|--help)   UsageHelp; exit ;;
        --) shift ; break ;;
    esac
done

if [[ -z $SERVERHOSTNAME ]]
then
     echo "Specify the hostname of the server hosting the Master Domain Manager with the option '-s'."
     echo "Try \"$0 -h\" for more information."
     exit 1
fi

if [[ -z $SERVERPORT ]] 
then
     SERVERPORT=31116
fi

if [[ -z $AGVER ]]
then
    AGVER=9.4.0.03
fi

if [[ -z $IMGNAME ]]
then
    IMGNAME=workload-scheduler-agent
fi

BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"`

echo "Building the docker image using the following parameters:"
echo "------------------ VARIABLE ------------------------------"
echo "SERVERHOSTNAME = $SERVERHOSTNAME"
echo "SERVERPORT     = $SERVERPORT"
echo "AGVER          = $AGVER"
echo "IMGNAME        = $IMGNAME"
echo "------------------ FIXED   ------------------------------"
echo "AGENT USER     = wauser"
echo "AGENT PATH     = /home/wauser/TWA/TWS"
echo "---------------------------------------------------------"
echo "BUILD_DATE     = $BUILD_DATE"
echo "---------------------------------------------------------"
sleep 5

# Build the new image. 
docker build --force-rm  --rm=true \
  --build-arg SERVERHOSTNAME=$SERVERHOSTNAME \
  --build-arg SERVERPORT=$SERVERPORT \
  --build-arg BUILD_DATE=$BUILD_DATE \
  -t ${IMGNAME}:${AGVER} .  2>&1 | tee $0.log


echo "Generating docker-compose.yml file"
cat > docker-compose.yml << EOF
# This file has been automatically generated by the $0 command
#
# Set these variables to configure the agent to use your own server and agent name
# Run "docker-compose up -d" to run the container
# Run "docker-compose scale iws_agent=5" to run 5 containers (5 agents)
#
# SERVERHOSTNAME=ws94mdm1.example.com      # JobManagerGW.ini ResourceAdvisorUrl
# BKMSERVERHOSTNAME=ws94mdm2.example.com   # JobManagerGW.ini BackupResourceAdvisorUrls 
# SERVERPORT=31116                         # JobManagerGW.ini ResourceAdvisorUrl and BackupResourceAdvisorUrls 
# AGENTID=9F00EA76214011E786BCC9EEA2347192 # JobManager.ini UUID - AgentID (use to persist agents in the resource database and reuse the same agent in the broker)
# AGENTNAME=WSAGENT99                      # ComputerSystemDisplayName 
# AGENTHOSTNAME=myhost.example.com         # hostname in JobManager.ini and JobManagerGWID FullyQualifiedHostname and ResourceAdvisorUrl 
# RECONFIGURE_AGENT=NO                     # Set to YES to force refresh of all configuration options, must set CURRENT_AGENTID="${AGENTID}" and RECONFIGURE_AGENT=NO to keep last configuration
# 
#
iws_agent:
 image: ${IMGNAME}:${AGVER}
 environment:
  - SERVERHOSTNAME=$SERVERHOSTNAME
  - SERVERPORT=$SERVERPORT
  - AGENTNAME=WSAGENT99
  - RECONFIGURE_AGENT=NO
 volumes:
  - data:/home/wauser/TWA/TWS/stdlist 
EOF
 
  
echo "See $0.log for more details."
echo "Customize docker-compose.yml and run 'docker-compose up -d' to start the first container"