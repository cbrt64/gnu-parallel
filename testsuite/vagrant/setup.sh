#!/bin/bash

setup_one() {
    # setup_one ubuntu/trusty64 172.27.27.2
    if [ -z "$2" ] ; then
	echo Usage: setup_one ubuntu/trusty64 172.27.27.2
	return 1
    fi
    vfile="$1"/Vagrantfile
    mkdir -p "$1"
    cp Vagrantfile.tmpl "$vfile"
    (
	cd "$1"
	perl -i -pe "s{%%VMBOX%%}{$1}g;s/%%IP%%/$2/" Vagrantfile
	vagrant up
	vagrant ssh -c 'ip addr || ifconfig'
    )
    ssh-keygen -R $2
    ssh vagrant@$2 hostname
}
export -f setup_one

destroy_one() {
    (
	cd "$1"
	vagrant destroy -f
    )
    rm -r ./"$1"
}
export -f destroy_one


server_list() {
    grep -v '#' <<SSHOK
#generic/arch.98
hfm4/centos4.4
hfm4/centos5.5
#generic/centos6.6
#generic/centos7.7
#generic/centos8.8
MarcinOrlowski/debian4-i386.14
twolfman/debian6-lamp-drush.16
puphpet/debian75-x64.17
#generic/debian8.18
#generic/debian9.19
#generic/debian10.30
#generic/devuan3.43
#generic/freebsd11.71
#generic/freebsd12.72
#generic/gentoo.99
#generic/netbsd9.89
#generic/oracle7.127
#generic/rhel6.106
#generic/rhel7.107
#generic/rhel8.108
#generic/ubuntu1604.216
#generic/ubuntu1804.218
#generic/ubuntu2004.220
SSHOK

    # Ignore for now
    true <<EOF
generic/alpine310
generic/alpine311
generic/alpine312
generic/alpine35
generic/alpine36
generic/alpine37
generic/alpine38
generic/alpine39
generic/dragonflybsd5
generic/fedora25
generic/fedora26
generic/fedora27
generic/fedora28
generic/fedora29
generic/fedora30
generic/fedora31
generic/fedora32
generic/hardenedbsd11
generic/hardenedbsd12
generic/netbsd8
generic/openbsd6
generic/opensuse15
generic/opensuse42
generic/oracle8
generic/ubuntu1604
generic/ubuntu1610
generic/ubuntu1704
generic/ubuntu1710
generic/ubuntu1804
generic/ubuntu1810
generic/ubuntu1904
generic/ubuntu1910
generic/ubuntu2004
EOF
}

destroy_all() {
    server_list | parallel -j50% --plus --tag destroy_one {.} 172.27.27.{+.}
}

# No ssh to ip-addr
# generic/devuan1
# generic/devuan2

# Gamle: Centos3, Centos5, OracleXE, Debian7

setup_all() {
    # IP address *.2 and up
    server_list | parallel -j50% --plus --tag setup_one {.} 172.27.27.{+.}
}
