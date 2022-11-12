AC_INIT([parallel],[20230122],[bug-parallel@gnu.org])

# on MSys2 prefer msys to native programs, especially perl
# native windows perl does not work for the time being
case "`uname -s`" in
    MSYS*|MINGW*)
	PATH="/usr/bin:$PATH"
	export PATH
	;;
esac

AX_SYS_PERLSHARPBANG

AM_INIT_AUTOMAKE([-Wall -Werror foreign])
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_FILES([
  Makefile
  src/Makefile
])

AC_ARG_ENABLE(documentation,
  AS_HELP_STRING([--disable-documentation],[Omit building and installing the documentation. (default=no)]),,
		 [enable_documentation=yes])
AM_CONDITIONAL([DOCUMENTATION], [test x$enable_documentation = xyes])
AC_PROG_LN_S
AC_OUTPUT
