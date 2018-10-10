NULL =

AM_CPPFLAGS = -DGETTEXT_PACKAGE='"gutter"'

AM_CFLAGS = \
    $(GLIB_CFLAGS) \
    $(GIO_LIBS) \
    $(GDK_CFLAGS) \
    $(GTK_CFLAGS) \
    $(CAIRO_CFLAGS) \
    $(PANGO_CFLAGS) \
    $(GARCON_CFLAGS) \
    $(X11_CFLAGS) \
    $(GEE_CFLAGS) \
    $(NULL)

AM_VALAFLAGS = \
    --vapidir=$(top_srcdir) \
    --pkg=posix \
    --pkg=gdk-3.0 \
    --pkg=gdk-x11-3.0 \
    --pkg=gio-2.0 \
    --pkg=gio-unix-2.0 \
    --pkg=gtk+-3.0 \
    --pkg=cairo \
    --pkg=pango \
    --pkg=garcon-1 \
    --pkg=x11 \
    --pkg=gee-0.8 \
    $(NULL)

bin_PROGRAMS = gutter
gutter_SOURCES = \
    bimap.vala \
    clock.vala \
    get-window-property.vala \
    main.vala \
    menu.vala \
    monitor.vala \
    status-area.vala \
    task-list.vala \
    window.vala \
    x-event-filter-manager.vala \
    fixes.h \
    fixes.vapi \
    $(NULL)

gutter_LDADD = \
    -lm \
    $(GLIB_LIBS) \
    $(GIO_LIBS) \
    $(GDK_LIBS) \
    $(GTK_LIBS) \
    $(CAIRO_LIBS) \
    $(PANGO_LIBS) \
    $(GARCON_LIBS) \
    $(X11_LIBS) \
    $(GEE_LIBS) \
    $(NULL)
