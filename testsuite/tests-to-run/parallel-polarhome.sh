#!/bin/bash

# Check servers up on http://www.polarhome.com/service/status/

P_ALL="alpha tru64 hpux-ia64 syllable pidora raspbian solaris openindiana aix hpux qnx debian-ppc suse solaris-x86 mandriva ubuntu scosysv unixware centos miros macosx redhat netbsd openbsd freebsd debian dragonfly vax ultrix minix irix hurd beaglebone cubieboard2"
P_NOTWORKING="vax alpha openstep"
P_NOTWORKING_YET="ultrix irix"

P_WORKING="openbsd tru64 debian freebsd redhat netbsd macosx miros centos unixware pidora ubuntu scosysv raspbian solaris-x86 aix mandriva debian-ppc suse solaris hpux openindiana hpux-ia64"
P_WORKING="openbsd tru64 debian freebsd redhat netbsd macosx miros centos unixware pidora ubuntu scosysv raspbian solaris-x86 aix mandriva debian-ppc suse solaris hpux openindiana hpux-ia64"
P_TEMPORARILY_BROKEN="minix hurd dragonfly"

P="$P_WORKING"
POLAR=`parallel -k echo {}.polarhome.com ::: $P`
S_POLAR=`parallel -k echo -S 1/{}.polarhome.com ::: $P`

# 20150414 --timeout 80 -> 40
# 20151219 --retries 5 -> 2
# 20160821 --timeout 10 -> 100 (DNS problems)
# 20171122 --timeout 100 -> 20 (Raising it did not get more successes)
TIMEOUT=20
RETRIES=4

echo '### Tests on polarhome machines'
# On each remote machine:
#   $HOME/setupenv is a sourcable script that sets path+activates env_parallel
#     It is platform dependant

echo 'Setup on polarhome machines'
# Avoid the stupid /etc/issue.net banner at Polarhome: -oLogLevel=quiet
stdout parallel -kj0 --delay 0.2 ssh -oLogLevel=quiet {} mkdir -p bin ::: $POLAR &

par_onall() {
    stdout parallel -j0 -k --retries $RETRIES --timeout $TIMEOUT --delay 0.1 --tag \
	   --onall $S_POLAR "$@"
}
export -f par_onall

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
stdout parallel -kj30 -r --retries $RETRIES --timeout $TIMEOUT --delay 0.13 --tag -v \
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
par_onall 'func() { cat <(echo bash only A); };export -f func; bin/parallel func ::: ' ::: 1

echo
echo '### Does PARALLEL_SHELL help exporting a bash function not kill parallel'
echo
PARALLEL_SHELL=/bin/bash par_onall 'func() { cat <(echo bash only B); };export -f func; bin/parallel func ::: ' ::: 1

echo
echo '### env_parallel echo :::: <(echo OK)'
echo '(bash only)'
echo
par_onall 'bin/env_parallel --install && echo {}' ::: install-OK
par_onall 'source setupenv || . `pwd`/setupenv; env_parallel echo env_parallel :::' ::: run-OK
par_onall 'source setupenv || . `pwd`/setupenv; env_parallel echo reading from process substitution :::: <(echo {})' ::: OK |
    # csh on NetBSD does not support process substitution
    grep -v ': /tmp/.*: No such file or directory'

# eval 'myfunc() { echo '$(perl -e 'print "x"x20000')'; }'
# env_parallel myfunc ::: a | wc # OK
# eval 'myfunc2() { echo '$(perl -e 'print "x"x120000')'; }'
# env_parallel myfunc ::: a | wc # Fail too big env
# Can this be made faster using `ssh -M`?
# Can it be moved to virtualbox?

# Started earlier - therefore wait
wait; cat /tmp/test_empty_cmd
rm /tmp/test_empty_cmd
