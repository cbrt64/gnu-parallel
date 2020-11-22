#!/bin/bash

echo "### These tests requires VirtualBox running with the following images"
echo 'vagrant@centos3'

SERVER1=centos3
SSHUSER1=vagrant
SSHLOGIN1=$SSHUSER1@$SERVER1
# server with shellshock hardened bash
SERVER2=172.27.27.1
SSHUSER2=parallel
export SSHLOGIN2=$SSHUSER2@$SERVER2

stdout ping -w 1 -c 1 centos3 >/dev/null || (
    # Vagrant does not set the IP addr
    cd testsuite/vagrant/tange/centos3/ 2>/dev/null
    cd vagrant/tange/centos3/ 2>/dev/null
    cd ../vagrant/tange/centos3/ 2>/dev/null
    stdout vagrant up >/dev/null
    vagrant ssh -c 'sudo ifconfig eth1 172.27.27.3' |
	# Ignore empty ^M line
	grep ..
)
(
    # Copy binaries to server
    cd testsuite/vagrant/tange/centos3/ 2>/dev/null
    cd vagrant/tange/centos3/ 2>/dev/null
    cd ../vagrant/tange/centos3/ 2>/dev/null
    cd ../../../..
    scp -q .*/src/{parallel,sem,sql,niceload,env_parallel*} $SSHLOGIN1:bin/
    ssh $SSHLOGIN1 'touch .parallel/will-cite; mkdir -p bin'
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
