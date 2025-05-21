#! /bin/bash
set -e

RSYNC=/usr/bin/rsync 
SSH=/usr/bin/ssh 
KEY=/user/.ssh/id_rsa
RUSER=user
RHOST=10.128.0.10 
RPATH1=/home/user/easy-rsa
RPATH2=/home/user/artefacts
LPATH=/home/user/backup/ca

$RSYNC -avrzhHl -e "$SSH -i $KEY" $RUSER@$RHOST:$RPATH1 $RUSER@$RHOST:$RPATH2 $LPATH



