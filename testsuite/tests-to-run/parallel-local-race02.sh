#!/bin/bash

# These fail regularly

#par_ctrlz_should_suspend_children() {
    echo 'bug #46120: Suspend should suspend (at least local) children'
    echo 'it should burn 1.9 CPU seconds, but no more than that'
    echo 'The 5 second sleep will make it be killed by timeout when it fgs'
    stdout bash -i -c 'stdout /usr/bin/time -f CPUTIME=%U parallel --timeout 5 -q perl -e "while(1){ }" ::: 1 | \grep -q CPUTIME=1 &
      sleep 1.9;
      kill -TSTP -$!;
      sleep 5;
      fg;
      echo Zero=OK $?' | grep -v '\[1\]' | grep -v 'SHA256'

    stdout bash -i -c 'echo 1 | stdout /usr/bin/time -f CPUTIME=%U parallel --timeout 5 -q perl -e "while(1){ }" | \grep -q CPUTIME=1 &
      sleep 1.9;
      kill -TSTP -$!;
      sleep 5;
      fg;
      echo Zero=OK $?' | grep -v '\[1\]' | grep -v 'SHA256'

    echo Control case: Burn for 2.9 seconds
    stdout bash -i -c 'stdout /usr/bin/time -f CPUTIME=%U parallel --timeout 5 -q perl -e "while(1){ }" ::: 1 | \grep -q CPUTIME=1 &
      sleep 2.9;
      kill -TSTP -$!;
      sleep 5;
      fg;
      echo 1=OK $?' | grep -v '\[1\]' | grep -v 'SHA256'
#}

par_parcat_mixing() {
    echo 'parcat output should mix: a b a b'
    mktmpfifo() {
	tmp=$(tempfile)
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
    tmp1=$(mktmpfifo)
    tmp2=$(mktmpfifo)
    slow_output a > $tmp1 &
    sleep 1
    slow_output b > $tmp2 &
    parcat $tmp1 $tmp2 | tr -s ab
}

par_testhalt() {
    testhalt_false() {
	echo '### testhalt --halt '$1;
	(yes 0 | head -n 10; seq 10) |
	    stdout parallel -kj4 --delay 0.27 --halt $1 \
		   'echo job {#}; sleep {= $_=0.3*($_+1+seq()) =}; exit {}'; echo $?;
    }
    testhalt_true() {
	echo '### testhalt --halt '$1;
	(seq 10; yes 0 | head -n 10) |
	    stdout parallel -kj4 --delay 0.17 --halt $1 \
		   'echo job {#}; sleep {= $_=0.3*($_+1+seq()) =}; exit {}'; echo $?;
    };
    export -f testhalt_false;
    export -f testhalt_true;

    stdout parallel -kj0 --delay 0.11 --tag testhalt_{4} {1},{2}={3} \
	::: now soon ::: fail success done ::: 0 1 2 30% 70% ::: true false |
	# Remove lines that only show up now and then
	perl -ne '/Starting no more jobs./ or print'
}

par_hostgroup() {
    echo '### --hostgroup force ncpu'
    parallel --delay 0.1 --hgrp -S @g1/1/parallel@lo -S @g2/3/lo whoami\;sleep 0.4{} ::: {1..8} | sort

    echo '### --hostgroup two group arg'
    parallel -k --sshdelay 0.1 --hgrp -S @g1/1/parallel@lo -S @g2/3/lo whoami\;sleep 0.3{} ::: {1..8}@g1+g2 | sort

    echo '### --hostgroup one group arg'
    parallel --delay 0.2 --hgrp -S @g1/1/parallel@lo -S @g2/3/lo whoami\;sleep 0.4{} ::: {1..8}@g2

    echo '### --hostgroup multiple group arg + unused group'
    parallel --delay 0.2 --hgrp -S @g1/1/parallel@lo -S @g1/3/lo -S @g3/100/tcsh@lo whoami\;sleep 0.8{} ::: {1..8}@g1+g2 | sort

    echo '### --hostgroup two groups @'
    parallel -k --hgrp -S @g1/parallel@lo -S @g2/lo --tag whoami\;echo ::: parallel@g1 tange@g2

    echo '### --hostgroup'
    parallel -k --hostgroup -S @grp1/lo echo ::: no_group explicit_group@grp1 implicit_group@lo

    echo '### --hostgroup --sshlogin with @'
    parallel -k --hostgroups -S parallel@lo echo ::: no_group implicit_group@parallel@lo

    echo '### --hostgroup -S @group'
    parallel -S @g1/ -S @g1/1/tcsh@lo -S @g1/1/localhost -S @g2/1/parallel@lo whoami\;true ::: {1..6} | sort

    echo '### --hostgroup -S @group1 -Sgrp2'
    parallel -S @g1/ -S @g2 -S @g1/1/tcsh@lo -S @g1/1/localhost -S @g2/1/parallel@lo whoami\;true ::: {1..6} | sort

    echo '### --hostgroup -S @group1+grp2'
    parallel -S @g1+g2 -S @g1/1/tcsh@lo -S @g1/1/localhost -S @g2/1/parallel@lo whoami\;true ::: {1..6} | sort
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

par_continuous_output() {
    # After the first batch, each jobs should output when it finishes.
    # Old versions delayed output by $jobslots jobs
    doit() {
	echo "Test delayed output with '$1'"
	echo "-u is optimal but hard to reach, due to non-mixing"
	seq 10 |
	    parallel -j1 $1 --delay 1 -N0 echo |
	    parallel -j4 $1 -N0 'sleep 0.6;date' |
	    timestamp -dd |
	    perl -pe 's/(.).*/$1/'
    }
    export -f doit
    parallel -k doit ::: '' -u
}

export -f $(compgen -A function | grep par_)
compgen -A function | grep par_ | sort |
    #    parallel --joblog /tmp/jl-`basename $0` -j10 --tag -k '{} 2>&1'
        parallel --joblog /tmp/jl-`basename $0` -j1 --tag -k '{} 2>&1'
