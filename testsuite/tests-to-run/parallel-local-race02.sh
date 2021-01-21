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

par_sql_CSV() {
    echo '### CSV write to the right place'
    rm -rf /tmp/parallel-CSV
    mkdir /tmp/parallel-CSV
    parallel --sqlandworker csv:///%2Ftmp%2Fparallel-CSV/OK echo ::: 'ran OK'
    ls /tmp/parallel-CSV
    stdout parallel --sqlandworker csv:///%2Fmust%2Ffail/fail echo ::: 1 |
	perl -pe 's/\d/0/g'
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

par_PARALLEL_RSYNC_OPTS() {
    echo '### test rsync opts'
    touch parallel_rsync_opts.test
    parallel --rsync-opts -rlDzRRRR -vv -S parallel@lo --trc {}.out touch {}.out ::: parallel_rsync_opts.test |
	perl -ne 's/(rsync .*?RRRR)/print $1/ge'
    export PARALLEL_RSYNC_OPTS=-zzrrllddRRRR
    parallel -vv -S parallel@lo --trc {}.out touch {}.out ::: parallel_rsync_opts.test |
	perl -ne 's/(rsync .*?RRRR)/print $1/ge'
    rm parallel_rsync_opts.test parallel_rsync_opts.test.out
    echo
}

par_retries_bug_from_2010() {
    echo '### Bug with --retries'
    seq 1 8 |
	parallel --retries 2 --sshlogin 8/localhost,8/: -j+0 "hostname; false" |
	wc -l
    seq 1 8 |
	parallel --retries 2 --sshlogin 8/localhost,8/: -j+1 "hostname; false" |
	wc -l
    seq 1 2 |
	parallel --retries 2 --sshlogin 8/localhost,8/: -j-1 "hostname; false" |
	wc -l
    seq 1 1 |
	parallel --retries 2 --sshlogin 1/localhost,1/: -j1 "hostname; false" |
	wc -l
    seq 1 1 |
	parallel --retries 2 --sshlogin 1/localhost,1/: -j9 "hostname; false" |
	wc -l
    seq 1 1 |
	parallel --retries 2 --sshlogin 1/localhost,1/: -j0 "hostname; false" |
	wc -l

    echo '### These were not affected by the bug'
    seq 1 8 |
	parallel --retries 2 --sshlogin 1/localhost,9/: -j-1 "hostname; false" |
	wc -l
    seq 1 8 |
	parallel --retries 2 --sshlogin 8/localhost,8/: -j-1 "hostname; false" |
	wc -l
    seq 1 1 |
	parallel --retries 2 --sshlogin 1/localhost,1/:  "hostname; false" |
	wc -l
    seq 1 4 |
	parallel --retries 2 --sshlogin 2/localhost,2/: -j-1 "hostname; false" |
	wc -l
    seq 1 4 |
	parallel --retries 2 --sshlogin 2/localhost,2/: -j1 "hostname; false" |
	wc -l
    seq 1 4 |
	parallel --retries 2 --sshlogin 1/localhost,1/: -j1 "hostname; false" |
	wc -l
    seq 1 2 |
	parallel --retries 2 --sshlogin 1/localhost,1/: -j1 "hostname; false" |
	wc -l
}

par_kill_hup() {
    echo '### Are children killed if GNU Parallel receives HUP? There should be no sleep at the end'

    parallel -j 2 -q bash -c 'sleep {} & pid=$!; wait $pid' ::: 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 &
    T=$!
    sleep 3.9
    pstree $$
    kill -HUP $T
    sleep 4
    pstree $$
}

par_resume_failed_k() {
    echo '### bug #38299: --resume-failed -k'
    tmp=$(tempfile)
    parallel -k --resume-failed --joblog $tmp echo job{#} val {}\;exit {} ::: 0 1 2 3 0 1
    echo try 2. Gives failing - not 0
    parallel -k --resume-failed --joblog $tmp echo job{#} val {}\;exit {} ::: 0 1 2 3 0 1
    echo with exit 0
    parallel -k --resume-failed --joblog $tmp echo job{#} val {}\;exit 0  ::: 0 1 2 3 0 1
    sleep 0.5
    echo try 2 again. Gives empty
    parallel -k --resume-failed --joblog $tmp echo job{#} val {}\;exit {} ::: 0 1 2 3 0 1
    rm $tmp
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

    stdout parallel -k --delay 0.11 --tag testhalt_{4} {1},{2}={3} \
	::: now soon ::: fail success done ::: 0 1 2 30% 70% ::: true false |
	# Remove lines that only show up now and then
	perl -ne '/Starting no more jobs./ or print'
}

par_continuous_output() {
    # After the first batch, each jobs should output when it finishes.
    # Old versions delayed output by $jobslots jobs
    doit() {
	echo "Test delayed output with '$1'"
	echo "-u is optimal but hard to reach, due to non-mixing"
	seq 10 |
	    parallel -j1 $1 --delay 1.5 -N0 echo |
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
