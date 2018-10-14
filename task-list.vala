namespace Gutter {

protected class WindowButton: Gtk.Bin
    // A button representing a toplevel window on a TaskList
{
    protected Gtk.Widget? _image = null;
    protected Gtk.Label _label = new Gtk.Label(null);
    protected Gtk.Box hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
    protected bool is_popped_out = false;
    protected Gtk.RadioButton button = new Gtk.RadioButton(null);
    protected Gtk.Window? popup = null;
    protected bool popup_saw_enter_event;
        // Whether this.popup has received an enter event since we created it
    
    private X.Window xwindow;
    public X.Window get_xwindow()
        // The toplevel window that is controlled through this widget
    {
        return this.xwindow;
    }
    
    public WindowButton(SList<Gtk.RadioButton>? group, X.Window xwindow) {
        Object();
        this.xwindow = xwindow;
        if (group != null) {
            this.button.set_group(group);
        }
    }
    
    construct {
        this.button["draw-indicator"] = false;
        this.button.relief = Gtk.ReliefStyle.NONE;
        this.button.enter_notify_event.connect(
            this.on_button_enter_notify_event
        );
        this.button.button_release_event.connect(
            this.on_button_button_release_event
        );
        this.button.show();
        this.add(this.button);
        
        this.hbox.show();
        this.button.add(this.hbox);
        
        this._label.ellipsize = Pango.EllipsizeMode.END;
        this._label.xalign = 0.0f;
        this._label.show();
        this.hbox.pack_start(this._label, true, true, 0);
    }
    
    public string? wb_label {
        get { return this._label.label; }
        set { this._label.label = value; }
    }
    
    public Gtk.Widget? wb_image {
        get { return this._image; }
        set {
            if (this._image != null) {
                this.hbox.remove(this._image);
            }
            this._image = value;
            if (this._image != null) {
                this._image.show();
                this.hbox.pack_start(this._image, false, true, 0);
                this.hbox.reorder_child(this._image, 0);
            }
        }
    }
    
    protected bool on_button_enter_notify_event(
        Gtk.Widget widget, Gdk.EventCrossing event
    ) {
        if (!this.is_popped_out) {
            // Figure out how wide our size request would be if this._label were
            // not ellipsized.
            var prev_ellipsize = this._label.ellipsize;
            this._label.ellipsize = Pango.EllipsizeMode.NONE;
            int width;
            this.get_preferred_width(null, out width);
            this._label.ellipsize = prev_ellipsize;
            var monitor =
                this.get_display().get_monitor_at_window(this.get_window());
            var monitor_geom = monitor.get_geometry();
            width = int.min(width, monitor_geom.width/2);
            
            // If we currently have smaller width than we would request without
            // ellipsization (meaning that this._label is probably ellipsized),
            // create a popup to show more of this._label.
            Gtk.Allocation alloc;
            this.get_allocation(out alloc);
            if (width > alloc.width) {
                this.is_popped_out = true;
                this.popup = new Gtk.Window(Gtk.WindowType.POPUP);
                this.popup.add_events(Gdk.EventMask.STRUCTURE_MASK);
                this.popup.set_type_hint(Gdk.WindowTypeHint.POPUP_MENU);
                this.popup.destroy_with_parent = true;
                this.popup.transient_for = this.get_toplevel() as Gtk.Window;
                
                this.remove(this.button);
                this.popup.add(this.button);
                this.popup.set_size_request(width, alloc.height);
                
                // FIXME: Make this work with Gutter on the left side?
                int x = monitor_geom.width - width;
                
                Gtk.Widget toplevel = this.get_toplevel();
                int toplevel_y;
                toplevel.get_window().get_origin(null, out toplevel_y);
                int y_wrt_toplevel;
                bool succ = this.translate_coordinates(
                    toplevel, 0, 0, null, out y_wrt_toplevel
                ); return_val_if_fail(succ, false);
                int y = toplevel_y + y_wrt_toplevel;
                
                this.popup.move(x, y);
                
                this.popup.leave_notify_event.connect((w, e) => {
                    this.hide_popup();
                    return false;
                });
                
                // It is possible that the popup will never get an enter (and
                // therefore a leave) event, since the pointer could have
                // moved on by the time the popup is mapped, or it could pop up
                // in the wrong place.  So, we hide it if it hasn’t received an
                // enter event within about one second.
                this.popup_saw_enter_event = false;
                this.popup.enter_notify_event.connect((w, e) => {
                    this.popup_saw_enter_event = true;
                    return false;
                });
                Timeout.add_seconds(1, () => {
                    if (!this.popup_saw_enter_event) {
                        this.hide_popup();
                    }
                    return false;  // Do not repeat this timeout
                });
                
                this.popup.show();
            }
        }
        return false;
    }
    
    public override void get_preferred_width(
        out int minimum, out int natural
    ) {
        // Request the same size as this.button even when it isn’t our child
        // (because it is in this.popup).
        this.button.get_preferred_width(out minimum, out natural);
    }
    
    public override void get_preferred_height(
        out int minimum, out int natural
    ) {
        // Request the same size as this.button even when it isn’t our child
        // (because it is in this.popup).
        this.button.get_preferred_height(out minimum, out natural);
    }
    
    public override void size_allocate(Gtk.Allocation allocation) {
        base.size_allocate(allocation);
        
        Gtk.Widget? child = this.get_child();
        if (child != null && child.visible) {
            child.size_allocate(allocation);
        }
    }
    
    protected void hide_popup() {
        if (this.is_popped_out) {
            this.is_popped_out = false;
            this.popup.remove(this.button);
            this.add(this.button);
            this.popup.destroy();
            this.popup = null;
        }
    }
    
    protected bool on_button_button_release_event(
        Gtk.Widget widget, Gdk.EventButton event
    ) {
        // FIXME: If you click the button for the parent of a modal dialog, the
        // focus stays on the dialog, but the parent’s button is activated.
        
        assert(this.get_window() != null);
        
        if (event.button != 1) return false;
        
        var msg_ev = X.Event();
        msg_ev.type = X.EventType.ClientMessage;
        msg_ev.xclient.window = this.xwindow;
        msg_ev.xclient.format = 32;
        
        if (button.active) {
            // Iconify the corresponding toplevel window
            
            msg_ev.xclient.message_type =
                Gdk.X11.get_xatom_by_name("WM_CHANGE_STATE");
            msg_ev.xclient.data.l[0] = XFixes.IconicState;
            msg_ev.xclient.data.l[1] = 0;  // Unused
            msg_ev.xclient.data.l[2] = 0;  // Unused
        }
        else {
            // Activate the corresponding toplevel window
            
            msg_ev.xclient.message_type =
                Gdk.X11.get_xatom_by_name("_NET_ACTIVE_WINDOW");
            msg_ev.xclient.data.l[0] = 2;  // Source (this program) is a pager
            msg_ev.xclient.data.l[1] = event.time;  // Timestamp
            msg_ev.xclient.data.l[2] =
                (long)
                ((Gdk.X11.Window)this.get_toplevel().get_window()).get_xid();
        }
        msg_ev.xclient.data.l[3] = 0;  // Unused
        msg_ev.xclient.data.l[4] = 0;  // Unused
        
        var root = this.get_screen().get_root_window();
        var xroot = (root as Gdk.X11.Window).get_xid();
        unowned X.Display xdisplay = 
            ((Gdk.X11.Display)this.get_display()).get_xdisplay();
        var status = XFixes.send_event(
            xdisplay,
            xroot, false,
            X.EventMask.SubstructureNotifyMask
                | X.EventMask.SubstructureRedirectMask,
            msg_ev
        ); warn_if_fail(status != 0);
        
        return false;
    }
    
    // Forwarding stuff to this.button
    
    public bool active {
        get { return this.button.active; }
        set { this.button.active = value; }
    }
    
    public unowned SList<Gtk.RadioButton>? get_group() {
        return this.button.get_group();
    }
}

public class TaskList: Gtk.Box {
    static X.Atom xatom__net_client_list =
        Gdk.X11.get_xatom_by_name("_NET_CLIENT_LIST");
    static X.Atom xatom__net_active_window =
        Gdk.X11.get_xatom_by_name("_NET_ACTIVE_WINDOW");
    
    protected Bimap<X.Window?, unowned WindowButton> xwindow_to_button =
        new Bimap<X.Window?, unowned WindowButton> (
            (wa, wb) => { return *(X.Window*)wa == *(X.Window*)wb; },
            (ba, bb) => { return ba == bb; }
        );
    
    public TaskList() {
        Object(orientation: Gtk.Orientation.VERTICAL, homogeneous: true);
    }
    
    construct {
        this.on_client_list_changed();
    }
    
    public override void realize() {
        base.realize();
        
        Gdk.Window root = this.get_screen().get_root_window();
        root.set_events(root.get_events() | Gdk.EventMask.PROPERTY_CHANGE_MASK);
        root.add_filter(this.filter_root_window_xevent);
            // Apparently it is impossible to use a real closure for this,
            // but if you just need to reference ‘this’ it’s OK.
    }
    
    public override void unrealize() {
        Gdk.Window root = this.get_screen().get_root_window();
        root.remove_filter(this.filter_root_window_xevent);
        
        base.unrealize();
    }
    
    private Gdk.FilterReturn filter_root_window_xevent(
        Gdk.XEvent xev_gdk, Gdk.Event ev
    ) {
        var xev = (X.Event*) xev_gdk;
        
        var xroot = Gdk.X11.get_default_root_xwindow();
        if (
            xev.type == X.EventType.PropertyNotify
            && xev.xproperty.window == xroot
        ) {
            if (xev.xproperty.atom == xatom__net_client_list) {
                this.on_client_list_changed();
            }
            else if (xev.xproperty.atom == xatom__net_active_window) {
                this.on_active_window_changed();
            }
        }
        return Gdk.FilterReturn.CONTINUE;
    }
    
    protected void on_client_list_changed() {
        unowned X.Display xdisplay = Gdk.X11.get_default_xdisplay();
        X.Window xroot = Gdk.X11.get_default_root_xwindow();
        XArray32 windows;
        switch (
            get_window_property32(
                xdisplay,
                xroot,
                xatom__net_client_list,
                false,
                X.XA_WINDOW,
                out windows
            )
        ) {
        case GetWindowPropertyResult.BAD_WINDOW:
            warning("Root window is invalid?");
            break;
        case GetWindowPropertyResult.FAILURE:
            warning(_(
                "Couldn't retrieve window list; "
                +"possibly window manager is not WM Spec 1.3 compliant, "
                +"or there is no window manager."
            ));
            break;
        case GetWindowPropertyResult.SUCCESS:
            int final_icon_w, final_icon_h;
            Gtk.icon_size_lookup(
                Gtk.IconSize.BUTTON, out final_icon_w, out final_icon_h
            );
            WindowButton? button = null;
            foreach (var window_ulong in windows) {
                X.Window window = (X.Window) window_ulong;
                
                XArray32 state;
                if (
                    get_window_property32(
                        xdisplay,
                        window,
                        Gdk.X11.get_xatom_by_name("_NET_WM_STATE"),
                        false,
                        X.XA_ATOM,
                        out state
                    ) == GetWindowPropertyResult.SUCCESS
                    &&
                    Gdk.X11.get_xatom_by_name("_NET_WM_STATE_SKIP_TASKBAR")
                        in state
                ) {
                    continue;
                }
                
                WindowButton? existing_button =
                    this.xwindow_to_button.lookup(window);
                if (existing_button != null) {
                    button = button ?? existing_button;
                    continue;
                }
                
                var display = Gdk.X11.Display.lookup_for_xdisplay(xdisplay);
                // TODO: Check whether ‘display’ is null
                var window_gdk =
                    new Gdk.X11.Window.foreign_for_display(display, window);
                window_gdk.set_events(
                    window_gdk.get_events() | Gdk.EventMask.PROPERTY_CHANGE_MASK
                );
                XEventFilterManager.add(
                    window_gdk,
                    X.EventType.PropertyNotify,
                    this,
                    this.on_window_property_change
                );
                
                button = new WindowButton(
                    button != null ? button.get_group() : null, window
                );
                this.xwindow_to_button.insert(window, button);
                this.update_window_button_label(xdisplay, window);
                
                XArray32 icon_data;
                if (
                    get_window_property32(
                        xdisplay,
                        window,
                        Gdk.X11.get_xatom_by_name("_NET_WM_ICON"),
                        false,
                        X.XA_CARDINAL,
                        out icon_data
                    ) == GetWindowPropertyResult.SUCCESS
                    && icon_data.length > 0
                ) {
                    ulong icon_index = 0;
                    ulong i = 0;
                    while (i+1 < icon_data.length) {
                        if (icon_data[i] > icon_data[icon_index]) {
                            icon_index = i;
                        }
                        i += icon_data[i] * icon_data[i+1] + 2;
                    }
                    ulong icon_w = icon_data[icon_index];
                    ulong icon_h = icon_data[icon_index];
                    if (icon_index + icon_w*icon_h <= icon_data.length) {
                        uchar *icon_pix = malloc(4*icon_w*icon_h*sizeof(uchar));
                        for (
                            size_t pix_index = 0;
                            pix_index < icon_w*icon_h;
                            pix_index++
                        ) {
                            ulong pix = icon_data[icon_index+pix_index];
                            icon_pix[4*pix_index] =
                                (uchar) ((pix & 0x00ff0000UL) >> 16);
                            icon_pix[4*pix_index+1] =
                                (uchar) ((pix & 0x0000ff00UL) >> 8);
                            icon_pix[4*pix_index+2] =
                                (uchar) (pix & 0x000000ffUL);
                            icon_pix[4*pix_index+3] =
                                (uchar) ((pix & 0xff000000UL) >> 24);
                        }
                        var pixbuf = new Gdk.Pixbuf.from_data(
                            (uchar[]) icon_pix,
                            Gdk.Colorspace.RGB,
                            true,
                            8,
                            (int) icon_w, (int) icon_h,
                            4 * (int) icon_w,
                            GLib.free
                        );
                        button.wb_image = new Gtk.Image.from_pixbuf(
                            pixbuf.scale_simple(
                                final_icon_w, final_icon_h,
                                Gdk.InterpType.BILINEAR
                            )
                        );
                    }
                    else {
                        warning(
                            "Incomplete icon (size %lux%lu) in _NET_WM_ICON",
                            icon_w, icon_h
                        );
                    }
                }
                
                button.show();
                this.pack_start(button, false, true, 0);
            }
            // Remove buttons for nonexistent windows
            var dead_xwindows = new SList<X.Window?> ();
            foreach (var xwindow in this.xwindow_to_button) {
                bool found = false;
                foreach (var other in windows) {
                    if (xwindow == (X.Window)other) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    dead_xwindows.append(xwindow);
                }
            }
            foreach (var xwindow in dead_xwindows) {
                WindowButton? dead_button =
                    this.xwindow_to_button.lookup(xwindow);
                if (dead_button != null) {
                    this.xwindow_to_button.remove(xwindow);
                    this.remove(dead_button);
                }
                else warn_if_reached();
            }
            break;
        }
    }
    
    protected void on_active_window_changed() {
        XArray32 xwindow_arr;
        if (
            get_window_property32(
                Gdk.X11.get_default_xdisplay(),
                Gdk.X11.get_default_root_xwindow(),
                xatom__net_active_window,
                false,
                X.XA_WINDOW,
                out xwindow_arr
            ) == GetWindowPropertyResult.SUCCESS
            && xwindow_arr.length > 0
        ) {
            var xwindow = (X.Window) xwindow_arr[0];
            WindowButton? button = this.xwindow_to_button.lookup(xwindow);
            if (button != null) {
                button.active = true;
            }
        }
    }
    
    protected bool on_window_property_change(X.Event xevent)
        requires (xevent.type == X.EventType.PropertyNotify)
    {
        if (
            xevent.xproperty.atom
                == Gdk.X11.get_xatom_by_name("_NET_WM_VISIBLE_NAME")
            ||
            xevent.xproperty.atom == Gdk.X11.get_xatom_by_name("_NET_WM_NAME")
            ||
            xevent.xproperty.atom == X.XA_WM_NAME
        ) {
            // FIXME: sometimes we get property change events when a window is
            // destroyed, and then update_window_button_label causes a BadWindow
            // error when trying to retrieve the new value of the property.
            // Possibly fixed.
            this.update_window_button_label(
                xevent.xproperty.display, xevent.xproperty.window
            );
        }
        return false;
    }
    
    protected void update_window_button_label(
        X.Display xdisplay, X.Window xwindow
    ) {
        WindowButton? button = this.xwindow_to_button.lookup(xwindow);
        return_if_fail(button != null);
        
        X.Atom xatom_utf8_string = Gdk.X11.get_xatom_by_name("UTF8_STRING");
        X.Atom props[6] = {
            Gdk.X11.get_xatom_by_name("_NET_WM_VISIBLE_NAME"),
                xatom_utf8_string,
            Gdk.X11.get_xatom_by_name("_NET_WM_NAME"), xatom_utf8_string,
            X.XA_WM_NAME, Gdk.X11.get_xatom_by_name("STRING")
        };
        
        XArray8 name_arr;
        unowned string? name = null;
        for (size_t i = 0; i < props.length; i += 2) {
            GetWindowPropertyResult gwp_res;
            gwp_res = get_window_property8(
                xdisplay,
                xwindow,
                props[i],
                false,
                props[i+1],
                out name_arr
            );
            if (gwp_res == GetWindowPropertyResult.BAD_WINDOW) return;
            if (gwp_res == GetWindowPropertyResult.SUCCESS) {
                name = name_arr.to_string();
                break;
            }
        }
        
        button.wb_label = name ?? "Window 0x%lx".printf(xwindow);
    }
}

}  // end namespace Gutter
