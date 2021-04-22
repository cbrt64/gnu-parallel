#!/bin/bash -x

# SPDX-FileCopyrightText: 2021 Ole Tange, http://ole.tange.dk and Free Software and Foundation, Inc.
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Argument can be substring of tests (such as 'local')

export LANG=C
export LC_ALL=C
unset LC_MONETARY
SHFILE=/tmp/unittest-parallel.sh
MAX_SEC_PER_TEST=900
export TIMEOUT=$MAX_SEC_PER_TEST

run_once() {
    script=$1
    base=`basename "$script" .sh`
    diff -Naur wanted-results/"$base" actual-results/"$base" >/dev/null ||
	bash "$script" | perl -pe 's:'$HOME':~:g' > actual-results/"$base"
}
export -f run_once

run_test() {
    script="$1"
    base=`basename "$script" .sh`
    export TMPDIR=/tmp/"$base"-tmpdir
    mkdir -p "$TMPDIR"
    # Clean before. May be owned by other users
    sudo rm -f /tmp/*.{tmx,pac,arg,all,log,swp,loa,ssh,df,pip,tmb,chr,tms,par} ||
	printf "%s\0" /tmp/*.par | sudo parallel -0 -X rm
    # Force running once
    echo >> actual-results/"$base"
    if [ "$TRIES" = "3" ] ; then
	# Try 2 times
	run_once $script
	run_once $script
    fi
    run_once $script
    diff -Naur wanted-results/"$base" actual-results/"$base" ||
	(touch "$script" && echo touch "$script")
    
    # Check if it was cleaned up
    find /tmp -maxdepth 1 |
	perl -ne '/\.(tmx|pac|arg|all|log|swp|loa|ssh|df|pip|tmb|chr|tms|par)$/ and
                  ++$a and
                  print "TMP NOT CLEAN. FOUND: $_".`touch '$script'`;'
    # May be owned by other users
    sudo rm -f /tmp/*.{tmx,pac,arg,all,log,swp,loa,ssh,df,pip,tmb,chr,tms,par}
}
export -f run_test

create_monitor_script() {
    # Create a monitor script
    echo forever "'echo; pstree -lp '"$$"'; pstree -l'" $$ >/tmp/monitor
    chmod 755 /tmp/monitor
}

log_rotate() {
    # Log rotate
    mkdir -p log
    seq 10 -1 1 |
	parallel -j1 mv log/testsuite.log.{} log/testsuite.log.'{= $_++ =}'
    mv testsuite.log log/testsuite.log.1
}

create_monitor_script
log_rotate

printf "\033[48;5;78;38;5;0m     `date`     \033[00m\n"
mkdir -p actual-results
ls -t tests-to-run/*${1}*.sh | egrep -v "${2}" |
    parallel --tty -tj1 run_test | tee testsuite.log
# If testsuite.log contains @@ then there is a diff
if grep -q '@@' testsuite.log ; then
    false
else
    # No @@'s: So everything worked: Copy the source
    rm -rf src-passing-testsuite
    cp -a ../src src-passing-testsuite
fi
printf "\033[48;5;208;38;5;0m     `date`     \033[00m\n"
