#!/bin/bash

. `which env_parallel.bash`
env_parallel --session

par_many_var() {
    gen500k() { seq -f %f 1000000000000000 1000000000050000 | head -c 131000; }
    for a in `seq 6000`; do eval "export a$a=1" ; done
    gen500k | stdout parallel --load 5 -Xkj1  'echo {} {} {} {} | wc' |
	perl -pe 's/\d{10,}.\d+ //g'
}

par_many_var_func() {
    gen500k() { seq -f %f 1000000000000000 1000000000050000 | head -c 131000; }
    for a in `seq 5000`; do eval "export a$a=1" ; done
    for a in `seq 5000`; do eval "a$a() { 1; }" ; done
    for a in `seq 5000`; do eval export -f a$a ; done
    gen500k | stdout parallel --load 21 -Xkj1  'echo {} {} {} {} | wc' |
	perl -pe 's/\d{10,}.\d+ //g'
}

par_many_func() {
    gen500k() { seq -f %f 1000000000000000 1000000000050000 | head -c 131000; }
    for a in `seq 5000`; do eval "a$a() { 1; }" ; done
    for a in `seq 5000`; do eval export -f a$a ; done
    gen500k | stdout parallel --load 6 -Xkj1  'echo {} {} {} {} | wc' |
	perl -pe 's/\d{10,}.\d+ //g'
}

par_big_func() {
    gen500k() { seq -f %f 1000000000000000 1000000000050000 | head -c 131000; }
    big=`seq 1000`
    for a in `seq 50`; do eval "a$a() { '$big'; }" ; done
    for a in `seq 50`; do eval export -f a$a ; done
    gen500k | stdout parallel --load 3 -Xkj1  'echo {} {} {} {} | wc' |
	perl -pe 's/\d{10,}.\d+ //g'
}

par_many_var_big_func() {
    gen500k() { seq -f %f 1000000000000000 1000000000050000 | head -c 131000; }
    big=`seq 1000`
    for a in `seq 5000`; do eval "export a$a=1" ; done
    for a in `seq 10`; do eval "a$a() { '$big'; }" ; done
    for a in `seq 10`; do eval export -f a$a ; done
    gen500k | stdout parallel --load 6 -Xkj1  'echo {} {} {} {} | wc' |
	perl -pe 's/\d{10,}.\d+ //g'
}

par_big_func_name() {
    gen500k() { seq -f %f 1000000000000000 1000000000050000 | head -c 131000; }
    big=`perl -e print\"x\"x10000`
    for a in `seq 10`; do eval "export a$big$a=1" ; done
    gen500k | stdout parallel --load 7 -Xkj1  'echo {} {} {} {} | wc' |
	perl -pe 's/\d{10,}.\d+ //g'
}

par_big_var_func_name() {
    gen500k() { seq -f %f 1000000000000000 1000000000050000 | head -c 131000; }
    big=`perl -e print\"x\"x10000`
    for a in `seq 10`; do eval "export a$big$a=1" ; done
    for a in `seq 10`; do eval "a$big$a() { 1; }" ; done
    for a in `seq 10`; do eval export -f a$big$a ; done
    gen500k | stdout parallel --load 5 -Xkj1  'echo {} {} {} {} | wc' |
	perl -pe 's/\d{10,}.\d+ //g'
}

scp /usr/local/bin/parallel macosx.p:bin/

export -f $(compgen -A function | grep par_)
#compgen -A function |
compgen -A function |
    grep par_ |
    LC_ALL=C sort |
    env_parallel --timeout 3000% --tag -k -S macosx.p
