#! /bin/bash
set -e

RSYNC=/usr/bin/rsync 
SSH=/usr/bin/ssh 
KEY=/user/.ssh/id_rsa
RUSER=user
RHOST=10.128.0.12
RPATH1=/etc/prometheus 
RPATH2=/home/user/artefacts
LPATH=/home/user/backup/monitoring

$RSYNC -avrzhHl -e "$SSH -i $KEY" $RUSER@$RHOST:$RPATH1 $RUSER@$RHOST:$RPATH2 $LPATH



