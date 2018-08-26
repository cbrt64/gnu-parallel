#!/bin/bash

# Check servers up on http://www.polarhome.com/service/status/
unset TIMEOUT
. `which env_parallel.bash`
env_parallel --session

P_ALL="openstep qnx pidora alpha tru64 hpux-ia64 syllable raspbian solaris openindiana aix hpux debian-ppc suse solaris-x86 mandriva ubuntu scosysv unixware centos miros macosx redhat netbsd openbsd freebsd debian dragonfly vax ultrix minix irix hurd beaglebone cubieboard2"
P="$P_ALL"

# 2018-04-22 MAXTIME=20
MAXTIME=25
RETRIES=4
MAXPROC=150

# select a running master (debian or ubuntu)
MASTER=$(parallel -j0 --halt now,success=1 ssh {} echo {} \
		  ::: {suse,ubuntu,debian}.polarhome.com)

parallel -j0 --delay 0.1 --retries $RETRIES \
	 rsync -a /usr/local/bin/{parallel,env_parallel,env_parallel.*[^~],parcat} \
	 ::: $MASTER:bin/

doit() {
    # Avoid the stupid /etc/issue.net banner at Polarhome: -oLogLevel=quiet
    PARALLEL_SSH="ssh -oLogLevel=quiet"
    export PARALLEL_SSH
    export MAXTIME
    export RETRIES
    export MAXPROC
    export RET_TIME_K="-k --retries $RETRIES --timeout $MAXTIME"
    
    echo MAXTIME=$MAXTIME RETRIES=$RETRIES MAXPROC=$MAXPROC

    echo '### Filter out working servers'
    POLAR="` bin/parallel -j0 $RET_TIME_K $PARALLEL_SSH {} echo {} ::: $P`"
    S_POLAR=`bin/parallel -j0 $RET_TIME_K echo -S 1/{} ::: $POLAR`
    
    copy() {
	# scp, but atomic (avoid half files if disconnected)
	host=$1
	src="$2"
	dst="$3"
	cat "$src" |
	    stdout ssh -oLogLevel=quiet $host "mkdir -p bin;cat > bin/'$dst'.tmp && chmod 755 bin/'$dst'.tmp && mv bin/'$dst'.tmp bin/'$dst'"
    }
    export -f copy
    
    par_nonall() {
	parallel -j$MAXPROC $RET_TIME_K --delay 0.1 --tag \
		 --nonall $S_POLAR --argsep ,:- \
		 'source setupenv >&/dev/null || . `pwd`/setupenv;' "$@"
    }
    export -f par_nonall

    echo '### Copy commands to servers'
    env_parallel -vj$MAXPROC $RET_TIME_K --delay 0.03 --tag copy {2} {1} {1/} \
	     ::: bin/{parallel,env_parallel,env_parallel.*[^~],parcat,stdout} \
	     ::: $POLAR
    echo Done copying

    echo
    echo '### Works on ...'
    echo
    par_nonall parallel echo Works on {} ::: '`hostname`' 2>&1

    # Test empty command
    test_empty_cmd() {
	echo '### Test if empty command in process list causes problems'
	perl -e '$0=" ";sleep 10' &
	parallel echo ::: OK_with_empty_cmd
    }
    export -f test_empty_cmd
    PARALLEL='--env test_empty_cmd' par_nonall test_empty_cmd 2>&1

    echo
    echo '### Fails if tmpdir is R/O'
    echo
    par_nonall "stdout parallel --tmpdir / echo ::: test read-only tmp |" \
	       "perl -pe '\$exit += s:/[a-z0-9_]+.arg:/XXXXXXXX.arg:gi; \$exit += s/[0-9][0-9][0-9][0-9]/0000/gi; END { exit not \$exit }' &&" \
	       "echo OK readonly tmp" 2>&1

    echo
    echo '### --number-of-cores/--number-of-cpus should work with no error'
    echo
    par_nonall parallel --number-of-sockets 2>&1
    par_nonall parallel --number-of-cores 2>&1
    par_nonall parallel --number-of-threads 2>&1
    par_nonall parallel --number-of-cpus 2>&1

    echo
    echo '### Does exporting a bash function kill parallel'
    echo
    # http://zmwangx.github.io/blog/2015-11-25-bash-function-exporting-fiasco.html
    par_nonall 'func() { cat <(echo bash only A); };export -f func; bin/parallel func ::: 1' 2>&1

    echo
    echo '### Does PARALLEL_SHELL help exporting a bash function not kill parallel'
    echo
    (
	mkdir -p tmp/bin;
	cp /bin/bash tmp/bin
	cd tmp
	PARALLEL_SHELL=bin/bash par_nonall 'func() { cat <(echo bash only B); };export -f func; bin/parallel func ::: 1'
    )

    echo
    echo '### env_parallel echo :::: <(echo OK)'
    echo '(bash ksh mksh zsh only)'
    echo
    par_nonall 'bin/env_parallel --install && echo install-OK' 2>&1
    par_nonall 'env_parallel echo env_parallel ::: run-OK' 2>&1
    par_nonall 'env_parallel echo reading from process substitution :::: <(echo OK)' |
	# csh on NetBSD does not support process substitution
	grep -v ': /tmp/.*: No such file or directory'

    echo
    echo '### parset arr seq ::: 2 3 4'
    echo '(bash ksh mksh zsh only)'
    echo
    par_nonall 'parset arr seq ::: 2 3 4; echo ${arr[*]}' 2>&1
    echo '### env_parset arr seq ::: 2 3 4'
    par_nonall 'start=2;env_parset arr seq \$start ::: 2 3 4; echo ${arr[*]}' 2>&1

    echo
    echo '### parset var1,var2,var3 seq ::: 2 3 4'
    echo '(bash ksh mksh zsh ash dash only)'
    echo
    par_nonall 'parset var1,var2,var3 seq ::: 2 3 4; echo $var1,$var2,$var3' 2>&1
    echo '### env_parset var1,var2,var3 seq ::: 2 3 4'
    par_nonall 'start=2; env_parset var1,var2,var3 seq \$start ::: 2 3 4; echo $var1,$var2,$var3' 2>&1
}

env_parallel -u -S$MASTER doit ::: 1

# eval 'myfunc() { echo '$(perl -e 'print "x"x20000')'; }'
# env_parallel myfunc ::: a | wc # OK
# eval 'myfunc2() { echo '$(perl -e 'print "x"x120000')'; }'
# env_parallel myfunc ::: a | wc # Fail too big env
