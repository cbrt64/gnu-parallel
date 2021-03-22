#!/bin/bash

# SPDX-FileCopyrightText: 2021 Ole Tange, http://ole.tange.dk and Free Software and Foundation, Inc.
#
# SPDX-License-Identifier: GPL-3.0-or-later

# GNU Parallel SQL tests
# The tests must be able to run in parallel

export SQLITE=sqlite3:///%2Frun%2Fshm%2Fparallel.db
export PG=pg://`whoami`:`whoami`@lo/`whoami`
export MYSQL=mysql://`whoami`:`whoami`@lo/`whoami`
export CSV=csv:///%2Frun%2Fshm%2Fcsv

rm -f /run/shm/parallel.db
mkdir -p /run/shm/csv

par_few_duplicate_run() {
    echo '### With many workers there will be some duplicates'
    TABLE=TBL$RANDOM
    DBURL="$1"/$TABLE
    parallel --sqlmaster $DBURL echo ::: {1..100}
    lines=$( (
	       parallel --sqlworker $DBURL &
	       parallel --sqlworker $DBURL &
	       parallel --sqlworker $DBURL &
	       parallel --sqlworker $DBURL &
	       wait
	   ) | wc -l)
    sql "$1" "drop table $TABLE;"
    if [ $lines -gt 105 ] ; then
	echo Error: $lines are more than 5% duplicates
    else
	echo OK
    fi
}

hostname=`hostname`
export -f $(compgen -A function | egrep 'p_|par_')
# Tested that -j0 in parallel is fastest (up to 15 jobs)
compgen -A function | grep par_ | sort |
  stdout parallel -vj5 -k --tag --joblog /tmp/jl-`basename $0` {1} {2} \
	 :::: - :::  \$CSV \$MYSQL \$PG \$SQLITE |
  perl -pe 's/tbl\d+/TBL99999/gi;' |
  perl -pe 's/(from TBL99999 order) .*/$1/g' |
  perl -pe 's/ *\b'"$hostname"'\b */hostname/g' | 
  grep -v -- --------------- |
  perl -pe 's/ *\bhost\b */host/g' |
  perl -pe 's/ +/ /g'

