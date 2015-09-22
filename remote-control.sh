#!/bin/sh

usage()
{

cat <<-EOF
	usage: $0 options

	This script runs scripts on remote logstash machines.

	Commands supported: status, run, stop, update-git, clear-cache, clear-logs, tail-err, tail-out, copy-file

	Options:
		-h	Show this message
		-R	Which Region to use (us-east-1-testflight,etc)
		-c 	Which command to run (run, stop, clear-cache, etc).
		-m	Manager component
		-r	Router component
		-rI     Router-internal only
		-rE	Router-external only
		-s	Supervisor component
		-sZ	Supervisor that accepts an arg to specify which sub region (a, d, e) for (us-east-1a, etc)	
		-e	Elasticsearch Component, not included in -all, and can only be used by itself not with other components	
		-x	Custom command, pass desired command as arg to -d
		-f	Full path to file to copy(for file copy command) 	
		-p	Full path to the logstash installation (default uses /opt/atlantis/logstash or /data/atlantis/elasticsearch)
EOF
}

PWD=`pwd`
ALLCOMMANDS=('status' 'run' 'stop' 'clear-cache' 'clear-logs' 'tail-err' 'tail-out' 'update-git' 'copy-file')
REMOTEPATHLS="/opt/atlantis/logstash"
REMOTEPATHES="/data/atlantis/elasticsearch"
REMOTEPATH=""
REPONAMEMATCH="atlantis-*"
HOSTFILES="${PWD}/hosts"
REGION=""
COMMAND=""
ISCUSTOM=""
CUSTOMCMD=""
COPYFILEPATH=""
TAGMATCH=""
TAGMATCHRAY=()
HOSTSDATA=()
HOSTSTAGS=()
HOSTS=()
PATHS=()
TAGOUT=()

#checkcmd() {
#
#	if [[ " ${ALLCOMMANDS[@]} " =~ ${COMMAND} ]] ; then
#		return 1 
#	else
#		return 0 
#	fi	
#
#}

parsehostfile(){

if [ ! -e $HOSTFILES/$REGION-hosts ]; then
	echo "The region ${REGION} does not have a hosts file, try again..."
	exit 1
fi
INNERTAG=""
OUTERTAG=""
COUNT=0
while read line; do 

	if [[ $line == *:: ]] ; then 
		INNERTAG=""
		OUTERTAG="$(echo $line | sed 's/://g')"
	elif [[ $line == *: ]] ; then
		INNERTAG="$(echo $line | sed 's/://g')"
		INNERTAG=":${INNERTAG}"
	else
		HOSTSDATA+=($line)
		HOSTSTAGS+=($OUTERTAG$INNERTAG)
	fi

done <$HOSTFILES/$REGION-hosts

}

printhosts(){

	for K in "${!HOSTSDATA[@]}"; do echo "${K} - ${HOSTSDATA[${K}]}"; done
	for K in "${!HOSTSTAGS[@]}"; do echo "${K} - ${HOSTSTAGS[${K}]}"; done


}

buildtagmatch() {

	for i in "${!TAGMATCHRAY[@]}"; do
		if [[ "$i" == "0" ]]; then
			TAGMATCH="${TAGMATCHRAY[${i}]}"
		else 
			TAGMATCH="${TAGMATCH}|${TAGMATCHRAY[${i}]}"
		fi

	done


}

gethosts() {

	buildtagmatch
	echo "Currently Matching: ${TAGMATCH}"
	for K in "${!HOSTSTAGS[@]}"; do 
		TAGS="${HOSTSTAGS[${K}]}"
		TAGOUT+=($TAGS)	
		if [[ $TAGS =~ $TAGMATCH ]]; then
			HOSTS+=("${HOSTSDATA[${K}]}")
			if [[ $TAGS == "elasticsearch" ]]; then
				PATHS+=("${REMOTEPATHES}")
			else
				PATHS+=("${REMOTEPATHLS}")
			fi
		fi	
	done

	runcmd
}

runcmd() {
	if [ "${COMMAND}" = "update-git" ]; then

		for i in "${!HOSTS[@]}"; do
			echo "Updating git repo on ${TAGOUT[${i}]} : ${HOSTS[${i}]}..."
			CMDSTR="cd ${PATHS[${i}]}/${REPONAMEMATCH}/;git pull"
			ssh root@${HOSTS[${i}]} $CMDSTR 
		done

	elif [ "${COMMAND}" = "copy-file" ]; then

		for i in "${!HOSTS[@]}"; do
			echo "Copying file on ${TAGOUT[${i}]} : ${HOSTS[${i}]}..."
			scp $COPYFILEPATH root@${HOSTS[${i}]}:${PATHS[${i}]}
		done

	elif [ "${ISCUSTOM}" = "true" ]; then
		for i in "${!HOSTS[@]}"; do
			echo "Running custom command on ${TAGOUT[${i}]} : ${HOSTS[${i}]}..."
			CMDSTR="$CUSTOMCMD"
			ssh root@${HOSTS[${i}]} $CMDSTR
		done
	else	
		#default to status
		if [[ "${COMMAND}" = "" ]]; then
			COMMAND="status"
		fi

		for i in "${!HOSTS[@]}"; do
			echo "Running command: ${COMMAND} on ${TAGOUT[${i}]} : ${HOSTS[${i}]}..."
			CMDSTR="bash ${PATHS[${i}]}/${REPONAMEMATCH}/scripts/remote-scripts/${COMMAND}.sh"
			ssh root@${HOSTS[${i}]} $CMDSTR
		done

	fi
}


while getopts "hR:msrrIrEsZ:eac:x:f:p:" OPTION; do

	case $OPTION in
	h)
		usage
		exit 1
		;;
	R)
		REGION=$OPTARG	
		;;
	c)
		COMMAND=$OPTARG
		;;
	m)
		TAGMATCHRAY+=("manager")
		;;
	s)
		TAGMATCHRAY+=("supervisor*")
		;;
	sZ)
			if [[ $OPTARG != "" ]] ; then
				TAGMATCHRAY+=("supervisor:${OPTARG}")	
			else
				echo "No sub region passed to command, try again."
				exit 1
			fi
		;;
	r)
		TAGMATCHRAY+=("router*")
		;;
	rI)
		TAGMATCHRAY+=("router:internal")
		;;
	rE)
		TAGMATCHRAY+=("router:external")
		;;
	e)
		TAGMATCHRAY+=("elasticsearch")
		;;
	a)
		TAGMATCHRAY+=(".*")
		;;
	x)
		ISCUSTOM="true"
		CUSTOMCMD=$OPTARG
		;;
	f)
		
		COPYFILEPATH=$OPTARG
		if [ ! -e $COPYFILEPATH ]; then
			echo "Invalid file passed with -f"
			exit 1
		fi
		;;
	p)
		REMOTEPATHES=$OPTARG
		REMOTEPATHLS=$OPTARG
		;;	
	\?)
		echo "Invalid option: -$OPTION"
		;;
	esac
done

parsehostfile
gethosts
exit 0
