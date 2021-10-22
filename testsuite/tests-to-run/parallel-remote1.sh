#!/bin/bash

# SPDX-FileCopyrightText: 2021 Ole Tange, http://ole.tange.dk and Free Software and Foundation, Inc.
#
# SPDX-License-Identifier: GPL-3.0-or-later

SERVER1=parallel-server1
SERVER2=parallel-server2
SERVER3=parallel-server3
SSHUSER1=vagrant
SSHUSER2=vagrant
SSHUSER3=vagrant
export SSHLOGIN1=$SSHUSER1@$SERVER1
export SSHLOGIN2=$SSHUSER2@$SERVER2
export SSHLOGIN3=$SSHUSER3@$SERVER3

#SERVER1=parallel-server1
#SERVER2=lo
#SSHLOGIN1=parallel@parallel-server1
#SSHLOGIN2=parallel@lo
#SSHLOGIN3=parallel@parallel-server2

par_special_ssh() {
    echo '### Test use special ssh'
    echo 'TODO test ssh with > 9 simultaneous'
    echo 'ssh "$@"; echo "$@" >>/tmp/myssh1-run' >/tmp/myssh1
    echo 'ssh "$@"; echo "$@" >>/tmp/myssh2-run' >/tmp/myssh2
    chmod 755 /tmp/myssh1 /tmp/myssh2
    seq 1 100 | parallel --sshdelay 0.03 --retries 10 --sshlogin "/tmp/myssh1 $SSHLOGIN1,/tmp/myssh2 $SSHLOGIN2" -k echo
}

par_filter_hosts_different_errors() {
    echo '### --filter-hosts - OK, non-such-user, connection refused, wrong host'
    stdout parallel --nonall --filter-hosts -S localhost,NoUser@localhost,154.54.72.206,"ssh 5.5.5.5" hostname |
	grep -v 'parallel: Warning: Removed'
}

par_timeout_retries() {
    echo '### test --timeout --retries'
    stdout parallel -j0 --timeout 5 --retries 3 -k ssh {} echo {} \
	   ::: 192.168.1.197 8.8.8.8 $SSHLOGIN1 $SSHLOGIN2 $SSHLOGIN3 |
	grep -v 'Warning: Permanently added'
}

par_filter_hosts_no_ssh_nxserver() {
    echo '### test --filter-hosts with server w/o ssh, non-existing server'
    stdout parallel -S 192.168.1.197,8.8.8.8,$SSHLOGIN1,$SSHLOGIN2,$SSHLOGIN3 --filter-hosts --nonall -k --tag echo |
	grep -v 'parallel: Warning: Removed'
}

par_controlmaster_is_faster() {
    echo '### bug #41964: --controlmaster not seems to reuse OpenSSH connections to the same host'
    (parallel -S $SSHLOGIN1 true ::: {1..20};
     echo No --controlmaster - finish last) & 
    (parallel -M -S $SSHLOGIN1 true ::: {1..20};
     echo With --controlmaster - finish first) & 
    wait
}

par_workdir_in_HOME() {
    echo '### test --workdir . in $HOME'
    cd && mkdir -p parallel-test && cd parallel-test && 
	echo OK > testfile &&
	stdout parallel --workdir . --transfer -S $SSHLOGIN1 cat {} ::: testfile |
	    grep -v 'Permanently added'
}

export -f $(compgen -A function | grep par_)
compgen -A function | grep par_ | LC_ALL=C sort |
    parallel --timeout 1000% -j6 --tag -k --joblog /tmp/jl-`basename $0` '{} 2>&1' |
    perl -pe 's:/usr/bin:/bin:g'

  
cat <<'EOF' | sed -e s/\$SERVER1/$SERVER1/\;s/\$SERVER2/$SERVER2/\;s/\$SSHLOGIN1/$SSHLOGIN1/\;s/\$SSHLOGIN2/$SSHLOGIN2/\;s/\$SSHLOGIN3/$SSHLOGIN3/ | parallel -vj3 -k -L1 -r




echo '### TODO: test --filter-hosts proxied through the one host'


EOF
rm /tmp/myssh1 /tmp/myssh2 /tmp/myssh1-run /tmp/myssh2-run

