#!/bin/bash

. `which env_parallel.bash`
env_parallel --session

par_many_args() {
    rm -f ~/.parallel/tmp/sshlogin/*/linelen
    pecho() { perl -e 'print "@ARGV\n"' "$@"; }
    export -f pecho
    gen500k() { yes | head -c 131000; }
    for a in `seq 6000`; do eval "export a$a=1" ; done
    gen500k | stdout parallel --load 27 -Xkj1  'pecho {} {} {} {} | wc' |
	perl -pe 's/\d{10,}.\d+ //g'
}

par_many_var() {
    rm -f ~/.parallel/tmp/sshlogin/*/linelen
    pecho() { perl -e 'print "@ARGV\n"' "$@"; }
    export -f pecho
    gen500k() { seq -f %f 1000000000000000 1000000000050000 | head -c 131000; }
    for a in `seq 6000`; do eval "export a$a=1" ; done
    gen500k | stdout parallel --load 4 -Xkj1  'pecho {} {} {} {} | wc' |
	perl -pe 's/\d{10,}.\d+ //g'
}

par_many_var_func() {
    rm -f ~/.parallel/tmp/sshlogin/*/linelen
    gen500k() { seq -f %f 1000000000000000 1000000000050000 | head -c 131000; }
    pecho() { perl -e 'print "@ARGV\n"' "$@"; }
    export -f pecho
    for a in `seq 5000`; do eval "export a$a=1" ; done
    for a in `seq 5000`; do eval "a$a() { 1; }" ; done
    for a in `seq 5000`; do eval export -f a$a ; done
    gen500k | stdout parallel --load 20 -Xkj1  'pecho {} {} {} {} | wc' |
	perl -pe 's/\d{10,}.\d+ //g'
}

par_many_func() {
    rm -f ~/.parallel/tmp/sshlogin/*/linelen
    gen500k() { seq -f %f 1000000000000000 1000000000050000 | head -c 131000; }
    pecho() { perl -e 'print "@ARGV\n"' "$@"; }
    export -f pecho
    for a in `seq 5000`; do eval "a$a() { 1; }" ; done
    for a in `seq 5000`; do eval export -f a$a ; done
    gen500k | stdout parallel --load 5 -Xkj1  'pecho {} {} {} {} | wc' |
	perl -pe 's/\d{10,}.\d+ //g'
}

par_big_func() {
    rm -f ~/.parallel/tmp/sshlogin/*/linelen
    gen500k() { seq -f %f 1000000000000000 1000000000050000 | head -c 131000; }
    pecho() { perl -e 'print "@ARGV\n"' "$@"; }
    export -f pecho
    big=`seq 1000`
    for a in `seq 1`; do eval "a$a() { '$big'; }" ; done
    for a in `seq 1`; do eval export -f a$a ; done
    gen500k | stdout parallel --load 2 -Xkj1  'pecho {} {} {} {} | wc' |
	perl -pe 's/\d{10,}.\d+ //g'
}

par_many_var_big_func() {
    rm -f ~/.parallel/tmp/sshlogin/*/linelen
    gen500k() { seq -f %f 1000000000000000 1000000000050000 | head -c 131000; }
    pecho() { perl -e 'print "@ARGV\n"' "$@"; }
    export -f pecho
    big=`seq 1000`
    for a in `seq 5000`; do eval "export a$a=1" ; done
    for a in `seq 10`; do eval "a$a() { '$big'; }" ; done
    for a in `seq 10`; do eval export -f a$a ; done
    gen500k | stdout parallel --load 5 -Xkj1  'pecho {} {} {} {} | wc' |
	perl -pe 's/\d{10,}.\d+ //g'
}

par_big_func_name() {
    rm -f ~/.parallel/tmp/sshlogin/*/linelen
    gen500k() { seq -f %f 1000000000000000 1000000000050000 | head -c 131000; }
    pecho() { perl -e 'print "@ARGV\n"' "$@"; }
    export -f pecho
    big=`perl -e print\"x\"x10000`
    for a in `seq 10`; do eval "export a$big$a=1" ; done
    gen500k | stdout parallel --load 5 -Xkj1  'pecho {} {} {} {} | wc' |
	perl -pe 's/\d{10,}.\d+ //g'
}

par_big_var_func_name() {
    rm -f ~/.parallel/tmp/sshlogin/*/linelen
    gen500k() { seq -f %f 1000000000000000 1000000000050000 | head -c 131000; }
    pecho() { perl -e 'print "@ARGV\n"' "$@"; }
    export -f pecho
    big=`perl -e print\"x\"x10000`
    for a in `seq 10`; do eval "export a$big$a=1" ; done
    for a in `seq 10`; do eval "a$big$a() { 1; }" ; done
    for a in `seq 10`; do eval export -f a$big$a ; done
    gen500k | stdout parallel --load 4 -Xkj1  'pecho {} {} {} {} | wc' |
	perl -pe 's/\d{10,}.\d+ //g'
}

scp /usr/local/bin/parallel macosx.p:bin/

export -f $(compgen -A function | grep par_)
#compgen -A function |
compgen -A function |
    grep par_ |
    LC_ALL=C sort |
    env_parallel --timeout 3000% --tag -k -S macosx.p
