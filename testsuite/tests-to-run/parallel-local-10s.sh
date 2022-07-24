#!/bin/bash

# SPDX-FileCopyrightText: 2021-2022 Ole Tange, http://ole.tange.dk and Free Software and Foundation, Inc.
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Simple jobs that never fails
# Each should be taking 10-30s and be possible to run in parallel
# I.e.: No race conditions, no logins

par_reload_slf_every_second() {
    echo "### --slf should reload every second"
    tmp=$(mktemp)
    echo 1/lo >"$tmp"
    (
	sleep 3
	(echo 1/localhost
	 echo 1/127.0.0.1) >>"$tmp"
    ) &
    # This used to take 20 seconds (version 20220322) because the
    # updated --slf would only read after first job finished
    seq 3 |
	stdout /usr/bin/time -f %e parallel --slf "$tmp" 'true {};sleep 10' |
        perl -ne '$_ < 20 and print "OK\n"'
    rm "$tmp"
}

par_load_blocks() {
    echo "### Test if --load blocks. Bug.";
    export PARALLEL="--load 300%"
    (seq 1 1000 |
	 parallel -kj2 --load 300% --recend "\n" --spreadstdin gzip -1 |
	 zcat | sort -n | md5sum
     seq 1 1000 |
	 parallel -kj200 --load 300% --recend "\n" --spreadstdin gzip -1 |
	 zcat | sort -n | md5sum) 2>&1 |
	grep -Ev 'processes took|Consider adjusting -j'
}

par_round_robin_blocks() {
    echo "bug #49664: --round-robin does not complete"
    seq 20000000 | parallel -j8 --block 10M --round-robin --pipe wc -c | wc -l
}

par_compress_prg_fails() {
    echo '### bug #44546: If --compress-program fails: fail'
    doit() {
	(parallel $* --compress-program false \
		  echo \; sleep 1\; ls ::: /no-existing
	echo $?) | tail -n1
    }
    export -f doit
    stdout parallel --tag -k doit ::: '' --line-buffer ::: '' --tag ::: '' --files |
	grep -v -- -dc
}

par_dryrun_timeout_ungroup() {
    echo 'bug #51039: --dry-run --timeout 1.4m -u breaks'
    seq 1000 | stdout parallel --dry-run --timeout 1.4m -u --jobs 10 echo | wc
}

par_opt_arg_eaten() {
    echo 'bug #31716: Options with optional arguments may eat next argument'
    echo '### Test https://savannah.gnu.org/bugs/index.php?31716'
    seq 1 5 | stdout parallel -k -l echo {} OK
    seq 1 5 | stdout parallel -k -l 1 echo {} OK

    echo '### -k -l -0'
    printf '1\0002\0003\0004\0005\000' | stdout parallel -k -l -0 echo {} OK

    echo '### -k -0 -l'
    printf '1\0002\0003\0004\0005\000' | stdout parallel -k -0 -l echo {} OK

    echo '### -k -0 -l 1'
    printf '1\0002\0003\0004\0005\000' | stdout parallel -k -0 -l 1 echo {} OK

    echo '### -k -0 -l 0'
    printf '1\0002\0003\0004\0005\000' | stdout parallel -k -0 -l 0 echo {} OK

    echo '### -k -0 -L -0 - -0 is argument for -L'
    printf '1\0002\0003\0004\0005\000' | stdout parallel -k -0 -L -0 echo {} OK

    echo '### -k -0 -L 0 - -L always takes arg'
    printf '1\0002\0003\0004\0005\000' | stdout parallel -k -0 -L 0 echo {} OK

    echo '### -k -0 -L 0 - -L always takes arg'
    printf '1\0002\0003\0004\0005\000' | stdout parallel -k -L 0 -0 echo {} OK

    echo '### -k -e -0'
    printf '1\0002\0003\0004\0005\000' | stdout parallel -k -e -0 echo {} OK

    echo '### -k -0 -e eof'
    printf '1\0002\0003\0004\0005\000' | stdout parallel -k -0 -e eof echo {} OK

    echo '### -k -i -0'
    printf '1\0002\0003\0004\0005\000' | stdout parallel -k -i -0 echo {} OK

    echo '### -k -0 -i repl'
    printf '1\0002\0003\0004\0005\000' | stdout parallel -k -0 -i repl echo repl OK
}

par_nice() {
    echo 'Check that --nice works'
    # parallel-20160422 OK
    check_for_2_bzip2s() {
	perl -e '
	for(1..5) {
	       # Try 5 times if the machine is slow starting bzip2
	       sleep(1);
	       @out = qx{ps -eo "%c %n" | grep 18 | grep bzip2};
	       if($#out == 1) {
		     # Should find 2 lines
		     print @out;
		     exit 0;
	       }
           }
	   print "failed\n@out";
	   '
    }
    # wait for load < 8
    parallel --load 8 echo ::: load_10
    parallel -j0 --timeout 10 --nice 18 bzip2 '<' ::: /dev/zero /dev/zero &
    pid=$!
    check_for_2_bzip2s
    parallel --retries 10 '! kill -TERM' ::: $pid 2>/dev/null
}

par_colsep() {
    echo '### Test of --colsep'
    echo 'a%c%b' | parallel --colsep % echo {1} {3} {2}
    (echo 'a%c%b'; echo a%c%b%d) | parallel -k --colsep % echo {1} {3} {2} {4}
    (echo a%c%b; echo d%f%e) | parallel -k --colsep % echo {1} {3} {2}
    parallel -k --colsep % echo {1} {3} {2} ::: a%c%b d%f%e
    parallel -k --colsep % echo {1} {3} {2} ::: a%c%b
    parallel -k --colsep % echo {1} {3} {2} {4} ::: a%c%b a%c%b%d


    echo '### Test of tab as colsep'
    printf 'def\tabc\njkl\tghi' | parallel -k --colsep '\t' echo {2} {1}
    parallel -k -a <(printf 'def\tabc\njkl\tghi') --colsep '\t' echo {2} {1}

    echo '### Test of multiple -a plus colsep'
    parallel --xapply -k -a <(printf 'def\njkl\n') -a <(printf 'abc\tghi\nmno\tpqr') --colsep '\t' echo {2} {1}

    echo '### Test of multiple -a no colsep'
    parallel --xapply -k -a <(printf 'ghi\npqr\n') -a <(printf 'abc\tdef\njkl\tmno') echo {2} {1}

    echo '### Test of quoting after colsplit'
    parallel --colsep % echo {2} {1} ::: '>/dev/null%>/tmp/null'

    echo '### Test of --colsep as regexp'
    (echo 'a%c%%b'; echo a%c%b%d) | parallel -k --colsep %+ echo {1} {3} {2} {4}
    parallel -k --colsep %+ echo {1} {3} {2} {4} ::: a%c%%b a%c%b%d
    (echo 'a% c %%b'; echo a%c% b %d) | parallel -k --colsep %+ echo {1} {3} {2} {4}
    (echo 'a% c %%b'; echo a%c% b %d) | parallel -k --colsep %+ echo '"{1}_{3}_{2}_{4}"'

    echo '### Test of -C'
    (echo 'a% c %%b'; echo a%c% b %d) | parallel -k -C %+ echo '"{1}_{3}_{2}_{4}"'

    echo '### Test of --trim n'
    (echo 'a% c %%b'; echo a%c% b %d) | parallel -k --trim n --colsep %+ echo '"{1}_{3}_{2}_{4}"'
    parallel -k -C %+ echo '"{1}_{3}_{2}_{4}"' ::: 'a% c %%b' 'a%c% b %d'

    echo '### Test of bug: If input is empty string'
    (echo ; echo abcbdbebf;echo abc) | parallel -k --colsep b -v echo {1}{2}
}

par_failing_compressor() {
    echo 'Compress with failing (de)compressor'
    echo 'Test --tag/--line-buffer/--files in all combinations'
    echo 'Test working/failing compressor/decompressor in all combinations'
    echo '(-k is used as a dummy argument)'
    stdout parallel -vk --header : --argsep ,,, \
	     parallel -k {tag} {lb} {files} --compress --compress-program {comp} --decompress-program {decomp} echo ::: C={comp},D={decomp} \
	     ,,, tag --tag -k \
	     ,,, lb --line-buffer -k \
	     ,,, files --files -k \
	     ,,, comp 'cat;true' 'cat;false' \
	     ,,, decomp 'cat;true' 'cat;false' |
	perl -pe 's:/par......par:/tmpfile:'
}

par_fifo_under_csh() {
    echo '### Test --fifo under csh'

    csh -c "seq 3000000 | parallel -k --pipe --fifo 'sleep .{#};cat {}|wc -c ; false; echo \$status; false'"
    echo exit $?
}

par_parset() {
    echo '### test parset'
    . `which env_parallel.bash`

    echo 'Put output into $myarray'
    parset myarray -k seq 10 ::: 14 15 16
    echo "${myarray[1]}"

    echo 'Put output into vars "$seq, $pwd, $ls"'
    parset "seq pwd ls" -k ::: "seq 10" pwd ls
    echo "$seq"

    echo 'Put output into vars ($seq, $pwd, $ls)':
    into_vars=(seq pwd ls)
    parset "${into_vars[*]}" -k ::: "seq 5" pwd ls
    echo "$seq"

    echo 'The commands to run can be an array'
    cmd=("echo '<<joe  \"double  space\"  cartoon>>'" "pwd")
    parset data -k ::: "${cmd[@]}"
    echo "${data[0]}"
    echo "${data[1]}"

    echo 'You cannot pipe into parset, but must use a tempfile'
    seq 10 > /tmp/parset_input_$$
    parset res -k echo :::: /tmp/parset_input_$$
    echo "${res[0]}"
    echo "${res[9]}"
    rm /tmp/parset_input_$$

    echo 'or process substitution'
    parset res -k echo :::: <(seq 0 10)
    echo "${res[0]}"
    echo "${res[9]}"

    echo 'Commands with newline require -0'
    parset var -k -0 ::: 'echo "line1
line2"' 'echo "command2"'
    echo "${var[0]}"
}

par_parset2() {
    . `which env_parallel.bash`
    echo '### parset into array'
    parset arr1 echo ::: foo bar baz
    echo ${arr1[0]} ${arr1[1]} ${arr1[2]}

    echo '### parset into vars with comma'
    parset comma3,comma2,comma1 echo ::: baz bar foo
    echo $comma1 $comma2 $comma3

    echo '### parset into vars with space'
    parset 'space3 space2 space1' echo ::: baz bar foo
    echo $space1 $space2 $space3

    echo '### parset with newlines'
    parset 'newline3 newline2 newline1' seq ::: 3 2 1
    echo "$newline1"
    echo "$newline2"
    echo "$newline3"

    echo '### parset into indexed array vars'
    parset 'myarray[6],myarray[5],myarray[4]' echo ::: baz bar foo
    echo ${myarray[*]}
    echo ${myarray[4]} ${myarray[5]} ${myarray[5]}

    echo '### env_parset'
    alias myecho='echo myecho "$myvar" "${myarr[1]}"'
    myvar="myvar"
    myarr=("myarr  0" "myarr  1" "myarr  2")
    mynewline="`echo newline1;echo newline2;`"
    env_parset arr1 myecho ::: foo bar baz
    echo "${arr1[0]} ${arr1[1]} ${arr1[2]}"
    env_parset comma3,comma2,comma1 myecho ::: baz bar foo
    echo "$comma1 $comma2 $comma3"
    env_parset 'space3 space2 space1' myecho ::: baz bar foo
    echo "$space1 $space2 $space3"
    env_parset 'newline3 newline2 newline1' 'echo "$mynewline";seq' ::: 3 2 1
    echo "$newline1"
    echo "$newline2"
    echo "$newline3"
    env_parset 'myarray[6],myarray[5],myarray[4]' myecho ::: baz bar foo
    echo "${myarray[*]}"
    echo "${myarray[4]} ${myarray[5]} ${myarray[5]}"

    echo 'bug #52507: parset arr1 -v echo ::: fails'
    parset arr1 -v seq ::: 1 2 3
    echo "${arr1[2]}"
}

par_perlexpr_repl() {
    echo '### {= and =} in different groups separated by space'
    parallel echo {= s/a/b/ =} ::: a
    parallel echo {= s/a/b/=} ::: a
    parallel echo {= s/a/b/=}{= s/a/b/=} ::: a
    parallel echo {= s/a/b/=}{=s/a/b/=} ::: a
    parallel echo {= s/a/b/=}{= {= s/a/b/=} ::: a
    parallel echo {= s/a/b/=}{={=s/a/b/=} ::: a
    parallel echo {= s/a/b/ =} {={==} ::: a
    parallel echo {={= =} ::: a
    parallel echo {= {= =} ::: a
    parallel echo {= {= =} =} ::: a

    echo '### bug #45842: Do not evaluate {= =} twice'
    parallel -k echo '{=  $_=++$::G =}' ::: {1001..1004}
    parallel -k echo '{=1 $_=++$::G =}' ::: {1001..1004}
    parallel -k echo '{=  $_=++$::G =}' ::: {1001..1004} ::: {a..c}
    parallel -k echo '{=1 $_=++$::G =}' ::: {1001..1004} ::: {a..c}

    echo '### bug #45939: {2} in {= =} fails'
    parallel echo '{= s/O{2}//=}' ::: OOOK
    parallel echo '{2}-{=1 s/O{2}//=}' ::: OOOK ::: OK
}

par_END() {
    echo '### Test -i and --replace: Replace with argument'
    (echo a; echo END; echo b) | parallel -k -i -eEND echo repl{}ce
    (echo a; echo END; echo b) | parallel -k --replace -eEND echo repl{}ce
    (echo a; echo END; echo b) | parallel -k -i+ -eEND echo repl+ce
    (echo e; echo END; echo b) | parallel -k -i'*' -eEND echo r'*'plac'*'
    (echo a; echo END; echo b) | parallel -k --replace + -eEND echo repl+ce
    (echo a; echo END; echo b) | parallel -k --replace== -eEND echo repl=ce
    (echo a; echo END; echo b) | parallel -k --replace = -eEND echo repl=ce
    (echo a; echo END; echo b) | parallel -k --replace=^ -eEND echo repl^ce
    (echo a; echo END; echo b) | parallel -k -I^ -eEND echo repl^ce

    echo '### Test -E: Artificial end-of-file'
    (echo include this; echo END; echo not this) | parallel -k -E END echo
    (echo include this; echo END; echo not this) | parallel -k -EEND echo

    echo '### Test -e and --eof: Artificial end-of-file'
    (echo include this; echo END; echo not this) | parallel -k -e END echo
    (echo include this; echo END; echo not this) | parallel -k -eEND echo
    (echo include this; echo END; echo not this) | parallel -k --eof=END echo
    (echo include this; echo END; echo not this) | parallel -k --eof END echo
}

par_xargs_compat() {
    echo xargs compatibility
    a_b-c() { echo a_b; echo c; }
    a_b_-c-d() { echo a_b' '; echo c; echo d; }
    a_b_-c-d-e() { echo a_b' '; echo c; echo d; echo e; }
    one_mb_line() { perl -e 'print "z"x1000000'; }
    stdsort() { "$@" | LC_ALL=C sort; }

    echo '### Test -L -l and --max-lines'
    a_b-c | parallel -km -L2 echo
    a_b-c | parallel -k -L2 echo
    a_b-c | xargs -L2 echo

    echo '### xargs -L1 echo'
    a_b-c | parallel -km -L1 echo
    a_b-c | parallel -k -L1 echo
    a_b-c | xargs -L1 echo

    echo 'Lines ending in space should continue on next line'
    echo '### xargs -L1 echo'
    a_b_-c-d | parallel -km -L1 echo
    a_b_-c-d | parallel -k -L1 echo
    a_b_-c-d | xargs -L1 echo

    echo '### xargs -L2 echo'
    a_b_-c-d-e | parallel -km -L2 echo
    a_b_-c-d-e | parallel -k -L2 echo
    a_b_-c-d-e | xargs -L2 echo

    echo '### xargs -l echo'
    a_b_-c-d-e | parallel -l -km echo # This behaves wrong
    a_b_-c-d-e | parallel -l -k echo # This behaves wrong
    a_b_-c-d-e | xargs -l echo

    echo '### xargs -l2 echo'
    a_b_-c-d-e | parallel -km -l2 echo
    a_b_-c-d-e | parallel -k -l2 echo
    a_b_-c-d-e | xargs -l2 echo

    echo '### xargs -l1 echo'
    a_b_-c-d-e | parallel -km -l1 echo
    a_b_-c-d-e | parallel -k -l1 echo
    a_b_-c-d-e | xargs -l1 echo

    echo '### xargs --max-lines=2 echo'
    a_b_-c-d-e | parallel -km --max-lines 2 echo
    a_b_-c-d-e | parallel -k --max-lines 2 echo
    a_b_-c-d-e | xargs --max-lines=2 echo

    echo '### xargs --max-lines echo'
    a_b_-c-d-e | parallel --max-lines -km echo # This behaves wrong
    a_b_-c-d-e | parallel --max-lines -k echo # This behaves wrong
    a_b_-c-d-e | xargs --max-lines echo

    echo '### test too long args'
    one_mb_line | parallel echo 2>&1
    one_mb_line | xargs echo 2>&1
    (seq 1 10; one_mb_line; seq 12 15) | stdsort parallel -j1 -km -s 10 echo
    (seq 1 10; one_mb_line; seq 12 15) | stdsort xargs -s 10 echo
    (seq 1 10; one_mb_line; seq 12 15) | stdsort parallel -j1 -kX -s 10 echo

    echo '### Test -x'
    echo '-km'
    (seq 1 10; echo 12345; seq 12 15) | stdsort parallel -j1 -km -s 10 -x echo
    echo '-kX'
    (seq 1 10; echo 12345; seq 12 15) | stdsort parallel -j1 -kX -s 10 -x echo
    echo '-x'
    (seq 1 10; echo 12345; seq 12 15) | stdsort xargs -s 10 -x echo
    echo '-km -x'
    (seq 1 10; echo 1234;  seq 12 15) | stdsort parallel -j1 -km -s 10 -x echo
    echo '-kX -x'
    (seq 1 10; echo 1234;  seq 12 15) | stdsort parallel -j1 -kX -s 10 -x echo
    echo '-x'
    (seq 1 10; echo 1234;  seq 12 15) | stdsort xargs -s 10 -x echo
}

par_sem_2jobs() {
    echo '### Test semaphore 2 jobs running simultaneously'
    parallel --semaphore --id 2jobs -u -j2 'echo job1a 1; sleep 4; echo job1b 3'
    sleep 0.5
    parallel --semaphore --id 2jobs -u -j2 'echo job2a 2; sleep 4; echo job2b 5'
    sleep 0.5
    parallel --semaphore --id 2jobs -u -j2 'echo job3a 4; sleep 4; echo job3b 6'
    parallel --semaphore --id 2jobs --wait
    echo done
}

par_semaphore() {
    echo '### Test if parallel invoked as sem will run parallel --semaphore'
    sem --id as_sem -u -j2 'echo job1a 1; sleep 3; echo job1b 3'
    sleep 0.5
    sem --id as_sem -u -j2 'echo job2a 2; sleep 3; echo job2b 5'
    sleep 0.5
    sem --id as_sem -u -j2 'echo job3a 4; sleep 3; echo job3b 6'
    sem --id as_sem --wait
    echo done
}

par_line_buffer() {
    echo "### --line-buffer"
    tmp1=$(mktemp)
    tmp2=$(mktemp)

    seq 10 | parallel -j20 --line-buffer  'seq {} 10 | pv -qL 10' > $tmp1
    seq 10 | parallel -j20                'seq {} 10 | pv -qL 10' > $tmp2
    cat $tmp1 | wc
    diff $tmp1 $tmp2 >/dev/null
    echo These must diff: $?
    rm $tmp1 $tmp2
}

par_pipe_line_buffer() {
    echo "### --pipe --line-buffer"
    tmp1=$(mktemp)
    tmp2=$(mktemp)

    nowarn() {
	# Ignore certain warnings
	# parallel: Warning: Starting 11 processes took > 2 sec.
	# parallel: Warning: Consider adjusting -j. Press CTRL-C to stop.
	grep -v '^parallel: Warning: (Starting|Consider)'
    }

    export PARALLEL="-N10 -L1 --pipe  -j20 --tagstring {#}"
    seq 200| parallel --line-buffer pv -qL 10 > $tmp1 2> >(nowarn)
    seq 200| parallel               pv -qL 10 > $tmp2 2> >(nowarn)
    cat $tmp1 | wc
    diff $tmp1 $tmp2 >/dev/null
    echo These must diff: $?
    rm $tmp1 $tmp2
}

par_pipe_line_buffer_compress() {
    echo "### --pipe --line-buffer --compress"
    seq 200| parallel -N10 -L1 --pipe  -j20 --line-buffer --compress --tagstring {#} pv -qL 10 | wc
}

par__pipepart_spawn() {
    echo '### bug #46214: Using --pipepart doesnt spawn multiple jobs in version 20150922'
    seq 1000000 > /tmp/num1000000
    stdout parallel --pipepart --progress -a /tmp/num1000000 --block 10k -j0 true |
	grep 1:local | perl -pe 's/\d\d\d/999/g; s/\d\d+|[2-9]/2+/g;'
}

par__pipe_tee() {
    echo 'bug #45479: --pipe/--pipepart --tee'
    echo '--pipe --tee'

    random100M() {
	< /dev/zero openssl enc -aes-128-ctr -K 1234 -iv 1234 2>/dev/null |
	    head -c 100M;
    }
    random100M | parallel --pipe --tee cat ::: {1..3} | LC_ALL=C wc -c
}

par__pipepart_tee() {
    echo 'bug #45479: --pipe/--pipepart --tee'
    echo '--pipepart --tee'

    export TMPDIR=/dev/shm/parallel
    mkdir -p $TMPDIR
    random100M() {
	< /dev/zero openssl enc -aes-128-ctr -K 1234 -iv 1234 2>/dev/null |
	    head -c 100M;
    }
    tmp=$(mktemp)
    random100M >$tmp
    parallel --pipepart --tee -a $tmp cat ::: {1..3} | LC_ALL=C wc -c
    rm $tmp
}

par_k() {
    echo '### Test -k'
    ulimit -n 50
    (echo "sleep 3; echo begin";
     seq 1 30 |
	 parallel -j1 -kq echo "sleep 1; echo {}";
     echo "echo end") |
	stdout nice parallel -k -j0 |
	grep -Ev 'No more file handles.|Raising ulimit -n' |
	perl -pe '/parallel:/ and s/\d/X/g'
}

par_k_linebuffer() {
    echo '### bug #47750: -k --line-buffer should give current job up to now'

    parallel --line-buffer --tag -k 'seq {} | pv -qL 10' ::: {10..20}
    parallel --line-buffer -k 'echo stdout top;sleep 1;echo stderr in the middle >&2; sleep 1;echo stdout' ::: end 2>&1
}

par_maxlinelen_m_I() {
    echo "### Test max line length -m -I"

    seq 1 60000 | parallel -I :: -km -j1 echo a::b::c | LC_ALL=C sort >/tmp/114-a$$;
    md5sum </tmp/114-a$$;
    export CHAR=$(cat /tmp/114-a$$ | wc -c);
    export LINES=$(cat /tmp/114-a$$ | wc -l);
    echo "Chars per line ($CHAR/$LINES): "$(echo "$CHAR/$LINES" | bc);
    rm /tmp/114-a$$
}

par_maxlinelen_X_I() {
    echo "### Test max line length -X -I"

    seq 1 60000 | parallel -I :: -kX -j1 echo a::b::c | LC_ALL=C sort >/tmp/114-b$$;
    md5sum </tmp/114-b$$;
    export CHAR=$(cat /tmp/114-b$$ | wc -c);
    export LINES=$(cat /tmp/114-b$$ | wc -l);
    echo "Chars per line ($CHAR/$LINES): "$(echo "$CHAR/$LINES" | bc);
    rm /tmp/114-b$$
}

par_compress_fail() {
    echo "### bug #41609: --compress fails"
    seq 12 | parallel --compress --compress-program gzip -k seq {} 10000 | md5sum
    seq 12 | parallel --compress -k seq {} 10000 | md5sum
}

par_results_csv() {
    echo "bug #: --results csv"

    doit() {
	parallel -k $@ --results -.csv echo ::: H2 22 23 ::: H1 11 12;
    }
    export -f doit
    parallel -k --tag doit ::: '--header :' '' \
	::: --tag '' ::: --files '' ::: --compress '' |
    perl -pe 's:/par......par:/tmpfile:g;s/\d+\.\d+/999.999/g'
}

par_kill_children_timeout() {
    echo '### Test killing children with --timeout and exit value (failed if timed out)'
    pstree $$ | grep sleep | grep -v anacron | grep -v screensave | wc
    doit() {
	for i in `seq 100 120`; do
	    bash -c "(sleep $i)" &
	    sleep $i &
	done;
	wait;
	echo No good;
    }
    export -f doit
    parallel --timeout 3 doit ::: 1000000000 1000000001
    echo $?;
    sleep 2;
    pstree $$ | grep sleep | grep -v anacron | grep -v screensave | wc
}

par_tmux_fg() {
    echo 'bug #50107: --tmux --fg should also write how to access it'
    stdout parallel --tmux --fg sleep ::: 3 | perl -pe 's/.tmp\S+/tmp/'
}


par_retries_all_fail() {
    echo "bug #53748: -k --retries 10 + out of filehandles = blocking"
    ulimit -n 30
    seq 8 |
	parallel -k -j0 --retries 2 --timeout 0.1 'echo {}; sleep {}; false' 2>/dev/null
}

par_sockets_cores_threads() {
    echo '### Test --number-of-sockets/cores/threads'
    unset PARALLEL_CPUINFO
    unset PARALLEL_LSCPU
    parallel --number-of-sockets
    parallel --number-of-cores
    parallel --number-of-threads
    parallel --number-of-cpus

    echo '### Test --use-sockets-instead-of-threads'
    (seq 1 4 |
	 stdout parallel --use-sockets-instead-of-threads -j100% sleep) &&
	echo sockets done &
    (seq 1 4 | stdout parallel -j100% sleep) && echo threads done &
    wait
    echo 'Threads should complete first on machines with less than 8 sockets'
}

par_long_line_remote() {
    echo '### Deal with long command lines on remote servers'
    perl -e "print(((\"'\"x5000).\"\\n\")x6)" |
	parallel -j1 -S lo -N 10000 echo {} |wc
    perl -e 'print((("\$"x5000)."\n")x50)' |
	parallel -j1 -S lo -N 10000 echo {} |wc
}

par_shellquote() {
    echo '### Test --shellquote in all shells'
    doit() {
	# Run --shellquote for ascii 1..255 in a shell
	shell="$1"
	"$shell" -c perl\ -e\ \'print\ pack\(\"c\*\",1..255\)\'\ \|\ parallel\ -0\ --shellquote
    }
    export -f doit
    parallel --tag -q -k doit {} ::: ash bash csh dash fish fizsh ksh2020 ksh93 lksh mksh posh rzsh sash sh static-sh tcsh yash zsh csh tcsh
}

par_tmp_full() {
    # Assume /tmp/shm is easy to fill up
    export SHM=/tmp/shm/parallel
    mkdir -p $SHM
    sudo umount -l $SHM 2>/dev/null
    sudo mount -t tmpfs -o size=10% none $SHM

    echo "### Test --tmpdir running full. bug #40733 was caused by this"
    stdout parallel -j1 --tmpdir $SHM cat /dev/zero ::: dummy
}

par_jobs_file() {
    echo '### Test of -j filename - non-existent file'
    stdout parallel -j no_such_file echo ::: 1 |
	perl -ne '/Tange, O.|Zenodo./ or print'

    echo '### Test of -j filename'
    echo 3 >/tmp/jobs_to_run1
    parallel -j /tmp/jobs_to_run1 -v sleep {} ::: 10 8 6 5 4
    # Should give 6 8 10 5 4
}

export -f $(compgen -A function | grep par_)
compgen -A function | grep par_ | LC_ALL=C sort |
    parallel --timeout 1000% -j10 --tag -k --joblog /tmp/jl-`basename $0` '{} 2>&1' |
    perl -pe 's/,31,0/,15,0/' |
    # Replace $PWD with . even if given as ~/...
    perl -pe 's:~:'$HOME':g' |
    perl -pe 's:'$PWD':.:g' |
    perl -pe 's:'$HOME':~:g'
