#!/bin/bash

date="$(date +'%d')"
month="$(date +'%m')"
year="$(date +'%Y')"

PFLOGSUMM=/usr/sbin/pflogsumm
PYGTAIL=/usr/sbin/pygtail.py

PFVALS=( 'received' 'delivered' 'forwarded' 'deferred' 'bounced' 'rejected' 'held' 'discarded' 'reject_warnings' 'bytes_received' 'bytes_delivered' )
declare -a StringArray=("external-incoming" "fmlr" "lists" "smtpauth" "external-outgoing" "ldns" "rp" "webmail")

write_result () {
    echo "$2"
    exit $1
}

readvalue () {
        local $key
        key=$(echo ${PFVALS[@]} | grep -wo $1)
        if [ -n "${key}" ]; then
                value=$(grep -e "^${key};" "${PFSTATSFILE}" | cut -d ";" -f2)
                echo "${value}"

        else
                rm "${TEMPFILE}"
                result_text="ERROR: could not get value \"$1\" from ${PFSTATSFILE}"
                result_code="1"
                write_result "${result_code}" "${result_text}"
        fi
}

# update value  in data file
updatevalue() {
        local $key
        local $pfkey

        key=$1
        pfkey=$(echo "$1" | tr '_' ' ')

        # convert value to bytes
        value=$(grep -m 1 "$pfkey" $TEMPFILE | awk '{print $1}' | awk '/k|m/{p = /k/?1:2}{printf "%d\n", int($1) * 1024 ^ p}')

        # update values in data file
        old_value=$(grep -e "^${key};" "${PFSTATSFILE}" | cut -d ";" -f2)
        if [ -n "${old_value}" ]; then
                sed -i -e "s/^${key};${old_value}/${key};$((${old_value}+${value}))/" "${PFSTATSFILE}"
        else
                echo "${key};${value}" >> "${PFSTATSFILE}"

        fi
}


if [ ! -x ${PFLOGSUMM} ] ; then
    echo "ERROR: ${PFLOGSUMM} not found"
    exit 1
fi

if [ ! -x ${PYGTAIL} ] ; then
    echo "ERROR: ${PYGTAIL} not found"
    exit 1
fi

# Iterate the string array using for loop
for val in ${StringArray[@]}; do

    filename="$val.$(date +'%Y%m%d')"
	#echo $filename
	MAILLOG=/logdisk/$year/$month/maillog/$filename

	PFOFFSETFILE=/tmp/$filename-zabbix-postfix-offset.dat
	PFSTATSFILE=/tmp/$filename-postfix_statsfile.dat
	TEMPFILE=$(mktemp)

	echo $PFSTATSFILE

	if [ ! -r ${MAILLOG} ] ; then
        echo "ERROR: ${MAILLOG} not readable"
        exit 1
	fi

	if [ ! -w "${PFSTATSFILE}" ]; then
        touch "${PFSTATSFILE}" && chown root:root "${PFSTATSFILE}" > /dev/null 2>&1

        if [ ! $? -eq 0 ]; then
                result_text="ERROR: wrong exit code returned while creating file ${PFSTATSFILE} and setting its owner to root:root"
                result_code="1"
                write_result "${result_code}" "${result_text}"
        fi
	fi

	if [ -n "$1" ]; then
        readvalue "$1"
	else
        # read the new part of mail log and read it with pflogsumm to get the summary
        "${PYGTAIL}" -o"${PFOFFSETFILE}" "${MAILLOG}" | "${PFLOGSUMM}" -h 0 -u 0 --no_bounce_detail --no_deferral_detail --no_reject_detail --no_smtpd_warnings --no_no_msg_size > "${TEMPFILE}" 2>/dev/null

        if [ ! $? -eq 0 ]; then
                result_text="ERROR: wrong exit code returned while running  \"${PYGTAIL}\" -o\"${PFOFFSETFILE}\" \"${MAILLOG}\" | \"${PFLOGSUMM}\" -h 0 -u 0 --no_bounce_detail --no_deferral_detail --no_reject_detail --no_smtpd_warnings --no_no_msg_size > \"${TEMPFILE}\" 2>/dev/null"
                result_code="1"
                write_result "${result_code}" "${result_text}"
        fi

        # update all values from pflogsumm summary
        for i in "${PFVALS[@]}"; do
                updatevalue "$i"
        done

        result_text="OK: statistics updated"
        result_code="0"
        write_result "${result_code}" "${result_text}"
	fi

rm "${TEMPFILE}"


done