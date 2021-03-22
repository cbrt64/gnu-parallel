#!/bin/bash

# SPDX-FileCopyrightText: 2021 Ole Tange, http://ole.tange.dk and Free Software and Foundation, Inc.
#
# SPDX-License-Identifier: GPL-3.0-or-later

# -L1 will join lines ending in ' '
cat <<'EOF' | sed -e 's/;$/; /;s/$SERVER1/'$SERVER1'/;s/$SERVER2/'$SERVER2'/' | stdout parallel -vj0 -k --joblog /tmp/jl-`basename $0` -L1 -r
echo '### Test mutex. This should not mix output'; 
  parallel --semaphore --id mutex -u seq 1 10 '|' pv -qL 20; 
  parallel --semaphore --id mutex -u seq 11 20 '|' pv -qL 100; 
  parallel --semaphore --id mutex --wait; 
  echo done

echo '### Test similar example as from man page - run 2 jobs simultaneously'
echo 'Expect done: 1 2 5 3 4'
for i in 5 1 2 3 4 ; do 
  sleep 0.2; 
  echo Scheduling $i; 
  sem -j2 --id ex2jobs -u echo starting $i ";" sleep $i ";" echo done $i; 
done; 
sem --id ex2jobs --wait

echo '### Test --fg followed by --bg'
  parallel -u --id fgbg --fg --semaphore seq 1 10 '|' pv -qL 30; 
  parallel -u --id fgbg --bg --semaphore seq 11 20 '|' pv -qL 30; 
  parallel -u --id fgbg --fg --semaphore seq 21 30 '|' pv -qL 30; 
  parallel -u --id fgbg --bg --semaphore seq 31 40 '|' pv -qL 30; 
  sem --id fgbg --wait

echo '### Test bug #33621: --bg -p should give an error message'
  stdout parallel -p --bg echo x{}

echo '### Failed on 20141226'
  sem --fg --line-buffer --id bugin20141226 echo OK

echo '### Test --st +1/-1'
  stdout sem --id st --line-buffer "echo A normal-start;sleep 3;echo C normal-end"; 
  stdout sem --id st --line-buffer --st 1 "echo B st1-start;sleep 3;echo D st1-end"; 
  stdout sem --id st --line-buffer --st -1 "echo ERROR-st-1-start;sleep 3;echo ERROR-st-1-end"; 
  stdout sem --id st --wait


EOF
