VALAFLAGS += --Xcc=-DGETTEXT_PACKAGE=\"gutter\" --Xcc=-I.

ifndef NODEBUG
	VALAFLAGS += -g
else
	VALAFLAGS += --Xcc=-O3
endif

VALALIBS = --vapidir=/usr/share/vala/vapi --vapidir=. --pkg=x11 \
	--pkg=gdk-2.0 --pkg=gdk-x11-2.0 --pkg=gtk+-2.0 --pkg=pango --pkg=gee-1.0 \
	--pkg=posix --pkg=gio-2.0

modules = main window menu task-list bimap \
	get-window-property x-event-filter-manager status-area \
	clock

gutter: $(modules:%=%.vala) garcon-1.vapi fixes.vapi
	valac $(VALAFLAGS) $(VALALIBS) \
		$(patsubst %.vapi,--pkg=%,$(filter %.vapi,$^)) \
		-o $@ $(filter %.vala,$^)

garcon-1.vapi: garcon-1/garcon-1.gi garcon-1/garcon-1.metadata
	vapigen --library garcon-1 --pkg gio-2.0 garcon-1/garcon-1.gi

garcon-1/garcon-1.gi: garcon-1/garcon-1.files garcon-1/garcon-1.defines garcon-1/garcon-1.namespace
	vala-gen-introspect garcon-1 garcon-1

.PHONY: clean
clean:
	$(RM) gutter
	@echo "To also clean generated .vapi files, do 'make clean-vapi'."

.PHONY: clean-vapi
clean-vapi:
	$(RM) garcon-1.vapi garcon-1/garcon-1.gi
