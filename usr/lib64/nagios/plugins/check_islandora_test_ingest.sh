#!/bin/bash
FH="/usr/local/fedora"
USERNAME="username"
PASSWORD="password"
FEDORA_HOST="localhost"
SOLR_HOST="localhost"
PORT="8080"
PROT="http"
PID="nagios:check_all"
CURRENT_TIME=$(date +"%T")
LABEL_DEFAULT="NagiosCheck$CURRENT_TIME"
IMAGE_URL="http://si-islandora.si.edu/sites/all/themes/smithsonian-theme/logo.png"
DSID="NAGIOS"
DSID_MICRO="TN"
TMP_FILE="/tmp/nagios_check_islandora_test_ingest.tmp" #/tmp/nagios_check_islandora_test_ingest.settings
TEXT_OUTPUT="Islandora test ingest"

# Exit codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

#number of attempts before script returns state critical
NUM_ATTEMPT_FAIL=6 #default, nagios checks every 5 minutes. eg: 6 attempts would be 30 minutes waiting for messages to get through

#default exit var
EXIT_CODE=$STATE_OK


function reset_file() {
	cat <<EOF > $TMP_FILE
0
$LABEL_DEFAULT
EOF
}

if [ -f $TMP_FILE ]; then
    NAGIOS_STACK_NUM=`head -1 $TMP_FILE`
    if [ "$NAGIOS_STACK_NUM" = "" ]; then
    	NAGIOS_STACK_NUM=0
    fi
    LABEL=`head -2 $TMP_FILE | tail -1`
    if [[ "$LABEL" = "$NAGIOS_STACK_NUM" || "$LABEL" = "" ]]; then
    	LABEL=$LABEL_DEFAULT
    fi
    if [ $NAGIOS_STACK_NUM -lt $NUM_ATTEMPT_FAIL ]; then
		NAGIOS_STACK_NUM=`expr $NAGIOS_STACK_NUM + 1`
		cat <<EOF > $TMP_FILE
$NAGIOS_STACK_NUM
$LABEL
EOF
#	else
#		cat <<EOF > test_stack.settings
#$NAGIOS_STACK_NUM
#$LABEL
#EOF
	fi
else
	NAGIOS_STACK_NUM=1
	LABEL=$LABEL_DEFAULT
	cat <<EOF > $TMP_FILE
$NAGIOS_STACK_NUM
$LABEL
EOF
fi

function fedora_ingest_check() {
	#ingest into fedora
	if [[ $NAGIOS_STACK_NUM -eq 1 || $NAGIOS_STACK_NUM -eq $NUM_ATTEMPT_FAIL ]]; then
		image_check=`curl -s -o /dev/null -w "%{http_code}" $IMAGE_URL`
		if [ "$image_check" != "200" ]; then
			TEXT_OUTPUT="$TEXT_OUTPUT; Failed to access image"
			echo $TEXT_OUTPUT
			exit $STATE_CRITICAL
		fi
	
		#first make sure pid nagios:check is deleted
		delete=`curl -XDELETE -u"$USERNAME:$PASSWORD" "$PROT://$FEDORA_HOST:$PORT/fedora/objects/$PID" 2> /dev/null`
		#try add new object
		ingest_object=`curl -XPOST -u"$USERNAME:$PASSWORD" "$PROT://$FEDORA_HOST:$PORT/fedora/objects/$PID?label=$LABEL" 2> /dev/null`
		ingest_relsext=`curl -s -w "%{http_code}" -u "$USERNAME:$PASSWORD" -H "Content-type:text/xml" -X POST --upload-file /usr/lib64/nagios/plugins/relsext.xml "$PROT://$FEDORA_HOST:$PORT/fedora/objects/$PID/datastreams/RELS-EXT?mimeType=text/xml&controlGroup=X&dsLabel=RELSEXT" 2> /dev/null`
		if [[ "$ingest_object" = "$PID" ]]; then
			#add datastream to nagios:check to check microservices
			ingest_datastream=`curl -s -o /dev/null -w "%{http_code}" -XPOST "$PROT://$FEDORA_HOST:$PORT/fedora/objects/$PID/datastreams/$DSID?mimeType=image/jpeg&controlGroup=M&dsLabel=$LABEL&dsLocation=$IMAGE_URL" --data     "" -u $USERNAME:$PASSWORD 2> /dev/null`
			if [ "$ingest_datastream" != "201" ]; then
				TEXT_OUTPUT="$TEXT_OUTPUT; Datastream ingest failed"
				echo $TEXT_OUTPUT
				exit $STATE_CRITICAL
			fi
		else
			TEXT_OUTPUT="$TEXT_OUTPUT; Object ingest failed"
			echo $TEXT_OUTPUT
			exit $STATE_CRITICAL
		fi		
	fi
}

function fedora_check() {
	object_check=`curl -s -o /dev/null -w "%{http_code}" -u"$USERNAME:$PASSWORD" "$PROT://$FEDORA_HOST:$PORT/fedora/objects/$PID"`
	if [ "$object_check" != "200" ]; then
		TEXT_OUTPUT="$TEXT_OUTPUT; Ingested object can't be found"
		echo $TEXT_OUTPUT
		exit $STATE_CRITICAL
	fi
	
	datastream_check=`curl -s -o /dev/null -w "%{http_code}" -u"$USERNAME:$PASSWORD" "$PROT://$FEDORA_HOST:$PORT/fedora/objects/$PID/datastreams/$DSID"`
	if [ "$datastream_check" != "200" ]; then
		TEXT_OUTPUT="$TEXT_OUTPUT; Ingested datastream can't be found"
		echo $TEXT_OUTPUT
		exit $STATE_CRITICAL
	fi
}

function micro_check() {
	micro_check=`curl -s -o /dev/null -w "%{http_code}" -u"$USERNAME:$PASSWORD" "$PROT://$FEDORA_HOST:$PORT/fedora/objects/$PID/datastreams/$DSID_MICRO"`
	if [ "$micro_check" != "200" ]; then
		TEXT_OUTPUT="$TEXT_OUTPUT; Microservices failed"
		EXIT_CODE=$STATE_CRITICAL
	fi
}

function solr_check() {
	#check solr for new dc.title value to match label const
	solr_index=`curl "http://$SOLR_HOST:8080/solr/select/?q=PID:%22$PID%22&indent=on&fl=DC.content.title_s&qt=standard&wt=json" 2> /dev/null`
	solr_label=`echo "$solr_index" | grep $LABEL`	
	if [ "$solr_label" = "" ]; then
		TEXT_OUTPUT="$TEXT_OUTPUT; Solr index failed"
		EXIT_CODE=$STATE_CRITICAL
	fi
}

TEXT_OUTPUT="$TEXT_OUTPUT; Attempt: $NAGIOS_STACK_NUM of $NUM_ATTEMPT_FAIL"

#run checks
fedora_ingest_check

fedora_check
sleep 20
micro_check
#solr_check

if [[ "$EXIT_CODE" = "$STATE_CRITICAL" && $NAGIOS_STACK_NUM -lt NUM_ATTEMPT_FAIL ]]; then
	TEXT_OUTPUT="$TEXT_OUTPUT; JMS Message queue backlog (unknown state)"
	EXIT_CODE=$STATE_UNKNOWN
fi


if [[ "$EXIT_CODE" = "$STATE_CRITICAL" && $NAGIOS_STACK_NUM -eq $NUM_ATTEMPT_FAIL ]]; then
	TEXT_OUTPUT="$TEXT_OUTPUT; Islandora test ingest failed after $NAGIOS_STACK_NUM of $NUM_ATTEMPT_FAIL attempts"
	EXIT_CODE=$STATE_CRITICAL
fi

#reset test_stack.settings to 0 if everything checks out ok
if [ "$EXIT_CODE" = "$STATE_OK" ]; then
	TEXT_OUTPUT="$TEXT_OUTPUT; Islandora test ingest was successful"
	reset_file	
fi

echo $TEXT_OUTPUT
#exit with EXIT_CODE var
exit $EXIT_CODE
