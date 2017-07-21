#!/bin/bash

# Simple jobs that never fails
# Each should be taking >100s and be possible to run in parallel
# I.e.: No race conditions, no logins

# tmpdir with > 5 GB available
TMP5G=${TMP5G:-/dev/shm}
export TMP5G

rm -f /tmp/*.{tmx,pac,arg,all,log,swp,loa,ssh,df,pip,tmb,chr,tms,par}

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

    no_mem_leak() {
	measure() {
	    # Input:
	    #   $1 = iterations
	    #   $2 = sleep 1 sec for every $2
	    seq $1 | ramusage parallel -u sleep '{= $_=$_%'$2'?0:1 =}'
	}
	export -f measure
	
	# Return false if leaking
	max1000=$(parallel measure {} 100000 ::: 1000 1000 1000 1000 1000 1000 1000 1000 |
    			 sort -n | tail -n 1)
	min30000=$(parallel measure {} 100000 ::: 3000 3000 3000 |
    			  sort -n | head -n 1)
	if [ $max1000 -gt $min30000 ] ; then
	    # Make sure there are a few sleeps
	    max1000=$(parallel measure {} 100 ::: 1000 1000 1000 1000 1000 1000 1000 1000 |
			     sort -n | tail -n 1)
	    min30000=$(parallel measure {} 100 ::: 3000 3000 3000 |
			      sort -n | head -n 1)
	    if [ $max1000 -gt $min30000 ] ; then
		echo $max1000 -gt $min30000 = no leak
		return 0
	    else
		echo not $max1000 -gt $min30000 = possible leak
		return 1
	    fi
	else
	    echo not $max1000 -gt $min30000 = possible leak
	    return 1
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


export -f $(compgen -A function | grep par_)
compgen -A function | grep par_ | sort | parallel -vj0 -k --tag --joblog /tmp/jl-`basename $0` '{} 2>&1'
