#!/bin/bash

# SPDX-FileCopyrightText: 2021-2022 Ole Tange, http://ole.tange.dk and Free Software and Foundation, Inc.
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Simple jobs that never fails
# Each should be taking 1-3s and be possible to run in parallel
# I.e.: No race conditions, no logins

par_skip_first_line() {
    tmpdir=$(mktemp)
    (echo `seq 10000`;echo MyHeader; seq 10) |
	parallel -k --skip-first-line --pipe --block 10 --header '1' cat
    (echo `seq 10000`;echo MyHeader; seq 10) > "$tmpdir"
    parallel -k --skip-first-line --pipepart -a "$tmpdir" --block 10 --header '1' cat
}

par_long_input() {
    echo '### Long input lines should not fail if they are not used'
    longline_tsv() {
	perl -e '$a = "X"x3000000;
	  map { print join "\t", $_, $a, "$_/$a.$a", "$a/$_.$a", "$a/$a.$_\n" }
          (a..c)'
    }
    longline_tsv |
	parallel --colsep '\t' echo {1} {3//} {4/.} '{=5 s/.*\.// =}'
    longline_tsv |
	parallel --colsep '\t' echo {-5} {-3//} {-2/.} '{=-1 s/.*\.// =}'
}

par_plus_slot_replacement() {
    echo '### show {slot} {0%} {0#}'
    parallel -k --plus 'sleep 0.{%};echo {slot}=$PARALLEL_JOBSLOT={%}' ::: A B C
    parallel -j15 -k --plus 'echo Seq: {0#} {#}' ::: {1..100} | sort
    parallel -j15 -k --plus 'sleep 0.{}; echo Slot: {0%} {%}' ::: {1..100} |
	sort -u
}

par_recend_recstart_hash() {
    echo "### bug #59843: --regexp --recstart '#' fails"
    (echo '#rec1'; echo 'bar'; echo '#rec2') |
	parallel -k --regexp --pipe -N1 --recstart '#' wc
    (echo ' rec1'; echo 'bar'; echo ' rec2') |
	parallel -k --regexp --pipe -N1 --recstart ' ' wc
    (echo 'rec2';  echo 'bar#';echo 'rec2' ) |
	parallel -k --regexp --pipe -N1 --recend '#' wc
    (echo 'rec2';  echo 'bar ';echo 'rec2' ) |
	parallel -k --regexp --pipe -N1 --recend ' ' wc
}

par_sqlandworker_uninstalled_dbd() {
    echo 'bug #56096: dbi-csv no such column'
    mkdir -p /tmp/parallel-bug-56096
    sudo mv /usr/share/perl5/DBD/CSV.pm /usr/share/perl5/DBD/CSV.pm.gone
    parallel --sqlandworker csv:///%2Ftmp%2Fparallel-bug-56096/mytable echo ::: must_fail
    sudo cp /usr/share/perl5/DBD/CSV.pm.gone /usr/share/perl5/DBD/CSV.pm
    parallel --sqlandworker csv:///%2Ftmp%2Fparallel-bug-56096/mytable echo ::: works
}

par_results_compress() {
    tmpdir=$(mktemp)
    rm -r "$tmpdir"
    parallel --results $tmpdir --compress echo ::: 1
    cat "$tmpdir"/*/*/stdout | pzstd -qdc

    rm -r "$tmpdir"
    parallel --results $tmpdir echo ::: 1
    cat "$tmpdir"/*/*/stdout

    rm -r "$tmpdir"
    parallel --results $tmpdir --compress echo ::: '  ' /
    cat "$tmpdir"/*/*/stdout | pzstd -qdc
    
    rm -r "$tmpdir"
    parallel --results $tmpdir echo ::: '  ' /
    cat "$tmpdir"/*/*/stdout

    rm -r "$tmpdir"
}

par_I_X_m() {
    echo '### Test -I with -X and -m'

    seq 10 | parallel -k 'seq 1 {.} | parallel -k -I :: echo {.} ::'
    seq 10 | parallel -k 'seq 1 {.} | parallel -j1 -X -k -I :: echo a{.} b::'
    seq 10 | parallel -k 'seq 1 {.} | parallel -j1 -m -k -I :: echo a{.} b::'
}

par_open_files_blocks() {
    echo 'bug #38439: "open files" with --files --pipe blocks after a while'
    ulimit -n 28
    yes "`seq 3000`" |
	head -c 20M |
	stdout parallel -j10 --pipe -k echo {#} of 21 |
	grep -v 'No more file handles.' |
	grep -v 'Only enough file handles to run .* jobs in parallel.' |
	grep -v 'Raising ulimit -n or /etc/security/limits.conf' |
	grep -v 'Try running .parallel -j0 -N .* --pipe parallel -j0.' |
	grep -v 'or increasing .ulimit -n. .try: ulimit -n .ulimit -Hn..' |
	grep -v 'or increasing .nofile. in /etc/security/limits.conf' |
	grep -v 'or increasing /proc/sys/fs/file-max'
}

par_pipe_unneeded_procs() {
    echo 'bug #34241: --pipe should not spawn unneeded processes - part 2'
    seq 500 | parallel --tmpdir . -j10 --pipe --block 1k --files wc >/dev/null
    ls *.par | wc -l; rm *.par
    seq 500 | parallel --tmpdir . -j10 --pipe --block 1k --files --dry-run wc >/dev/null
    echo No .par should exist
    stdout ls *.par
}

par_interactive() {
    echo '### Test -p --interactive'
    cat >/tmp/parallel-script-for-expect <<_EOF
#!/bin/bash

seq 1 3 | parallel -k -p "sleep 0.1; echo opt-p"
seq 1 3 | parallel -k --interactive "sleep 0.1; echo opt--interactive"
_EOF
    chmod 755 /tmp/parallel-script-for-expect

    (
	expect -b - <<_EOF
spawn /tmp/parallel-script-for-expect
expect "echo opt-p 1"
send "y\n"
expect "echo opt-p 2"
send "n\n"
expect "echo opt-p 3"
send "y\n"
expect "opt-p 1"
expect "opt-p 3"
expect "echo opt--interactive 1"
send "y\n"
expect "echo opt--interactive 2"
send "n\n"
#expect "opt--interactive 1"
expect "echo opt--interactive 3"
send "y\n"
expect "opt--interactive 3"
send "\n"
_EOF
	echo
    ) | perl -ne 's/\r//g;/\S/ and print' |
	# Race will cause the order to change
	LC_ALL=C sort
}

par_bug43654() {
    echo "bug #43654: --bar with command not using {} - only last output line "
    COLUMNS=80 stdout parallel --bar true {.} ::: 1 | perl -pe 's/.*\r/\r/'
}

par_replacement_rename() {
    echo "### Test --basenamereplace"
    parallel -j1 -k -X --basenamereplace FOO echo FOO ::: /a/b.c a/b.c b.c /a/b a/b b
    parallel -k --basenamereplace FOO echo FOO ::: /a/b.c a/b.c b.c /a/b a/b b

    echo "### Test --bnr"
    parallel -j1 -k -X --bnr FOO echo FOO ::: /a/b.c a/b.c b.c /a/b a/b b
    parallel -k --bnr FOO echo FOO ::: /a/b.c a/b.c b.c /a/b a/b b

    echo "### Test --extensionreplace"
    parallel -j1 -k -X --extensionreplace FOO echo FOO ::: /a/b.c a/b.c b.c /a/b a/b b
    parallel -k --extensionreplace FOO echo FOO ::: /a/b.c a/b.c b.c /a/b a/b b

    echo "### Test --er"
    parallel -j1 -k -X --er FOO echo FOO ::: /a/b.c a/b.c b.c /a/b a/b b
    parallel -k --er FOO echo FOO ::: /a/b.c a/b.c b.c /a/b a/b b

    echo "### Test --basenameextensionreplace"
    parallel -j1 -k -X --basenameextensionreplace FOO echo FOO ::: /a/b.c a/b.c b.c /a/b a/b b
    parallel -k --basenameextensionreplace FOO echo FOO ::: /a/b.c a/b.c b.c /a/b a/b b

    echo "### Test --bner"
    parallel -j1 -k -X --bner FOO echo FOO ::: /a/b.c a/b.c b.c /a/b a/b b
    parallel -k --bner FOO echo FOO ::: /a/b.c a/b.c b.c /a/b a/b b
}

par_replacement_strings() {
    echo "### Test {/}"
    parallel -j1 -k -X echo {/} ::: /a/b.c a/b.c b.c /a/b a/b b
    
    echo "### Test {/.}"
    parallel -j1 -k -X echo {/.} ::: /a/b.c a/b.c b.c /a/b a/b b
    
    echo "### Test {#/.}"
    parallel -j1 -k -X echo {2/.} ::: /a/number1.c a/number2.c number3.c /a/number4 a/number5 number6
    
    echo "### Test {#/}"
    parallel -j1 -k -X echo {2/} ::: /a/number1.c a/number2.c number3.c /a/number4 a/number5 number6
    
    echo "### Test {#.}"
    parallel -j1 -k -X echo {2.} ::: /a/number1.c a/number2.c number3.c /a/number4 a/number5 number6
}

par_bug34241() {
    echo "### bug #34241: --pipe should not spawn unneeded processes"
    echo | parallel -r -j2 -N1 --pipe md5sum -c && echo OK
}

par_test_gt_quoting() {
    echo '### Test of quoting of > bug'
    echo '>/dev/null' | parallel echo

    echo '### Test of quoting of > bug if line continuation'
    (echo '> '; echo '> '; echo '>') | parallel --max-lines 3 echo
}

par_eof_on_command_line_input_source() {
    echo '### Test of eof string on :::'
    parallel -k -E ole echo ::: foo ole bar
}

par_empty_string_command_line() {
    echo '### Test of ignore-empty string on :::'
    parallel -k -r echo ::: foo '' ole bar
}

par_trailing_space_line_continuation() {
    echo '### Test of trailing space continuation'
    (echo foo; echo '';echo 'ole ';echo bar;echo quux) | xargs -r -L2 echo
    (echo foo; echo '';echo 'ole ';echo bar;echo quux) | parallel -kr -L2 echo
    parallel -kr -L2 echo ::: foo '' 'ole ' bar quux

    echo '### Test of trailing space continuation with -E eof'
    (echo foo; echo '';echo 'ole ';echo bar;echo quux) | xargs -r -L2 -E bar echo
    (echo foo; echo '';echo 'ole ';echo bar;echo quux) | parallel -kr -L2 -E bar echo
    parallel -kr -L2 -E bar echo ::: foo '' 'ole ' bar quux
}

par_mix_triple_colon_with_quad_colon() {
    echo '### Test :::: mixed with :::'
    echo '### Test :::: < ::: :::'
    parallel -k echo {1} {2} {3} :::: <(seq 6 7) ::: 4 5 ::: 1 2 3
    
    echo '### Test :::: <  < :::: <'
    parallel -k echo {1} {2} {3} :::: <(seq 6 7) <(seq 4 5) :::: <(seq 1 3)
    
    echo '### Test -a ::::  < :::: <'
    parallel -k -a <(seq 6 7) echo {1} {2} {3} :::: <(seq 4 5) :::: <(seq 1 3)
    
    echo '### Test -a -a :::'
    parallel -k -a <(seq 6 7) -a <(seq 4 5) echo {1} {2} {3} ::: 1 2 3
    
    echo '### Test -a - -a :::'
    seq 6 7 | parallel -k -a - -a <(seq 4 5) echo {1} {2} {3} ::: 1 2 3
    
    echo '### Test :::: < - :::'
    seq 4 5 | parallel -k echo {1} {2} {3} :::: <(seq 6 7) - ::: 1 2 3
}

par_test_E() {
    echo '### Test -E'
    seq 1 100 | parallel -k -E 5 echo :::: - ::: 2 3 4 5 6 7 8 9 10 :::: <(seq 3 11)
    
    echo '### Test -E one empty'
    seq 1 100 | parallel -k -E 3 echo :::: - ::: 2 3 4 5 6 7 8 9 10 :::: <(seq 3 11)
    
    echo '### Test -E 2 empty'
    seq 1 100 | parallel -k -E 3 echo :::: - ::: 3 4 5 6 7 8 9 10 :::: <(seq 3 11)
    
    echo '### Test -E all empty'
    seq 3 100 | parallel -k -E 3 echo :::: - ::: 3 4 5 6 7 8 9 10 :::: <(seq 3 11)
}

par_test_job_number() {
    echo '### Test {#}'
    seq 1 10 | parallel -k echo {#}
}

par_seqreplace_long_line() {
    echo '### Test --seqreplace and line too long'
    seq 1 1000 |
	stdout parallel -j1 -s 210 -k --seqreplace I echo IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII \|wc |
	uniq -c
}

par_bug37042() {
    echo '### bug #37042: -J foo is taken from the whole command line - not just the part before the command'
    echo '--tagstring foo' > ~/.parallel/bug_37042_profile; 
    parallel -J bug_37042_profile echo ::: tag_with_foo; 
    parallel --tagstring a -J bug_37042_profile echo ::: tag_with_a; 
    parallel --tagstring a echo -J bug_37042_profile ::: print_-J_bug_37042_profile
    
    echo '### Bug introduce by fixing bug #37042'
    parallel --xapply -a <(printf 'abc') --colsep '\t' echo {1}
}

par_header() {
    echo "### Test --header with -N"
    (echo h1; echo h2; echo 1a;echo 1b; echo 2a;echo 2b; echo 3a) |
	parallel -j1 --pipe -N2 -k --header '.*\n.*\n' echo Start\;cat \; echo Stop
    
    echo "### Test --header with --block 1k"
    (echo h1; echo h2; perl -e '$a="x"x110;for(1..22){print $_,$a,"\n"}') |
	parallel -j1 --pipe -k --block 1k --header '.*\n.*\n' echo Start\;cat \; echo Stop

    echo "### Test --header with multiple :::"
    parallel --header : echo {a} {b} {1} {2} ::: b b1 ::: a a2
}

par_profiles_with_space() {
    echo '### bug #42902: profiles containing arguments with space'
    echo "--rpl 'FULLPATH chomp(\$_=\"/bin/bash=\".\`readlink -f \$_\`);' " > ~/.parallel/FULLPATH; 
    parallel -JFULLPATH echo FULLPATH ::: $0
    PARALLEL="--rpl 'FULLPATH chomp(\$_=\"/bin/bash=\".\`readlink -f \$_\`);' -v" parallel  echo FULLPATH ::: $0
    PARALLEL="--rpl 'FULLPATH chomp(\$_=\"/bin/bash=\".\`readlink -f \$_\`);' perl -e \'print \\\"@ARGV\\\n\\\"\' " parallel With script in \\\$PARALLEL FULLPATH ::: . |
	perl -pe 's:parallel./:parallel/:'
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

par_result() {
    echo "### Test --results"
    mkdir -p /tmp/parallel_results_test
    parallel -k --results /tmp/parallel_results_test/testA echo {1} {2} ::: I II ::: III IIII
    cat /tmp/parallel_results_test/testA/*/*/*/*/stdout | LC_ALL=C sort
    ls /tmp/parallel_results_test/testA/*/*/*/*/* | LC_ALL=C sort
    rm -rf /tmp/parallel_results_test/testA*

    echo "### Test --res"
    mkdir -p /tmp/parallel_results_test
    parallel -k --res /tmp/parallel_results_test/testD echo {1} {2} ::: I II ::: III IIII
    cat /tmp/parallel_results_test/testD/*/*/*/*/stdout | LC_ALL=C sort
    ls /tmp/parallel_results_test/testD/*/*/*/*/* | LC_ALL=C sort
    rm -rf /tmp/parallel_results_test/testD*

    echo "### Test --result"
    mkdir -p /tmp/parallel_results_test
    parallel -k --result /tmp/parallel_results_test/testE echo {1} {2} ::: I II ::: III IIII
    cat /tmp/parallel_results_test/testE/*/*/*/*/stdout | LC_ALL=C sort
    ls /tmp/parallel_results_test/testE/*/*/*/*/* | LC_ALL=C sort
    rm -rf /tmp/parallel_results_test/testE*

    echo "### Test --results --header :"
    mkdir -p /tmp/parallel_results_test
    parallel -k --header : --results /tmp/parallel_results_test/testB echo {1} {2} ::: a I II ::: b III IIII
    cat /tmp/parallel_results_test/testB/*/*/*/*/stdout | LC_ALL=C sort
    ls /tmp/parallel_results_test/testB/*/*/*/*/* | LC_ALL=C sort
    rm -rf /tmp/parallel_results_test/testB*

    echo "### Test --results --header : named - a/b swapped"
    mkdir -p /tmp/parallel_results_test
    parallel -k --header : --results /tmp/parallel_results_test/testC echo {a} {b} ::: b III IIII ::: a I II
    cat /tmp/parallel_results_test/testC/*/*/*/*/stdout | LC_ALL=C sort
    ls /tmp/parallel_results_test/testC/*/*/*/*/* | LC_ALL=C sort
    rm -rf /tmp/parallel_results_test/testC*

    echo "### Test --results --header : piped"
    mkdir -p /tmp/parallel_results_test
    (echo Col; perl -e 'print "backslash\\tab\tslash/null\0eof\n"') | parallel  --header : --result /tmp/parallel_results_test/testF true
    cat /tmp/parallel_results_test/testF/*/*/*/*/stdout | LC_ALL=C sort
    find /tmp/parallel_results_test/testF/*/*/* | LC_ALL=C sort
    rm -rf /tmp/parallel_results_test/testF*

    echo "### Test --results --header : piped - non-existing column header"
    mkdir -p /tmp/parallel_results_test
    (printf "Col1\t\n"; printf "v1\tv2\tv3\n"; perl -e 'print "backslash\\tab\tslash/null\0eof\n"') |
	parallel --header : --result /tmp/parallel_results_test/testG true
    cat /tmp/parallel_results_test/testG/*/*/*/*/stdout | LC_ALL=C sort
    find /tmp/parallel_results_test/testG/ | LC_ALL=C sort
    rm -rf /tmp/parallel_results_test/testG*
}

par_result_replace() {
    echo '### bug #49983: --results with {1}'
    parallel --results /tmp/par_{}_49983 -k echo ::: foo bar baz
    cat /tmp/par_*_49983
    find /tmp/par_*_49983 | LC_ALL=C sort
    rm -rf /tmp/par_*_49983

    parallel --results /tmp/par_{}_49983 -k echo ::: foo bar baz ::: A B C
    cat /tmp/par_*_49983
    find /tmp/par_*_49983 | LC_ALL=C sort
    rm -rf /tmp/par_*_49983

    parallel --results /tmp/par_{1}-{2}_49983 -k echo ::: foo bar baz ::: A B C
    cat /tmp/par_*_49983
    find /tmp/par_*_49983 | LC_ALL=C sort
    rm -rf /tmp/par_*_49983

    parallel --results /tmp/par__49983 -k echo ::: foo bar baz ::: A B C
    cat /tmp/par_*_49983/*/*/*/*/stdout
    find /tmp/par_*_49983 | LC_ALL=C sort
    rm -rf /tmp/par_*_49983

    parallel --results /tmp/par__49983 --header : -k echo ::: foo bar baz ::: A B C
    cat /tmp/par_*_49983/*/*/*/*/stdout
    find /tmp/par_*_49983 | LC_ALL=C sort
    rm -rf /tmp/par_*_49983

    parallel --results /tmp/par__49983-{}/ --header : -k echo ::: foo bar baz ::: A B C
    cat /tmp/par_*_49983*/stdout
    find /tmp/par_*_49983-* | LC_ALL=C sort
    rm -rf /tmp/par_*_49983-*
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

par_test_cpu_detection_cpuinfo() {
    pack() { zstd -19 | mmencode; }
    unpack() { mmencode -u | zstd -d; }
    export -f unpack
    # ssh server cat /proc/cpuinfo | pack

    cpu1() {
	echo '2-8-8-8 Xeon 8 core server in Germany'
	echo '
	KLUv/QRYbRIARmlzIxBtqgDhSWTqT86MkL9zqf+EhavXzwbElKKZVR0oAgBg5J4gcQBiAGEA
	sLnXDwczA4YzTNLcWTvx+utwzbFmQQYUDEZyZ60JhQYkubMk+Zi3NptQSECQAeUFvwJhFAiH
	cDh4wAOAnBvxgAeAO2tjk1+UO2vBhWZkzZ31gC+26BM7BrfKhZVvkptwZ0HvoROSSzHkzqKz
	e92kzALNss2vjU/N6N5c/Ep8Sms8b5+gcl8Xv41PO951/TZ/oW+kPnF0Z62WGmQJtiR3Flxq
	4aE3sZPzVV5X7TNxxHofd9aaOGLIncP26pPPPW5Lp/vEbkHvS6djzJ3Vknyw8ZohD81Bjw7i
	U67Vm6RyX7a7r8T6KlKH7J6GTmd9csYzTW+F/iQfmlN6eOm7Nt6N5csZI7r8OBxtd12fKltt
	Od0jfCUPYXP96G+DH+ur491XtvvbfdpV9CrGP3btXaE7eoIRdA/MYrEsFE2jNIxCkSgUhkES
	ZlmWZVEURUGSJEmYU+XGlZps8XQlJjPYpkofxVzgXV/jBN1LIagxprmzqtwopQfbw7AFMoAw
	GMud1fzilGaDPeqj81GuFkZ/UVKXmFBz9EO5PsIncjT4pVpXTx5mux83IFADQJsOKpW46nns
	Is7U2ZTFVYV3C3OmxEovTmU8sZyTYlYqcdTzmEUsR6PYOlV4tzAnSqz04lTGE8s5KWalEkc9
	j1nEqahrvJxROjsHSSvQhQq1tpf4zCUJFtpLU3TfUioW5HyRY49kj+F7XHNrWzFtIuMXRNui
	cMxHAZLOSIU=
	' | unpack
    }
    cpu2() {
	echo '1-4-8-4 Core i7-3632QM Acer laptop'
	echo '
	KLUv/QRYBRkANvyjJDBtnADAQSgjJ0We2YiUIhYo1GYrjfN9LZSRbXi0c1gXhgBQJaUAjQCQ
	AFstjEt/y7WLjrldy3NJYZ2SHbJMae46JVsalxR2RPcoxwvjbzHHk8cuBwx/Hia6pGiF4+uD
	LbZEjWjxPA9zSVEqFBoYjYRxSdEmmZzMwaXgkuKIbleblwqFBEazaG5wCQeENzw0TuQMELgH
	NEQA6JQID4AAuKQoXPEN6JKiPG0SLtElZfIcXNUhy5anHRc0OkjUhEtKc9OULWpkYVxSpmRW
	JucuAfLJlS35WxnfpHRMq/Pc1JnSfZSwmrrTg811xj11XM1RssP3ZdxtXhL/3mI84Su1h/1+
	nPmNMl+ZP1lSXQLh3bJ17vYHQ1712CNHed9rH5GQfTF4deznbPhVfkPCrgxe134yPOO+8l7b
	FUYO2eqSorBjvaVYHOaS8jSi781BlkXpepVJdIJstbBOLikKJA6u3txG3quftJvSzZXoq+5g
	jJxCtvXgaW5/Kdd8ail3npR7o5jvek+tvh9kVRN8U/VY7y2u2eZZxFSXRNY1slhy1vWp0PWk
	0b22tE2M+x3Zyj1zuxrJG2Z6lPnNsT1kbT+3JY8YCbujzPwG9pv1Ehj5WzZx+5TtooR/ItZu
	n2gTDwIf27u4r6buWtkcZfzEEQQETgMtGA5BFDlQg1k8EBRBEEMALSDoeZpGAbRoGo/jNAWN
	RcHjNA3DMNCCYZ6GYSDoWTCPwyxSR4XqWHHBT6WQu7wF6ekijecC53bUI+eSwsw6W1vLE11S
	OiqMDvfW9CxPs2AUOOugdEhqqZp5Z147oSadsnlqmMiks5kuP1LI1k/hBFkGoZbGvOnc+/j2
	veb6au5w6qPbeyWc+lXIV14UBzsgIKMZ0jAPK+HdMhUFdRtVjCeXO5JNULexYjxRJq2g2EaV
	8O7CRoIUlGysjsfKBCko2ag6HruIkWyCuo0V44ky2YRS1xX8jOLIPpdShdsmd5zFkNBhyRjs
	jWqiDxsGiQbeb74N2hniRTgqfc6PK/sOQHV9UrS1UtKWyvnmCMjuOeEbaVqYTWLEy8KHcwab
	fNdt
	' | unpack
    }
    cpu3() {
	echo '1-2-4-2 Core i5-2410M laptop firewall'
	echo '
	KLUv/QRYTRUAdrWRJCBtLACzSvaJv8mdRORLLoVMJ3pdprIRArYowWEZLgRCIHoEDZEAfQCA
	ALM94qbc+9LZVuOOaol8MPJ6MQ5Ze00x4WWw8MXBYO6orXj9nTTWluJ4LCCQRrmjVEUCA1Mm
	xh21brZJ24vLcUdJ5GPe2qsiAYHBLJYXHKLh4AwMpbEMELwHMDwALJ0HD3AAuKM2MvmlcUcp
	uG7G1dxRFPBFBj3ituBWqbDyRXIR7ij3HjqdXGkx7ig6u7dNyitytkd4bl0d/SQPIWtN0d8I
	P9bXybu/bPe3+7Qn6FOMf9zYu7pPOoIQbG+YbX5lfGnGdtbiV8KntMbz9h9T+7b4ZXza8a3r
	t/nrvlF6xNAdpVrCIE8sRrmj4EoL717ETc5Xedu0T8TQ6qW4o1TE0GLcOWSvPvnaY7aWO6qX
	Bo/wgSYMfpLYV2I9vZedbnz1WfmgY+ue1vVVNp789pgt0xflaWz33Wv82Byfcp3eKFM7s939
	JdbX3k9ROuT2tDud9ckZ32h6q7uEk4BRhI3/JD9iiK6E7SG6zLO2nPIUkgknzzod8pR3c0oe
	XvqukXdk+XJGiC4/k0bZW9enSlY7DONoIIvFQcAsiwJhIAvHY1EUAgZj8WiU5VS5cSVMsni6
	E5MXZFGlT3o0LvCuL/KGuaO6e6lzbDWaO6rKjVLyIHsazXoQLCAPAn5xSmZkLYr0LK1tuS8n
	pqtw4xNxiyKrK19CfmWUnbn3SHdS3StP91h65T1FfXQ+ytNC6C9K6RPTsUk/lOvp9mMRj/AG
	JSDQIqIi7LRUwrvFZJLUAVuxPLHcLdUEdcBUDE/UqSanrs9zRmXkcaNU+bZlG7hrcxA2mUBy
	T8tuUnd4augwnjSRdwOqb6To3FJWLMn5yBHIbnjCtm86kCEx8rLwgZ4B68GiZg==
	' | unpack
    }
    cpu4() {
	echo '1-2-2-2 AMD Opteron 244 dual core laptop(?)'
	echo '
	KLUv/QRYvQoANtlJIkBprACDMMQtkTstiphu+tF3RsomRkcLaiECKgDo7qgtvyZCAEQAOQCP
	WWerZUFc4QE7AaJ0dHLCDRiLr6TL4r9SgsrIVQLJV2KAb5n7w00ZMBbtzaiO+Sy+EvMajmSi
	Qgr5So7s1iYdVgErQYUUnnkPtyjfZG2RNh52qpXhK6WHHVvZHIK4CR1Kxq/UPAsN6DFOFSB8
	QWjD66ujsaYGFOWgQBTJV0oNBwwk+UpNDE5H7tHuHf1AB9sTijZ/Mj4kt521vTZ8x5l71n57
	zK6I2rXtlfGd3ree1+Yrc13oD7uvlLphkB8qeQvBIZEonvPMg848955fM+pqwyLbO/qQrJaE
	GlAOBElC+UrNb2UjF9SM9CEjo3zhZ6TR7qN4CFlrhj5Cu6/dDxAAAieJgnrpvudbNgNUIOzA
	MqSoSuBmxjF3/rkp5oAwr3m0DVcImxgIDpyVKKrENj8=
	' | unpack
    }
    cpu5() {
	echo '2-24-48-24 24-core (maxwell?)'
	echo '
	KLUv/QRYdSQAGkNoCyQADcMCI0TLks4mlR/lnQWq4v01q/9MCZihKMz3R7P+/yfjrxe5AKIA
	pAAKdnLCyuueNSgYcfRSeGMYCkYcyJs7DVYooYPcjoTeGL10uivYGQ9+6XTHSm+MTkjoHGAf
	yJ3mYFNY4MMAgyNJQdQbYyvA/i645o6FGAIMk6Q3hlFBQYNkIeiNsW+6SR2Mx3pjJCRk3tpH
	BQUJEIVAeoGnxRUmSQMYgkNwcOABHgCQcyM8wAMAb4yNTT4lbwzD2TfjkbwxKDgwNsQV7A5n
	q1ywEirkJnhjPGig88ldHMgbg87udZPyERXKGb+S3vou4UlwFNFxfCj5CkbQTbQ9gi7zrC2n
	PIXEdCbP+vzNmTDw0nc9vA/LlzMi6LJhwdF219VQZastp3t0zq7roz8k0PLjP/KO01xT6O+B
	H+vrwruftvvbfdoP4k+Mh+zau74vtMJBOO6J2ubXxl/M6N5c/Cb4lNZ43v7yuK+L38anHe+6
	fpu/7xsXVzDijWF0ojk84VDojeHsYp0/GMdK3hhVbpQJ6DRDcqSFAMMo9sZohnEm5uHoSPe8
	sb/dDp1oxB/kxSvvKVRIJ6T8rIM4jHLxCfO1hTZQrl8Jncl16WHlR7oL9b0rXzr8yvPA+9po
	e3vw0TEgFprzJxt99C5BiD+L9l20ft7bTjfCalgJndf2GVzXV+l48h3klp4nZFjb/ebeH3T8
	6B6fcn2eoMddbXc/xfra+yf2n7i4w87Q73QGDGOYojCFJYwxxpZiii3EEGMUwyxJKYbQQmsh
	i2EUoyhpUQohRSmFEiUpibHE0lJJJaVQQikphBikEFoQhRjDMGtRFKUwlhKFkIQQsha2MJWw
	hKXFFkMpscSQhDCEMcyyLEtKTEEWslayLIolSVprIbUkpRCEUkIpIYSYlNCCEKMgtCQIMbYs
	ayWJUmullBJCR1Plxk002eLpTph8OE1RKVws6wLeFR6erDdGdy99rwWA56ixqCwgIiKDAAhC
	MCMAACxsAhKoQBgGIBAIxsEIwTkOEfxPwgUfLJZYP9vKZrhEZep2u7k7XFK1ZLTlxfNql0Dp
	yIyLNj3Wy9LeMRJXK8cgHu09Fq1Yq8b0XW09VsBqLc3ckYn047pXflSABeQzkYdcPcePl78l
	oEW3htyWDCvcopK7b0uGSt6uFhO7XBKlKikuaCWPOa6tcXOiBR1jXNPFta0FfQxn6O1mJGr5
	2Luq5WO+pnaPdalaeiyWdukXgH8mpTAUl1kS47K2M8j8mHlcElJyq2RtiZDCbSm5+7ZkGJQZ
	l7eixcwul0SpiowL2tRYJ0t7x0hcrRyDeLT3WLSiVo7pM9pyrIDRyjFUlvv8H/M+JvuQKzUY
	kM7MMXFBQ7TYyblwJnts2KkJO02wk27ZTOpjv06V+jple920PkaXcca67lrtscV1V9y9WuCx
	xLUirn8t9NjMkJcZXC01dpO13hjFq01jyqKWjd272jEWZke+Xv7966LvqzZTC0zEIma1yNpX
	ketyZer/0g6AFe7sFs2nePnngUV+Cv9cPO6zftzOuDDzXMWe+8I/vwr+ll9K
	' | unpack
    }
    cpu6() {
	echo '1-2-2-2 HP Laptop Compaq 6530b'
	echo '
	KLUv/QRY1Q8A1iZsIyBvqwA3o23SyJIQjJ06dkMYGMYDOkA5MLcI3iHqFTCAyKAwaQBhAFkA
	BstXShcNEAYKi5SvtE7UKLU9pSxfKQIb885WFw0MioNgOcKvKEpj4hQRCl8ZFQYcgxYeIAEA
	o1y3Cl9pH4NvML5ScuvEp5qvZOHaY88hVuV2QoeFDYLL8JWc9pDRgTtRyleSsXs1SlYBy/iy
	37Xnt/nrfN/kED9fKXWEOa5QjeUruZ2su9MgVhjb5NVoHxA/qtfiKyWIH6V83bE2G2zamK2M
	eog1Oe0royrGV+oIbA7SWil3TFtbSFglPJxh7EXrr0SZqoVhCAoOAjudN8h/5DK74wjfE/KG
	LB/G98jlh0Qlu/Z8TMhmw6h/7hG8c0zbor8Q/pufknefsd3f7suOnkfvvbGy93Quacg9Tt80
	tvmT8Sfx6Zm+b4Qv5Xzn7Tsi/ep7y7Isak24byMMsne5FZGVY9CUbeJgLvCeDfKme6XjMMU0
	X2nCfTDSHHswjXI4CJSDgsZXam4vRiJEQRD15Eqm8+cej4S574R19KcOX/KM3iyRvrHdfcab
	d6yPdi7jbDC+M00HGgDJQBXgHVgYGFDCduKMmpHxiUzAByptDXwxQm8Orkb8MKwzCJ2GRGOh
	S1UsIOebOfYk2efwPdf8XqtmFQx7uDu4QYQPJQq2DBQj
	' | unpack
    }
    cpu7() {
	echo '1-8-8-8 Huawei P Smart Octa-core (4x2.36 GHz Cortex-A53 & 4x1.7 GHz Cortex-A53)'
	echo '
	KLUv/QRYZQUAwkkgH1BnrABA24MVyJENxj4WLhwSzxygdYSSvS59MzORDgyGAoEto0jsDTHx
	9XOWl0pYpXrUG5qMPlbneFtuptv5FMdasGcns3AXCd8HEEQylmN3Q5V+oUp/WRoo36uHPHs6
	+wS+1kuCN9TLzdRNJHYM1hsSQAACYkE8JPWGOHaviyxTDgAkQAkMUAcDFIMBSmCAOhigGAwo
	4Wbu07xD5gw177vZqo64sbtwFDXaE3w=
	' | unpack
    }
    cpu8() {
	echo '1-4-4-4 x96 quad-core Android TV-box'
	echo '
	KLUv/QRY5QcAhlE1H1BnKwDIkoetw1FHvrd6TW5nqI4+EQedzut9ABQptb4rACoALAD72HTS
	yk/im3vpzs7kbugyATqUkc6ORAG7AF+v3P8qKK0RiLPTzJzcmE4E9W9C+qMuDC+XM+FLV09h
	E+lcd0VsFHoHV7lcXB2t29Uq88Yq8xA2UX5yb77KfaSkV6aEdHbosq+3Gs64G9qYPqX1GiuB
	6cKRoYzvB4kBdLr1Je+rShcoKVYc2jpeAaUQZCHItkI6rJSUYZOhzs6B+5oNUHsIDIyIs8O9
	i6S3AKF1dhYmDgA0xZA5Q837braqI67uHZjSlgNrgIOBQ8Q8pCcNnhe5YjIBX0edag==
	' | unpack
    }
    cpu9() {
	echo '1-6-6-6 Kramses 200 USD laptop 6-core'
	echo '
	KLUv/QRYlQcAgk8uH1AJrABITeNdwrPRAqt9X9oa+rr/FE0XsNM0A4oUUSIDBmKowyiQcm/F
	1bpHYhKJN2Fil2uzj1AMCHmi+/CivJxl8wjF8EIlVtlpUwbbQgjFcONYdrmRTnyRTjxjT4OP
	mm/LkVuvCdm5F7OevZiFVEfGPxo2fffUHUZGD5s+s6dxzOYK7XH4DUsn6j6caoBSEkDUkz9B
	OTi8hVeAAhjSAFdvXeVIHxAInlxbujNlXkPpyffFqMtbiAIVAC1AFUAfSJgbUAKU9wNU9gNU
	+QH1Gq2EwfCdq39vKWe7c6q/wBoyA0HbuS0w7lMlg1sHMAcaacWR
	' | unpack
    }
    cpu10() {
	echo '4-48-48-48 Dell R815 4 CPU 48-core'
	echo '
	KLUv/QRYRSEApj+vIjBLLADDcJR4ZOmSMcbRLoFyVLE7QWmYAUkyhG4uXRgCwJ2sAJ0ApQDz
	j2zYCFV5LceJnYZVIM0Qb46jYRWIevMJ5ZWQjNJCjmp8w8bjkeeoRoStN0cvIDkTshH1CaNs
	CIZFChDO1ntzcITsMyPCiDSlBpRi7M1xRBwoMI9SSq1JvTn4qbFGUVJkvTkWkLSWbyNOWckZ
	HkAvAFQjvnbhBgoEbw6mEDrz5jgmP5UiyXpzQExJoeINGxEDBYIoL8SM2yB4czzSieoDsYSo
	N0dUuznWyCIBh4hwwdOxNJ5OR8GA8xeKttona4qP6pVQpZeQPY2P81B457kT23obqtCnrdCf
	WheO5eixr3MheBuq8Xfihwo97XTexr5P9MRisX3sr63OnXii9BP0OWFsiP5lnHH3uftRT4pP
	lJ7RjamY8Unjtr/QXqo0HkZ6XthH0aW33F+meI70DO2jpo99z23Pz5lKb1jFm+PoBZz2AXlv
	jskSB7BxIykJvK9MfOnm6Hkg4pI3x4WYOi5BmhfQHsHdMbUKEhoQ594cbSWti5pA2JIcjm5k
	219wO3M2oHd0L3S6nctRQ/QdIE+HJdiT4ox4IaVOYt5GAon4TqngbkB7lmA7VkbQHWKdDpX6
	UpSYv5ZS6Xzhbes8MB41dR7JT4V+n4dfCUmHfifkH6SuZ8TLCo4sd0MLOWFLeui4+zQBlyg+
	SgvvxKdSB4rylCRxyXvtOcdca6sxpthabymmmFOOYRqzLGxRlKUkK1lqJa29x5hza7WmnHKM
	Mcxay6JUU5THJIlb3muKcyxpbT3GGmuKOYZ5bVkcU5S2koQp9t5inFNLa09hzCWvPfXUY865
	1dZizqm23lpuMUxjloUtirKUJFHJe+8551xrrTHG2FprIQ+Mt+XbEQyq1Hq8fXpv733fNxdi
	ygsIQfqIH6pFZoDlqEGwFQAEQA4AEAACcBMAAAgGEshgGAgBCAKCSSQgOCYK/2sGH+oAS++e
	VqS/F4zU7z0u9T1GSvVeu1K9N6t0c0/yY6Xag3up98Qm5T0PSZX3+IzOLfeqIuUexEu952Ap
	4T2fk3T3ICSle8dR6vZaKf29IEi/53FS7xlISvesJW0mAjIpo27dS5JU7yEm/T1VkH5vEJK6
	vYOlfc9AqdxjqzT3ZpSK1AAym0h99z5VpS1TIwAH5ABuGkB5CC7/HDKKQAjgbgBaw+LsTyLv
	1Z/UMvrTdJ7On3T45E9q/GnKFP7IHmOV1p6oStVeqErXXlRKa0/USmsvVKVqL1altScqpbU3
	qlJbGwD2iO3o4vIdhC9r3/gEqm4WaLhveaVn2a/WmtxlZf1r5amu/n8Oqy5VPeifi7Z8D+pV
	HtHLu3cB1t7Q82P9mJ5lzZxZiTsc5NfnI+/+/t8Hj/tsF7ZZhZabKpETW3DxywH3CuPZ
	' | unpack
    }
    cpu11() {
	echo '1-4-8-4 4-core/8 thread Lenovo T480'
	echo '
	KLUv/QRYvRIA5mt4IyBvKwATk8iUn9xdIuJLbC8JrUxyQsMubiQkFCUoEAiB6BE0eABoAGcA
	qSHywcdrlRyy9toiwirB4QyjNF9pL15/I401lSQJQZIYXDA8JMpXgsjHvLXVBcNC0hAoR/gE
	hMInksZiMNB4D3iQAFg6FR4QAfCVNjL5hVG+UoLrZlTNV7KALzLnDzcFt8qGle+Ru/CV3HPQ
	6eRCKvlKdHZvm5RVjxt7V/dIP9CB7Q1jm18ZH5qxnbX4hfAprfG8fYOofVv8Mj7t+Nb12/x1
	3wj9YecrpYYwyBVqWb4SXGjh3Xu4yfkqb4vW8bCjei2+UnrYUcnXIXv1ydceM8V8pV462x9u
	yb0vnU0ZfAX8yvPB+8ooO3PvETqcCIN3klFH3xrFeQSxnl+IdfRe9iobT/4+oBnfHrMl+qI4
	mO1+bI5PuUZvlKidReeM7e4vsb72PorQITdHu9NZn5zxTNNb3Z/k74Mf62vk3V+2+9t92pHz
	KMYHBQUFTcNoGo0GwywMg8FYFmVRFEWtKjcuhEkWT7disoLsqfRBBswF3vU9fsD4St291Dmm
	mOYrVblRQh5kDkZVnsxiP3LsbrcdfcTx7jWG5HtHul9efJw39pcIYldefLz2Q+GYgz0a0s4j
	3Uh178qXMC8gICMhGnYpKuGdGMVqqIR3FoZMSQ3V8ZiYkhqq4zGLIFFXQ8V6IkZdDRXzxHJI
	FKuhEt6JTTFr7sHFkbEspWq3gcg4GEnCDRHCLERgJRyDNg6inUEsukGicXWpWC7nkyOR3f6E
	T9+IZeJitNtyLQ6A1ShkK/65
	' | unpack
    }
    cpu12() {
	echo '4-64-64-64 Dell R815 4 CPU 64-core'
	echo '
	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
	/q05b9gEeqJ524Ixfxz8jbBi
	' | unpack
    }
    cpu13() {
	echo '1-2-2-2 AMD Neo N36L Dual-Core Processor'
	echo '
	KLUv/QRoPRQA9iRoIyCPmwBAIy3LSinV2zbLlasWEvo1qQe/YpQhuFH+WyAIGgB4ZgBYAFoA
	rN2p1bjy7LIA8UeDkReNn89SaykAuHCQiCwGQ1lNF4fz2m42LxTPCBkInIIaHgFxTBzmxB8e
	LqAd8KB7WuGp6h3AJYO6QJiKa6okh3YtDRIKq/XLpyEF1lKE7GW0MJ4AECFzLhg3XxbfOEwu
	W5iakpR3xxV+P28kM0VyiuofhpzErUMcrfYR1HXlxNZv8iOU9Vz6VPvI+sX95H2yp0ZnR7md
	LAYuo3Rn7cHWm4uSibMCraR1e221VWtpsGsaBw01S0aK07b4brGgS1Fs3HtVo2dvmjyJtWTN
	Jrfgc9M+iRj+WZ2SjKse2qhIXBrxK0s56dLqSpJHufdbC/cQJsJuD+rb2ye2cOE7g9BJmzH1
	U80Prk/gY46rCwzDOJhl4YtHv5qv/e0+P6WPuzgFdWzRwLlb88iDOSNjql/qc5pT6QFZOB21
	h3gsRFQskIMCAwSDbQod2CwNJkoZe+XyGYxHJqbqTnJyDnrn2K0Sc+qMFiqZlZRqalxnKDAE
	iFNnHPIyW6sjBSmjVv2fZQzcoCUQPqCxgIN0gPYK4Id9CK2Xrhh+6pczlgJU1dW5V1wXneBN
	Dso0OEHQ1BAQD8hEOKPSSEqqnbiUo9qSNWNCSqPFwUg3GEdg597rYovkh/VDJS4Jc2hsDA3N
	hu0BT8rqVWmlI7y1M7cQWtFBkCZ5dJEVHCEfnkAcxowh8tfz/1gcq4N0e/Ln4LoBaCTxpDA/
	K9wEOcdPpxqOgLHqXpMH0AQrQRswgv0G5nqaeJrhzIzcgz0m/QlzxxEQGeDTfXJ21z8GJGDt
	hOfZ08YsNAENX1FX
	' | unpack
    }
    cpu14() {
	echo '1-1-1-1 Intel Xeon X5675 (mandriva.p)'
	echo '
 	KLUv/QRo1QwABt5WJBCNWAGjFDHykUWSQEvNjTGJMp1z5pZCA7MA9TKhFAAAEwwAAlEASgBI
	AI5SkwOF5Y6KYGPe2WtyYNBQJBYf+BmNhuHwhoUCGNfhAQwAd9Q+Bs8wd5RyC8W3mjtK4tpj
	j0usy+2ECAubBNfgjoLaIyMEN7IUd5SM3atRcmcRX8r5ztvXxuyOSb/6vowv+117fpu/0PdF
	LvGjI+Y4YiluI+sONYkVxjZ5ddqnVyLxYxEk3OFYFuWO2knrL0SZrsaiSTgYisUD3X0ZZ4Px
	HQKCcNJzym+QOcJLougixzkdijF6eOVZuvZ8JmSzYdQ/d9aekPwE7xzTlvQn5Mt2X/b0+PTe
	IS25h9M3i8n4kfg0azkT7tuIQfYuNyLyckyaskUczAUc09YSCL9ne7iC6V4JQWzCfTBqjj1M
	sxpLoqEozR3V3F6M4sN67nlAmHsv+4TKkb8oD7Pdb5RJv9gYKBAixjTqEIhm1AHKWTCgrkEE
	YstArr0BOSgXJ4Xmpu4j9PRpQcgRCckdf4fcSFol9GuGecuj5uBxngHakML8
	' | unpack
    }
    cpu15() {
	echo '1-1-1-1 Intel(R) Celeron(R) M (eee900)'
	echo '
	KLUv/QRo5Q0ABp9XIkBrqwCI2LZJIts7o1loU/RrgCM1Bkm4qbLeX6WzKj6uMAFQAE8ARwAL
	JHEgV0hbZFGyfUlxhRq4zDo7PSwsEOTgX8Ao1WnCAxwArpC+BU+AuELIaYsvGVyhh9u3mDvM
	ktMJGRSuA1XhCrVVZGxQn4RcIRm7lUXJAdxIyRVy+qh7W4cZjDtZmUOV1ofD60XGIAiTIrxC
	jbMozzbmbu1cuGx5XSGVkSXEFeoGrlu2294ttv1gcEJoeIJIPGxfGWyxlEiQAYXQw0KHjdim
	06c4zJwl7eT3XO6A14X/5rufaPdlO5g73vsyW+/ZzmjHMY79iY99NXwp5ztrX+FgV/auiy/7
	nfW8Nl/b9T13mOlmuSmpCfVps+B6l9qInNxyptxH4D13eULQrbK1NaE+2KxbSoFBSiADCKLg
	fbGJS5rL2Omcpyxu7rvh1eh3e2cmwr178WNRVMbZSoJ4FJWTKXcnKADAIKuqBxBI54gcFYp3
	xUIMqhrUyHoLjYPwgszI7eGRdSUOFMYQlpP0pOoEAV0WM1zTXUey4OeJUEZtb+UNcgLSAYUj
	iyXJQ3TVfIX50ANedGFbHwEc/JQzJup4YQ==
	' | unpack
    }

    export -f $(compgen -A function | grep ^cpu)
    
    test_one() {
	eval $1 | head -n1
	export PARALLEL_CPUINFO="$(eval $1 | tail -n +2)"
	echo $(parallel --number-of-sockets) \
	     $(parallel --number-of-cores) \
	     $(parallel --number-of-threads) \
	     $(parallel --number-of-cpus)
    }
    export -f test_one
    compgen -A function | grep ^cpu | sort | parallel -j0 -k test_one
    rm ~/.parallel/tmp/sshlogin/*/cpuspec 2>/dev/null
}

par_test_cpu_detection_lscpu() {
    pack() { zstd -19 | mmencode; }
    unpack() { mmencode -u | zstd -d; }
    export -f unpack
    # ssh server lscpu | pack
    
    cpu1() {
	echo '2-8-8-8 Xeon 8 core server in Germany'
	echo '
	KLUv/QRodQYA8solITAL5gF7YbnaqsSsYkliK98HHFiNI3FSwNumyBYOykA5Aew4x163Zw87
	7XAqwtiSPYwAiCZa/8LET3hd+xO/ZCDAJQlLGEACjIF+VflN4KP1dFkhfg/zHeDC9Esbp39R
	LyBo2lZJfWLmstJeIOmA2/WGWC23lWFWY1uv2rAKCd1SESOtGFYhITDsnsJDEK24vW70+1S0
	SxQgQIII9QEdLfxiBElVRWsZDqgLA+oSr9kgrmS70kDZt2WvOkEnODfAiaJIAWgWoteFUwLs
	8nwc
	' | unpack
    }
    cpu2() {
	echo '1-4-8-4 Core i7-3632QM Acer laptop'
	echo '
	KLUv/QRoxR8AukKICyngcGoTEJCWSciVLZJIKEXuzdZEplGI3JgV4DZJLMuEV2COJ8wwH2L4
	BcEAsgChABMIwcjiqQJCoZiUW0AsFAUYGxxMCkBPd7MpzAYHDRQMCMYPfDKB0Xg0HgjoA0wq
	D0ABQDr1HjHgLRmcMI9LU6eeZz9JPo1eNlAgeYTs5cQ7gkmFCMyCwjg6MSzIGWEChgHXYy5T
	GS0VhsCDolnbn0/bw5PARDQVdVQpwnGHppbyxbLnVuePBucG5TNnZAwB85Syt+DZuhVCTBYl
	PPsSYRyPO7Q6D4xGAAaQDLqHha8gkYBxPJpHxHRIxqhXtlpWRBAx+yncNw3H1BiVc4ZWaWAB
	l4UrJkeQhfSMvQ6ulXz21FuvuFcqnbGyRyhPSVu1CMKs9uI8I2z+yqVIIE8DZN3SAMd8nsiJ
	KluCQ5hNskmvTCh34LRw1J43pezB9QuTCY4pPckXVCRu4OkFBE5I7ROKLG9tS4G0dXLIZOJB
	q0W7Re5Oa8kvrU0dFfO1aOKKR2Nyhkb0wSMYaVlqnS0gMNNDZeJBbbVBJ5jGAkJRoOGgSEgC
	beE7gxBqNuO5nbOT+wfdE3Mby4qq6aeaXfuu+Om9NbX4wk9n7/ptOfMZyfzI0/PJuesudW72
	tv5otNpL0K0raB9ju2/yl656xLSeyz3VPrL74n7yPtnTSY/2OYQh1RgwLHvl86g3jBCho77e
	hdUnrjC4YFzqDiMcks2J0NPW9HmEQqFCuYMFBg2FQkQiIrlDPm1wO+OXxnwJvbWIAaP1KX4M
	W7TmUWVbDXPn3r+2bxXVFdO7mJZm74Uu5jedchji50xXem9GqHGnbM/VPekaIFMWbuL219Hm
	O+voOTp65jBfe+9svluknsa15rGoFln8eiyeT5J6Soqnc6rHdNoNU8mafmvhMqYzFo2D6dq7
	xfZxe/pjMa03kjk/OeltV8PsEbY+6O54cDZ7BpahRa6tvb69OtNo18L3CwQbXNjTA3IgUABA
	FFkPLUa8gdKoM6utIHa/NrtPEu5DQv8gyge6RJ2RmegWA2w0olDY/5lu43u3KLpQpvV9DWB7
	CFzd08L6NLcg3DK2Iii4oCIi1jNIE2hkLi8wQYrBQthc9idpAuBaroQWpoIwMqR3NNkECfJu
	sp2IAOACZSd4BLmUzVHl0rV1Cx0Tz3XrtPBCCl8Kvi0Wusx4XxBktMyMQbkszXzEs4pfZzPl
	aJcthoylYAaKfS4KyazRcAhc3IKx7ShmMdAXiKvD0NxyiR0chavOhoeEWuhRXAvYVR9j44TQ
	yFRTQMEnwBmtgAoLU0YIijDMvRARZYMpA4smUrtjrICOHpSiNYqBXUcja59JvwK0LWESpwSv
	+wJQ
	' | unpack
    }
    cpu3() {
	echo '1-2-4-2 Core i5-2410M laptop firewall'
	echo '
	KLUv/QRobR0AFj+vJvCyNgHQEZLJrWwzBCOlyJ2IXthpoGeK2U1oGVrADy9eHBY/BkIIsgCr
	AJsAlEmEYJJAgT4kMAcbuFJqZ54PiQiIhAD6wjGQyAQaMNgHYDQPwABQisFDrzx1EfNQOm8p
	Nl0bXhRuBTXC4fIZHVQNeAZMRsUTybRytMg6Y8MDxfap0jGdHM0jGYA07/sV7huAFs/ksarn
	WgiTCzzWljscee6VTpGwfiyfWadzDA9k6+DD9XUvxStT3bS4dsfyTCgX6JUGIEkAA6iL1ICM
	z7hoeCaUiIJwvaKz6qa9nDYZAg03ykcRT905mXTeSObBBR0Z21SuKhHrOltSsTXlO8j+uk15
	ttYdr7slc7W22asqzEx2pOuMzW8qM5cK9Iiun2KsazCZK/DUaaqkyfQ1vMIOA+PyVAte/qC5
	uMJmezFTRyj0vYLRmOjlbL+KuvT68k7vW4lNha/SOMSymEskUMTg0Fp24hOKchprdxGK5xrQ
	aMC4zT5W44ESDCaZiwsmbqIFAS6EAAJJgC5GBfPc0llSeRipaaqMOG2yqCFrpt5l43bzF/x7
	rHGHr5I81W/OIWX+5Gv6RVFf2di53Tlcvem1UyTN5K1ItbON/JxNXSq/rWRHuNq1UVcmP5l6
	476yvLorZb2S0yu8YQ/icdpNp4m9Y8WMEnuDHWa/WLOB+95Ot2QwNJkLbEBEGYzH1sHYbrmw
	XC6gcF+UrfNtp0Ld/L0KAuqFjD81j4u8qEWOOrc8fPLNJjtze2oqp91bRrfSekudcae89E1f
	Clr3iI5xOJqyL6VtviSlPU9p7yTmb8tLUk+9aOKw98tiV4vxdVb2qdR25Ji66A2bjBK6DkWi
	idsmTzUnP2Vfp0Sudoky8yHWX5T1J1vE7jP2wkh9QmFt9w7X8SrqNfmF8uxuK9lkhO9s4osy
	9vUnI7yLcRNJDWMgUASALDIelxSA43If9uHpvXHEbfAybA5yiTzjJGNsNEJhrP/trvE9thy4
	EPWxBL9Ev+3Tc4V4y+yIoASj88gBPDh1YC0Hj+9SAIGlXIksTAVhZEDvaLMJEPRuqp2YAOQC
	TScOHg0AZWaC3ta8uvJY+7RdpnWcJnqpGYJyWZn52M42vTHmkCoi6xGLgGI6qJBMGjmMBMaA
	xU0EY9tRzDJQ4nY0BW6JnRuEi+6GBsRfsKN4C1hVzzGGYiil6i4wwSfBmRYAFSBTdAhduMYs
	pN+yYcqIRXOpXTBSQCcPSsga9cCuhh7z/9NC2xMmKUr4tsTH
	' | unpack
    }
    _cpu4() {
	echo '1-2-2-2 dual core laptop(?)'
	echo '
	' | unpack
    }
    _cpu5() {
	echo '2-24-48-24 24-core (maxwell?)'
	echo '
	' | unpack
    }
    _cpu6() {
	echo '1-2-2-2 HP Laptop Compaq 6530b'
	echo '
	' | unpack
    }
    cpu7() {
	echo '1-8-8-8 Huawei P Smart Octa-core (4x2.36 GHz Cortex-A53 & 4x1.7 GHz Cortex-A53)'
	echo '
	KLUv/QRoTQgAgk8yJCCN6AGBEUmyQvipyGwhCMTqQifa7nWt/lvbXsAxLGVACC2ABrswzRtD
	KImUazOO/vUjml18lTF9qBAGEXY5CsYxMaQJmQvlLPmUUkqxNMwykSDxhEWqHCIfpf2OZQgg
	ZdLvM+rIJC+G7aa00gJkwGCfTnbDLo5dzM83RJu1fUY7MBt7U8faIwxboCh+vj7I3PJBRTbW
	eUzRSvacPOCG/0+BH2/nDe6XWOxqWOCfg7IwARWg3YwKnfyYol1NpDlj/LRLvvW/SHMoGAAr
	Q5AWDg9qGEBiofABuk3KGsauTvhpnhsa5HVShxsS93JpFOfBzhP4ZgBCDQ0XCuEub/2VgAiV
	mwwoAdUl+VI=
	' | unpack
    }
    cpu8() {
	echo '1-4-4-4 x96 quad-core Android TV-box'
	echo '
	KLUv/QRo/QgAtpE4JBCNWAHfG9LkksIm0BaMBALBz/jVBGlPVDQCo6NyBAUAwCBwEC4ALwAv
	AE3Pdb/CdQp8qMWbgAkggTgKsm3Q4Oq6V+ENa+PHtSUIlBuYHrM3ylI/2hs93AgNJUKbo6OP
	wb9x2qJDORYaBQnn2KA2qCXS+vDEqRwdtcTnrLIx5YhBMcoCQQ+1/s5JT34q++OePenb28ku
	oTlh7mAtuGutJaBYGMsEguMR7F0CcdRCLp7AlVI7ohhGqqdtezZt2y92uj4zwajwcja9hKa3
	k15PBt3hSVEfciy6hLiCefi5YmHRfBgggCQg1HBWDGNRBoJsaT4B1kZtNKSQAf5kC+J/a19p
	9jscIBj33n2UBCmUphwBwqU/HBDKFhi+RQnSA8zN
	' | unpack
    }
    _cpu9() {
	echo '1-6-6-6 Kramses 200 USD laptop 6-core'
	echo '
	' | unpack
    }
    _cpu10() {
	echo '4-48-48-48 Dell R815 4 CPU 48-core'
	echo '
	' | unpack
    }
    Venter_cpu11() {
	echo '1-4-8-4 4-core/8 thread Lenovo T480'
	echo '
	' | unpack
    }
    cpu12() {
	echo '4-64-64-64 Dell R815 4 CPU 64-core'
	echo '
	KLUv/QRoNR8A2kBECygQbcYJiNmWkVvZhZlEnSKWBFp0GRq85wI/vMgYA62BnzagCgCAQaAg
	tQCvAKEAjwPx4OCIj9hIGkchwCHQLBUUOBIPuFJqQyQPQ/N8RmZlcT48wGsAME5t6eD6FrzT
	Fh3JwkTcviUdcDSwbahTUw0HHD5jgyoBvsERoUHiQCSL1gksss5oIGEi+1TZls4JQtI8SqJ5
	3a9wnQIdJG5RPbdacIstRyZ57o2+cFgrLJ9ZZ2sNCVzbIIKr614GU9t0cO1II3GeL/RGCtME
	YADa4lNkfIQHA4nzQM8CcoZOqpn2Tmw2BAmYXrj4UxtulIcgnrpzruj8kCuCB0RkZFOZWqrr
	bPkiY8pvcN01m/Jrqzd10eJtb0Bcq+3lqAKP7XWcwbxkJLrO2HymEoIBI2Jrp2dwc0i9MGja
	TCVpvWOD3mnbUe+Ra4dHet1Gayp0lIRkaRSHYWCUZ3maR3kUCoVCWTgMjpJwGgKNwjSMYlEW
	C4OSeGLhNM5zxnFmG7vgzKLQiS32tjBIJCgMGLdXhZWQMI2ARCK9ML5TaBQc9RyTXyj/pKly
	/bEGtbfeFmoN0belJJMR3skI32J8QFIn1HA1P3fJuNt89FhUNvmWEWqIQuCdW4wj/J7OKPMn
	Q6RD3vvElJMc+9P0kq/iY18P+Tn7XSqfrVxfQNiVveuSn/zOuK8sr+36qlNS4sdyCRg9Y7TO
	YITXIQyBwS2aD7jOrfQGxIMvQIDYBiN746Hh8AWF66Jsnc5RAUlzcWKdU0vyU9utpEwteW5e
	5qUtMm1vyysSHS51DIqYQowbkjvhJ7DooGpG7i3he831ZV/0XvVIRvsW9WqWUMT0SLJHUGdk
	0GwWZey/qKG2yvpOt4j3wp3AlxFyjvYRFcdPrFXSKSMibM2VGT7WLd739aK1mOxV/AhbD3WQ
	fJA0LXf2LNIh1bpWiyFnXW/IZJRnFsh5Fgj7etIb5Rh2IIAAYJCsDt0Itwf3dUHgOS8IC3/b
	cx+tCmlszVYPLUY2cy6k32i2tsTCachLepZh+yFZ+9QZqUTqQcGisUgRvvEwh9VHGLSDCXO7
	4229V2jZPh1WaFKMZmTN3FKTRx/WIhwGNK8IzwuWRBf5u7SCYK6uBC1MtTDiFrOijJL+3UQ7
	keVCzWv4iQk9sM2ASaSnUIZnvcRUvcJqZcM5YIQfVShhtbI0nFeGKOysSdUYXLuFbGw5uKQI
	9TqKlwFgqMGU058zcDgdl7WAndaEy5TLvwFg5aqP4zgAYc3lakmdkAAuoQCsBrIlQlAIw4he
	PFE6mEJmPV3qB3YDIAGdPCihNatiXaWRte+lXwO0mTBJUQLQlar+
	' | unpack
    }
    cpu13() {
	echo '1-2-2-2 AMD Neo N36L Dual-Core Processor'
	echo '
	KLUv/QRolRgAtnKPJQCPWACgNvIHK2l1aPsb21+AYWrULM1pbgXRH0X4Tira///c/16KAI4A
	fQCRyR+um5YG4mTgi0xasEzaa7lUV5OFyut0ci/kJxaLiMa5NE8vRpu8dSo0zmyvSx3bSlU0
	TsPR/OC/8kEBKdE8kFVdn9WArD3OUPTcL3qkgDfj8Zm3OjdpJHtOMnxh94O4pK6rEt/OUJoC
	yBv9IoHnEcAA62YUoPMWEwpNAQSCRK5Ltlbdth/V6iQJ0+tncaxvbQkzo5mo+W3pRSIx0zXc
	S9hZpHYg3HZbSWLvGdGPeg2r+Ah25Zl+8EWsroTVxR2UZ/nz51HewyPPUo21OweiuRCQyPma
	ZbyLBnIwYIBg8FwmKpY5TUpEvodzsehwOAYcjkiGg+UxyUfp9qWpk3nbrBMXgKxaOATkEfG5
	Ea9UHhAbQE5I9eQbTf1Z5le+pF8xnuIKSrAd8mhGb83Yzib6WjueLr89yh652rfFL6OvHN+4
	v0y/7hutV1TiicEGSdcZsTeZYfaLKyTsojrJB+GTTrlQvOEWRoyf+wSlUnF5Y+WDk/ZWCKuG
	p59k/Lot36SHoDvJznVfrSw6T5RhmCBDZ6vL1QPNWowh+qo8RpsQsmoE3zRG69usmUIYCnKv
	Heb95MPgc/SOsXiear3SVsoKYsQitT1a/Exj00KIxvYIIYli8C0bnfQQ52qvs5+c8U/Suwe5
	u1fRRqc8pFPezTlBdCvUkjXL2Y6Z0j0e4WnjdvXR5Cx19E0n1Nde8hCyxhl+ViBABMAoqhrs
	g7Hf/B/GILKuc2SwMcJQiDgBwi/gjABrg9JzmNOqR1vTDhyWM8swRNQfQlP0aR5ABZrRgKxQ
	LLVBwPczF9136UFQQFcRWm8ZQoe1KIqmjbAGHt6QXhiuOxL3tMSZcblsxP24SlsticeSMQPw
	nwvt4I9uNEhBXFEJoUWnhtbCEDvYBbOhnR6FO++GRBrkG7DW9Rm5AoWQy9RySiElwBmtgAoL
	UzgEXRjGXoiIssGUkUUTqd0xvoBOHpTCmkWxrpQel//TQhslTAKUqRruSw==
	' | unpack
    }
    cpu14() {
	echo '1-1-1-1 Intel Xeon X5675 (mandriva.p)'
	echo '
	KLUv/QRonQYAwsolIjBpzABoi2gVcBKev0FN8WI7YcCuNoTmTbB1dAmqC8N6MAf9xOhcS6B+
	oOLc0Qb145avJCV9NqgRCTRE5ZAsLCJ3UOm9nwP6Pbd+2qihgkUvysD6XJ2vNKuvSDiO7aw/
	UJ2JJoBuk5QfQVrssW26Wen4rx+YManHlUC3TAuQBw/M+Gkv5FqfpKYfJIAxwZfHWZafaSUx
	ExcgQEik8g6fj08zd4EHssVA93AJ8C7xnA3qlYxXshyLBYN1XHECyZgjRUkKjzkkLOUQtuV4
	YQqnBNP0ggo=
	' | unpack
    }
    cpu15() {
	echo '1-1-1-1 Intel(R) Celeron(R) M (eee900)'
	echo '
	KLUv/QRohQoANpVBJCDJVgAHS35yk/0LNr7il7y4NiXZTi5J2xh8EMPkH0ICUAugATkAOAA5
	AFDzg//KBxEyshyKJFqSPScHvrD7GRyq62rk2xnH6ldBJBQHNqybEUHnKZJoMR7GO7S16rb9
	LK0GBJfkrAs3+uHAsJHJKw7BdVNajAx8kU1wW0JWvkpugQDkdTq5CcuZ9Cq0yVtntJzZXpc6
	ttWCsJoH7dvil9FXjm/cX6Zf942XV3RiikGCtXiciQQiTWo61iLRADRNY+EhPZR8lG5P1sJD
	appGnczbZqUB6zW9exVt564cI78V+thnfmKZXxkzHRPjH23s3O4WruAE2y8ztjOKvtaOp8tv
	j7I/mB0gQIaMujr8eNMPYIxoDLDgY+WX46hwjTmVzU7HpqEtYHxLTLzqx8jKta+0nIvY4e1q
	oiCpQLqitFXU0Fyo+a4q4SvbmVMCr0burQ==
	' | unpack
    }
    export -f $(compgen -A function | grep ^cpu)
    
    test_one() {
	eval $1 | head -n1
	export PARALLEL_LSCPU="$(eval $1 | tail -n +2)"
	echo $(parallel --number-of-sockets) \
	     $(parallel --number-of-cores) \
	     $(parallel --number-of-threads) \
	     $(parallel --number-of-cpus)
    }
    export -f test_one
    compgen -A function | grep ^cpu | sort | parallel -j0 -k test_one
    rm ~/.parallel/tmp/sshlogin/*/cpuspec 2>/dev/null
}

par_null_resume() {
    echo '### --null --resume --jl'
    log=/tmp/null-resume-$$.log

    true > "$log"
    printf "%s\n" a b c | parallel --resume -k --jl $log echo
    printf "%s\n" a b c | parallel --resume -k --jl $log echo
    true > "$log"
    printf "%s\0" A B C | parallel --null --resume -k --jl $log echo
    printf "%s\0" A B C | parallel --null --resume -k --jl $log echo
    rm "$log"
}

par_pipepart_block() {
    echo '### --pipepart --block -# (# < 0)'

    seq 1000 > /run/shm/parallel$$
    parallel -j2 -k --pipepart echo {#} :::: /run/shm/parallel$$
    parallel -j2 -k --block -1 --pipepart echo {#}-2 :::: /run/shm/parallel$$
    parallel -j2 -k --block -2 --pipepart echo {#}-4 :::: /run/shm/parallel$$
    parallel -j2 -k --block -10 --pipepart echo {#}-20 :::: /run/shm/parallel$$
    rm /run/shm/parallel$$
}

par_block_negative_prefix() {
    tmp=`mktemp`
    seq 100000 > $tmp
    echo '### This should generate 10*2 jobs'
    parallel -j2 -a $tmp --pipepart --block -0.01k -k md5sum | wc
    rm $tmp
}

par_sql_colsep() {
    echo '### SQL should add Vn columns for --colsep'
    dburl=sqlite3:///%2ftmp%2fparallel-sql-colsep-$$/bar
    parallel -k -C' ' --sqlandworker $dburl echo /{1}/{2}/{3}/{4}/ \
	     ::: 'a A' 'b B' 'c C' ::: '1 11' '2 22' '3 33'
    parallel -k -C' ' echo /{1}/{2}/{3}/{4}/ \
	     ::: 'a A' 'b B' 'c C' ::: '1 11' '2 22' '3 33'
    parallel -k -C' ' -N3 --sqlandworker $dburl echo \
	     ::: 'a A' 'b B' 'c C' ::: '1 11' '2 22' '3 33' '4 44' '5 55' '6 66'
    parallel -k -C' ' -N3 echo \
	     ::: 'a A' 'b B' 'c C' ::: '1 11' '2 22' '3 33' '4 44' '5 55' '6 66'
    rm /tmp/parallel-sql-colsep-$$
}

export -f $(compgen -A function | grep par_)
compgen -A function | grep par_ | LC_ALL=C sort |
    parallel --timeout 1000% -j6 --tag -k --joblog /tmp/jl-`basename $0` '{} 2>&1' |
    perl -pe 's:/usr/bin:/bin:g;'
