all:
	perl -e 'exit $$ENV{YYYYMMDD} !~ /20/' 
	cd ../debian/ && make
	osc rm home-tange/parallel/parallel_*.dsc || true
	cp ../debian/parallel_*.dsc ../debian/parallel_*.tar.gz home-tange/parallel/
	cp `ls ../../parallel-2*.tar.bz2|grep -v latest|tail -n1` home-tange/parallel/
	perl -i -pe '/Version:/ and s/20\d\d\d\d\d\d/$$ENV{YYYYMMDD}/g' home-tange/parallel/parallel.spec
	# Update sha256sum
	cd home-tange/parallel && s=`sha256sum parallel-*.tar.bz2|field 1` perl -i -pe 's/(sha256sums=..)\w+(..)/$$1$$ENV{s}$$2/' PKGBUILD
	# Update version
	cd home-tange/parallel && perl -i -pe 's/pkgver=.*/pkgver=$$ENV{YYYYMMDD}/' PKGBUILD
	cd home-tange/parallel/ && osc diff
	cd home-tange/parallel/ && osc up
	cd home-tange/parallel/ && parallel osc add ::: *.spec *.dsc *.tar.gz *.tar.bz2 && echo Src added OK || true
	cd home-tange/parallel/ && osc ci -m "New release"
	### Wait for "building" state to complete
	echo '### Wait for "building" state'
	cd home-tange/parallel/ && yes building | parallel -vj1 --delay 10 --halt now,success=1 'osc results|G -E {}'
	echo '### Wait for "building" state to end'
	echo '### Ignore RedHat_RHEL-6 and Univention_3.2 that are broken'
	cd home-tange/parallel/ && yes building | parallel -vj1 --delay 10 --halt now,fail=1 'osc results|G -v RedHat_RHEL-6 -v Univention_3.2 -E {}' || true
	echo '### Wait for "finished" state of .deb'
	cd home-tange/parallel/ && echo succeeded | parallel -vj1 --retries 30 --delay 10 --halt now,success=1 'osc results|G -E "(Debian|Ubuntu).*{}"'
	echo '### Wait for "finished" state of .rpm'
	cd home-tange/parallel/ && echo succeeded | parallel -vj1 --retries 30 --delay 10 --halt now,success=1 'osc results|G -E "(SUSE|SLE|Scientific|RHEL|Fedora|CentOS).*{}"'

