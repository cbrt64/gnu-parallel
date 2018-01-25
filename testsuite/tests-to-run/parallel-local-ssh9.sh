#!/bin/bash

par_ash_embed() {
  myscript=$(cat <<'_EOF'
    echo '--embed'
    parallel --embed | tac | perl -pe '
      /^parallel/ and not $seen++ and s{^}{
echo \$b
parset a,b,c echo ::: ParsetOK ParsetOK ParsetOK
env_parallel echo ::: env_parallel_OK
parallel echo ::: parallel_OK
PATH=/usr/sbin:/usr/bin:/sbin:/bin
# Do not look for parallel in /usr/local/bin
. \`which env_parallel.ash\`
}
    ' | tac > parallel-embed
    chmod +x parallel-embed
    ./parallel-embed
#    rm parallel-embed
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
parallel echo ::: parallel_OK
PATH=/usr/sbin:/usr/bin:/sbin:/bin
# Do not look for parallel in /usr/local/bin
. \`which env_parallel.bash\`
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
parallel echo ::: parallel_OK
PATH=/usr/sbin:/usr/bin:/sbin:/bin
# Do not look for parallel in /usr/local/bin
. \`which env_parallel.ksh\`
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
parallel echo ::: parallel_OK
PATH=/usr/sbin:/usr/bin:/sbin:/bin
# Do not look for parallel in /usr/local/bin
. \`which env_parallel.sh\`
}
    ' | tac > parallel-embed
    chmod +x parallel-embed
    ./parallel-embed
#    rm parallel-embed
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
parallel echo ::: parallel_OK
PATH=/usr/sbin:/usr/bin:/sbin:/bin
# Do not look for parallel in /usr/local/bin
. \`which env_parallel.zsh\`
}
    ' | tac > parallel-embed
    chmod +x parallel-embed
    ./parallel-embed
    rm parallel-embed
_EOF
  )
  ssh zsh@lo "$myscript"
}

export -f $(compgen -A function | grep par_)
#compgen -A function | grep par_ | sort | parallel --delay $D -j$P --tag -k '{} 2>&1'
#compgen -A function | grep par_ | sort |
compgen -A function | grep par_ | sort -r |
#    parallel --joblog /tmp/jl-`basename $0` --delay $D -j$P --tag -k '{} 2>&1'
    parallel --joblog /tmp/jl-`basename $0` -j200% --tag -k '{} 2>&1' |
    perl -pe 's/line \d\d\d:/line XXX:/'
