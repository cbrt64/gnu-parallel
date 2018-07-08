#!/bin/bash

# Simple jobs that never fails
# Each should be taking >100s and be possible to run in parallel
# I.e.: No race conditions, no logins

# tmpdir with > 5 GB available
TMP5G=${TMP5G:-/dev/shm}
export TMP5G

rm -f /tmp/*.{tmx,pac,arg,all,log,swp,loa,ssh,df,pip,tmb,chr,tms,par}

par_exit_code() {
    echo 'bug #52207: Exit status 0 when child job is killed, even with "now,fail=1"'
    in_shell_run_command() {
	# Runs command in given shell via Perl's open3
	shell="$1"
	prg="$2"
	perl -MIPC::Open3 -e 'open3($a,$b,$c,"'$shell'","-c","'"$prg"'"); wait; print $?>>8,"\n"'
    }
    export -f in_shell_run_command

    runit() {
	OK="ash bash csh dash fish mksh posh rc sash sh static-sh tcsh"
	BAD="fdsh fizsh ksh ksh93 yash zsh"
	s=100
	cp /bin/sleep /tmp/mysleep
	
	echo '# Ideally the command should return the same'
	echo '#   with or without parallel'
	echo '# but fish 2.4.0 returns 1 while X.X.X returns 0'
	parallel -kj500% --argsep ,, --tag in_shell_run_command {1} '{=2 $_=Q($_) =}' \
		 ,, $OK $BAD ,, \
	'/tmp/mysleep '$s \
	'parallel --halt-on-error now,fail=1 /tmp/mysleep ::: '$s \
	'parallel --halt-on-error now,done=1 /tmp/mysleep ::: '$s \
	'parallel --halt-on-error now,done=1 true ::: '$s \
	'parallel --halt-on-error now,done=1 exit ::: '$s \
	'true;/tmp/mysleep '$s \
	'parallel --halt-on-error now,fail=1 "true;/tmp/mysleep" ::: '$s \
	'parallel --halt-on-error now,done=1 "true;/tmp/mysleep" ::: '$s \
	'parallel --halt-on-error now,done=1 "true;true" ::: '$s \
	'parallel --halt-on-error now,done=1 "true;exit" ::: '$s
    }
    export -f runit

    killsleep() {
	sleep 5
	while true; do killall -9 mysleep 2>/dev/null; sleep 1; done
    }
    export -f killsleep

    parallel -uj0 --halt now,done=1 ::: runit killsleep
}

par_retries_unreachable() {
  echo '### Test of --retries on unreachable host'
  seq 2 | stdout parallel -k --retries 2 -v -S 4.3.2.1,: echo
}

par_outside_file_handle_limit() {
    ulimit -n 1024
    echo "### Test Force outside the file handle limit, 2009-02-17 Gave fork error"
    (echo echo Start; seq 1 20000 | perl -pe 's/^/true /'; echo echo end) |
	stdout parallel -uj 0 | egrep -v 'processes took|adjusting' |
	perl -pe 's/\d\d\d/999/'
}

par_over_4GB() {
    echo '### Test if we can deal with output > 4 GB'
    echo |
	nice parallel --tmpdir $TMP5G -q perl -e '$a="x"x1000000;for(0..4300){print $a}' |
	nice md5sum
}

par_mem_leak() {
    echo "### test for mem leak"

    export parallel=parallel
    no_mem_leak() {
	run_measurements() {
	    from=$1
	    to=$2
	    pause_every=$3
	    measure() {
		# Input:
		#   $1 = iterations
		#   $2 = sleep 1 sec for every $2
		seq $1 | ramusage $parallel -u sleep '{= $_=$_%'$2'?0:1 =}'
	    }
	    export -f measure

	    seq $from $to | $parallel measure {} $pause_every |
    		sort -n
	}

	# Return false if leaking
	# Normal: 16940-17320
	max1000=$(run_measurements 1000 1007 100000 | tail -n1)
	min30000=$(run_measurements 15000 15004 100000 | head -n1)
	if [ $max1000 -gt $min30000 ] ; then
	    echo Probably no leak $max1000 -gt $min30000
	    return 0
	else
	    echo Probably leaks $max1000 not -gt $min30000
	    # Make sure there are a few sleeps
	    max1000=$(run_measurements 1001 1007 100 | tail -n1)
	    min30000=$(run_measurements 30000 30004 100 | head -n1)
	    if [ $max1000 -gt $min30000 ] ; then
		echo $max1000 -gt $min30000 = very likely no leak
		return 0
	    else
		echo not $max1000 -gt $min30000 = very likely leak
		return 1
	    fi
	fi
    }

    renice -n 3 $$ 2>/dev/null >/dev/null
    if no_mem_leak >/dev/null ; then
	echo no mem leak detected
    else
	echo possible mem leak;
    fi
}

par_timeout() {
    echo "### test --timeout"
    stdout time -f %e parallel --timeout 1s sleep ::: 10 |
	perl -ne '1 < $_ and $_ < 10 and print "OK\n"'
    stdout time -f %e parallel --timeout 1m sleep ::: 100 |
	perl -ne '10 < $_ and $_ < 100 and print "OK\n"'
}

par_halt_on_error() {
    mytest() {
	HALT=$1
	BOOL1=$2
	BOOL2=$3
	(echo "sleep 1;$BOOL1";
	    echo "sleep 2;$BOOL2";
	    echo "sleep 3;$BOOL1") |
	parallel -j10 --halt-on-error $HALT
	echo $?
	(echo "sleep 1;$BOOL1";
	    echo "sleep 2;$BOOL2";
	    echo "sleep 3;$BOOL1";
	    echo "sleep 4;non_exist";
	) |
	parallel -j10 --halt-on-error $HALT
	echo $?
    }
    export -f mytest
    parallel -j1 -k --tag mytest ::: -2 -1 0 1 2 ::: true false ::: true false
}

par_test_build_and_install() {
    cd ~/privat/parallel
    # Make a .tar.gz file
    stdout make dist |
	perl -pe 's/make\[\d\]/make[0]/g;s/\d{8}/00000000/g'
    LAST=$(ls *tar.gz | tail -n1)

    cd /tmp
    rm -rf parallel-20??????/
    tar xf ~/privat/parallel/$LAST
    cd parallel-20??????/

    echo "### Test normal build and install"
    # Make sure files depending on *.pod have to be rebuilt
    touch src/*pod src/sql
    ./configure &&
	sudo stdout nice make install |
	    perl -pe 's/make\[\d\]/make[0]/g;s/\d{8}/00000000/g'

    echo '### Test installation missing pod2*'
    parallel which ::: pod2html pod2man pod2texi pod2pdf |
	sudo parallel mv {} {}.hidden
    # Make sure files depending on *.pod have to be rebuilt
    touch src/*pod src/sql
    ./configure &&
	sudo stdout nice make install |
	    perl -pe 's/make\[\d\]/make[0]/g;s/\d{8}/00000000/g'

    parallel which {}.hidden ::: pod2html pod2man pod2texi pod2pdf |
	sudo parallel mv {} {.}
}

export -f $(compgen -A function | grep par_)
compgen -A function | grep par_ | sort | parallel -vj0 -k --tag --joblog /tmp/jl-`basename $0` '{} 2>&1'
