#!/bin/ksh

function plural
{
	if (( $1 == 1 )); then
		print ${2}
	else
		print ${2}s
	fi
}

function when
{
typeset -i relmajor relminor
 
(( secs = $(date +%s) - $(date --date="${1:?}" +%s) ))

(( OneMin = 60 ))
(( OneHour = OneMin*60 ))
(( OneDay = OneHour*24 ))

if (( secs < $OneHour )); then
	(( relmajor = secs / OneMin ))
	(( relminor = secs % OneMin ))
	print -- "$relmajor $(plural $relmajor minute) \\c"
#	(( relminor > 0 )) && print -- "and $relminor $(plural $relminor second) \\c"
	print "ago"
elif (( secs < $OneDay)); then
	(( relmajor = secs / OneHour ))
	(( relminor = (secs % OneHour) / OneMin ))
	print -- "$relmajor $(plural $relmajor hour) \\c"
	(( relminor > 0 )) && print -- "and $relminor $(plural $relminor minute) \\c"
	print "ago"
else
	(( relmajor = secs / OneDay ))
	(( relminor = (secs % OneDay) / OneHour ))
	print -- "$relmajor $(plural $relmajor day) \\c"
	(( relminor > 0 )) && print -- "and $relminor $(plural $relminor hour) \\c"
	print "ago"
fi
}

MAILBASE=~ubuntu/gmail
HTMLBASE=/var/www/html
URLBASE=https://mckserver.dyndns.org/cdn/inTouch
CDNBASE=$HTMLBASE/cdn/inTouch
FILTERCONF=~www-data/etc/inTouch.conf
POLLYCONF=~ubuntu/etc/awscreds.conf
AudioFile=$CDNBASE/ask$$.mp3
TmpFile=$CDNBASE/tmp$$
Silence=$CDNBASE/silence.mp3

typeset -l Member

Member=${1:?} Count=${2}
[ ! "$Count" ] && Count=0

trap "rm -f $TmpFile-*" HUP INT QUIT TERM EXIT

. $POLLYCONF

grep $Member, $FILTERCONF | IFS="," read x Filter x

cd $MAILBASE

[ "$Filter" ] && Playlist=$(
n=1
ls -1t -- *-$Filter.* 2>/dev/null | while read f
do
	[ $Count -gt 0 -a $n -gt $Count ] && break

	d=$f d=${d%-*} d=${d%:*} d=${d//-/ }
	m=$f m=${m%.*} m=${m##*-}

	grep $m, $FILTERCONF | IFS="," read x x v

	print $TmpFile-$n.mp3 $Silence

	case "$f" in

	*.txt)
		(print "<p>$(when "$d"), $m wrote:</p>"; cat $f) |
			AWS_VOICE=$v aws-polly.sh >$TmpFile-$n.mp3
		;;

	*.mp3)
		(print "<p>$(when "$d"), $m said:</p>") |
			AWS_VOICE=$v aws-polly.sh >$TmpFile-$n.mp3
		print $f
		;;

	esac

	(( ++n ))
done
)

print "<html><body>"

Suffix=""
[ "$Filter" != '*' ] && Suffix="from $Member"

if [ ! "$Playlist" ]; then
	print "<p>I'm sorry.  I didn't find any messages $Suffix.</p>"
else
	sox $Playlist $AudioFile
	n=$(ls -1t -- *-$Filter.* | wc -w)
	print "<p>I found $n $(plural $n message) $Suffix!</p><audio controls><source src="$URLBASE/${AudioFile##*/}"></audio>"
	
fi

print "</body></html>"
