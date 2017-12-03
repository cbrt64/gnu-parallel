#!/bin/bash

# Each test should at most run 1 ssh against parallel@lo or lo

par_path_remote_bash() {
  echo 'bug #47695: How to set $PATH on remote? Bash'
  rm -rf /tmp/parallel
  cp /usr/local/bin/parallel /tmp
  
  cat <<'_EOS' | stdout ssh nopathbash@lo -T | grep -Ev 'updates are security updates|packages can be updated|System restart required|Welcome to|https://|Ubuntu|http://|^$' | uniq
  echo BASH Path before: $PATH with no parallel
  parallel echo ::: 1
  # Race condition stderr/stdout
  sleep 1
  echo '^^^^^^^^ Not found is OK'
  # Exporting a big variable should not fail
  export A="`seq 1000`"
  PATH=$PATH:/tmp
  . /usr/local/bin/env_parallel.bash
  # --filter to see if $PATH with parallel is transferred
  env_parallel --filter --env A,PATH -Slo echo '$PATH' ::: OK
_EOS
  echo
}

par_path_remote_csh() {
  echo 'bug #47695: How to set $PATH on remote? csh'
  rm -rf /tmp/parallel
  cp /usr/local/bin/parallel /tmp

  cat <<'_EOS' | stdout ssh nopathcsh@lo -T | grep -Ev 'updates are security updates|packages can be updated|System restart required|Welcome to|https://|Ubuntu|http://' | uniq
  echo CSH Path before: $PATH with no parallel
  which parallel >& /dev/stdout
  echo '^^^^^^^^ Not found is OK'
  alias parallel=/tmp/parallel
  # Exporting a big variable should not fail
  setenv A "`seq 1000`"
  setenv PATH ${PATH}:/tmp
  cp /usr/local/bin/env_parallel* /tmp
  rehash
  if ("`alias env_parallel`" == '') then
    source `which env_parallel.csh`
  endif
  # --filter to see if $PATH with parallel is transferred
  env_parallel --filter --env A,PATH -Slo echo '$PATH' ::: OK
  # Sleep needed to avoid stderr/stdout mixing
  sleep 1
  echo Right now it seems csh does not respect $PATH if set from Perl
  echo Done
_EOS
}

par_keep_order() {
    echo '### Test --keep-order'
    seq 0 2 |
    parallel --keep-order -j100% -S 1/:,2/parallel@lo -q perl -e 'sleep 1;print "job{}\n";exit({})'
}

par_keeporder() {
    echo '### Test --keeporder'
    seq 0 2 |
    parallel --keeporder -j100% -S 1/:,2/parallel@lo -q perl -e 'sleep 1;print "job{}\n";exit({})'
}

par_load_csh() {
    echo '### Gave Word too long.'
    parallel --load 100% -S csh@lo echo ::: a
}

par_PARALLEL_RSYNC_OPTS() {
    echo '### test rsync opts'
    touch parallel_rsync_opts.test
    parallel --rsync-opts -rlDzRRRR -vv -S parallel@lo --trc {}.out touch {}.out ::: parallel_rsync_opts.test |
	perl -ne 's/(rsync .*?RRRR)/print $1/ge'
    export PARALLEL_RSYNC_OPTS=-zzrrllddRRRR
    parallel -vv -S parallel@lo --trc {}.out touch {}.out ::: parallel_rsync_opts.test |
	perl -ne 's/(rsync .*?RRRR)/print $1/ge'
    rm parallel_rsync_opts.test parallel_rsync_opts.test.out
    echo
}

par_bar_m() {
    echo '### test --bar -m'
    stdout parallel --bar -P 2 -m sleep ::: 1 1 2 2 3 3 |
	perl -pe 's/\r/\n/g'|
	grep -E '^[0-9]+ *$' |
	uniq
}

export -f $(compgen -A function | grep par_)
#compgen -A function | grep par_ | sort | parallel --delay $D -j$P --tag -k '{} 2>&1'
compgen -A function | grep par_ | sort |
    parallel --joblog /tmp/jl-`basename $0` --delay 0.1 -j10 --tag -k '{} 2>&1'
