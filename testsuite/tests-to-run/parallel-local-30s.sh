#!/bin/bash

# Simple jobs that never fails
# Each should be taking 30-100s and be possible to run in parallel
# I.e.: No race conditions, no logins

par_sigterm() {
    echo '### Test SIGTERM'
    parallel -k -j5 sleep 15';' echo ::: {1..99} >/tmp/parallel$$ 2>&1 &
    A=$!
    sleep 29; kill -TERM $A
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

par_tmp_full() {
    # Assume /tmp/shm is easy to fill up
    export SHM=/tmp/shm/parallel
    mkdir -p $SHM
    sudo umount -l $SHM 2>/dev/null
    sudo mount -t tmpfs -o size=10% none $SHM

    echo "### Test --tmpdir running full. bug #40733 was caused by this"
    stdout parallel -j1 --tmpdir $SHM cat /dev/zero ::: dummy
}

par_memory_leak() {
    a_run() {
	seq $1 |time -v parallel true 2>&1 |
	grep 'Maximum resident' |
	field 6;
    }
    export -f a_run
    echo "### Test for memory leaks"
    echo "Of 100 runs of 1 job at least one should be bigger than a 3000 job run"
    small_max=$(seq 100 | parallel a_run 1 | jq -s max)
    big=$(a_run 3000)
    if [ $small_max -lt $big ] ; then
	echo "Bad: Memleak likely."
    else
	echo "Good: No memleak detected."
    fi
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
	    grep -v '^parallel: Warning: (Starting|Consider)'
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

par_shellquote() {
    echo '### Test --shellquote in all shells'
    doit() {
	# Run --shellquote for ascii 1..255 in a shell
	shell="$1"
	"$shell" -c perl\ -e\ \'print\ pack\(\"c\*\",1..255\)\'\ \|\ parallel\ -0\ --shellquote
    }
    export -f doit
    parallel --tag -q -k doit {} ::: ash bash csh dash fish fizsh ksh ksh93 lksh mksh posh rzsh sash sh static-sh tcsh yash zsh csh tcsh
}

par_test_detected_shell() {
    echo '### bug #42913: Dont use $SHELL but the shell currently running'

    shells="ash bash csh dash fish fizsh ksh ksh93 mksh posh rbash rush rzsh sash sh static-sh tcsh yash zsh"
    test_unknown_shell() {
	shell="$1"
	tmp="/tmp/test_unknown_shell_$shell"
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

    stdout parallel -j0 --tag -k \
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
    parallel --tag -k doit ::: zstd pzstd clzip lz4 lzop pigz pxz gzip plzip pbzip2 lzma xz lzip bzip2 lbzip2 lrz
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
    parallel -qk --header : {pipe}_doit {tagstring} {compress} \
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

par_macron() {
    print_it() {
	parallel ::: "echo $1"
	parallel echo ::: "$1"
	parallel echo "$1" ::: "$1"
	parallel echo \""$1"\" ::: "$1"
	parallel -q echo ::: "$1"
	parallel -q echo "$1" ::: "$1"
	parallel -q echo \""$1"\" ::: "$1"
    }
    print_it "$(perl -e 'print "\257"')"
    print_it "$(perl -e 'print "\257\256"')"
    print_it "$(perl -e 'print "\257<\257<\257>\257>"')"
}

export -f $(compgen -A function | grep par_)
compgen -A function | grep par_ | sort |
    parallel -j0 --tag -k --joblog /tmp/jl-`basename $0` '{} 2>&1'
