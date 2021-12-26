#!/bin/bash

# SPDX-FileCopyrightText: 2021-2022 Ole Tange, http://ole.tange.dk and Free Software and Foundation, Inc.
#
# SPDX-License-Identifier: GPL-3.0-or-later

unset run_test
unset run_once

# SSH only allowed to localhost/lo

par_env_underscore() {
    echo '### --env _'
    echo ignored_var >> ~/.parallel/ignored_vars
    unset $(compgen -A function | grep par_)
    ignored_var="should not be copied"
    export ignored_var
    fUbAr="OK FUBAR" parallel -S parallel@lo --env _ echo '$fUbAr $ignored_var' ::: test
    echo 'In csh this may fail with ignored_var: Undefined variable.'
    fUbAr="OK FUBAR" parallel -S csh@lo --env _ echo '$fUbAr $ignored_var' ::: test 2>&1

    echo '### --env _ with explicit mentioning of normally ignored var $ignored_var'
    ignored_var="should be copied"
    fUbAr="OK FUBAR" parallel -S parallel@lo --env ignored_var,_ echo '$fUbAr $ignored_var' ::: test
    fUbAr="OK FUBAR" parallel -S csh@lo --env ignored_var,_ echo '$fUbAr $ignored_var' ::: test 2>&1
}    

par_warn_when_exporting_func() {
    echo 'bug #40137: SHELL not bash: Warning when exporting funcs'
    myrun() {
	. <(printf 'myfunc() {\necho Function run: $1\n}')
	export -f myfunc
	echo "Run function in $1"
	PARALLEL_SHELL=$1 parallel --env myfunc -S lo myfunc ::: OK
    }
    export -f myrun
    parallel -k --tag myrun ::: /bin/{sh,bash} /usr/bin/{ash,csh,dash,ksh,tcsh,zsh}
}

par_exporting_in_zsh() {
    echo '### zsh'
    
    echo 'env in zsh'
    echo 'Normal variable export'
    export B=\'"  Var with quote"
    PARALLEL_SHELL=/usr/bin/zsh parallel --env B echo '$B' ::: OK

    echo 'Function export as variable'
    export myfuncvar="() { echo myfuncvar as var \$*; }"
    PARALLEL_SHELL=/usr/bin/zsh parallel --env myfuncvar myfuncvar ::: OK

    echo 'Function export as function'
    myfunc() { echo myfunc ran $*; }
    export -f myfunc
    PARALLEL_SHELL=/usr/bin/zsh parallel --env myfunc myfunc ::: OK

    ssh zsh@lo 'fun="() { echo function from zsh to zsh \$*; }"; 
              export fun; 
              parallel --env fun fun ::: OK'

    ssh zsh@lo 'fun="() { echo function from zsh to bash \$*; }"; 
              export fun; 
              parallel -S parallel@lo --env fun fun ::: OK'
}

par_bigvar_csh() {
    echo '### csh'
    echo "3 big vars run remotely - length(base64) > 1000"
    stdout ssh csh@lo 'setenv A `seq 200|xargs`; 
                     setenv B `seq 200 -1 1|xargs`; 
                     setenv C `seq 300 -2 1|xargs`; 
                     parallel -Scsh@lo --env A,B,C -k echo \$\{\}\|wc ::: A B C'
    echo '### csh2'
    echo "3 big vars run locally"
    stdout ssh csh@lo 'setenv A `seq 200|xargs`; 
                     setenv B `seq 200 -1 1|xargs`; 
                     setenv C `seq 300 -2 1|xargs`; 
                     parallel --env A,B,C -k echo \$\{\}\|wc ::: A B C'
}

par_bigvar_rc() {
    echo '### rc'
    echo "3 big vars run remotely - length(base64) > 1000"
    stdout ssh rc@lo 'A=`{seq 200}; 
                    B=`{seq 200 -1 1}; 
                    C=`{seq 300 -2 1}; 
                    parallel -Src@lo --env A,B,C -k echo '"'"'${}|wc'"'"' ::: A B C'

    echo '### rc2'
    echo "3 big vars run locally"
    stdout ssh rc@lo 'A=`{seq 200}; 
                    B=`{seq 200 -1 1}; 
                    C=`{seq 300 -2 1}; 
                    parallel --env A,B,C -k echo '"'"'${}|wc'"'"' ::: A B C'
}

par_tmux_different_shells() {
    echo '### Test tmux works on different shells'
    (stdout parallel -Scsh@lo,tcsh@lo,parallel@lo,zsh@lo --tmux echo ::: 1 2 3 4; echo $?) |
	grep -v 'See output';
    (stdout parallel -Scsh@lo,tcsh@lo,parallel@lo,zsh@lo --tmux false ::: 1 2 3 4; echo $?) |
	grep -v 'See output';

    export PARTMUX='parallel -Scsh@lo,tcsh@lo,parallel@lo,zsh@lo --tmux '; 
    stdout ssh zsh@lo      "$PARTMUX" 'true  ::: 1 2 3 4; echo $status' | grep -v 'See output'; 
    stdout ssh zsh@lo      "$PARTMUX" 'false ::: 1 2 3 4; echo $status' | grep -v 'See output'; 
    stdout ssh parallel@lo "$PARTMUX" 'true  ::: 1 2 3 4; echo $?'      | grep -v 'See output'; 
    stdout ssh parallel@lo "$PARTMUX" 'false ::: 1 2 3 4; echo $?'      | grep -v 'See output'; 
    stdout ssh tcsh@lo     "$PARTMUX" 'true  ::: 1 2 3 4; echo $status' | grep -v 'See output'; 
    stdout ssh tcsh@lo     "$PARTMUX" 'false ::: 1 2 3 4; echo $status' | grep -v 'See output'; 
    echo "# command is currently too long for csh. Maybe it can be fixed?"; 
    stdout ssh csh@lo      "$PARTMUX" 'true  ::: 1 2 3 4; echo $status' | grep -v 'See output'; 
    stdout ssh csh@lo      "$PARTMUX" 'false ::: 1 2 3 4; echo $status' | grep -v 'See output'
}

par_tmux_length() {
    echo '### works'
    stdout parallel -Sparallel@lo --tmux echo ::: \\\\\\\"\\\\\\\"\\\;\@ | grep -v 'See output'
    stdout parallel -Sparallel@lo --tmux echo ::: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx | grep -v 'See output'

    echo '### These blocked due to length'
    stdout parallel -Slo      --tmux echo ::: \\\\\\\"\\\\\\\"\\\;\@ | grep -v 'See output'
    stdout parallel -Scsh@lo  --tmux echo ::: \\\\\\\"\\\\\\\"\\\;\@ | grep -v 'See output'
    stdout parallel -Stcsh@lo --tmux echo ::: \\\\\\\"\\\\\\\"\\\;\@ | grep -v 'See output'
    stdout parallel -Szsh@lo  --tmux echo ::: \\\\\\\"\\\\\\\"\\\;\@ | grep -v 'See output'
    stdout parallel -Scsh@lo  --tmux echo ::: 111111111111111111111111111111111111111111111111111111111 | grep -v 'See output'
}

par_transfer_return_multiple_inputs() {
    echo '### bug #43746: --transfer and --return of multiple inputs {1} and {2}'
    echo '### and:'
    echo '### bug #44371: --trc with csh complains'
    cd /tmp; echo file1 output line 1 > file1; echo file2 output line 3 > file2
    parallel -Scsh@lo --transferfile {1} --transferfile {2} --trc {1}.a --trc {2}.b \
	     '(cat {1}; echo A {1} output line 2) > {1}.a; (cat {2};echo B {2} output line 4) > {2}.b' ::: file1 ::: file2
    cat file1.a file2.b
    rm /tmp/file1 /tmp/file2 /tmp/file1.a /tmp/file2.b
}

par_csh_nice() {
    echo '### bug #44143: csh and nice'
    parallel --nice 1 -S csh@lo setenv B {}\; echo '$B' ::: OK
}

par_multiple_hosts_repeat_arg() {
    echo '### bug #45575: -m and multiple hosts repeats first args'
    seq 1 3 | parallel -X -S 2/lo,2/: -k echo 
}

export -f $(compgen -A function | grep par_)
compgen -A function | grep par_ | LC_ALL=C sort |
    parallel --timeout 3000% -j6 --tag -k --joblog /tmp/jl-`basename $0` '{} 2>&1' |
    perl -pe 's:/usr/bin:/bin:g;'
