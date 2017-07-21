#!/bin/bash

# Check servers up on http://www.polarhome.com/service/status/

P_ALL="alpha tru64 hpux-ia64 syllable pidora raspbian solaris openindiana aix hpux qnx debian-ppc suse solaris-x86 mandriva ubuntu scosysv unixware centos miros macosx redhat netbsd openbsd freebsd debian dragonfly vax ultrix minix irix hurd beaglebone cubieboard2"
P_NOTWORKING="vax alpha openstep"
P_NOTWORKING_YET="ultrix irix"

P_WORKING="tru64 syllable pidora raspbian solaris openindiana aix hpux qnx debian-ppc suse solaris-x86 mandriva ubuntu scosysv unixware centos miros macosx redhat netbsd openbsd freebsd debian"
P_TEMPORARILY_BROKEN="minix hurd hpux-ia64 dragonfly"

P="$P_WORKING"
P="$P_ALL"
POLAR=`parallel -k echo {}.polarhome.com ::: $P`
S_POLAR=`parallel -k echo -S 1/{}.polarhome.com ::: $P`

# 20150414 --timeout 80 -> 40
# 20151219 --retries 5 -> 2
# 20160821 --timeout 10 -> 100 (DNS problems)
TIMEOUT=130
RETRIES=4

echo '### Tests on polarhome machines'
echo 'Setup on polarhome machines'
# Avoid the stupid /etc/issue.net banner at Polarhome: -oLogLevel=quiet
#stdout parallel -kj0 ssh -oLogLevel=quiet {} mkdir -p bin ::: $POLAR &

test_empty_cmd() {
    echo
    echo '### Test if empty command in process list causes problems'
    echo
    perl -e '$0=" ";sleep 1' &
    bin/perl bin/parallel echo ::: OK_with_empty_cmd
}
export -f test_empty_cmd
stdout parallel -j0 -k --retries $RETRIES --timeout $TIMEOUT --delay 0.03 --tag \
  --nonall --env test_empty_cmd -S macosx.polarhome.com test_empty_cmd > /tmp/test_empty_cmd &

copy() {
    host=$1
    src="$2"
    dst="$3"
    cat "$src" |
	stdout ssh -oLogLevel=quiet $host "cat > bin/'$dst'.tmp && chmod 755 bin/'$dst'.tmp && mv bin/'$dst'.tmp bin/'$dst'"
}
export -f copy
stdout parallel -j100 -r --retries $RETRIES --timeout $TIMEOUT --delay 0.1 --tag -v \
       copy {2} {1} {1/} \
       ::: /usr/local/bin/{parallel,env_parallel,env_parallel.*} \
       ::: $POLAR

copy_and_test() {
    H=$1
    # scp to each polarhome machine does not work. Use cat
    # Avoid the stupid /etc/issue.net banner with -oLogLevel=quiet
    echo '### Run the test on '$H
    cat `which parallel` |
      stdout ssh -oLogLevel=quiet $H 'cat > bin/p.tmp && chmod 755 bin/p.tmp && mv bin/p.tmp bin/parallel && bin/perl bin/parallel echo Works on {} ::: '$H &&
      stdout ssh -oLogLevel=quiet $H 'bin/perl bin/parallel --tmpdir / echo ::: test read-only tmp' |
      perl -pe '$exit += s:/[a-z0-9_]+.arg:/XXXXXXXX.arg:gi; $exit += s/\d\d\d\d/0000/gi; END { exit not $exit }' &&
      echo OK
}
export -f copy_and_test
stdout parallel -j6 -k -r --retries $RETRIES --timeout $TIMEOUT --delay 0.1 --tag -v copy_and_test {} ::: $POLAR

echo
echo '### Test remote wrapper working on all platforms'
echo
parallel -j0 --nonall -k --timeout $TIMEOUT $S_POLAR hostname

echo
echo '### Does exporting a bash function kill parallel'
echo
# http://zmwangx.github.io/blog/2015-11-25-bash-function-exporting-fiasco.html
parallel --onall -j0 -k --tag --timeout $TIMEOUT $S_POLAR 'func() { cat <(echo bash only A); };export -f func; bin/parallel func ::: ' ::: 1 2>&1 | sort

echo
echo '### Does PARALLEL_SHELL help exporting a bash function not kill parallel'
echo
PARALLEL_SHELL=/bin/bash parallel --retries $RETRIES --onall -j0 -k --tag --timeout $TIMEOUT $S_POLAR 'func() { cat <(echo bash only B); };export -f func; bin/parallel func ::: ' ::: 1 2>&1 | sort

echo
echo '### env_parallel echo :::: <(echo OK)'
echo '(bash only)'
echo
parallel --retries $RETRIES --nonall -j0 -k --tag --timeout $TIMEOUT $S_POLAR 'bin/env_parallel --install'
parallel --retries $RETRIES --nonall -j0 -k --tag --timeout $TIMEOUT $S_POLAR 'env_parallel echo env_parallel ::: OK'
parallel --retries $RETRIES --nonall -j0 -k --tag --timeout $TIMEOUT $S_POLAR 'env_parallel echo reading from process substitution :::: <(echo OK)'

# eval 'myfunc() { echo '$(perl -e 'print "x"x20000')'; }'
# env_parallel myfunc ::: a | wc # OK
# eval 'myfunc2() { echo '$(perl -e 'print "x"x120000')'; }'
# env_parallel myfunc ::: a | wc # Fail too big env
# Can this be made faster using `ssh -M`?
# Can it be moved to virtualbox?

# Started earlier - therefore wait
wait; cat /tmp/test_empty_cmd
rm /tmp/test_empty_cmd
