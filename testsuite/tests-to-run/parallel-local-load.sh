#!/bin/bash

# Force load 12 in 10 seconds
seq 12 |
    stdout parallel --nice 11 --timeout 10 -j0 -N0 "bzip2 < /dev/zero" > /dev/null &

par_load_more_10s() {
    echo '### Test --load locally - should take >10s'
    stdout /usr/bin/time -f %e parallel --load 10 sleep ::: 1 |
	perl -ne 'print $_ > 10 ? "OK\n" : "Broken: $_\n"'
}

par_load_file_less_10s() {
    echo '### Test --load read from a file - less than 10s'
    echo 8 > /tmp/parallel_load_file2;
    (sleep 1; echo 1000 > /tmp/parallel_load_file2) &
    stdout /usr/bin/time -f %e parallel --load /tmp/parallel_load_file2 sleep ::: 1 |
	perl -ne 'print(($_ > 0.1 and $_ < 10) ? "OK\n" : "Broken: $_\n")'
    rm /tmp/parallel_load_file2
}

par_load_file_more_10s() {
    echo '### Test --load read from a file - more than 10s'
    echo 8 > /tmp/parallel_load_file;
    (sleep 10; echo 1000 > /tmp/parallel_load_file) &
    stdout /usr/bin/time -f %e parallel --load /tmp/parallel_load_file sleep ::: 1 |
	perl -ne 'print $_ > 10 ? "OK\n" : "Broken: $_\n"'
    rm /tmp/parallel_load_file
}

export -f $(compgen -A function | grep par_)
#compgen -A function | grep par_ | sort | parallel --delay $D -j$P --tag -k '{} 2>&1'
compgen -A function | grep par_ | sort |
    parallel --joblog /tmp/jl-`basename $0` -j200% --tag -k '{} 2>&1'
