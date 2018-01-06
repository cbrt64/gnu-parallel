#!/bin/bash

export PARALLEL="--load 300%"

par_test_delimiter() {
    echo "### Test : as delimiter. This can be confusing for uptime ie. --load";
    parallel -k --load 300% -d : echo ::: a:b:c
}

par_squared() {
    squared() {
	i=$1
	i2=$[i*i]
	seq $i2 | parallel -j0 --load 300% -kX echo {} | wc
	seq 1 ${i2}0000 |
	    parallel -kj20 --recend "\n" --spreadstdin gzip -1 |
	    zcat | sort -n | md5sum
    }
    export -f squared

    seq 10 -1 2 | stdout parallel -j5 -k squared |
	grep -Ev 'processes took|Consider adjusting -j'
}

par_load_blocks() {
    echo "### Test if --load blocks. Bug.";
    (seq 1 1000 |
	 parallel -kj2 --load 300% --recend "\n" --spreadstdin gzip -1 |
	 zcat | sort -n | md5sum
     seq 1 1000 |
	 parallel -kj200 --load 300% --recend "\n" --spreadstdin gzip -1 |
	 zcat | sort -n | md5sum) 2>&1 |
	grep -Ev 'processes took|Consider adjusting -j'
}

par_load_from_PARALLEL() {
    echo "### Test reading load from PARALLEL"
    # Ignore stderr due to 'Starting processes took > 2 sec'
    seq 1 1000000 |
	parallel -kj200 --recend "\n" --spreadstdin gzip -1 2>/dev/null |
	zcat | sort -n | md5sum
    seq 1 1000000 |
	parallel -kj20 --recend "\n" --spreadstdin gzip -1 |
	zcat | sort -n | md5sum
}

export -f $(compgen -A function | grep par_)
compgen -A function | grep par_ | sort |
    parallel -j0 --tag -k --joblog +/tmp/jl-`basename $0` '{} 2>&1'
