#!/bin/bash

# SPDX-FileCopyrightText: 2021-2022 Ole Tange, http://ole.tange.dk and Free Software and Foundation, Inc.
#
# SPDX-License-Identifier: GPL-3.0-or-later

SERVER1=parallel-server1
SERVER2=parallel-server2
SSHUSER1=vagrant
SSHUSER2=vagrant
SSHLOGIN1=$SSHUSER1@$SERVER1
SSHLOGIN2=$SSHUSER2@$SERVER2

echo '### Test -M (--retries to avoid false errors)'

seq 1 30 | parallel -j5 --retries 3 -k -M -S $SSHLOGIN1,$SSHLOGIN2 echo 2>/dev/null
seq 1 30 | parallel -j10 --retries 3 -k -M -S $SSHLOGIN1,$SSHLOGIN2 echo 2>/dev/null
