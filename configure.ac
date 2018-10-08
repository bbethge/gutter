# Process this file with autoconf to produce a configure script.

AC_INIT([Gutter], 0.1)
AM_INIT_AUTOMAKE
AC_CONFIG_SRCDIR([main.vala])
AC_PROG_CC
AM_PROG_VALAC
AC_ARG_VAR([VALAFLAGS], [Additional flags to pass to the Vala compiler])
PKG_CHECK_MODULES([GLIB], [glib-2.0])
PKG_CHECK_MODULES([GIO], [gio-2.0 gio-unix-2.0])
PKG_CHECK_MODULES([GDK], [gdk-2.0 gdk-x11-2.0])
PKG_CHECK_MODULES([GTK], [gtk+-2.0])
PKG_CHECK_MODULES([PANGO], [pango])
PKG_CHECK_MODULES([GARCON], [garcon-1])
PKG_CHECK_MODULES([X11], [x11])
PKG_CHECK_MODULES([GEE], [gee-0.8])
AC_CONFIG_FILES([Makefile])
AC_OUTPUT
