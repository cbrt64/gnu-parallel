# Minimal makefile for Sphinx documentation
#
# SPDX-FileCopyrightText: 2002-2021 Ole Tange, http://ole.tange.dk and Free Software and Foundation, Inc.
#
# SPDX-License-Identifier: GPL-3.0-or-later

# You can set these variables from the command line.
SPHINXOPTS    =
SPHINXBUILD   = sphinx-build
SOURCEDIR     = source
BUILDDIR      = build

all: copy
	make html

copy:
	cp -a ../*.rst source/

# Put it first so that "make" without argument is like "make help".
help:
	@$(SPHINXBUILD) -M help "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)

.PHONY: help Makefile

# Catch-all target: route all unknown targets to Sphinx using the new
# "make mode" option.  $(O) is meant as a shortcut for $(SPHINXOPTS).
%: Makefile
	@$(SPHINXBUILD) -M $@ "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)

clean:
	rm -rf "$(BUILDDIR)"
	cp "$(SOURCEDIR)"/sphinx.rst "$(SOURCEDIR)"/sphinx.rst.bak
	rm "$(SOURCEDIR)"/*.rst
	cp "$(SOURCEDIR)"/sphinx.rst.bak "$(SOURCEDIR)"/sphinx.rst
