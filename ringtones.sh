#!/bin/ksh

PATH=$PATH:/usr/sbin:/usr/local/bin

trap "" HUP INT QUIT

CDRFILE=/tmp/cdr.txt
RINGTONE=/tmp/ringtone.mp3
RINGPID=/tmp/ringpid.txt
CONFFILE=/usr/local/etc/ringtones.conf
AWSCREDS=/usr/local/etc/awscreds.conf
SOCKFILE=/var/run/asterisk/asterisk.ctl

while [ \! -e $SOCKFILE ]
do
	sleep 10
done

. $AWSCREDS

asterisk -x "core waitfullybooted"
asterisk -x "dialplan remove extension 6000@default"
asterisk -x 'dialplan add extension 6000,1,System(/bin/echo\ \"${STRFTIME(${EPOCH},,%m%d%Y-%H:%M:%S)}\"\ \"${CALLERID(all)}\"\ >>/tmp/cdr.txt) into default replace'

>$CDRFILE; chmod 777 $CDRFILE

tail -f $CDRFILE | while read cdr
do
	[ -f $RINGPID ] && kill $(<$RINGPID) >/dev/null 2>&1
	rm -f $RINGTONE $RINGPID

	cdr=${cdr#*<} cdr=${cdr%>*}

	[ ! "$cdr" ] && continue

	[[ $cdr == 0* ]] && continue

	grep "^$cdr" $CONFFILE | IFS=, read number voice ringtone

	if [ "$ringtone" ]; then
		print "$ringtone" | AWS_VOICE=$voice aws-polly.sh >$RINGTONE
	else
		print "Call from $(print "$cdr" | sed -e "s/./& /g")" | aws-polly.sh >$RINGTONE
	fi

	(
		loop=4; while (( loop-- > 0 ))
		do
			play $RINGTONE vol 2.0 >/dev/null 2>&1; sleep 3
		done
		rm -f $RINGTONE $RINGPID
	) &

	print "$!" >$RINGPID
done
