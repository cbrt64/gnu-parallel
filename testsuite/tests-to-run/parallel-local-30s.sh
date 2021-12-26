#!/bin/bash

# SPDX-FileCopyrightText: 2021-2022 Ole Tange, http://ole.tange.dk and Free Software and Foundation, Inc.
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Simple jobs that never fails
# Each should be taking 30-100s and be possible to run in parallel
# I.e.: No race conditions, no logins

par_shard() {
    echo '### --shard'
    # Each of the 5 lines should match:
    #   ##### ##### ######
    seq 100000 | parallel --pipe --shard 1 -j5  wc |
	perl -pe 's/(.*\d{5,}){3}/OK/'
    # Data should be sharded to all processes
    shard_on_col() {
	col=$1
	seq 10 99 | shuf | perl -pe 's/(.)/$1\t/g' |
	    parallel --pipe --shard $col -j2 --colsep "\t" sort -k$col |
	    field $col | sort | uniq -c
    }
    shard_on_col 1
    shard_on_col 2

    shard_on_col_name() {
	colname=$1
	col=$2
	(echo AB; seq 10 99 | shuf) | perl -pe 's/(.)/$1\t/g' |
	    parallel --header : --pipe --shard $colname -j2 --colsep "\t" sort -k$col |
	    field $col | sort | uniq -c
    }
    shard_on_col_name A 1
    shard_on_col_name B 2

    shard_on_col_expr() {
	colexpr="$1"
	col=$2
	(seq 10 99 | shuf) | perl -pe 's/(.)/$1\t/g' |
	    parallel --pipe --shard "$colexpr" -j2 --colsep "\t" "sort -k$col; echo c1 c2" |
	    field $col | sort | uniq -c
    }
    shard_on_col_expr '1 $_%=3' 1
    shard_on_col_expr '2 $_%=3' 2

    shard_on_col_name_expr() {
	colexpr="$1"
	col=$2
	(echo AB; seq 10 99 | shuf) | perl -pe 's/(.)/$1\t/g' |
	    parallel --header : --pipe --shard "$colexpr" -j2 --colsep "\t" "sort -k$col; echo c1 c2" |
	    field $col | sort | uniq -c
    }
    shard_on_col_name_expr 'A $_%=3' 1
    shard_on_col_name_expr 'B $_%=3' 2
    
    echo '*** broken'
    # Shorthand for --pipe -j+0
    seq 200000 | parallel --pipe --shard 1 wc |
	perl -pe 's/(.*\d{5,}){3}/OK/'
    # Combine with arguments
    seq 200000 | parallel --pipe --shard 1 echo {}\;wc ::: {1..5} ::: a b |
	perl -pe 's/(.*\d{5,}){3}/OK/'
}

par_test_diff_roundrobin_k() {
    echo '### test there is difference on -k'
    . $(which env_parallel.bash)
    mytest() {
	K=$1
	doit() {
	    # Sleep random time ever 1k line
	    # to mix up which process gets the next block
	    perl -ne '$t++ % 1000 or select(undef, undef, undef, rand()/10);print' |
		md5sum
	}
	export -f doit
	seq 1000000 |
	    parallel --block 65K --pipe $K --roundrobin doit |
	    sort
    }
    export -f mytest
    parset a,b,c mytest ::: -k -k ''
    # a == b and a != c or error
    if [ "$a" == "$b" ]; then
	if [ "$a" != "$c" ]; then
	    echo OK
	else
	    echo error a c
	fi
    else
	echo error a b
    fi
}

par_load_from_PARALLEL() {
    echo "### Test reading load from PARALLEL"
    export PARALLEL="--load 300%"
    # Ignore stderr due to 'Starting processes took > 2 sec'
    seq 1 1000000 |
	parallel -kj200 --recend "\n" --spreadstdin gzip -1 2>/dev/null |
	zcat | sort -n | md5sum
    seq 1 1000000 |
	parallel -kj20 --recend "\n" --spreadstdin gzip -1 |
	zcat | sort -n | md5sum
}

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
	# These give the same exit code prepended with 'true;' or not
	OK="ash csh dash fish fizsh ksh2020 posh rc sash sh tcsh"
	# These do not give the same exit code prepended with 'true;' or not
	BAD="bash fdsh ksh93 mksh static-sh yash zsh"
	s=100
	rm -f /tmp/mysleep
	cp /bin/sleep /tmp/mysleep
	
	echo '# Ideally the command should return the same'
	echo '#   with or without parallel'
	echo '# but fish 2.4.0 returns 1 while X.X.X returns 0'
	parallel -kj500% --argsep ,, --tag in_shell_run_command {1} {2} \
		 ,, $OK $BAD ,, \
	"/tmp/mysleep "$s \
	"parallel --halt-on-error now,fail=1 /tmp/mysleep ::: "$s \
	"parallel --halt-on-error now,done=1 /tmp/mysleep ::: "$s \
	"parallel --halt-on-error now,done=1 /bin/true ::: "$s \
	"parallel --halt-on-error now,done=1 exit ::: "$s \
	"true;/tmp/mysleep "$s \
	"parallel --halt-on-error now,fail=1 'true;/tmp/mysleep' ::: "$s \
	"parallel --halt-on-error now,done=1 'true;/tmp/mysleep' ::: "$s \
	"parallel --halt-on-error now,done=1 'true;/bin/true' ::: "$s \
	"parallel --halt-on-error now,done=1 'true;exit' ::: "$s
    }
    export -f runit

    killsleep() {
	sleep 5
	while true; do killall -9 mysleep 2>/dev/null; sleep 1; done
    }
    export -f killsleep

    parallel -uj0 --halt now,done=1 ::: runit killsleep
}

par_macron() {
    echo '### See if \257\256 \257<\257> is replaced correctly'
    print_it() {
	parallel $2 ::: "echo $1"
	parallel $2 echo ::: "$1"
	parallel $2 echo "$1" ::: "$1"
	parallel $2 echo \""$1"\" ::: "$1"
	parallel $2 echo "$1"{} ::: "$1"
	parallel $2 echo \""$1"\"{} ::: "$1"
    }
    export -f print_it
    parallel --tag -k print_it \
      ::: "$(perl -e 'print "\257"')" "$(perl -e 'print "\257\256"')" \
      "$(perl -e 'print "\257\257\256"')" \
      "$(perl -e 'print "\257<\257<\257>\257>"')" \
      ::: -X -q -Xq -k
}

par_groupby() {
    tsv() {
	printf "%s\t" a1 b1 C1; echo
	printf "%s\t" 2 2 2; echo
	printf "%s\t" 3 2 2; echo
	printf "%s\t" 3 3 2; echo
	printf "%s\t" 3 2 4; echo
	printf "%s\t" 3 2 2; echo
	printf "%s\t" 3 2 3; echo
	printf "%s\t" 3 1 3; echo
	printf "%s\t" 3 2 3; echo
	printf "%s\t" 3 3 3; echo
	printf "%s\t" 3 4 4; echo
	printf "%s\t" 3 5 4; echo
    }
    export -f tsv

    ssv() {
	# space separated
	printf "%s\t" a1 b1 C1; echo
	printf "%s " 2 2 2; echo
	printf "%s \t" 3 2 2; echo
	printf "%s\t " 3 3 2; echo
	printf "%s  " 3 2 4; echo
	printf "%s\t\t" 3 2 2; echo
	printf "%s\t  \t" 3 2 3; echo
	printf "%s\t  \t  " 3 1 3; echo
	printf "%s\t  \t " 3 2 3; echo
	printf "%s\t  \t" 3 3 3; echo
	printf "%s\t\t" 3 4 4; echo
	printf "%s\t \t" 3 5 4; echo
    }
    export -f ssv

    cssv() {
	# , + space separated
	printf "%s,\t" a1 b1 C1; echo
	printf "%s ," 2 2 2; echo
	printf "%s  ,\t" 3 2 2; echo
	printf "%s\t, " 3 3 2; echo
	printf "%s,," 3 2 4; echo
	printf "%s\t,,, " 3 2 2; echo
	printf "%s\t" 3 2 3; echo
	printf "%s\t, " 3 1 3; echo
	printf "%s\t," 3 2 3; echo
	printf "%s, \t" 3 3 3; echo
	printf "%s,\t," 3 4 4; echo
	printf "%s\t,," 3 5 4; echo
    }
    export -f cssv

    csv() {
	# , separated
	printf "%s," a1 b1 C1; echo
	printf "%s," 2 2 2; echo
	printf "%s," 3 2 2; echo
	printf "%s," 3 3 2; echo
	printf "%s," 3 2 4; echo
	printf "%s," 3 2 2; echo
	printf "%s," 3 2 3; echo
	printf "%s," 3 1 3; echo
	printf "%s," 3 2 3; echo
	printf "%s," 3 3 3; echo
	printf "%s," 3 4 4; echo
	printf "%s," 3 5 4; echo
    }
    export -f csv

    tester() {
	block="$1"
	groupby="$2"
	generator="$3"
	colsep="$4"
	echo "### test $generator | --colsep $colsep --groupby $groupby $block"
	$generator |
	    parallel --pipe --colsep "$colsep" --groupby "$groupby" -k $block 'echo NewRec; cat'
    }
    export -f tester
    # -N1 = allow only a single value
    # --block 20 = allow multiple groups of values
    parallel --tag -k tester \
	     ::: -N1 '--block 20' \
	     ::: '3 $_%=2' 3 's/^(.).*/$1/' C1 'C1 $_%=2' \
	     ::: tsv ssv cssv csv \
	     :::+ '\t' '\s+' '[\s,]+' ','

    # Test --colsep char: OK
    # Test --colsep pattern: OK
    # Test --colsep -N1: OK
    # Test --colsep --block 20: OK
    # Test --groupby colno: OK
    # Test --groupby 'colno perl': OK
    # Test --groupby colname: OK
    # Test --groupby 'colname perl': OK
    # Test space sep --colsep '\s': OK
    # Test --colsep --header : (OK: --header : not needed)
}

par_groupby_pipepart() {
    tsv() {
	# TSV file
	printf "%s\t" header_a1 head_b1 c1 d1 e1 f1; echo
	# Make 6 columns: 123456 => 1\t2\t3\t4\t5\t6
	seq 100000 999999 | perl -pe '$_=join"\t",split//' |
	    # Sort reverse on column 3 (This should group on col 3)
	    sort --parallel=8 --buffer-size=50% -k3r
    }
    export -f tsv

    ssv() {
	# space separated
	tsv | perl -pe '@sep=("\t"," "); s/\t/$sep[rand(2)]/ge;'
    }
    export -f ssv

    cssv() {
	# , + space separated
	tsv | perl -pe '@sep=("\t"," ",","); s/\t/$sep[rand(2)].$sep[rand(2)]/ge;'
    }
    export -f cssv

    csv() {
	# , separated
	tsv | perl -pe 's/\t/,/g;'
    }
    export -f csv

    tester() {
	generator="$1"
	colsep="$2"
	groupby="$3"
	tmp=`tempfile`
	
	echo "### test $generator | --colsep $colsep --groupby $groupby"
	$generator > $tmp
	parallel --header 1 --pipepart -k \
		 -a $tmp --colsep "$colsep" --groupby "$groupby" 'echo NewRec; wc'
    }
    export -f tester
    parallel --tag -k tester \
	     ::: tsv ssv cssv csv \
	     :::+ '\t' '\s+' '[\s,]+' ',' \
	     ::: '3 $_%=2' 3 c1 'c1 $_%=2' 's/^(\d+[\t ,]+){2}(\d+).*/$2/'
}

par_sighup() {
    echo '### Test SIGHUP'
    parallel -k -j5 sleep 15';' echo ::: {1..99} >/tmp/parallel$$ 2>&1 &
    A=$!
    sleep 29; kill -HUP $A
    wait
    LC_ALL=C sort /tmp/parallel$$
    rm /tmp/parallel$$
}

par_race_condition1() {
    echo '### Test race condition on 8 CPU (my laptop)'
    seq 1 5000000 > /tmp/parallel_race_cond
    seq 1 10 |
	parallel -k "cat /tmp/parallel_race_cond | parallel --pipe --recend '' -k gzip >/dev/null; echo {}"
    rm /tmp/parallel_race_cond
}

par_memory_leak() {
    a_run() {
	seq $1 |time -v parallel true 2>&1 |
	grep 'Maximum resident' |
	field 6;
    }
    export -f a_run
    echo "### Test for memory leaks"
    echo "Of 300 runs of 1 job at least one should be bigger than a 3000 job run"
    . `which env_parallel.bash`
    parset small_max,big ::: 'seq 300 | parallel a_run 1 | jq -s max' 'a_run 3000'
    if [ $small_max -lt $big ] ; then
	echo "Bad: Memleak likely."
    else
	echo "Good: No memleak detected."
    fi
}

par_slow_total_jobs() {
    echo 'bug #51006: Slow total_jobs() eats job'
    (echo a; sleep 15; echo b; sleep 15; seq 2) |
	parallel -k echo '{=total_jobs()=}' 2> >(perl -pe 's/\d/X/g')
}

par_memfree() {
    echo '### test memfree - it should be killed by timeout'
    parallel --memfree 1k echo Free mem: ::: 1k
    stdout parallel --timeout 20 --argsep II parallel --memfree 1t echo Free mem: ::: II 1t |
	grep -v TERM | grep -v ps/display.c
}

par_test_detected_shell() {
    echo '### bug #42913: Dont use $SHELL but the shell currently running'

    shells="ash bash csh dash fish fizsh ksh ksh93 mksh posh rbash rush rzsh sash sh static-sh tcsh yash zsh"
    test_unknown_shell() {
	shell="$1"
	tmp="/tmp/test_unknown_shell_$shell"
	# Remove the file to avoid potential text-file-busy
	rm -f "$tmp"
	cp $(which "$shell") "$tmp"
	chmod +x "$tmp"
	stdout $tmp -c 'parallel -Dinit echo ::: 1; true' |
	    grep Global::shell
	rm "$tmp"
    }
    export -f test_unknown_shell

    test_known_shell_c() {
	shell="$1"
	stdout $shell -c 'parallel -Dinit echo ::: 1; true' |
	    grep Global::shell
    }
    export -f test_known_shell_c

    test_known_shell_pipe() {
	shell="$1"
	echo 'parallel -Dinit echo ::: 1; true' |
	    stdout $shell | grep Global::shell
    }
    export -f test_known_shell_pipe

    stdout parallel -j2 --tag -k \
	   ::: test_unknown_shell test_known_shell_c test_known_shell_pipe \
	   ::: $shells |
	grep -Ev 'parallel: Warning: (Starting .* processes took|Consider adjusting)'
}

par_no_newline_compress() {
    echo 'bug #41613: --compress --line-buffer - no newline';
    pipe_doit() {
	tagstring="$1"
	compress="$2"
	echo tagstring="$tagstring" compress="$compress"
	perl -e 'print "O"'|
	    parallel "$compress" $tagstring --pipe --line-buffer cat
	echo "K"
    }
    export -f pipe_doit
    nopipe_doit() {
	tagstring="$1"
	compress="$2"
	echo tagstring="$tagstring" compress="$compress"
	parallel "$compress" $tagstring --line-buffer echo {} O ::: -n
	echo "K"
    }
    export -f nopipe_doit
    parallel -j1 -qk --header : {pipe}_doit {tagstring} {compress} \
	     ::: tagstring '--tagstring {#}' -k \
	     ::: compress --compress -k \
	     ::: pipe pipe nopipe
}

par_max_length_len_128k() {
    echo "### BUG: The length for -X is not close to max (131072)"
    (
	seq 1 60000 | perl -pe 's/$/.gif/' |
	    parallel -X echo {.} aa {}{.} {}{}d{} {}dd{}d{.} | head -n 1 | wc -c
	seq 1 60000 | perl -pe 's/$/.gif/' |
	    parallel -X echo a{}b{}c | head -n 1 | wc -c
	seq 1 60000 | perl -pe 's/$/.gif/' |
	    parallel -X echo | head -n 1 | wc -c
	seq 1 60000 | perl -pe 's/$/.gif/' |
	    parallel -X echo a{}b{}c {} | head -n 1 | wc -c
	seq 1 60000 | perl -pe 's/$/.gif/' |
	    parallel -X echo {}aa{} | head -n 1 | wc -c
	seq 1 60000 | perl -pe 's/$/.gif/' |
	    parallel -X echo {} aa {} | head -n 1 | wc -c
    ) |	perl -pe 's/131\d\d\d/131xxx/g'
}

par_round_robin_blocks() {
    echo "bug #49664: --round-robin does not complete"
    seq 20000000 | parallel -j8 --block 10M --round-robin --pipe wc -c | wc -l
}

par_plus_dyn_repl() {
    echo "Dynamic replacement strings defined by --plus"

    unset myvar
    echo ${myvar:-myval}
    parallel --rpl '{:-(.+)} $_ ||= $$1' echo {:-myval} ::: "$myvar"
    parallel --plus echo {:-myval} ::: "$myvar"
    parallel --plus echo {2:-myval} ::: "wrong" ::: "$myvar" ::: "wrong"
    parallel --plus echo {-2:-myval} ::: "wrong" ::: "$myvar" ::: "wrong"

    myvar=abcAaAdef
    echo ${myvar:2}
    parallel --rpl '{:(\d+)} substr($_,0,$$1) = ""' echo {:2} ::: "$myvar"
    parallel --plus echo {:2} ::: "$myvar"
    parallel --plus echo {2:2} ::: "wrong" ::: "$myvar" ::: "wrong"
    parallel --plus echo {-2:2} ::: "wrong" ::: "$myvar" ::: "wrong"

    echo ${myvar:2:3}
    parallel --rpl '{:(\d+?):(\d+?)} $_ = substr($_,$$1,$$2);' echo {:2:3} ::: "$myvar"
    parallel --plus echo {:2:3} ::: "$myvar"
    parallel --plus echo {2:2:3} ::: "wrong" ::: "$myvar" ::: "wrong"
    parallel --plus echo {-2:2:3} ::: "wrong" ::: "$myvar" ::: "wrong"

    echo ${#myvar}
    parallel --rpl '{#} $_ = length $_;' echo {#} ::: "$myvar"
    # {#} used for job number
    parallel --plus echo {#} ::: "$myvar"

    echo ${myvar#bc}
    parallel --rpl '{#(.+?)} s/^$$1//;' echo {#bc} ::: "$myvar"
    parallel --plus echo {#bc} ::: "$myvar"
    parallel --plus echo {2#bc} ::: "wrong" ::: "$myvar" ::: "wrong"
    parallel --plus echo {-2#bc} ::: "wrong" ::: "$myvar" ::: "wrong"
    echo ${myvar#abc}
    parallel --rpl '{#(.+?)} s/^$$1//;' echo {#abc} ::: "$myvar"
    parallel --plus echo {#abc} ::: "$myvar"
    parallel --plus echo {2#abc} ::: "wrong" ::: "$myvar" ::: "wrong"
    parallel --plus echo {-2#abc} ::: "wrong" ::: "$myvar" ::: "wrong"

    echo ${myvar%de}
    parallel --rpl '{%(.+?)} s/$$1$//;' echo {%de} ::: "$myvar"
    parallel --plus echo {%de} ::: "$myvar"
    parallel --plus echo {2%de} ::: "wrong" ::: "$myvar" ::: "wrong"
    parallel --plus echo {-2%de} ::: "wrong" ::: "$myvar" ::: "wrong"
    echo ${myvar%def}
    parallel --rpl '{%(.+?)} s/$$1$//;' echo {%def} ::: "$myvar"
    parallel --plus echo {%def} ::: "$myvar"
    parallel --plus echo {2%def} ::: "wrong" ::: "$myvar" ::: "wrong"
    parallel --plus echo {-2%def} ::: "wrong" ::: "$myvar" ::: "wrong"

    echo ${myvar/def/ghi}
    parallel --rpl '{/(.+?)/(.+?)} s/$$1/$$2/;' echo {/def/ghi} ::: "$myvar"
    parallel --plus echo {/def/ghi} ::: "$myvar"
    parallel --plus echo {2/def/ghi} ::: "wrong" ::: "$myvar" ::: "wrong"
    parallel --plus echo {-2/def/ghi} ::: "wrong" ::: "$myvar" ::: "wrong"

    echo ${myvar^a}
    parallel --rpl '{^(.+?)} s/^($$1)/uc($1)/e;' echo {^a} ::: "$myvar"
    parallel --plus echo {^a} ::: "$myvar"
    parallel --plus echo {2^a} ::: "wrong" ::: "$myvar" ::: "wrong"
    parallel --plus echo {-2^a} ::: "wrong" ::: "$myvar" ::: "wrong"
    echo ${myvar^^a}
    parallel --rpl '{^^(.+?)} s/($$1)/uc($1)/eg;' echo {^^a} ::: "$myvar"
    parallel --plus echo {^^a} ::: "$myvar"
    parallel --plus echo {2^^a} ::: "wrong" ::: "$myvar" ::: "wrong"
    parallel --plus echo {-2^^a} ::: "wrong" ::: "$myvar" ::: "wrong"

    myvar=AbcAaAdef
    echo ${myvar,A}
    parallel --rpl '{,(.+?)} s/^($$1)/lc($1)/e;' echo '{,A}' ::: "$myvar"
    parallel --plus echo '{,A}' ::: "$myvar"
    parallel --plus echo '{2,A}' ::: "wrong" ::: "$myvar" ::: "wrong"
    parallel --plus echo '{-2,A}' ::: "wrong" ::: "$myvar" ::: "wrong"
    echo ${myvar,,A}
    parallel --rpl '{,,(.+?)} s/($$1)/lc($1)/eg;' echo '{,,A}' ::: "$myvar"
    parallel --plus echo '{,,A}' ::: "$myvar"
    parallel --plus echo '{2,,A}' ::: "wrong" ::: "$myvar" ::: "wrong"
    parallel --plus echo '{-2,,A}' ::: "wrong" ::: "$myvar" ::: "wrong"
}

par_keeporder_roundrobin() {
    echo 'bug #50081: --keep-order --round-robin should give predictable results'

    export PARALLEL="-j13 --block 1m --pipe --roundrobin"
    random1G() {
	< /dev/zero openssl enc -aes-128-ctr -K 1234 -iv 1234 2>/dev/null |
	    head -c 1G;
    }
    a=$(random1G | parallel -k 'echo {#} $(md5sum)' | sort)
    b=$(random1G | parallel -k 'echo {#} $(md5sum)' | sort)
    c=$(random1G | parallel    'echo {#} $(md5sum)' | sort)
    if [ "$a" == "$b" ] ; then
	# Good: -k should be == -k
	if [ "$a" == "$c" ] ; then
	    # Bad: without -k the command should give different output
	    echo 'Broken: a == c'
	    printf "$a\n$b\n$c\n"
	else
	    echo OK
	fi
    else
	echo 'Broken: a <> b'
	printf "$a\n$b\n$c\n"
    fi
}

# was -j6 before segfault circus
export -f $(compgen -A function | grep par_)
compgen -A function | grep par_ | sort |
    #    parallel --delay 0.3 --timeout 1000% -j6 --tag -k --joblog /tmp/jl-`basename $0` '{} 2>&1'
    parallel --delay 0.3 --timeout 1000% -j6 --lb --tag -k --joblog /tmp/jl-`basename $0` '{} 2>&1'
