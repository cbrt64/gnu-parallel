#!/bin/bash

# SPDX-FileCopyrightText: 2021 Ole Tange, http://ole.tange.dk and Free Software and Foundation, Inc.
#
# SPDX-License-Identifier: GPL-3.0-or-later

mysqlrootpass=${mysqlrootpass:-M-b+Ydjq4ejT4E}
MYSQL_ADMIN_DBURL=mysql://root:$mysqlrootpass@/mysql

# Setup
sql $MYSQL_ADMIN_DBURL "drop user 'sqlunittest'@'localhost'"
sql $MYSQL_ADMIN_DBURL DROP DATABASE sqlunittest;
sql $MYSQL_ADMIN_DBURL CREATE DATABASE sqlunittest;
sql $MYSQL_ADMIN_DBURL "CREATE USER 'sqlunittest'@'localhost' IDENTIFIED BY 'CB5A1FFFA5A';"
sql $MYSQL_ADMIN_DBURL "GRANT ALL PRIVILEGES ON sqlunittest.* TO 'sqlunittest'@'localhost';"

MYSQL_TEST_DBURL=mysql://sqlunittest:CB5A1FFFA5A@/sqlunittest
export MYSQL_TEST_DBURL
export MYSQL_ADMIN_DBURL

uniqify() {
    file=$1
    perl -ne '$seen{$_}++ || print' "$file" > "$file".$$
    chmod 600 "$file".$$
    mv "$file".$$ "$file"
}
export -f uniqify

par_sql_from_url() {
    echo '### Test reading sql from url command line'
    echo |
	sql "$MYSQL_TEST_DBURL/?SELECT 'Yes it works' as 'Test reading SQL from command line';"

    echo '### Test reading sql from url command line %-quoting'
    echo |
	sql "$MYSQL_TEST_DBURL/?SELECT 'Yes it%20works' as 'Test%20%-quoting%20SQL from command line';"

    echo "### Test .sql/aliases with url on commandline"
    echo :sqlunittest mysql://sqlunittest:CB5A1FFFA5A@localhost:3306/sqlunittest >> ~/.sql/aliases
    uniqify ~/.sql/aliases
    echo |
	sql ":sqlunittest?SELECT 'Yes it%20works' as 'Test if .sql/aliases with %-quoting works';"
}

par_test_cyclic() {
    echo "### Test cyclic alias .sql/aliases"
    echo :cyclic :cyclic2 >> ~/.sql/aliases
    echo :cyclic2 :cyclic3 >> ~/.sql/aliases
    echo :cyclic3 :cyclic >> ~/.sql/aliases
    uniqify ~/.sql/aliases
    stdout sql ":cyclic3?SELECT 'NO IT DID NOT' as 'Test if :cyclic is found works';"
}

par_test_alias_with_statement() {
    echo "### Test alias with statement .sql/aliases"
    echo ":testselect sqlite:///%2Ftmp%2Ffile.sqlite?SELECT 'It works' AS 'Test statement in alias';" >> ~/.sql/aliases
    uniqify ~/.sql/aliases
    echo | stdout sql :testselect
    echo ":testselectmysql mysql://sqlunittest:CB5A1FFFA5A@localhost:3306/sqlunittest?SELECT 'It works' AS 'Test statement in alias';" >> ~/.sql/aliases
    uniqify ~/.sql/aliases
    echo | stdout sql :testselect
    echo | stdout sql :testselectmysql

    echo "### Test alias followed by SQL as arg"
    echo ignored | stdout sql :testselect "select 'Arg on cmdline';"

    echo "### Test alias with query followed by SQL as arg"
    echo ignored | stdout sql :testselect" select 'Query added to alias';" "select 'Arg on cmdline';"

    echo "### Test alias with statement .sql/aliases"
    echo "select 'Query from stdin';" | sql :testselect" select 'Query added to alias';"
    echo "select 'Query from stdin';" | sql :testselectmysql" select 'Query added to alias';"
}

par_test_empty_dburl() {
    echo "### Test empty dburl"
    stdout sql ''
}

par_test_dburl_colon() {
    echo "### Test dburl :"
    stdout sql ':'
}

par_multiarg_on_command_line() {
    echo "### Test oracle with multiple arguments on the command line"
    echo ":oraunittest oracle://hr:hr@oracle11.tange.dk/xe" >> ~/.sql/aliases
    uniqify ~/.sql/aliases
    sql :oraunittest "WHENEVER SQLERROR EXIT FAILURE" "SELECT 'arg2' FROM DUAL;" "SELECT 'arg3' FROM DUAL;"
}

par_newline_on_commandline() {
    echo "### Test oracle with \n arguments on the command line"
    sql :oraunittest 'select 1 from dual;\nselect 2 from dual;\x0aselect 3 from dual;'
}

par_showtables() {
    echo "### Test --show-tables"
    sql --show-tables :oraunittest | LC_ALL=C sort
}

par_showdatabases() {
    echo "### Test --show-databases"
    sql --show-databases :oraunittest
}

par_listproc() {
    echo "### Test --listproc"
    sql --listproc :oraunittest
    sql --listproc $MYSQL_TEST_DBURL |
	perl -pe 's/^\d+/XXX/'
}

export -f $(compgen -A function | grep par_)
compgen -A function | grep par_ | sort |
    parallel -j0 --tag -k --joblog +/tmp/jl-`basename $0` '{} 2>&1'
