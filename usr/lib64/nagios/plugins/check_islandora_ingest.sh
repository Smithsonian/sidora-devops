#!/bin/bash

USERNAME="username"
PASSWORD="password"
FEDORA_HOST="localhost"
SOLR_HOST="localhost"
PORT="8080"
PROT="http"
PIDX="nagios:check_all"
CURRENT_TIME=$(date +"%T")
LABEL_DEFAULT="NagiosCheck${CURRENT_TIME}"
#IMAGE_URL="http://workbench.sidora.si.edu/sites/all/themes/smithsonian-theme/logo.png"
IMAGE_URL="http://localhost:8080/tomcat.gif"
SOLR_PING="http://localhost:8080/solr/gsearch_solr/admin/ping"
DSID="NAGIOS"
DSID_MICRO="TN"
#TMP_FILE="/home/boylej/nagios_check_islandora_test_ingest.tmp"
TMP_FILE="/tmp/nagios_check_islandora_test_ingest.tmp"
TEXT_OUTPUT="Islandora test ingest"

# Exit codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

#number of attempts before script returns state critical
NUM_ATTEMPTS=6 #default, nagios checks every 5 minutes. eg: 6 attempts would be 30 minutes waiting for messages to get through

#default exit var
EXIT_CODE=${STATE_OK}


function reset_file() {
    printf "0\n${LABEL_DEFAULT}\n" > $TMP_FILE
}

function fedora_ingest_check() {
    #ingest into fedora
    if [[ $NAGIOS_STACK_NUM -eq 1 || $NAGIOS_STACK_NUM -eq $NUM_ATTEMPTS ]]; then
	image_check=$(curl -s -o /dev/null -w "%{http_code}" "${IMAGE_URL}")
	case $image_check in 
	    200)
		;;
	    201)
		;;
	    202)
		;;
	    *)
		TEXT_OUTPUT="${TEXT_OUTPUT}; Failed to access image"
		printf "${TEXT_OUTPUT}\n"
		exit ${STATE_CRITICAL}
            # There is a bug in this code so the is bypassed on the DEV for now.  DWD 20140503
	    # 20140630 - jwb - reverted to CRITICAL from OK - the check works with the correct URL
		;;
	esac
	
	#first make sure pid nagios:check is deleted
	delete=$(curl -XDELETE -u"${USERNAME}:${PASSWORD}" "${PROT}://${FEDORA_HOST}:${PORT}/fedora/objects/${PIDX}" 2> /dev/null)
	# 20140630 jwb - where is the verification for above? Also, why is $delete set? It remains unused!
	#try add new object
	ingest_object=$(curl -XPOST -u"${USERNAME}:${PASSWORD}" "${PROT}://${FEDORA_HOST}:${PORT}/fedora/objects/${PIDX}?label=${LABEL}" 2> /dev/null)
	ingest_relsext=$(curl -s -w "%{http_code}" -u"${USERNAME}:${PASSWORD}" -H "Content-type:text/xml" -XPOST --upload-file /usr/lib64/nagios/plugins/relsext.xml "${PROT}://${FEDORA_HOST}:${PORT}/fedora/objects/${PIDX}/datastreams/RELS-EXT?mimeType=text/xml&controlGroup=X&dsLabel=RELSEXT" 2> /dev/null)
	# 20140630 - jwb - ingest_relsext is another value stored, but never used :^\
	# 20140630 - jwb - wouldn't it be better to check the HTTP status code...?
	if [ "$ingest_object" = "${PIDX}" ]; then
	    #add datastream to nagios:check to check microservices
	    ingest_datastream=$(curl -s -o /dev/null -w "%{http_code}" -XPOST "${PROT}://${FEDORA_HOST}:${PORT}/fedora/objects/${PIDX}/datastreams/${DSID}?mimeType=image/gif&controlGroup=M&dsLabel=${LABEL}&dsLocation=${IMAGE_URL}" --data "" -u"${USERNAME}:${PASSWORD}" 2> /dev/null)
	    # 20140630 - jwb - we will need to verify that 201 is the only acceptable code.  200 or 202 should also be permitted
	    case $ingest_datastream in
		200)
		    ;;
		201)
		    ;;
		202)
		    ;;
		*)
		    TEXT_OUTPUT="${TEXT_OUTPUT}; Datastream ingest failed"
		    printf "${TEXT_OUTPUT}\n"
                    #exit ${STATE_OK}
		    exit ${STATE_CRITICAL}
		    ;;
	    esac
	else
	    TEXT_OUTPUT="${TEXT_OUTPUT}; Object ingest failed"
	    printf "${TEXT_OUTPUT}\n"
            #exit ${STATE_OK}
	    exit ${STATE_CRITICAL}
	fi		
    fi
}

function fedora_check() {
    object_check=$(curl -s -o /dev/null -w "%{http_code}" -u"${USERNAME}:${PASSWORD}" "${PROT}://${FEDORA_HOST}:${PORT}/fedora/objects/${PIDX}")
    case $object_check in
	200)
	    ;;
	201)
	    ;;
	202)
	    ;;
	*)
	    TEXT_OUTPUT="${TEXT_OUTPUT}; Ingested object can't be found"
	    printf "${TEXT_OUTPUT}\n"
	    exit ${STATE_CRITICAL}
	    ;;
	esac
    
    datastream_check=$(curl -s -o /dev/null -w "%{http_code}" -u"${USERNAME}:${PASSWORD}" "${PROT}://${FEDORA_HOST}:${PORT}/fedora/objects/${PIDX}/datastreams/${DSID}")
    case $datastream_check in
	200)
	    ;;
	201)
	    ;;
	202)
	    ;;
	*)
	    TEXT_OUTPUT="${TEXT_OUTPUT}; Ingested datastream can't be found"
	    printf "${TEXT_OUTPUT}\n"
	    exit ${STATE_CRITICAL}
	    ;;
    esac
}

function micro_check() {
    #micro_check=$(curl -s -o /dev/null -w "%{http_code}" -u"$USERNAME:$PASSWORD" "$PROT://$FEDORA_HOST:$PORT/fedora/objects/$PID/datastreams/$DSID_MICRO")
    micro_check=$(curl -s -o /dev/null -w "%{http_code}" -u"${USERNAME}:${PASSWORD}" "${PROT}://${FEDORA_HOST}:${PORT}/fedora/objects/${PIDX}/datastreams/${DSID_MICRO}")
    case $micro_check in
	200)
	    ;;
	201)
	    ;;
	202)
	    ;;
	*)
	    TEXT_OUTPUT="${TEXT_OUTPUT}; Microservices failed"
	    EXIT_CODE=${STATE_CRITICAL}
	    printf "micro_check: ${TEXT_OUTPUT}\n"
	    ;;
    esac
}

function solr_check() {
    #check solr for new dc.title value to match label const
    solr_index=$(curl "http://${SOLR_HOST}:8080/solr/gsearch_solr/select/?q=PID:%22${PIDX}%22&indent=on&fl=DC.content.title_s&qt=standard&wt=json" 2> /dev/null)
    solr_label=$(echo "$solr_index" | grep ${LABEL})
    if [ -z $solr_label ]; then
	TEXT_OUTPUT="${TEXT_OUTPUT}; Solr index failed; ${solr_index}"
	EXIT_CODE=${STATE_CRITICAL}
	printf "solr_check: ${TEXT_OUTPUT}\n"
    fi
}

if [ -f $TMP_FILE ]; then
    NAGIOS_STACK_NUM=$(head -1 $TMP_FILE)
    [ -z $NAGIOS_STACK_NUM ] && NAGIOS_STACK_NUM=0
    LABEL=$(head -2 $TMP_FILE | tail -1)
    if [[ "${LABEL}" = "$NAGIOS_STACK_NUM" || -z "${LABEL}" ]]; then
	LABEL=${LABEL_DEFAULT}
    fi
    if [ $NAGIOS_STACK_NUM -lt $NUM_ATTEMPTS ]; then
	let NAGIOS_STACK_NUM+=1
	printf "${NAGIOS_STACK_NUM}\n${LABEL}\n" > $TMP_FILE
    fi
else
    NAGIOS_STACK_NUM=1
    LABEL=${LABEL_DEFAULT}
    printf "${NAGIOS_STACK_NUM}\n${LABEL}\n" > $TMP_FILE
fi

TEXT_OUTPUT="${TEXT_OUTPUT}; Attempt: $NAGIOS_STACK_NUM of $NUM_ATTEMPTS"

#run checks
fedora_ingest_check
fedora_check
sleep 20
micro_check
#solr_check

if [ "${EXIT_CODE}" = "${STATE_CRITICAL}" ]; then
    if [ $NAGIOS_STACK_NUM -lt $NUM_ATTEMPTS ]; then
	TEXT_OUTPUT="${TEXT_OUTPUT}; JMS Message queue backlog (unknown state)"
	EXIT_CODE=${STATE_UNKNOWN}
    fi
fi


if [ "${EXIT_CODE}" = "${STATE_CRITICAL}" ]; then
    if [ $NAGIOS_STACK_NUM -eq $NUM_ATTEMPTS ]; then
	TEXT_OUTPUT="${TEXT_OUTPUT}; Islandora test ingest failed after $NAGIOS_STACK_NUM of $NUM_ATTEMPTS attempts"
	EXIT_CODE=${STATE_CRITICAL}
    fi
fi

#reset test_stack.settings to 0 if everything checks out ok
if [ "${EXIT_CODE}" = "${STATE_OK}" ]; then
    TEXT_OUTPUT="${TEXT_OUTPUT}; Islandora test ingest was successful"
    reset_file	
fi

printf "${TEXT_OUTPUT}\n"
exit ${EXIT_CODE}
