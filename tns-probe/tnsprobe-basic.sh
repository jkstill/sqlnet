#!/bin/bash

TESTMODE=0
TIMEOUT_DURATION=.5

# assumed Oracle Env ie already set

#. oraenv <<< ORCL

declare -a domainList

domainList[0]='192.168.1'
#domainList[1]='192.168.2'
#domainList[2]='192.168.3'

logFile=tnslist-$(date +'%Y%m%d-%H%M%S').log
listenerPort=1521

di=0

> $logFile


if [ $TESTMODE -gt 0 ]; then
	maxDomain=1
	serverMin=99
	serverMax=101
else
	maxDomain=${#domainList[*]}
	serverMin=2
	serverMax=254
fi

while [[ $di -lt $maxDomain ]]
do
	#echo Domain: ${domainList[$di]}
	for octet in $(seq $serverMin $serverMax )
	do
		address=${domainList[$di]}.${octet}
		#echo Address: $address

		# check if server exists - give it 2 seconds
		echo -n "checking $address "
		ping -c 1 -W 1 $address >/dev/null
		exists=$?
		remoteHost=''
		if [[ $exists -eq 0 ]]; then
			echo -n " - checking nslookup"
			#remoteHost=$(nslookup -query=alias $address | grep 'name.*=' | head -1|  cut -f2 -d= | sed -e 's/ //g' | sed -e 's/\.$//')
			# for less ambiguous output
			remoteHost=$(dig -x $address +short |  sed -e 's/\.$//')
		fi

		if [ $TESTMODE -gt 0 ]; then
			echo "Remote: $remoteHost"
		fi

		if [[ -n $remoteHost ]]; then
			#	now just look for listener on port 1521
			# or a range of ports
			echo -n " - checking tnsping"

			for tnsport in $(seq 1500 1599)
			do
				#port=$listenerPort
				port=$tnsport

				# using timeout as this query can take a long time
				#timeout 1 tnsping ${address}:${port} > /dev/null 2>&1
				#tnsping ${address}:${port} > /dev/null 2>&1
				# timeout accepts a floating point argument for DURATION, so .5 could be used instead of 1 second
				timeout $TIMEOUT_DURATION tnsping "(ADDRESS=(PROTOCOL=TCP)(HOST=${address})(PORT=${port}))" > /dev/null 2>&1
				found=$?
	
				if [[ $found -eq 0 ]]; then
					echo "$address:$remoteHost:$port" | tee -a $logFile
				fi
			done

		fi

		echo

	done

	(( di++ ))

done
