VALAFLAGS = --Xcc=-DGETTEXT_PACKAGE=\"gutter\"

ifndef NODEBUG
	VALAFLAGS += -g
endif

VALALIBS = --vapidir=/usr/share/vala/vapi --vapidir=. --pkg=fixes --pkg=x11 \
	--pkg=gdk-2.0 --pkg=gdk-x11-2.0 --pkg=gtk+-2.0 --pkg=pango --pkg=gee-1.0

gutter: gutter.c
	valac $(VALAFLAGS) $(VALALIBS) $^

%.c: %.vala
	valac -C $(VALAFLAGS) $(VALALIBS) $^
