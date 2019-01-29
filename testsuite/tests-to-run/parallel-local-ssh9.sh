#!/bin/bash

par_ash_embed() {
  myscript=$(cat <<'_EOF'
    echo '--embed'
    parallel --embed | tac | perl -pe '
      /^parallel/ and not $seen++ and s{^}{
echo \$b
parset a,b,c echo ::: ParsetOK ParsetOK ParsetOK
env_parallel echo ::: env_parallel_OK
env_parallel --env myvar echo {} --env \\\$myvar ::: env_parallel
myvar=OK
parallel echo ::: parallel_OK
PATH=/usr/sbin:/usr/bin:/sbin:/bin
# Do not look for parallel in /usr/local/bin
#. \`which env_parallel.ash\`
}
    ' | tac > parallel-embed
    chmod +x parallel-embed
    ./parallel-embed
    rm parallel-embed
_EOF
  )
  ssh ash@lo "$myscript"
}

par_bash_embed() {
  myscript=$(cat <<'_EOF'
    echo '--embed'
    parallel --embed | tac | perl -pe '
      /^parallel/ and not $seen++ and s{^}{
echo \${a[1]}
parset a echo ::: ParsetOK ParsetOK ParsetOK
env_parallel echo ::: env_parallel_OK
env_parallel --env myvar echo {} --env \\\$myvar ::: env_parallel
myvar=OK
parallel echo ::: parallel_OK
PATH=/usr/sbin:/usr/bin:/sbin:/bin
# Do not look for parallel in /usr/local/bin
#. \`which env_parallel.bash\`
}
    ' | tac > parallel-embed
    chmod +x parallel-embed
    ./parallel-embed
    rm parallel-embed
_EOF
  )
  ssh bash@lo "$myscript"
}

par_csh_embed() {
    echo Not implemented
}

par_fish_embed() {
    echo Not implemented
}

par_ksh_embed() {
  myscript=$(cat <<'_EOF'
    echo '--embed'
    parallel --embed | tac | perl -pe '
      /^parallel/ and not $seen++ and s{^}{
echo \${a[1]}
parset a echo ::: ParsetOK ParsetOK ParsetOK
env_parallel echo ::: env_parallel_OK
env_parallel --env myvar echo {} --env \\\$myvar ::: env_parallel
myvar=OK
parallel echo ::: parallel_OK
PATH=/usr/sbin:/usr/bin:/sbin:/bin
# Do not look for parallel in /usr/local/bin
#. \`which env_parallel.ksh\`
}
    ' | tac > parallel-embed
    chmod +x parallel-embed
    ./parallel-embed
    rm parallel-embed
_EOF
  )
  ssh ksh@lo "$myscript"
}

par_sh_embed() {
  myscript=$(cat <<'_EOF'
    echo '--embed'
    parallel --embed | tac | perl -pe '
      /^parallel/ and not $seen++ and s{^}{
echo \$b
parset a,b,c echo ::: ParsetOK ParsetOK ParsetOK
env_parallel echo ::: env_parallel_OK
env_parallel --env myvar echo {} --env \\\$myvar ::: env_parallel
myvar=OK
parallel echo ::: parallel_OK
PATH=/usr/sbin:/usr/bin:/sbin:/bin
# Do not look for parallel in /usr/local/bin
#. \`which env_parallel.sh\`
}
    ' | tac > parallel-embed
    chmod +x parallel-embed
    ./parallel-embed
    rm parallel-embed
_EOF
  )
  ssh sh@lo "$myscript"
}

par_tcsh_embed() {
    echo Not implemented
}

par_zsh_embed() {
  myscript=$(cat <<'_EOF'
    echo '--embed'
    parallel --embed | tac | perl -pe '
      /^parallel/ and not $seen++ and s{^}{
echo \${a[1]}
parset a echo ::: ParsetOK ParsetOK ParsetOK
env_parallel echo ::: env_parallel_OK
env_parallel --env myvar echo {} --env \\\$myvar ::: env_parallel
myvar=OK
parallel echo ::: parallel_OK
PATH=/usr/sbin:/usr/bin:/sbin:/bin
# Do not look for parallel in /usr/local/bin
}
    ' | tac > parallel-embed
    chmod +x parallel-embed
    ./parallel-embed
    rm parallel-embed
_EOF
  )
  ssh zsh@lo "$myscript"
}

par_propagate_env() {
    echo '### bug #41805: Idea: propagate --env for parallel --number-of-cores'
    echo '** test_zsh'
    FOO=test_zsh parallel --env FOO,HOME -S zsh@lo -N0 env ::: "" |sort|egrep 'FOO|^HOME'
    echo '** test_zsh_filter'
    FOO=test_zsh_filter parallel --filter-hosts --env FOO,HOME -S zsh@lo -N0 env ::: "" |sort|egrep 'FOO|^HOME'
    echo '** test_csh'
    FOO=test_csh parallel --env FOO,HOME -S csh@lo -N0 env ::: "" |sort|egrep 'FOO|^HOME'
    echo '** test_csh_filter'
    FOO=test_csh_filter parallel --filter-hosts --env FOO,HOME -S csh@lo -N0 env ::: "" |sort|egrep 'FOO|^HOME'
    echo '** bug #41805 done'
}

par_env_parallel_big_env() {
    echo '### bug #54128: command too long when exporting big env'
    . `which env_parallel.bash`
    a=`rand | perl -pe 's/\0//g'| head -c 70000`
    env_parallel -Slo echo should not ::: fail 2>&1
    a=`rand | perl -pe 's/\0//g'| head -c 80000`
    env_parallel -Slo echo should ::: fail 2>/dev/null || echo OK
}

par_no_route_to_host() {
    echo '### no route to host with | and -j0 causes inf loop'
    # Broken in parallel-20121122 .. parallel-20181022
    # parallel-20181022 -j0 -S 185.75.195.218 echo ::: {1..11}
    via_parallel() {
	seq 11 | stdout parallel -j0 -S $1 echo
    }
    export -f via_parallel
    raw() {
	stdout ssh $1 echo
    }
    export -f raw

    # Random hosts that there is no route to
    findhosts() {
	ip='$(($RANDOM%256)).$(($RANDOM%256)).$(($RANDOM%256)).$(($RANDOM%256))'
	stdout parallel --timeout 2 -j0 ssh -o PasswordAuthentication=no $ip echo ::: {1..10000} |
	    perl -ne 's/ssh:.* host (\d+\.\d+\.\d+\.\d+) .* No route .*/$1/ and print; $|=1'
    }

    # Retry if the hosts really fails this fast
    filterhosts() {
	stdout parallel --timeout 2 -j5 ssh -o PasswordAuthentication=no {} echo |
	    perl -ne 's/ssh:.* host (\d+\.\d+\.\d+\.\d+) .* No route .*/$1/ and print; $|=1'
    }

    (
	# Cache a list of hosts that fail fast with 'No route'
	# Filter the list 4 times to make sure to get good hosts
	renice 10 -p $$ >/dev/null
	findhosts | filterhosts | filterhosts |
	    filterhosts | filterhosts | head > /tmp/filtered.$$
	mv /tmp/filtered.$$ /tmp/filtered.hosts
    ) &
    (
	# We just need one to complete
	stdout parallel --halt now,done=1 -j0 raw :::: /tmp/filtered.hosts
	stdout parallel --halt now,done=1 -j0 via_parallel :::: /tmp/filtered.hosts
    ) | perl -pe 's/(\d+\.\d+\.\d+\.\d+)/i.p.n.r/' | puniq
}

export -f $(compgen -A function | grep par_)
#compgen -A function | grep par_ | sort | parallel --delay $D -j$P --tag -k '{} 2>&1'
#compgen -A function | grep par_ | sort |
compgen -A function | grep par_ | sort -r |
#    parallel --joblog /tmp/jl-`basename $0` --delay $D -j$P --tag -k '{} 2>&1'
    parallel --joblog /tmp/jl-`basename $0` --delay 0.1 -j200% --tag -k '{} 2>&1' |
    perl -pe 's/line \d\d\d+:/line XXX:/' |
    perl -pe 's/\[\d\d\d+\]:/[XXX]:/'
