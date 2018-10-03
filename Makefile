vala_bindir = $(if $(VALA_BINDIR),$(abspath $(VALA_BINDIR))/)
VALAC = $(vala_bindir)valac
VAPIGEN = $(vala_bindir)vapigen
VALA_GEN_INTROSPECT = $(vala_bindir)vala-gen-introspect
VALACFLAGS = --debug
CFLAGS = -g

valac_flags = --vapidir=. $(addprefix --vapidir=,$(VAPIDIRS))
cc_flags = -DGETTEXT_PACKAGE=\"gutter\" -I.

main_deps = window gtk+-2.0
window_deps = menu task-list status-area monitor clock gdk-2.0 gtk+-2.0
menu_deps = garcon-1 gdk-2.0 gtk+-2.0
task_list_deps = bimap get-window-property x-event-filter-manager \
	fixes x11 gdk-2.0 gdk-x11-2.0 gtk+-2.0
get_window_property_deps = fixes x11 gdk-2.0 gdk-x11-2.0
x_event_filter_manager_deps = gee-0.8 x11 gdk-2.0 gdk-x11-2.0
status_area_deps = fixes x11 gdk-2.0 gdk-x11-2.0 gtk+-2.0
monitor_deps = posix gdk-2.0 gtk+-2.0
clock_deps = pango gtk+-2.0

expand_deps =                                              \
	$(sort                                                 \
		$(foreach mod,$($(subst -,_,$(1))_deps),           \
			$(mod) $(call expand_deps,$(subst -,_,$(mod))) \
		)                                                  \
	)

modules := \
	$(filter main $(call expand_deps,main),$(basename $(wildcard *.vala)))
packages := $(filter-out $(modules),$(call expand_deps,main))
libraries := $(filter $(shell pkg-config --list-all),$(packages))
local_packages = fixes

all: gutter

gutter: $(modules:%=%.o)
	$(CC) -o gutter $(modules:%=%.o) $(LDFLAGS) \
		$(shell pkg-config --libs $(libraries)) -lm

define module_rules =
$(subst -,_,$(1))_full_deps := $$(call expand_deps,$(1))
$(subst -,_,$(1))_mods := $$(filter $$(modules),$$($(subst -,_,$(1))_full_deps))
$(subst -,_,$(1))_pkgs := \
	$$(filter-out $(modules),$$($(subst -,_,$(1))_full_deps))
$(subst -,_,$(1))_libs := glib-2.0 gobject-2.0 \
	$$(filter $$($(subst -,_,$(1))_pkgs),$$(libraries))

$(1).c $(1).h $(1).vapi: $(1).vala \
		$$(addsuffix .vapi,$$($(subst -,_,$(1))_mods) $$(filter $$(local_packages),$$($(subst -,_,$(1))_pkgs)))
	$$(VALAC) -C -o $(1).c -H $(1).h --vapi=$(1).vapi $$(valac_flags) \
		$$(addprefix --pkg=,$$($(subst -,_,$(1))_mods) $$($(subst -,_,$(1))_pkgs)) $$(VALACFLAGS) \
		$(1).vala
	touch $(1).c $(1).h $(1).vapi

$(1).o: $(1).c $(1).h $$($(subst -,_,$(1))_mods:%=%.h)
	$$(CC) -c -o $(1).o $$(cc_flags) \
		$$(if $$(strip $$($(subst -,_,$(1))_libs)),$$(shell pkg-config --cflags $$($(subst -,_,$(1))_libs))) \
		$$(CPPFLAGS) $$(CFLAGS) $(1).c

endef

$(foreach mod,$(modules),$(eval $(call module_rules,$(mod))))

.PHONY: clean
clean:
	$(RM) gutter $(modules:%=%.c) $(modules:%=%.h) $(modules:%=%.vapi) \
		$(modules:%=%.o)

.PHONY: help
help:
	@echo "Useful variables:"
	@echo "    VAPIDIRS     Non-standard directories where .vapi files are installed"
	@echo "                 (probably needed for garcon-1.vapi)"
	@echo "    VALA_BINDIR  Directory where Vala tools are installed"
	@echo "    VALAC        Alternate Vala compiler to use (overrides VALA_BINDIR)"
	@echo "    VALACFLAGS   Extra flags to pass to the Vala compiler (default --debug)"
	@echo "    CC           Alternate C compiler to use"
	@echo "    CPPFLAGS     Extra flags to pass to the C preprocessor"
	@echo "    CFLAGS       Extra flags to pass to the C compiler (default -g)"
	@echo "    LDFLAGS      Extra flags to pass to the linker"
	@echo "    VAPIGEN      Alternate 'vapigen' to use (overrides VALA_BINDIR)"
	@echo "    VALA_GEN_INTROSPECT"
	@echo "                 Alternate 'vala-gen-introspect' to use (overrides VALA_BINDIR)"
	@echo
	@echo "Special targets:"
	@echo "    all         Compile everything (i.e., just 'gutter')"
	@echo "    clean       Remove generated files"
	@echo "    help        Show this help"
	@echo
