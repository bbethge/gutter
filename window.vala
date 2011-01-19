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
        
        var vbox = new Gtk.VBox(false, 5);  // TODO: remove hard-coded size
        vbox.show();
        this.add(vbox);
        
        var menu = new Menu();
        menu.show();
        vbox.pack_start(menu, false, false, 0);
        
        var task_list = new Gutter.TaskList();
        task_list.show();
        vbox.pack_start(task_list, true, true, 0);
        
        var stat_area_align = new Gtk.Alignment(0.5f, 0.0f, 0.0f, 0.0f);
        stat_area_align.show();
        vbox.pack_start(stat_area_align, false, false, 0);
        
        var stat_area = new Gutter.StatusArea(0);
        stat_area.show();
        stat_area_align.add(stat_area);
        
        var monitor_align = new Gtk.Alignment(0.5f, 0.0f, 0.0f, 0.0f);
        monitor_align.show();
        vbox.pack_start(monitor_align, false, false, 0);
        
        var monitor = new Monitor();
        monitor.show();
        monitor_align.add(monitor);
        
        var hbox = new Gtk.HBox(false, 0);
        hbox.show();
        vbox.pack_end(hbox, false, true, 0);
        
        var clock = new Clock();
        clock.show();
        hbox.pack_start(clock, true, true, 0);
        
        var quit = new Gtk.Button();
        quit.xalign = 0.5f;
        quit.yalign = 0.5f;
        quit.relief = Gtk.ReliefStyle.NONE;
        quit.add(new Gtk.Image.from_stock(
            Gtk.STOCK_QUIT, Gtk.IconSize.LARGE_TOOLBAR
        ));
        quit.show_all();
        quit.clicked.connect((b) => this.hide());
        hbox.pack_end(quit, false, false, 0);
    }
    
    // Since we set a hard-coded default size, I don’t think it makes much
    // difference whether we override size_request to request the extra width
    // from the side shadow.
    
    public override void size_allocate(Gdk.Rectangle allocation)
        // The Vala bindings think the argument to this function is a
        // Gdk.Rectangle, but it really should be a Gtk.Allocation.  We can
        // probably ignore this since the two structures are identical.
    {
        base.size_allocate(allocation);
        
        Gtk.Widget? child = this.get_child();
        if (child != null && child.visible) {
            var child_alloc = Gdk.Rectangle();
            child_alloc.x = this.side == Side.RIGHT ? this.style.xthickness : 0;
            child_alloc.y = 0;
            child_alloc.width = allocation.width - this.style.xthickness;
            child_alloc.height = allocation.height;
            child.size_allocate(child_alloc);
        }
    }
    
    public override void realize() {
        base.realize();
        
        Gdk.Screen screen = this.get_screen();
        
        var geom = Gdk.Geometry();
        geom.min_width = (int)this.width;
        geom.max_width = (int)this.width;
        geom.min_height = screen.get_height();
        geom.max_height = geom.min_height;
        this.set_geometry_hints(
            this, geom, Gdk.WindowHints.MIN_SIZE | Gdk.WindowHints.MAX_SIZE
        );
        
        if (this.side == Side.RIGHT) {
            this.move(screen.get_width() - (int)this.width, 0);
        }
        else {
            this.move(0, 0);
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
            this.window,
            Gdk.Atom.intern("_NET_WM_STRUT_PARTIAL", false),
            atom_cardinal, 32,
            Gdk.PropMode.REPLACE,
            (uchar[])strut_vals, 12
        );
        Gdk.property_change(
            this.window,
            Gdk.Atom.intern("_NET_WM_STRUT", false),
            atom_cardinal, 32,
            Gdk.PropMode.REPLACE,
            (uchar[])strut_vals, 4
        );
        
        return result;
    }
    
    public override bool expose_event(Gdk.EventExpose event) {
        Gtk.Allocation allocation;
        this.get_allocation(out allocation);
        
        var clip = Gdk.Rectangle();
        clip.x = allocation.x; clip.y = allocation.y;
        clip.width = allocation.width; clip.height = allocation.height;
        
        Gtk.paint_shadow(
            this.style,
            this.get_window(),
            this.get_state(),
            Gtk.ShadowType.OUT,
            clip,
            this,
            "panel",
            this.side == Side.RIGHT ? 0 : -allocation.width, -allocation.height,
            2*allocation.width, 3*allocation.height
        );
        
        return base.expose_event(event);
    }
}

} // end namespace Gutter
