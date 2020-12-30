#!/bin/bash

par_dummy() { true; }

export -f $(compgen -A function | grep par_)
compgen -A function | grep par_ | sort |
    parallel -j0 --tag -k --joblog +/tmp/jl-`basename $0` '{} 2>&1'
