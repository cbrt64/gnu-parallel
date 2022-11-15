#!/bin/bash

# SPDX-FileCopyrightText: 2021-2022 Ole Tange, http://ole.tange.dk and Free Software and Foundation, Inc.
#
# SPDX-License-Identifier: GPL-3.0-or-later

par_csv_not_installed() {
    echo '### Give error if CSV.pm is not installed when using --csv'
    sudo parallel mv {} {}.hidden ::: /usr/share/perl5/Text/CSV.pm
    stdout parallel --csv echo ::: this should give an error
    sudo parallel mv {}.hidden {} ::: /usr/share/perl5/Text/CSV.pm
}

par_sem_dir() {
    echo '### bug #58985: sem stall if .parallel/semaphores is chmod 0'
    chmod 0 ~/.parallel/semaphores
    sem echo
    chmod 700 ~/.parallel/semaphores
}

par_parcat_mixing() {
    echo 'parcat output should mix: a b a b'
    mktempfifo() {
	tmp=$(mktemp)
	rm $tmp
	mkfifo $tmp
	echo $tmp
    }
    slow_output() {
	string=$1
	perl -e 'print "'$string'"x9000,"start\n"'
	sleep 2
	perl -e 'print "'$string'"x9000,"end\n"'
    }
    tmp1=$(mktempfifo)
    tmp2=$(mktempfifo)
    slow_output a > $tmp1 &
    sleep 1
    slow_output b > $tmp2 &
    parcat $tmp1 $tmp2 | tr -s ab
}

par_tmux_termination() {
    echo '### --tmux test - check termination'
    doit() {
	perl -e 'map {printf "$_%o%c\n",$_,$_}1..255' |
	    stdout parallel --tmux 'sleep 0.2;echo {}' :::: - ::: a b |
	    perl -pe 's:(/tmp\S*/tms).....:$1XXXXX:;'
    }
    export -f doit
    stdout parallel --timeout 120 doit ::: 1
}

par_linebuffer_tag_slow_output() {
    echo "Test output tag with mixing halflines"
    halfline() {
	perl -e '$| = 1; map { print $ARGV[0]; sleep(1); print "$_\n" } split //, "Half\n"' $1
    }
    export -f halfline
    parallel --delay 0.5 -j0 --tag --line-buffer halfline ::: a b
}

par_distribute_input_by_ability() {
    echo "### bug #48290: round-robin does not distribute data based on business"
    echo "### Distribute input to jobs that are ready"
    echo "Job-slot n is 50% slower than n+1, so the order should be 1..7"
    seq 20000000 |
	parallel --tagstring {#} -j7 --block 300k --round-robin --pipe \
	'pv -qL{=$_=$job->seq()**3+9=}0000 |wc -c' |
	sort -nk2 | field 1
}

par_print_before_halt_on_error() {
    echo '### What is printed before the jobs are killed'
    mytest() {
	HALT=$1
	(echo 0.1;
	    echo 3.2;
	    seq 0 7;
	    echo 0.3;
	    echo 8) |
	    parallel --tag --delay 0.1 -j4 -kq --halt $HALT \
		     perl -e 'sleep 1; sleep $ARGV[0]; print STDERR "",@ARGV,"\n"; '$HALT' > 0 ? exit shift : exit not shift;' {};
	echo exit code $?
    }
    export -f mytest
    parallel -j0 -k --tag mytest ::: -2 -1 0 1 2
}

par_bug56403() {
    echo 'bug #56403: --pipe block by time.'
    (
	sleep 2; # make sure parallel is ready
	echo job1a;
	sleep 2;
	echo job2b;
	echo -n job3c;
	sleep 2;
	echo job3d
    ) | parallel --blocktimeout 1 -j1 --pipe --tagstring {#} -k cat
    (
	sleep 2; # make sure parallel is ready
	echo job1a;
	sleep 1;
	echo job1b;
	echo -n job2c;
	sleep 4;
	echo job2d
    ) | parallel --blocktimeout 3 -j1 --pipe --tagstring {#} -k cat

}

par_delay_Xauto() {
    echo 'TODO: --retries for those that fail and --sshdelay'
    echo '### bug #58911: --delay Xauto'
    tmp=$(mktemp)
    doit() {
	perl -e '$a=shift;
	     $m = -M $a < 0.0000001;
	     `touch $a`;
	     print "$m\n";
	     exit $m;' $1;
    }
    export -f doit
    before=`date +%s`
    out=$(seq 30 | parallel --delay 0.03 -q doit "$tmp")
    after=`date +%s`
    # Round to 5 seconds
    normaldiff=$(( (after-before)/5 ))
    echo $normaldiff
    
    before=`date +%s`
    out=$(seq 30 | parallel --delay 0.03auto -q doit "$tmp")
    after=`date +%s`
    autodiff=$(( (after-before)/5 ))
    echo $autodiff
    
    rm "$tmp"
}

export -f $(compgen -A function | grep par_)
compgen -A function | grep par_ | sort |
    #    parallel --joblog /tmp/jl-`basename $0` -j10 --tag -k '{} 2>&1'
        parallel --joblog /tmp/jl-`basename $0` -j1 --tag -k '{} 2>&1'
