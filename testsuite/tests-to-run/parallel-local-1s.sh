#!/bin/bash

# Simple jobs that never fails
# Each should be taking 1-3s and be possible to run in parallel
# I.e.: No race conditions, no logins

par_max_length_len_128k() {
    echo "### BUG: The length for -X is not close to max (131072)"

    seq 1 60000 | parallel -X echo {.} aa {}{.} {}{}d{} {}dd{}d{.} |head -n 1 |wc
    seq 1 60000 | parallel -X echo a{}b{}c |head -n 1 |wc
    seq 1 60000 | parallel -X echo |head -n 1 |wc
    seq 1 60000 | parallel -X echo a{}b{}c {} |head -n 1 |wc
    seq 1 60000 | parallel -X echo {}aa{} |head -n 1 |wc
    seq 1 60000 | parallel -X echo {} aa {} |head -n 1 |wc
}

par_fifo_under_csh() {
    echo '### Test --fifo under csh'

    csh -c "seq 3000000 | parallel -k --pipe --fifo 'sleep .{#};cat {}|wc -c ; false; echo \$status; false'"
    echo exit $?
}

par_compress_prg_fails() {
    echo '### bug #44546: If --compress-program fails: fail'
    doit() {
	(parallel $* --compress-program false \
		  echo \; sleep 1\; ls ::: /no-existing
	echo $?) | tail -n1
    }
    export -f doit
    parallel --tag -k doit ::: '' --line-buffer ::: '' --tag ::: '' --files
}

par_pxz_complains() {
    echo 'bug #44250: pxz complains File format not recognized but decompresses anyway'

    # The first line dumps core if run from make file. Why?!
    stdout parallel --compress --compress-program pxz ls /{} ::: OK-if-missing-file
    stdout parallel --compress --compress-program pixz --decompress-program 'pixz -d' ls /{}  ::: OK-if-missing-file
    stdout parallel --compress --compress-program pixz --decompress-program 'pixz -d' true ::: OK-if-no-output
    stdout parallel --compress --compress-program pxz true ::: OK-if-no-output
}

par_test_XI_mI() {
    echo "### Test -I"
    seq 1 10 | parallel -k 'seq 1 {} | parallel -k -I :: echo {} ::'

    echo "### Test -X -I"
    seq 1 10 | parallel -k 'seq 1 {} | parallel -j1 -X -k -I :: echo a{} b::'

    echo "### Test -m -I"
    seq 1 10 | parallel -k 'seq 1 {} | parallel -j1 -m -k -I :: echo a{} b::'
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

par_result() {
    echo "### Test --results"
    mkdir -p /tmp/parallel_results_test
    parallel -k --results /tmp/parallel_results_test/testA echo {1} {2} ::: I II ::: III IIII
    ls /tmp/parallel_results_test/testA/*/*/*/*/*
    rm -rf /tmp/parallel_results_test/testA*

    echo "### Test --res"
    mkdir -p /tmp/parallel_results_test
    parallel -k --res /tmp/parallel_results_test/testD echo {1} {2} ::: I II ::: III IIII
    ls /tmp/parallel_results_test/testD/*/*/*/*/*
    rm -rf /tmp/parallel_results_test/testD*

    echo "### Test --result"
    mkdir -p /tmp/parallel_results_test
    parallel -k --result /tmp/parallel_results_test/testE echo {1} {2} ::: I II ::: III IIII
    ls /tmp/parallel_results_test/testE/*/*/*/*/*
    rm -rf /tmp/parallel_results_test/testE*

    echo "### Test --results --header :"
    mkdir -p /tmp/parallel_results_test
    parallel -k --header : --results /tmp/parallel_results_test/testB echo {1} {2} ::: a I II ::: b III IIII
    ls /tmp/parallel_results_test/testB/*/*/*/*/*
    rm -rf /tmp/parallel_results_test/testB*

    echo "### Test --results --header : named - a/b swapped"
    mkdir -p /tmp/parallel_results_test
    parallel -k --header : --results /tmp/parallel_results_test/testC echo {a} {b} ::: b III IIII ::: a I II
    ls /tmp/parallel_results_test/testC/*/*/*/*/*
    rm -rf /tmp/parallel_results_test/testC*

    echo "### Test --results --header : piped"
    mkdir -p /tmp/parallel_results_test
    (echo Col; perl -e 'print "backslash\\tab\tslash/null\0eof\n"') | parallel  --header : --result /tmp/parallel_results_test/testF true
    find /tmp/parallel_results_test/testF/*/*/* | sort
    rm -rf /tmp/parallel_results_test/testF*

    echo "### Test --results --header : piped - non-existing column header"
    mkdir -p /tmp/parallel_results_test
    (printf "Col1\t\n"; printf "v1\tv2\tv3\n"; perl -e 'print "backslash\\tab\tslash/null\0eof\n"') |
	parallel --header : --result /tmp/parallel_results_test/testG true
    find /tmp/parallel_results_test/testG/ | sort
    rm -rf /tmp/parallel_results_test/testG*
}

par_result_replace() {
    echo '### bug #49983: --results with {1}'
    parallel --results /tmp/par_{}_49983 -k echo ::: foo bar baz
    find /tmp/par_*_49983 | sort
    rm -rf /tmp/par_*_49983
    parallel --results /tmp/par_{}_49983 -k echo ::: foo bar baz ::: A B C
    find /tmp/par_*_49983 | sort
    rm -rf /tmp/par_*_49983
    parallel --results /tmp/par_{1}-{2}_49983 -k echo ::: foo bar baz ::: A B C
    find /tmp/par_*_49983 | sort
    rm -rf /tmp/par_*_49983
    parallel --results /tmp/par__49983 -k echo ::: foo bar baz ::: A B C
    find /tmp/par_*_49983 | sort
    rm -rf /tmp/par_*_49983
    parallel --results /tmp/par__49983 --header : -k echo ::: foo bar baz ::: A B C
    find /tmp/par_*_49983 | sort
    rm -rf /tmp/par_*_49983
    parallel --results /tmp/par__49983-{}/ --header : -k echo ::: foo bar baz ::: A B C
    find /tmp/par_*_49983-* | sort
    rm -rf /tmp/par_*_49983-*
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

par_incomplete_linebuffer() {
    echo 'bug #51337: --lb does not kill jobs at sigpipe'
    cat > /tmp/parallel--lb-test <<'_EOF'
#!/usr/bin/perl

while(1){ print ++$t,"\n"}
_EOF
    chmod +x /tmp/parallel--lb-test

    parallel --lb /tmp/parallel--lb-test ::: 1 | head
    # Should be empty
    ps aux | grep parallel[-]-lb-test
}


export -f $(compgen -A function | grep par_)
compgen -A function | grep par_ | sort |
    parallel -j6 --tag -k --joblog +/tmp/jl-`basename $0` '{} 2>&1'
