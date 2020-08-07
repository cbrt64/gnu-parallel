#!/bin/bash

# SSH only allowed to localhost/lo

par_autossh() {
    echo '### --ssh autossh'
    (
	export PARALLEL_SSH=autossh; export AUTOSSH_PORT=0
	stdout parallel -S lo echo ::: OK
	echo OK | stdout parallel --pipe -S lo cat
	stdout parallel -S lo false ::: a || echo OK should fail
	echo '### --ssh autossh - add commands that fail here'
	touch foo_autossh
	stdout parallel -S csh@lo --trc {}.out touch {}.out ::: foo_autossh
	ls foo_autossh*
	rm foo_autossh*
    ) | grep -Ev 'Warning: remote port forwarding failed for listen'
}

par_basefile_cleanup() {
    echo '### bug #46520: --basefile cleans up without --cleanup'
    touch bug_46520
    parallel -S parallel@lo --bf bug_46520 ls ::: bug_46520
    ssh parallel@lo ls bug_46520
    parallel -S parallel@lo --cleanup --bf bug_46520 ls ::: bug_46520
    stdout ssh parallel@lo ls bug_46520 # should not exist
}

par_input_loss_pipe() {
    echo '### bug #36595: silent loss of input with --pipe and --sshlogin'
    seq 10000 | xargs | parallel --pipe -S 8/localhost cat 2>/dev/null | wc
}

par_controlmaster_eats() {
    echo 'bug #36707: --controlmaster eats jobs'
    seq 2 | parallel -k --controlmaster --sshlogin localhost echo OK{}
}

par_lsh() {
    echo '### --ssh lsh'
    parallel --ssh 'lsh -c aes256-ctr' -S lo echo ::: OK
    echo OK | parallel --ssh 'lsh -c aes256-ctr' --pipe -S csh@lo cat
    # Todo rsync/trc csh@lo
    # Test gl. parallel med --ssh lsh: Hvilke fejler? brug dem. Også hvis de fejler
}

par_pipe_retries() {
    echo '### bug #45025: --pipe --retries does not reschedule on other host'
    seq 1 300030 |
	stdout parallel -k --retries 2 -S a.a,: --pipe 'wc;hostname' |
	perl -pe 's/'`hostname`'/localhost-:/'
    stdout parallel --retries 2 --roundrobin echo ::: should fail
}

par_env_parallel_onall() {
    echo "bug #54352: env_parallel -Slo --nonall myfunc broken in 20180722"
    . `which env_parallel.bash`
    doit() { echo Myfunc "$@"; }
    env_parallel -Slo --onall doit ::: works
    env_parallel -Slo --nonall doit works
}

par_command_len_shellquote() {
    echo '### test quoting will not cause a crash if too long'
    # echo "'''" | parallel --shellquote --shellquote --shellquote --shellquote

    testlen() {
	echo "$1" | parallel $2 | wc
    }
    export -f testlen

    outer() {
	export PARALLEL="--env testlen -k --tag"
	parallel $@ testlen '{=2 $_="$arg[1]"x$_ =}' '{=3 $_=" --shellquote"x$_ =}' \
	     ::: '"' "'" ::: {1..10} ::: {1..10}
    }
    export -f outer

    stdout parallel --tag -k outer ::: '-Slo -j10' '' |
	perl -pe 's/131\d\d\d/131xxx/g';
}

export -f $(compgen -A function | grep par_)
compgen -A function | grep par_ | sort -r |
    # 2019-07-14 100% slowed down 4 threads/16GB
    parallel -j75% --joblog /tmp/jl-`basename $0` -j3 --tag -k --delay 0.1 --retries 3 '{} 2>&1'
