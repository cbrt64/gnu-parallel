#!/bin/bash

cat <<'EOF' | sed -e s/\$SERVER1/$SERVER1/\;s/\$SERVER2/$SERVER2/ | stdout parallel -j10 -k -L1
echo '### Test bug #34241: --pipe should not spawn unneeded processes'
  seq 5 | ssh csh@lo parallel -k --block 5 --pipe -j10 cat\\\;echo Block_end

echo '### --env _'
  fUbAr="OK FUBAR" parallel -S csh@lo --env _ echo '$fUbAr $DISPLAY' ::: test
echo '### --env _ with explicit mentioning of normally ignored var $DISPLAY'
  fUbAr="OK FUBAR" parallel -S csh@lo --env DISPLAY,_ echo '$fUbAr $DISPLAY' ::: test

echo 'bug #40137: SHELL not bash: Warning when exporting funcs'
  . <(printf 'myfunc() {\necho $1\n}'); export -f myfunc; parallel --env myfunc -S lo myfunc ::: no_warning
  . <(printf 'myfunc() {\necho $1\n}'); export -f myfunc; SHELL=/bin/sh parallel --env myfunc -S lo myfunc ::: warning

echo '### --filter-hosts --slf <()'
  parallel --nonall --filter-hosts --slf <(echo localhost) echo OK

echo '### bug #40002: --files and --nonall seem not to work together:'
  parallel --files --nonall -S localhost true | tee >(parallel rm) | wc -l

echo '### bug #40001: --joblog and --nonall seem not to work together:'
  parallel --joblog - --nonall -S lo,localhost true | wc -l

echo '### bug #40132: FreeBSD: --workdir . gives warning if . == $HOME'
  cd && parallel --workdir . -S lo pwd ::: "" 

EOF
