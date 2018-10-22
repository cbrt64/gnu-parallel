#!/bin/bash

# Simple jobs that never fails
# Each should be taking 1-3s and be possible to run in parallel
# I.e.: No race conditions, no logins

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
    ls /tmp/parallel_results_test/testA/*/*/*/*/* | LC_ALL=C sort
    rm -rf /tmp/parallel_results_test/testA*

    echo "### Test --res"
    mkdir -p /tmp/parallel_results_test
    parallel -k --res /tmp/parallel_results_test/testD echo {1} {2} ::: I II ::: III IIII
    ls /tmp/parallel_results_test/testD/*/*/*/*/* | LC_ALL=C sort
    rm -rf /tmp/parallel_results_test/testD*

    echo "### Test --result"
    mkdir -p /tmp/parallel_results_test
    parallel -k --result /tmp/parallel_results_test/testE echo {1} {2} ::: I II ::: III IIII
    ls /tmp/parallel_results_test/testE/*/*/*/*/* | LC_ALL=C sort
    rm -rf /tmp/parallel_results_test/testE*

    echo "### Test --results --header :"
    mkdir -p /tmp/parallel_results_test
    parallel -k --header : --results /tmp/parallel_results_test/testB echo {1} {2} ::: a I II ::: b III IIII
    ls /tmp/parallel_results_test/testB/*/*/*/*/* | LC_ALL=C sort
    rm -rf /tmp/parallel_results_test/testB*

    echo "### Test --results --header : named - a/b swapped"
    mkdir -p /tmp/parallel_results_test
    parallel -k --header : --results /tmp/parallel_results_test/testC echo {a} {b} ::: b III IIII ::: a I II
    ls /tmp/parallel_results_test/testC/*/*/*/*/* | LC_ALL=C sort
    rm -rf /tmp/parallel_results_test/testC*

    echo "### Test --results --header : piped"
    mkdir -p /tmp/parallel_results_test
    (echo Col; perl -e 'print "backslash\\tab\tslash/null\0eof\n"') | parallel  --header : --result /tmp/parallel_results_test/testF true
    find /tmp/parallel_results_test/testF/*/*/* | LC_ALL=C sort
    rm -rf /tmp/parallel_results_test/testF*

    echo "### Test --results --header : piped - non-existing column header"
    mkdir -p /tmp/parallel_results_test
    (printf "Col1\t\n"; printf "v1\tv2\tv3\n"; perl -e 'print "backslash\\tab\tslash/null\0eof\n"') |
	parallel --header : --result /tmp/parallel_results_test/testG true
    find /tmp/parallel_results_test/testG/ | LC_ALL=C sort
    rm -rf /tmp/parallel_results_test/testG*
}

par_result_replace() {
    echo '### bug #49983: --results with {1}'
    parallel --results /tmp/par_{}_49983 -k echo ::: foo bar baz
    find /tmp/par_*_49983 | LC_ALL=C sort
    rm -rf /tmp/par_*_49983
    parallel --results /tmp/par_{}_49983 -k echo ::: foo bar baz ::: A B C
    find /tmp/par_*_49983 | LC_ALL=C sort
    rm -rf /tmp/par_*_49983
    parallel --results /tmp/par_{1}-{2}_49983 -k echo ::: foo bar baz ::: A B C
    find /tmp/par_*_49983 | LC_ALL=C sort
    rm -rf /tmp/par_*_49983
    parallel --results /tmp/par__49983 -k echo ::: foo bar baz ::: A B C
    find /tmp/par_*_49983 | LC_ALL=C sort
    rm -rf /tmp/par_*_49983
    parallel --results /tmp/par__49983 --header : -k echo ::: foo bar baz ::: A B C
    find /tmp/par_*_49983 | LC_ALL=C sort
    rm -rf /tmp/par_*_49983
    parallel --results /tmp/par__49983-{}/ --header : -k echo ::: foo bar baz ::: A B C
    find /tmp/par_*_49983-* | LC_ALL=C sort
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

par_header_parens() {
    echo 'bug #49538: --header and {= =}'

    parallel --header : echo '{=v2=}{=v1 $_=Q($_)=}' ::: v1 K ::: v2 O
    parallel --header : echo '{2}{=1 $_=Q($_)=}' ::: v2 K ::: v1 O
    parallel --header : echo {var/.} ::: var sub/dir/file.ext
    parallel --header : echo {var//} ::: var sub/dir/file.ext
    parallel --header : echo {var/.} ::: var sub/dir/file.ext
    parallel --header : echo {var/} ::: var sub/dir/file.ext
    parallel --header : echo {var.} ::: var sub/dir/file.ext
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

par_pipe_compress_blocks() {
    echo "### bug #41482: --pipe --compress blocks at different -j/seq combinations"
    seq 1 | parallel -k -j2 --compress -N1 -L1 --pipe cat
    echo echo 1-4 + 1-4
    seq 4 | parallel -k -j3 --compress -N1 -L1 -vv echo
    echo 4 times wc to stderr to stdout
    (seq 4 | parallel -k -j3 --compress -N1 -L1 --pipe wc '>&2') 2>&1 >/dev/null
    echo 1 2 3 4
    seq 4 | parallel -k -j3 --compress echo
    echo 1 2 3 4
    seq 4 | parallel -k -j1 --compress echo
    echo 1 2
    seq 2 | parallel -k -j1 --compress echo
    echo 1 2 3
    seq 3 | parallel -k -j2 --compress -N1 -L1 --pipe cat
}

par_too_long_line_X() {
    echo 'bug #54869: Long lines break'
    seq 3000 | parallel -Xj1 'echo {} {} {} {} {} {} {} {} {} {} {} {} {} {} | wc'
}

export -f $(compgen -A function | grep par_)
compgen -A function | grep par_ | LC_ALL=C sort |
    parallel -j6 --tag -k --joblog +/tmp/jl-`basename $0` '{} 2>&1'
