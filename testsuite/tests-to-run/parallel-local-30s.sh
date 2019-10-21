#!/bin/bash

# Simple jobs that never fails
# Each should be taking 30-100s and be possible to run in parallel
# I.e.: No race conditions, no logins

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
    echo "Of 100 runs of 1 job none should be bigger than a 3000 job run"
    . `which env_parallel.bash`
    parset small_max,big ::: 'seq 100 | parallel a_run 1 | jq -s max' 'a_run 3000'
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

linebuffer_matters() {
    echo "### (--linebuffer) --compress $TAG should give different output"
    nolbfile=$(mktemp)
    lbfile=$(mktemp)
    controlfile=$(mktemp)
    randomfile=$(mktemp)
    # Random data because it does not compress well
    # forcing the compress tool to spit out compressed blocks
    perl -pe 'y/[A-Za-z]//cd; $t++ % 1000 or print "\n"' < /dev/urandom |
	head -c 10000000 > $randomfile
    export randomfile

    testfunc() {
	linebuffer="$1"

	incompressible_ascii() {
	    # generate some incompressible ascii
	    # with lines starting with the same string
	    id=$1
	    shuf $randomfile | perl -pe 's/^/'$id' /'
	    # Sleep to give time to linebuffer-print the first part
	    sleep 10
	    shuf $randomfile | perl -pe 's/^/'$id' /'
	    echo
	}
	export -f incompressible_ascii

	nowarn() {
	    # Ignore certain warnings
	    # parallel: Warning: Starting 11 processes took > 2 sec.
	    # parallel: Warning: Consider adjusting -j. Press CTRL-C to stop.
	    grep -v '^parallel: Warning: (Starting|Consider)' >&2
	}

	parallel -j0 $linebuffer --compress $TAG \
		 incompressible_ascii ::: {0..10} 2> >(nowarn) |
	    perl -ne '/^(\d+)\s/ and print "$1\n"' |
	    uniq |
	    sort
    }

    # These can run in parallel if there are enough ressources
    testfunc > $nolbfile
    testfunc > $controlfile
    testfunc --linebuffer > $lbfile
    wait

    nolb="$(cat $nolbfile)"
    control="$(cat $controlfile)"
    lb="$(cat $lbfile)"
    rm $nolbfile $lbfile $controlfile $randomfile

    if [ "$nolb" == "$control" ] ; then
	if [ "$lb" == "$nolb" ] ; then
	    echo "BAD: --linebuffer makes no difference"
	else
	    echo "OK: --linebuffer makes a difference"
	fi
    else
	echo "BAD: control and nolb are not the same"
    fi
}
export -f linebuffer_matters

par_linebuffer_matters_compress_tag() {
    export TAG=--tag
    linebuffer_matters
}

par_linebuffer_matters_compress() {
    linebuffer_matters
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
	$tmp -c 'parallel -Dinit echo ::: 1; true' |
	    grep Global::shell
	rm "$tmp"
    }
    export -f test_unknown_shell

    test_known_shell_c() {
	shell="$1"
	$shell -c 'parallel -Dinit echo ::: 1; true' |
	    grep Global::shell
    }
    export -f test_known_shell_c

    test_known_shell_pipe() {
	shell="$1"
	echo 'parallel -Dinit echo ::: 1; true' |
	    $shell | grep Global::shell
    }
    export -f test_known_shell_pipe

    stdout parallel -j2 --tag -k \
	   ::: test_unknown_shell test_known_shell_c test_known_shell_pipe \
	   ::: $shells |
	grep -Ev 'parallel: Warning: (Starting .* processes took|Consider adjusting)'
}

par_linebuffer_files() {
    echo 'bug #48658: --linebuffer --files'
    rm -rf /tmp/par48658-*

    doit() {
	compress="$1"
	echo "normal"
	parallel --linebuffer --compress-program $compress seq ::: 100000 |
	    wc -l
	echo "--files"
	parallel --files --linebuffer --compress-program $1 seq ::: 100000 |
	    wc -l
	echo "--results"
	parallel --results /tmp/par48658-$compress --linebuffer --compress-program $compress seq ::: 100000 |
	    wc -l
	rm -rf "/tmp/par48658-$compress"
    }
    export -f doit
    # lrz complains 'Warning, unable to set nice value on thread'
    parallel -j1 --tag -k doit ::: zstd pzstd clzip lz4 lzop pigz pxz gzip plzip pbzip2 lzma xz lzip bzip2 lbzip2 lrz
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

    seq 1 60000 | perl -pe 's/$/.gif/' | parallel -X echo {.} aa {}{.} {}{}d{} {}dd{}d{.} |head -n 1 |wc
    seq 1 60000 | perl -pe 's/$/.gif/' | parallel -X echo a{}b{}c |head -n 1 |wc
    seq 1 60000 | perl -pe 's/$/.gif/' | parallel -X echo |head -n 1 |wc
    seq 1 60000 | perl -pe 's/$/.gif/' | parallel -X echo a{}b{}c {} |head -n 1 |wc
    seq 1 60000 | perl -pe 's/$/.gif/' | parallel -X echo {}aa{} |head -n 1 |wc
    seq 1 60000 | perl -pe 's/$/.gif/' | parallel -X echo {} aa {} |head -n 1 |wc
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
    random500m() {
	< /dev/zero openssl enc -aes-128-ctr -K 1234 -iv 1234 2>/dev/null |
	    head -c 500m;
    }
    a=$(random500m | parallel -k 'echo {#} $(md5sum)' | sort)
    b=$(random500m | parallel -k 'echo {#} $(md5sum)' | sort)
    c=$(random500m | parallel    'echo {#} $(md5sum)' | sort)
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

export -f $(compgen -A function | grep par_)
compgen -A function | grep par_ | sort |
    parallel --delay 0.3 --tag -k --joblog /tmp/jl-`basename $0` '{} 2>&1'
