#!/bin/sh

DATE=`date +'%Y-%m-%d-%H:%M:%S'`
LOGFILE="/tmp/backup.log"
BACKUPFILE="backup-${DATE}.tar.gz"
ACCOUNT="ds026@dsbackup.xs4all.nl"
KEEP_BACKUPS="7"

echo -n "" >"$LOGFILE"

do_error() {
	echo "!!! backup failed: $@" >>"$LOGFILE"
	cat "$LOGFILE" | while read LINE; do echo "  $LINE"; done
	exit 1;
}

do_command() {
	echo "*** running [$@]" >>"$LOGFILE"
	"$@" >>"$LOGFILE" 2>&1
	[ $? -ne 0 ] && do_error "$1 exited non-zero"
}

do_command tar -C / --exclude='var/www/www.finkproject.org/bindist' --exclude='var/www/distfiles' --show-omitted-dirs --totals -czf "/tmp/${BACKUPFILE}" etc home root var usr/local
do_command /usr/bin/rsync -av -e 'ssh -i /root/.ssh/id_nopass' "/tmp/${BACKUPFILE}" "$ACCOUNT":~/backups/
do_command rm "/tmp/${BACKUPFILE}"

# clear out old backup files
COUNT=0
for FILE in `ssh -i /root/.ssh/id_nopass "$ACCOUNT" ls -1 '~/backups/backup*.tar.gz' 2>/dev/null | sort -r`; do
	let COUNT="$COUNT + 1"
	if [ "$COUNT" -gt "$KEEP_BACKUPS" ]; then
		do_command ssh -i /root/.ssh/id_nopass "$ACCOUNT" rm "$FILE"
	fi
done

echo "*** done" >>"$LOGFILE"
