#!/bin/bash

(
    cd vagrant/tange/centos3/
    vagrant up
)

par_warning_on_centos3() {
    echo "### bug #37589: Red Hat 9 (Shrike) perl v5.8.0 built for i386-linux-thread-multi error"
    testone() {
	sshlogin="$1"
	program="$2"
	basename="$3"
	scp "$program" "$sshlogin":/tmp/"$basename"
	stdout ssh "$sshlogin" perl /tmp/"$basename" echo \
	       ::: Old_must_fail_New_must_be_OK
    }
    export -f testone
    parallel --tag -k testone {1} {2} {2/} \
	     ::: vagrant@centos3 vagrant@rhel8 \
	     ::: /usr/local/bin/parallel-20120822 `which parallel`
}

export -f $(compgen -A function | grep par_)
compgen -A function | grep par_ | LC_ALL=C sort |
    parallel --timeout 1000% -j6 --tag -k --joblog /tmp/jl-`basename $0` '{} 2>&1' |
    perl -pe 's:/usr/bin:/bin:g;'

(
    cd vagrant/tange/centos3/
    vagrant suspend
)
