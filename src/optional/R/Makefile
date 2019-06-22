all:
	# Install plyr if not installed
	Rscript -e 'usePackage <- function(p) { if (!is.element(p, installed.packages()[,1])) { install.packages(p, dep = TRUE) }; require(p, character.only = TRUE) }; usePackage("plyr");'
	# Install data.table if not installed
	Rscript -e 'usePackage <- function(p) { if (!is.element(p, installed.packages()[,1])) { install.packages(p, dep = TRUE) }; require(p, character.only = TRUE) }; usePackage("data.table");'
	cd gnuparallel && md5sum DESCRIPTION NAMESPACE R/gnuparallel.R man/gnuparallel-package.Rd > MD5
	R CMD check --as-cran gnuparallel
	R CMD build gnuparallel
	R CMD INSTALL --build gnuparallel_0.1.tar.gz
	R CMD check gnuparallel
labeling:
	R CMD build labeling
	R CMD INSTALL --build labeling_0.2.tar.gz
	R CMD check labeling

