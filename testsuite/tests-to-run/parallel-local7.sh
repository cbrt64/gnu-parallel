#!/bin/bash

par_tmux_filter() {
    # /tmp/parallel-local7/tmsOU2Ig
    perl -pe 's:(/tmp\S+/tms).....:$1XXXXX:;s/ p\d+/pID/;'
}
export -f par_tmux_filter

par_tmux() {
    # Read command line length on stdin
    # The line will be a number of \'s
    (stdout parallel --timeout 10 --tmux --delay 0.03 echo '{}{=$_="\\"x$_=}'; echo $?) |
	par_tmux_filter
}
export -f par_tmux

# Does not work
# cat >/tmp/parallel-local7-script <<EOF
# stdout /usr/bin/time -f %e 
# parallel --tmux --fg sleep ::: 1 2 3
# parallel --tmuxpane --fg sleep ::: 1 2 3
# EOF
# chmod +x /tmp/parallel-local7-script
# echo '### bug #48841: --tmux(pane) --fg should start tmux in foreground'
# stdout /usr/bin/time -f %e script -q -f -c /tmp/parallel-local7-script /dev/null |  perl -ne '$_ >= 26 and $_ <= 45 and print "OK\n"'

cat <<'EOF' | sed -e 's/;$/; /;s/$SERVER1/'$SERVER1'/;s/$SERVER2/'$SERVER2'/' | stdout parallel -vj8 --delay 1 --timeout 100 --retries 1 -k --joblog /tmp/jl-`basename $0` -L1

echo '### tmux-1.9'
  seq 000   100 | PARALLEL_TMUX=tmux-1.9 par_tmux
  seq 100   200 | PARALLEL_TMUX=tmux-1.9 par_tmux
  seq 200   300 | PARALLEL_TMUX=tmux-1.9 par_tmux
  seq 300   400 | PARALLEL_TMUX=tmux-1.9 par_tmux
  seq 400   500 | PARALLEL_TMUX=tmux-1.9 par_tmux
  seq 500   600 | PARALLEL_TMUX=tmux-1.9 par_tmux
  seq 600   700 | PARALLEL_TMUX=tmux-1.9 par_tmux
  seq 700   800 | PARALLEL_TMUX=tmux-1.9 par_tmux
  seq 800   900 | PARALLEL_TMUX=tmux-1.9 par_tmux
  seq 900  1000 | PARALLEL_TMUX=tmux-1.9 par_tmux
  seq 1000 1100 | PARALLEL_TMUX=tmux-1.9 par_tmux
  seq 1100 1200 | PARALLEL_TMUX=tmux-1.9 par_tmux
  seq 1200 1300 | PARALLEL_TMUX=tmux-1.9 par_tmux
  seq 1300 1400 | PARALLEL_TMUX=tmux-1.9 par_tmux
  seq 1400 1500 | PARALLEL_TMUX=tmux-1.9 par_tmux
  seq 1500 1600 | PARALLEL_TMUX=tmux-1.9 par_tmux
  seq 1600 1700 | PARALLEL_TMUX=tmux-1.9 par_tmux
  seq 1700 1800 | PARALLEL_TMUX=tmux-1.9 par_tmux
  seq 1800 1900 | PARALLEL_TMUX=tmux-1.9 par_tmux
  seq 1900 2000 | PARALLEL_TMUX=tmux-1.9 par_tmux
  seq 2000 2018 | PARALLEL_TMUX=tmux-1.9 par_tmux
echo '### tmux-1.9 fails'
  echo 2019 | PARALLEL_TMUX=tmux-1.9 par_tmux
  echo 2020 | PARALLEL_TMUX=tmux-1.9 par_tmux
  echo 2021 | PARALLEL_TMUX=tmux-1.9 par_tmux

echo '### tmux-1.8'
  seq   1 100 | PARALLEL_TMUX=tmux-1.8 par_tmux
  seq 101 200 | PARALLEL_TMUX=tmux-1.8 par_tmux
  seq 201 231 | PARALLEL_TMUX=tmux-1.8 par_tmux
echo '### tmux-1.8 fails'
  echo 232 | PARALLEL_TMUX=tmux-1.8 par_tmux
  echo 233 | PARALLEL_TMUX=tmux-1.8 par_tmux
  echo 234 | PARALLEL_TMUX=tmux-1.8 par_tmux

echo '### tmux-1.8 0..255 ascii'
perl -e 'print map { ($_, map { pack("c*",$_) } grep { $_>=1 && $_!=10 } $_-110..$_),"\n" } 0..255' | 
   PARALLEL_TMUX=tmux-1.8 stdout parallel --tmux --timeout 5 echo | par_tmux_filter; echo $?

echo '### tmux-1.9 0..255 ascii'
perl -e 'print map { ($_, map { pack("c*",$_) } grep { $_>=1 && $_!=10 } 0..$_),"\n" } 0..255' | 
   PARALLEL_TMUX=tmux-1.9 stdout parallel --tmux --timeout 5 echo | par_tmux_filter; echo $?

echo '### Test output ascii'
  rm -f /tmp/paralocal7-ascii*; 
  perl -e 'print map { ($_, map { pack("c*",$_) } grep { $_>=1 && $_!=10 } $_-10..$_),"\n" } 1..255' | stdout parallel --tmux echo {}'>>/tmp/paralocal7-ascii{%}' | par_tmux_filter; 
  sort /tmp/paralocal7-ascii* | md5sum

echo '### Test critical lengths. Must not block'
  seq 140 260 | PARALLEL_TMUX=tmux-1.8 stdout parallel --tmux echo '{}{=$_="&"x$_=}' | par_tmux_filter
  seq 140 260 | PARALLEL_TMUX=tmux-1.9 stdout parallel --tmux echo '{}{=$_="&"x$_=}' | par_tmux_filter
  seq 560 850 | PARALLEL_TMUX=tmux-1.8 stdout parallel --tmux echo '{}{=$_="a"x$_=}' | par_tmux_filter
  seq 560 850 | PARALLEL_TMUX=tmux-1.9 stdout parallel --tmux echo '{}{=$_="a"x$_=}' | par_tmux_filter

EOF

rm -f /tmp/paralocal7*
