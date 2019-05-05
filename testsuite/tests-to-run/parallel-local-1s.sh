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

par_test_cpu_detection() {
    # Xeon 8 core server in Germany
    cpuinfo1="
processor	: 0
vendor_id	: GenuineIntel
cpu family	: 6
model		: 23
model name	: Intel(R) Xeon(R) CPU           E5405  @ 2.00GHz
stepping	: 10
cpu MHz		: 1995.036
cache size	: 6144 KB
physical id	: 0
siblings	: 4
core id		: 0
cpu cores	: 4
apicid		: 0
initial apicid	: 0
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx lm constant_tsc arch_perfmon pebs bts rep_good pni dtes64 monitor ds_cpl vmx tm2 ssse3 cx16 xtpr pdcm dca sse4_1 xsave lahf_lm tpr_shadow vnmi flexpriority
bogomips	: 3990.07
clflush size	: 64
cache_alignment	: 64
address sizes	: 38 bits physical, 48 bits virtual
power management:

processor	: 1
vendor_id	: GenuineIntel
cpu family	: 6
model		: 23
model name	: Intel(R) Xeon(R) CPU           E5405  @ 2.00GHz
stepping	: 10
cpu MHz		: 1995.036
cache size	: 6144 KB
physical id	: 0
siblings	: 4
core id		: 1
cpu cores	: 4
apicid		: 1
initial apicid	: 1
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx lm constant_tsc arch_perfmon pebs bts rep_good pni dtes64 monitor ds_cpl vmx tm2 ssse3 cx16 xtpr pdcm dca sse4_1 xsave lahf_lm tpr_shadow vnmi flexpriority
bogomips	: 3990.00
clflush size	: 64
cache_alignment	: 64
address sizes	: 38 bits physical, 48 bits virtual
power management:

processor	: 2
vendor_id	: GenuineIntel
cpu family	: 6
model		: 23
model name	: Intel(R) Xeon(R) CPU           E5405  @ 2.00GHz
stepping	: 10
cpu MHz		: 1995.036
cache size	: 6144 KB
physical id	: 0
siblings	: 4
core id		: 2
cpu cores	: 4
apicid		: 2
initial apicid	: 2
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx lm constant_tsc arch_perfmon pebs bts rep_good pni dtes64 monitor ds_cpl vmx tm2 ssse3 cx16 xtpr pdcm dca sse4_1 xsave lahf_lm tpr_shadow vnmi flexpriority
bogomips	: 3990.03
clflush size	: 64
cache_alignment	: 64
address sizes	: 38 bits physical, 48 bits virtual
power management:

processor	: 3
vendor_id	: GenuineIntel
cpu family	: 6
model		: 23
model name	: Intel(R) Xeon(R) CPU           E5405  @ 2.00GHz
stepping	: 10
cpu MHz		: 1995.036
cache size	: 6144 KB
physical id	: 0
siblings	: 4
core id		: 3
cpu cores	: 4
apicid		: 3
initial apicid	: 3
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx lm constant_tsc arch_perfmon pebs bts rep_good pni dtes64 monitor ds_cpl vmx tm2 ssse3 cx16 xtpr pdcm dca sse4_1 xsave lahf_lm tpr_shadow vnmi flexpriority
bogomips	: 3990.03
clflush size	: 64
cache_alignment	: 64
address sizes	: 38 bits physical, 48 bits virtual
power management:

processor	: 4
vendor_id	: GenuineIntel
cpu family	: 6
model		: 23
model name	: Intel(R) Xeon(R) CPU           E5405  @ 2.00GHz
stepping	: 10
cpu MHz		: 1995.036
cache size	: 6144 KB
physical id	: 1
siblings	: 4
core id		: 0
cpu cores	: 4
apicid		: 4
initial apicid	: 4
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx lm constant_tsc arch_perfmon pebs bts rep_good pni dtes64 monitor ds_cpl vmx tm2 ssse3 cx16 xtpr pdcm dca sse4_1 xsave lahf_lm tpr_shadow vnmi flexpriority
bogomips	: 3990.02
clflush size	: 64
cache_alignment	: 64
address sizes	: 38 bits physical, 48 bits virtual
power management:

processor	: 5
vendor_id	: GenuineIntel
cpu family	: 6
model		: 23
model name	: Intel(R) Xeon(R) CPU           E5405  @ 2.00GHz
stepping	: 10
cpu MHz		: 1995.036
cache size	: 6144 KB
physical id	: 1
siblings	: 4
core id		: 1
cpu cores	: 4
apicid		: 5
initial apicid	: 5
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx lm constant_tsc arch_perfmon pebs bts rep_good pni dtes64 monitor ds_cpl vmx tm2 ssse3 cx16 xtpr pdcm dca sse4_1 xsave lahf_lm tpr_shadow vnmi flexpriority
bogomips	: 3990.04
clflush size	: 64
cache_alignment	: 64
address sizes	: 38 bits physical, 48 bits virtual
power management:

processor	: 6
vendor_id	: GenuineIntel
cpu family	: 6
model		: 23
model name	: Intel(R) Xeon(R) CPU           E5405  @ 2.00GHz
stepping	: 10
cpu MHz		: 1995.036
cache size	: 6144 KB
physical id	: 1
siblings	: 4
core id		: 2
cpu cores	: 4
apicid		: 6
initial apicid	: 6
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx lm constant_tsc arch_perfmon pebs bts rep_good pni dtes64 monitor ds_cpl vmx tm2 ssse3 cx16 xtpr pdcm dca sse4_1 xsave lahf_lm tpr_shadow vnmi flexpriority
bogomips	: 3990.05
clflush size	: 64
cache_alignment	: 64
address sizes	: 38 bits physical, 48 bits virtual
power management:

processor	: 7
vendor_id	: GenuineIntel
cpu family	: 6
model		: 23
model name	: Intel(R) Xeon(R) CPU           E5405  @ 2.00GHz
stepping	: 10
cpu MHz		: 1995.036
cache size	: 6144 KB
physical id	: 1
siblings	: 4
core id		: 3
cpu cores	: 4
apicid		: 7
initial apicid	: 7
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx lm constant_tsc arch_perfmon pebs bts rep_good pni dtes64 monitor ds_cpl vmx tm2 ssse3 cx16 xtpr pdcm dca sse4_1 xsave lahf_lm tpr_shadow vnmi flexpriority
bogomips	: 3990.04
clflush size	: 64
cache_alignment	: 64
address sizes	: 38 bits physical, 48 bits virtual
power management:
";
    # Core i7-3632QM Acer laptop
    cpuinfo2="
processor	: 0
vendor_id	: GenuineIntel
cpu family	: 6
model		: 58
model name	: Intel(R) Core(TM) i7-3632QM CPU @ 2.20GHz
stepping	: 9
microcode	: 0x20
cpu MHz		: 1444.686
cache size	: 6144 KB
physical id	: 0
siblings	: 8
core id		: 0
cpu cores	: 4
apicid		: 0
initial apicid	: 0
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx rdtscp lm constant_tsc arch_perfmon pebs bts rep_good nopl xtopology nonstop_tsc cpuid aperfmperf pni pclmulqdq dtes64 monitor ds_cpl vmx est tm2 ssse3 cx16 xtpr pdcm pcid sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm cpuid_fault epb pti ssbd ibrs ibpb stibp tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms xsaveopt dtherm ida arat pln pts flush_l1d
bugs		: cpu_meltdown spectre_v1 spectre_v2 spec_store_bypass l1tf
bogomips	: 4390.24
clflush size	: 64
cache_alignment	: 64
address sizes	: 36 bits physical, 48 bits virtual
power management:

processor	: 1
vendor_id	: GenuineIntel
cpu family	: 6
model		: 58
model name	: Intel(R) Core(TM) i7-3632QM CPU @ 2.20GHz
stepping	: 9
microcode	: 0x20
cpu MHz		: 1341.455
cache size	: 6144 KB
physical id	: 0
siblings	: 8
core id		: 0
cpu cores	: 4
apicid		: 1
initial apicid	: 1
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx rdtscp lm constant_tsc arch_perfmon pebs bts rep_good nopl xtopology nonstop_tsc cpuid aperfmperf pni pclmulqdq dtes64 monitor ds_cpl vmx est tm2 ssse3 cx16 xtpr pdcm pcid sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm cpuid_fault epb pti ssbd ibrs ibpb stibp tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms xsaveopt dtherm ida arat pln pts flush_l1d
bugs		: cpu_meltdown spectre_v1 spectre_v2 spec_store_bypass l1tf
bogomips	: 4390.24
clflush size	: 64
cache_alignment	: 64
address sizes	: 36 bits physical, 48 bits virtual
power management:

processor	: 2
vendor_id	: GenuineIntel
cpu family	: 6
model		: 58
model name	: Intel(R) Core(TM) i7-3632QM CPU @ 2.20GHz
stepping	: 9
microcode	: 0x20
cpu MHz		: 1411.511
cache size	: 6144 KB
physical id	: 0
siblings	: 8
core id		: 1
cpu cores	: 4
apicid		: 2
initial apicid	: 2
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx rdtscp lm constant_tsc arch_perfmon pebs bts rep_good nopl xtopology nonstop_tsc cpuid aperfmperf pni pclmulqdq dtes64 monitor ds_cpl vmx est tm2 ssse3 cx16 xtpr pdcm pcid sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm cpuid_fault epb pti ssbd ibrs ibpb stibp tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms xsaveopt dtherm ida arat pln pts flush_l1d
bugs		: cpu_meltdown spectre_v1 spectre_v2 spec_store_bypass l1tf
bogomips	: 4390.24
clflush size	: 64
cache_alignment	: 64
address sizes	: 36 bits physical, 48 bits virtual
power management:

processor	: 3
vendor_id	: GenuineIntel
cpu family	: 6
model		: 58
model name	: Intel(R) Core(TM) i7-3632QM CPU @ 2.20GHz
stepping	: 9
microcode	: 0x20
cpu MHz		: 1449.892
cache size	: 6144 KB
physical id	: 0
siblings	: 8
core id		: 1
cpu cores	: 4
apicid		: 3
initial apicid	: 3
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx rdtscp lm constant_tsc arch_perfmon pebs bts rep_good nopl xtopology nonstop_tsc cpuid aperfmperf pni pclmulqdq dtes64 monitor ds_cpl vmx est tm2 ssse3 cx16 xtpr pdcm pcid sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm cpuid_fault epb pti ssbd ibrs ibpb stibp tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms xsaveopt dtherm ida arat pln pts flush_l1d
bugs		: cpu_meltdown spectre_v1 spectre_v2 spec_store_bypass l1tf
bogomips	: 4390.24
clflush size	: 64
cache_alignment	: 64
address sizes	: 36 bits physical, 48 bits virtual
power management:

processor	: 4
vendor_id	: GenuineIntel
cpu family	: 6
model		: 58
model name	: Intel(R) Core(TM) i7-3632QM CPU @ 2.20GHz
stepping	: 9
microcode	: 0x20
cpu MHz		: 1482.598
cache size	: 6144 KB
physical id	: 0
siblings	: 8
core id		: 2
cpu cores	: 4
apicid		: 4
initial apicid	: 4
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx rdtscp lm constant_tsc arch_perfmon pebs bts rep_good nopl xtopology nonstop_tsc cpuid aperfmperf pni pclmulqdq dtes64 monitor ds_cpl vmx est tm2 ssse3 cx16 xtpr pdcm pcid sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm cpuid_fault epb pti ssbd ibrs ibpb stibp tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms xsaveopt dtherm ida arat pln pts flush_l1d
bugs		: cpu_meltdown spectre_v1 spectre_v2 spec_store_bypass l1tf
bogomips	: 4390.24
clflush size	: 64
cache_alignment	: 64
address sizes	: 36 bits physical, 48 bits virtual
power management:

processor	: 5
vendor_id	: GenuineIntel
cpu family	: 6
model		: 58
model name	: Intel(R) Core(TM) i7-3632QM CPU @ 2.20GHz
stepping	: 9
microcode	: 0x20
cpu MHz		: 1485.571
cache size	: 6144 KB
physical id	: 0
siblings	: 8
core id		: 2
cpu cores	: 4
apicid		: 5
initial apicid	: 5
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx rdtscp lm constant_tsc arch_perfmon pebs bts rep_good nopl xtopology nonstop_tsc cpuid aperfmperf pni pclmulqdq dtes64 monitor ds_cpl vmx est tm2 ssse3 cx16 xtpr pdcm pcid sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm cpuid_fault epb pti ssbd ibrs ibpb stibp tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms xsaveopt dtherm ida arat pln pts flush_l1d
bugs		: cpu_meltdown spectre_v1 spectre_v2 spec_store_bypass l1tf
bogomips	: 4390.24
clflush size	: 64
cache_alignment	: 64
address sizes	: 36 bits physical, 48 bits virtual
power management:

processor	: 6
vendor_id	: GenuineIntel
cpu family	: 6
model		: 58
model name	: Intel(R) Core(TM) i7-3632QM CPU @ 2.20GHz
stepping	: 9
microcode	: 0x20
cpu MHz		: 1554.185
cache size	: 6144 KB
physical id	: 0
siblings	: 8
core id		: 3
cpu cores	: 4
apicid		: 6
initial apicid	: 6
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx rdtscp lm constant_tsc arch_perfmon pebs bts rep_good nopl xtopology nonstop_tsc cpuid aperfmperf pni pclmulqdq dtes64 monitor ds_cpl vmx est tm2 ssse3 cx16 xtpr pdcm pcid sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm cpuid_fault epb pti ssbd ibrs ibpb stibp tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms xsaveopt dtherm ida arat pln pts flush_l1d
bugs		: cpu_meltdown spectre_v1 spectre_v2 spec_store_bypass l1tf
bogomips	: 4390.24
clflush size	: 64
cache_alignment	: 64
address sizes	: 36 bits physical, 48 bits virtual
power management:

processor	: 7
vendor_id	: GenuineIntel
cpu family	: 6
model		: 58
model name	: Intel(R) Core(TM) i7-3632QM CPU @ 2.20GHz
stepping	: 9
microcode	: 0x20
cpu MHz		: 1530.523
cache size	: 6144 KB
physical id	: 0
siblings	: 8
core id		: 3
cpu cores	: 4
apicid		: 7
initial apicid	: 7
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx rdtscp lm constant_tsc arch_perfmon pebs bts rep_good nopl xtopology nonstop_tsc cpuid aperfmperf pni pclmulqdq dtes64 monitor ds_cpl vmx est tm2 ssse3 cx16 xtpr pdcm pcid sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm cpuid_fault epb pti ssbd ibrs ibpb stibp tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms xsaveopt dtherm ida arat pln pts flush_l1d
bugs		: cpu_meltdown spectre_v1 spectre_v2 spec_store_bypass l1tf
bogomips	: 4390.24
clflush size	: 64
cache_alignment	: 64
address sizes	: 36 bits physical, 48 bits virtual
power management:
";
    # Core i5-2410M laptop firewall
    cpuinfo3="
processor	: 0
vendor_id	: GenuineIntel
cpu family	: 6
model		: 42
model name	: Intel(R) Core(TM) i5-2410M CPU @ 2.30GHz
stepping	: 7
microcode	: 0x1a
cpu MHz		: 1699.871
cache size	: 3072 KB
physical id	: 0
siblings	: 4
core id		: 0
cpu cores	: 2
apicid		: 0
initial apicid	: 0
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx rdtscp lm constant_tsc arch_perfmon pebs bts rep_good nopl xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx est tm2 ssse3 cx16 xtpr pdcm pcid sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx lahf_lm epb kaiser tpr_shadow vnmi flexpriority ept vpid xsaveopt dtherm ida arat pln pts
bugs		: cpu_meltdown spectre_v1 spectre_v2
bogomips	: 4589.58
clflush size	: 64
cache_alignment	: 64
address sizes	: 36 bits physical, 48 bits virtual
power management:

processor	: 1
vendor_id	: GenuineIntel
cpu family	: 6
model		: 42
model name	: Intel(R) Core(TM) i5-2410M CPU @ 2.30GHz
stepping	: 7
microcode	: 0x1a
cpu MHz		: 1668.005
cache size	: 3072 KB
physical id	: 0
siblings	: 4
core id		: 0
cpu cores	: 2
apicid		: 1
initial apicid	: 1
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx rdtscp lm constant_tsc arch_perfmon pebs bts rep_good nopl xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx est tm2 ssse3 cx16 xtpr pdcm pcid sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx lahf_lm epb kaiser tpr_shadow vnmi flexpriority ept vpid xsaveopt dtherm ida arat pln pts
bugs		: cpu_meltdown spectre_v1 spectre_v2
bogomips	: 4589.58
clflush size	: 64
cache_alignment	: 64
address sizes	: 36 bits physical, 48 bits virtual
power management:

processor	: 2
vendor_id	: GenuineIntel
cpu family	: 6
model		: 42
model name	: Intel(R) Core(TM) i5-2410M CPU @ 2.30GHz
stepping	: 7
microcode	: 0x1a
cpu MHz		: 1687.939
cache size	: 3072 KB
physical id	: 0
siblings	: 4
core id		: 1
cpu cores	: 2
apicid		: 2
initial apicid	: 2
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx rdtscp lm constant_tsc arch_perfmon pebs bts rep_good nopl xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx est tm2 ssse3 cx16 xtpr pdcm pcid sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx lahf_lm epb kaiser tpr_shadow vnmi flexpriority ept vpid xsaveopt dtherm ida arat pln pts
bugs		: cpu_meltdown spectre_v1 spectre_v2
bogomips	: 4589.58
clflush size	: 64
cache_alignment	: 64
address sizes	: 36 bits physical, 48 bits virtual
power management:

processor	: 3
vendor_id	: GenuineIntel
cpu family	: 6
model		: 42
model name	: Intel(R) Core(TM) i5-2410M CPU @ 2.30GHz
stepping	: 7
microcode	: 0x1a
cpu MHz		: 1572.967
cache size	: 3072 KB
physical id	: 0
siblings	: 4
core id		: 1
cpu cores	: 2
apicid		: 3
initial apicid	: 3
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx rdtscp lm constant_tsc arch_perfmon pebs bts rep_good nopl xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx est tm2 ssse3 cx16 xtpr pdcm pcid sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx lahf_lm epb kaiser tpr_shadow vnmi flexpriority ept vpid xsaveopt dtherm ida arat pln pts
bugs		: cpu_meltdown spectre_v1 spectre_v2
bogomips	: 4589.58
clflush size	: 64
cache_alignment	: 64
address sizes	: 36 bits physical, 48 bits virtual
power management:
";
    #
    cpuinfo4="
processor	: 0
vendor_id	: AuthenticAMD
cpu family	: 15
model		: 5
model name	: AMD Opteron(tm) Processor 244
stepping	: 10
cpu MHz		: 1808.337
cache size	: 1024 KB
fdiv_bug	: no
hlt_bug		: no
f00f_bug	: no
coma_bug	: no
fpu		: yes
fpu_exception	: yes
cpuid level	: 1
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush mmx fxsr sse sse2 syscall nx mmxext lm 3dnowext 3dnow
bogomips	: 3619.37
clflush size	: 64
power management: ts fid vid ttp

processor	: 1
vendor_id	: AuthenticAMD
cpu family	: 15
model		: 5
model name	: AMD Opteron(tm) Processor 244
stepping	: 10
cpu MHz		: 1808.337
cache size	: 1024 KB
fdiv_bug	: no
hlt_bug		: no
f00f_bug	: no
coma_bug	: no
fpu		: yes
fpu_exception	: yes
cpuid level	: 1
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush mmx fxsr sse sse2 syscall nx mmxext lm 3dnowext 3dnow
bogomips	: 3616.94
clflush size	: 64
power management: ts fid vid ttp
";
    cpuinfo5="
processor	: 0
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 0
siblings	: 24
core id		: 0
cpu cores	: 12
apicid		: 0
initial apicid	: 0
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.82
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 1
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 0
siblings	: 24
core id		: 1
cpu cores	: 12
apicid		: 2
initial apicid	: 2
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.82
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 2
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 0
siblings	: 24
core id		: 2
cpu cores	: 12
apicid		: 4
initial apicid	: 4
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.82
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 3
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 0
siblings	: 24
core id		: 3
cpu cores	: 12
apicid		: 6
initial apicid	: 6
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.82
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 4
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 0
siblings	: 24
core id		: 4
cpu cores	: 12
apicid		: 8
initial apicid	: 8
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.82
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 5
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 0
siblings	: 24
core id		: 5
cpu cores	: 12
apicid		: 10
initial apicid	: 10
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.82
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 6
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 0
siblings	: 24
core id		: 8
cpu cores	: 12
apicid		: 16
initial apicid	: 16
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.82
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 7
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 0
siblings	: 24
core id		: 9
cpu cores	: 12
apicid		: 18
initial apicid	: 18
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.82
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 8
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 0
siblings	: 24
core id		: 10
cpu cores	: 12
apicid		: 20
initial apicid	: 20
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.82
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 9
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 0
siblings	: 24
core id		: 11
cpu cores	: 12
apicid		: 22
initial apicid	: 22
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.82
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 10
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 0
siblings	: 24
core id		: 12
cpu cores	: 12
apicid		: 24
initial apicid	: 24
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.82
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 11
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 0
siblings	: 24
core id		: 13
cpu cores	: 12
apicid		: 26
initial apicid	: 26
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.82
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 12
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 1
siblings	: 24
core id		: 0
cpu cores	: 12
apicid		: 32
initial apicid	: 32
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.28
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 13
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 1
siblings	: 24
core id		: 1
cpu cores	: 12
apicid		: 34
initial apicid	: 34
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.28
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 14
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 1
siblings	: 24
core id		: 2
cpu cores	: 12
apicid		: 36
initial apicid	: 36
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.28
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 15
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 1
siblings	: 24
core id		: 3
cpu cores	: 12
apicid		: 38
initial apicid	: 38
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.28
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 16
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 1
siblings	: 24
core id		: 4
cpu cores	: 12
apicid		: 40
initial apicid	: 40
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.28
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 17
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 1
siblings	: 24
core id		: 5
cpu cores	: 12
apicid		: 42
initial apicid	: 42
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.28
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 18
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 1
siblings	: 24
core id		: 8
cpu cores	: 12
apicid		: 48
initial apicid	: 48
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.28
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 19
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 1
siblings	: 24
core id		: 9
cpu cores	: 12
apicid		: 50
initial apicid	: 50
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.28
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 20
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 1
siblings	: 24
core id		: 10
cpu cores	: 12
apicid		: 52
initial apicid	: 52
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.28
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 21
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 1
siblings	: 24
core id		: 11
cpu cores	: 12
apicid		: 54
initial apicid	: 54
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.28
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 22
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 1
siblings	: 24
core id		: 12
cpu cores	: 12
apicid		: 56
initial apicid	: 56
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.28
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 23
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 1
siblings	: 24
core id		: 13
cpu cores	: 12
apicid		: 58
initial apicid	: 58
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.28
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 24
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 0
siblings	: 24
core id		: 0
cpu cores	: 12
apicid		: 1
initial apicid	: 1
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.82
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 25
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 0
siblings	: 24
core id		: 1
cpu cores	: 12
apicid		: 3
initial apicid	: 3
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.82
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 26
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 0
siblings	: 24
core id		: 2
cpu cores	: 12
apicid		: 5
initial apicid	: 5
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.82
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 27
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 0
siblings	: 24
core id		: 3
cpu cores	: 12
apicid		: 7
initial apicid	: 7
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.82
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 28
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 0
siblings	: 24
core id		: 4
cpu cores	: 12
apicid		: 9
initial apicid	: 9
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.82
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 29
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 0
siblings	: 24
core id		: 5
cpu cores	: 12
apicid		: 11
initial apicid	: 11
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.82
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 30
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 0
siblings	: 24
core id		: 8
cpu cores	: 12
apicid		: 17
initial apicid	: 17
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.82
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 31
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 0
siblings	: 24
core id		: 9
cpu cores	: 12
apicid		: 19
initial apicid	: 19
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.82
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 32
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 0
siblings	: 24
core id		: 10
cpu cores	: 12
apicid		: 21
initial apicid	: 21
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.82
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 33
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 0
siblings	: 24
core id		: 11
cpu cores	: 12
apicid		: 23
initial apicid	: 23
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.82
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 34
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 0
siblings	: 24
core id		: 12
cpu cores	: 12
apicid		: 25
initial apicid	: 25
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.82
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 35
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 0
siblings	: 24
core id		: 13
cpu cores	: 12
apicid		: 27
initial apicid	: 27
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.82
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 36
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 1
siblings	: 24
core id		: 0
cpu cores	: 12
apicid		: 33
initial apicid	: 33
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.28
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 37
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 1
siblings	: 24
core id		: 1
cpu cores	: 12
apicid		: 35
initial apicid	: 35
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.28
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 38
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 1
siblings	: 24
core id		: 2
cpu cores	: 12
apicid		: 37
initial apicid	: 37
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.28
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 39
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 1
siblings	: 24
core id		: 3
cpu cores	: 12
apicid		: 39
initial apicid	: 39
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.28
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 40
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 1
siblings	: 24
core id		: 4
cpu cores	: 12
apicid		: 41
initial apicid	: 41
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.28
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 41
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 1
siblings	: 24
core id		: 5
cpu cores	: 12
apicid		: 43
initial apicid	: 43
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.28
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 42
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 1
siblings	: 24
core id		: 8
cpu cores	: 12
apicid		: 49
initial apicid	: 49
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.28
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 43
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 1
siblings	: 24
core id		: 9
cpu cores	: 12
apicid		: 51
initial apicid	: 51
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.28
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 44
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 1
siblings	: 24
core id		: 10
cpu cores	: 12
apicid		: 53
initial apicid	: 53
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.28
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 45
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 1
siblings	: 24
core id		: 11
cpu cores	: 12
apicid		: 55
initial apicid	: 55
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.28
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 46
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 1
siblings	: 24
core id		: 12
cpu cores	: 12
apicid		: 57
initial apicid	: 57
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.28
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:

processor	: 47
vendor_id	: GenuineIntel
cpu family	: 6
model		: 62
model name	: Intel(R) Xeon(R) CPU E5-2697 v2 @ 2.70GHz
stepping	: 4
microcode	: 1046
cpu MHz		: 2699.914
cache size	: 30720 KB
physical id	: 1
siblings	: 24
core id		: 13
cpu cores	: 12
apicid		: 59
initial apicid	: 59
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm ida arat epb xsaveopt pln pts dtherm pti retpoline tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms
bogomips	: 5399.28
clflush size	: 64
cache_alignment	: 64
address sizes	: 46 bits physical, 48 bits virtual
power management:
";
    # HP Laptop Compaq 6530b
    cpuinfo6="
processor	: 0
vendor_id	: GenuineIntel
cpu family	: 6
model		: 23
model name	: Celeron(R) Dual-Core CPU       T3000  @ 1.80GHz
stepping	: 10
microcode	: 0xa07
cpu MHz		: 1795.441
cache size	: 1024 KB
physical id	: 0
siblings	: 2
core id		: 0
cpu cores	: 2
apicid		: 0
initial apicid	: 0
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx lm constant_tsc arch_perfmon pebs bts nopl aperfmperf pni dtes64 monitor ds_cpl tm2 ssse3 cx16 xtpr pdcm xsave lahf_lm dtherm
bugs		:
bogomips	: 3590.88
clflush size	: 64
cache_alignment	: 64
address sizes	: 36 bits physical, 48 bits virtual
power management:

processor	: 1
vendor_id	: GenuineIntel
cpu family	: 6
model		: 23
model name	: Celeron(R) Dual-Core CPU       T3000  @ 1.80GHz
stepping	: 10
microcode	: 0xa07
cpu MHz		: 1795.441
cache size	: 1024 KB
physical id	: 0
siblings	: 2
core id		: 1
cpu cores	: 2
apicid		: 1
initial apicid	: 1
fpu		: yes
fpu_exception	: yes
cpuid level	: 13
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx lm constant_tsc arch_perfmon pebs bts nopl aperfmperf pni dtes64 monitor ds_cpl tm2 ssse3 cx16 xtpr pdcm xsave lahf_lm dtherm
bugs		:
bogomips	: 3590.88
clflush size	: 64
cache_alignment	: 64
address sizes	: 36 bits physical, 48 bits virtual
power management:

";
    # Huawei P Smart Octa-core (4x2.36 GHz Cortex-A53 & 4x1.7 GHz Cortex-A53)
    cpuinfo7="
processor	: 0
BogoMIPS	: 3.84
Features	: fp asimd evtstrm aes pmull sha1 sha2 crc32
CPU implementer	: 0x41
CPU architecture: 8
CPU variant	: 0x0
CPU part	: 0xd03
CPU revision	: 4

processor	: 1
BogoMIPS	: 3.84
Features	: fp asimd evtstrm aes pmull sha1 sha2 crc32
CPU implementer	: 0x41
CPU architecture: 8
CPU variant	: 0x0
CPU part	: 0xd03
CPU revision	: 4

processor	: 2
BogoMIPS	: 3.84
Features	: fp asimd evtstrm aes pmull sha1 sha2 crc32
CPU implementer	: 0x41
CPU architecture: 8
CPU variant	: 0x0
CPU part	: 0xd03
CPU revision	: 4

processor	: 3
BogoMIPS	: 3.84
Features	: fp asimd evtstrm aes pmull sha1 sha2 crc32
CPU implementer	: 0x41
CPU architecture: 8
CPU variant	: 0x0
CPU part	: 0xd03
CPU revision	: 4

processor	: 4
BogoMIPS	: 3.84
Features	: fp asimd evtstrm aes pmull sha1 sha2 crc32
CPU implementer	: 0x41
CPU architecture: 8
CPU variant	: 0x0
CPU part	: 0xd03
CPU revision	: 4

processor	: 5
BogoMIPS	: 3.84
Features	: fp asimd evtstrm aes pmull sha1 sha2 crc32
CPU implementer	: 0x41
CPU architecture: 8
CPU variant	: 0x0
CPU part	: 0xd03
CPU revision	: 4

processor	: 6
BogoMIPS	: 3.84
Features	: fp asimd evtstrm aes pmull sha1 sha2 crc32
CPU implementer	: 0x41
CPU architecture: 8
CPU variant	: 0x0
CPU part	: 0xd03
CPU revision	: 4

processor	: 7
BogoMIPS	: 3.84
Features	: fp asimd evtstrm aes pmull sha1 sha2 crc32
CPU implementer	: 0x41
CPU architecture: 8
CPU variant	: 0x0
CPU part	: 0xd03
CPU revision	: 4

";
    test_one() {
	export PARALLEL_CPUINFO="$1"
	echo $(parallel --number-of-sockets) \
	     $(parallel --number-of-cores) \
	     $(parallel --number-of-threads) \
	     $(parallel --number-of-cpus)
    }
    export -f test_one
    parallel -j0 -0 -k --tagstring {2} test_one {1} \
	 :::  "$cpuinfo1" "$cpuinfo2" "$cpuinfo3" "$cpuinfo4" "$cpuinfo5" "$cpuinfo6" "$cpuinfo7" \
	 :::+ "2-8-8-8" "1-4-8-4" "1-2-4-2" "1-2-2-2" "2-24-48-24" "1-2-2-2" "1-8-8-8"
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

export -f $(compgen -A function | grep par_)
compgen -A function | grep par_ | LC_ALL=C sort |
    parallel -j6 --tag -k --joblog /tmp/jl-`basename $0` '{} 2>&1'
