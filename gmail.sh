#!/bin/ksh

PATH=$PWD:$HOME/bin:$PATH

INBOX=$HOME/gmail
ADDRESSFILE=$HOME/etc/gmail.conf
TmpFile=tmp$$
TextFile="message.txt"
AudioFile="audio"
Date=$(date "+%Y%m%d-%H:%M:%S")
Seqno=$$

trap "rm -f $TmpFile $TextFile $AudioFile.*" HUP INT QUIT TERM EXIT

cd $INBOX

rm -f $TextFile $AudioFile.*
FromAddr=$(gmail.py $TextFile $AudioFile)
FromAddr=${FromAddr#*<}
FromAddr=${FromAddr%>*}

[[ $FromAddr == [0-9]* ]] && FromAddr=${FromAddr%@*}

grep $FromAddr, $ADDRESSFILE | IFS="," read x Member

[ ! "$Member" ] && exit

umask 022

AudioFile=$(ls $AudioFile.* 2>/dev/null)
if [ -f "$AudioFile" ]; then
	[ "${AudioFile#*.}" != mp3 ] && ffmpeg -i $AudioFile ${AudioFile%.*}.mp3 2>/dev/null
	sox ${AudioFile%.*}.mp3 -r16k "$Date:$Seqno-$Member.mp3"
	rm -f ${AudioFile%.*}.*

elif [ -f "$TextFile" ]; then
	recode -f html..ascii <$TextFile |
		sed -e "s/<[^>]\+>//g" -e "s/^[ 	]*//" -e "/^$/d" -e "/Multimedia/d" >$TmpFile
	mv $TmpFile "$Date:$Seqno-$Member.txt"
	rm -f $TextFile
fi
