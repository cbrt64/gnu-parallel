#!/bin/bash

# SPDX-FileCopyrightText: 2021-2022 Ole Tange, http://ole.tange.dk and Free Software and Foundation, Inc.
#
# SPDX-License-Identifier: GPL-3.0-or-later

echo "### These tests requires VirtualBox running with the following images"
echo 'vagrant@centos3'

# add this to .ssh/config
#   Host centos3
#     HostKeyAlgorithms +ssh-rsa,ssh-dss
#     PubkeyAcceptedAlgorithms +ssh-dss
#     user vagrant

# add this to: /etc/ssh/sshd_config on 172.27.27.1
#   HostKeyAlgorithms +ssh-rsa
# and:
#   systemctl restart sshd

SERVER1=centos3
SSHUSER1=vagrant
SSHLOGIN1=$SSHUSER1@$SERVER1
# server with shellshock hardened bash
SERVER2=172.27.27.1
SSHUSER2=parallel
export SSHLOGIN2=$SSHUSER2@$SERVER2

start_centos3() {
    stdout ping -w 1 -c 1 centos3 >/dev/null || (
	# Vagrant does not set the IP addr
	cd testsuite/vagrant/tange/centos3/ 2>/dev/null
	cd vagrant/tange/centos3/ 2>/dev/null
	cd ../vagrant/tange/centos3/ 2>/dev/null
	vagrantssh() {
	    port=$(perl -ne '/#/ and next; /config.vm.network.*host:\s*(\d+)/ and print $1' Vagrantfile)
	    w4it-for-port-open localhost $port
	    ssh -oKexAlgorithms=+diffie-hellman-group1-sha1 \
		-oHostKeyAlgorithms=+ssh-rsa,ssh-dss \
		-oPubkeyAcceptedAlgorithms=+ssh-dss -p$port vagrant@localhost "$@" |
		# Ignore empty ^M line
		grep ..
	}
	stdout vagrant up >/dev/null &
	(sleep 10; stdout vagrant up >/dev/null ) &
	vagrantssh 'sudo /sbin/ifconfig eth1 172.27.27.3; echo centos3: added 172.27.27.3 >&2'
    )
}
start_centos3

(
    # Copy binaries to server
    cd testsuite/vagrant/tange/centos3/ 2>/dev/null
    cd vagrant/tange/centos3/ 2>/dev/null
    cd ../vagrant/tange/centos3/ 2>/dev/null
    cd ../../../..
    ssh $SSHLOGIN1 'mkdir -p .parallel bin; touch .parallel/will-cite'
    scp -q .*/src/{parallel,sem,sql,niceload,env_parallel*} $SSHLOGIN1:bin/
    ssh $SSHLOGIN1 'echo PATH=\$PATH:\$HOME/bin >> .bashrc'
    # Allow login from centos3 to $SSHLOGIN2 (that is shellshock hardened)
    ssh $SSHLOGIN1 cat .ssh/id_rsa.pub | ssh $SSHLOGIN2 'cat >>.ssh/authorized_keys'
    ssh $SSHLOGIN1 'cat .ssh/id_rsa.pub >>.ssh/authorized_keys; chmod 600 .ssh/authorized_keys'
    ssh $SSHLOGIN1 'ssh -o StrictHostKeyChecking=no localhost true; ssh -o StrictHostKeyChecking=no '$SSHLOGIN2' true;'
) &

. `which env_parallel.bash`
env_parallel --session

par_shellshock_bug() {
    bash -c 'echo bug \#43358: shellshock breaks exporting functions using --env name;
      echo Non-shellshock-hardened to non-shellshock-hardened;
      funky() { echo Function $1; };
      export -f funky;
      PARALLEL_SHELL=bash parallel --env funky -S localhost funky ::: non-shellshock-hardened'

    bash -c 'echo bug \#43358: shellshock breaks exporting functions using --env name;
      echo Non-shellshock-hardened to shellshock-hardened;
      funky() { echo Function $1; };
      export -f funky;
      PARALLEL_SHELL=bash parallel --env funky -S '$SSHLOGIN2' funky ::: shellshock-hardened'
}

#   As the copied environment is written in Bash dialect
#   we get 'shopt'-errors and 'declare'-errors.
#   We can safely ignore those.
export LC_ALL=C
export TMPDIR=/tmp
env_parallel --env par_shellshock_bug --env LC_ALL --env SSHLOGIN2 --env _ \
	     -vj9 -k --joblog /tmp/jl-`basename $0` --retries 3 \
	     -S $SSHLOGIN1 --tag '{} 2>&1' \
	     ::: $(compgen -A function | grep par_ | sort) \
	     2> >(grep -Ev 'shopt: not found|declare: not found|No xauth data')
