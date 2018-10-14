namespace Gutter {

public class Window: Gtk.Window {
    protected ulong width = 150;
    
    public enum Side {
        LEFT,
        RIGHT
    }
    protected Side side = Side.RIGHT;
    
    public Window() {
        Object(type: Gtk.WindowType.TOPLEVEL, app_paintable: true);
    }
    
    construct {
        this.title = _("Gutter");
        this.gravity =
            this.side == Side.RIGHT
            ? Gdk.Gravity.NORTH_EAST : Gdk.Gravity.NORTH_WEST;
        this.type_hint = Gdk.WindowTypeHint.DOCK;
        this.skip_taskbar_hint = true;
        this.skip_pager_hint = true;
        
        // TODO: remove hard-coded size
        var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 5);
        var vbox_css_provider = new Gtk.CssProvider();
        vbox_css_provider.parsing_error.connect((p, s, e) => {
            warning("Error in hard-coded CSS: %s", e.message);
        });
        try {
            vbox_css_provider.load_from_data(
                  "box {"
                +@"    margin-$(this.side == Side.RIGHT ? "left" : "right"):"
                + "        1px;"
                + "}"
            );
        }
        catch (Error e) {
            warning("Unexpected error while parsing CSS: %s", e.message);
        }
        vbox.get_style_context().add_provider(
            vbox_css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
        vbox.show();
        this.add(vbox);
        
        var menu = new Menu();
        menu.show();
        vbox.pack_start(menu, false, false, 0);
        
        var task_list = new Gutter.TaskList();
        task_list.show();
        vbox.pack_start(task_list, true, true, 0);
        
        // FIXME: Status area is not shown
        var stat_area = new Gutter.StatusArea(0);
        stat_area.halign = Gtk.Align.CENTER;
        stat_area.show();
        vbox.pack_start(stat_area, false, false, 0);
        
        var monitor = new Monitor();
        monitor.halign = Gtk.Align.CENTER;
        monitor.show();
        vbox.pack_start(monitor, false, false, 0);
        
        var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        hbox.show();
        vbox.pack_end(hbox, false, true, 0);
        
        var clock = new Clock();
        clock.show();
        hbox.pack_start(clock, true, true, 0);
        
        var quit = new Gtk.Button();
        quit.halign = Gtk.Align.CENTER;
        quit.valign = Gtk.Align.CENTER;
        quit.relief = Gtk.ReliefStyle.NONE;
        quit.add(new Gtk.Image.from_icon_name(
            "gtk-quit", Gtk.IconSize.LARGE_TOOLBAR
        ));
        quit.show_all();
        quit.clicked.connect((b) => this.hide());
        hbox.pack_end(quit, false, false, 0);
    }
    
    public override void realize() {
        base.realize();
        
        var window = this.get_window();
        return_if_fail(window != null);
        var monitor = this.get_display().get_monitor_at_window(window);
        var monitor_geom = monitor.get_geometry();
        
        var geom = Gdk.Geometry();
        geom.min_width = (int)this.width;
        geom.max_width = (int)this.width;
        geom.min_height = monitor_geom.height;
        geom.max_height = monitor_geom.height;
        this.set_geometry_hints(
            this, geom, Gdk.WindowHints.MIN_SIZE | Gdk.WindowHints.MAX_SIZE
        );
        
        if (this.side == Side.RIGHT) {
            this.move(
                monitor_geom.x + monitor_geom.width - (int)this.width,
                monitor_geom.y
            );
        }
        else {
            this.move(monitor_geom.x, monitor_geom.y);
        }
    }
    
    public override bool configure_event(Gdk.EventConfigure event) {
        bool result = base.configure_event(event);
        
        var atom_cardinal = Gdk.Atom.intern("CARDINAL", false);
        ulong strut_vals[12] = { 0 };
        strut_vals[this.side == Side.RIGHT ? 1 : 0] = event.width;
        strut_vals[this.side == Side.RIGHT ? 6 : 4] = event.y;
        strut_vals[this.side == Side.RIGHT ? 7 : 5] = event.y + event.height-1;
        Gdk.property_change(
            this.get_window(),
            Gdk.Atom.intern("_NET_WM_STRUT_PARTIAL", false),
            atom_cardinal, 32,
            Gdk.PropMode.REPLACE,
            (uchar[])strut_vals, 12
        );
        Gdk.property_change(
            this.get_window(),
            Gdk.Atom.intern("_NET_WM_STRUT", false),
            atom_cardinal, 32,
            Gdk.PropMode.REPLACE,
            (uchar[])strut_vals, 4
        );
        
        return result;
    }
    
    public override bool draw(Cairo.Context cr) {
        int width = this.get_allocated_width();
        int height = this.get_allocated_height();
        var style = this.get_style_context();
        
        style.render_background(cr, 0, 0, width, height);
        style.render_frame(cr, 0, 0, width, height);
        
        return base.draw(cr);
    }
}

} // end namespace Gutter
