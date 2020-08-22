#!/bin/bash

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

par_shellshock() {
    # Bash on centos3 is non-shellshock-hardened
    echo '### bug #43358: shellshock breaks exporting functions using --env'
    echo shellshock-hardened to shellshock-hardened
    funky() { echo Function $1; }
    export -f funky
    parallel --env funky -S parallel@localhost funky ::: shellshock-hardened

    echo '2bug #43358: shellshock breaks exporting functions using --env'
    echo shellshock-hardened to non-shellshock-hardened
    funky() { echo Function $1; }
    export -f funky
    parallel --env funky -S centos3 funky ::: non-shellshock-hardened
}

export -f $(compgen -A function | grep par_)
compgen -A function | grep par_ | LC_ALL=C sort |
    parallel --timeout 1000% -j6 --tag -k --joblog /tmp/jl-`basename $0` '{} 2>&1' |
    perl -pe 's:/usr/bin:/bin:g;'
