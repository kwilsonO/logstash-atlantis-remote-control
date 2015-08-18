#!/bin/sh

usage()
{

cat <<-EOF
	usage: $0 options

	This script runs scripts on remote logstash machines.

	Commands supported: status, run, stop, clear-cache, clear-logs, tail-err, tail-out 

	Options:
		-h	Show this message
		-c 	Which command to run (run, stop, clear-cache, etc).
		-msra	Which components (m-anager, s-upervisor, r-outer, a-ll)
		-z	Which region/zone you want to execute in (useast1a, useast1d, useast1e), none executes all.
		-i	Internal flag, without this flag it is assumed to run in both internal and external.
		-e	External flag, without this flag it is assumed to run in both internal and external.
EOF
}

PWD=`pwd`
ALLCOMMANDS=('status' 'run' 'stop' 'clear-cache' 'clear-logs' 'tail-err' 'tail-out' 'update-git')
REMOTEPATH="/root/atlantis-analytics"
ROUTERPATH="${REMOTEPATH}/logstash-atlantis-router"
MANAGERPATH="${REMOTEPATH}/logstash-atlantis-manager"
SUPERVISORPATH="${REMOTEPATH}/logstash-atlantis-supervisor"
HOSTFILES="${PWD}/hosts"
COMMAND=""
MANAGER=""
ROUTER=""
SUPERVISOR=""
INTERNAL=""
EXTERNAL=""
REGION=""
HOSTS=()
PATHS=()

#checkcmd() {
#
#	if [[ " ${ALLCOMMANDS[@]} " =~ ${COMMAND} ]] ; then
#		return 1 
#	else
#		return 0 
#	fi	
#
#}

gethosts() {

	if [ "${ROUTER}" = "true" ]; then
		if [ "${INTERNAL}" = "true" ]; then
			for f in $HOSTFILES/router-internal*; do
				HOSTS+=($(cat $f))
				PATHS+=($ROUTERPATH)	
			done
		fi

		if [ "${EXTERNAL}" = "true" ]; then

			for f in $HOSTFILES/router-external*; do
				HOSTS+=($(cat $f))
				PATHS+=($ROUTERPATH)
			done
		fi
		
		if [ "${EXTERNAL}" = "" ] && [ "${INTERNAL}" = "" ] ; then 
			for f in $HOSTFILES/router-*; do
				HOSTS+=($(cat $f))
				PATHS+=($ROUTERPATH)
			done
		fi
	fi
	
	if [ "${MANAGER}" = "true" ]; then 
		for f in $HOSTFILES/manager*; do
			HOSTS+=($(cat $f))
			PATHS+=($MANAGERPATH)
		done
	fi

	if [ "${SUPERVISOR}" = "true" ]; then
		
		if [ "${REGION}" = "" ]; then 
			for f in $HOSTFILES/supervisor*; do
				HOSTS+=($(cat $f))
				PATHS+=($SUPERVISORPATH)
			done	
		else 
			for f in $HOSTFILES/supervisor-$REGION*; do
				HOSTS+=($(cat $f))
				PATHS+=($SUPERVISORPATH)
			done
		fi

	fi

	runcmd
}

runcmd() {
	if [ $COMMAND = "update-git" ]; then

		for i in "${!HOSTS[@]}"; do
			echo "Updating git repo on ${HOSTS[${i}]}..."
			CMDSTR="cd ${PATHS[${i}]}/;git pull;"
			ssh root@${HOSTS[${i}]} $CMDSTR 
		done

	else 

		for i in "${!HOSTS[@]}"; do
			echo "Running command: ${COMMAND} on ${HOSTS[${i}]}..."
			CMDSTR="sh ${PATHS[${i}]}/scripts/remote-control/${COMMAND}.sh"
			ssh root@${HOSTS[${i}]} $CMDSTR 
		done

	fi
}


while getopts "hmsraiec:z:" OPTION; do

	case $OPTION in
	h)
		usage
		exit 1
		;;
	c)
		COMMAND=$OPTARG
		;;
	m)
		MANAGER="true"
		;;
	s)
		SUPERVISOR="true"
		;;
	r)
		ROUTER="true"
		;;
	a)
		MANAGER="true"
		SUPERVISOR="true"
		ROUTER="true"
		;;
	z)
		REGION=$OPTARG
		;;
	i)
		INTERNAL="true"
		;;
	e)
		EXTERNAL="true"
		;;
	\?)
		echo "Invalid option: -$OPTION"
		;;
	esac
done

gethosts
exit 0
