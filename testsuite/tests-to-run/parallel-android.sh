#!/bin/bash

unset TIMEOUT
. `which env_parallel.bash`
env_parallel --session

host=$(parallel -j0 --halt now,success=1 ssh {} echo {} ::: android1 android2 2>/dev/null)
echo $host >&2

doit() {
    export PARALLEL_SSH='ssh -p2222'
    parallel -k echo ::: Basic usage works
    parallel -k -S localhost echo ::: Remote usage works
}

scp /usr/local/bin/parallel $host:/data/data/com.termux/files/usr/bin
env_parallel -S $host doit ::: a
