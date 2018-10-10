namespace Gutter {

public class StatusArea: Gtk.Box {
    protected Gdk.Window? manager_window = null;
    public uint32 timestamp;
    
    public StatusArea(uint32 time = 0) {
        Object(orientation: Gtk.Orientation.HORIZONTAL, homogeneous: false);
        this.timestamp = time;
    }
    
    construct {
        int icon_w, icon_h;
        Gtk.icon_size_lookup(
            Gtk.IconSize.LARGE_TOOLBAR, out icon_w, out icon_h
        );
        this.set_size_request(-1, icon_h);
    }
    
    public override void realize() {
        base.realize();
        
        var wa = Gdk.WindowAttr();
        wa.width = 1;
        wa.height = 1;
        wa.wclass = Gdk.WindowWindowClass.INPUT_ONLY;
        wa.window_type = Gdk.WindowType.CHILD;
        this.manager_window = new Gdk.Window(this.get_window(), wa, 0);
        
        Gdk.Screen screen = this.get_screen();
        var atom__net_system_tray_sn =
            Gdk.Atom.intern(@"_NET_SYSTEM_TRAY_S$(screen.get_number())", false);
        
        if (Gdk.selection_owner_set(
            this.manager_window,
            atom__net_system_tray_sn,
            this.timestamp,
            false
        )) {
            var msg_ev = X.Event();
            msg_ev.type = X.EventType.ClientMessage;
            msg_ev.xclient.window =
                (this.get_screen().get_root_window() as Gdk.X11.Window)
                .get_xid();
            msg_ev.xclient.message_type = Gdk.X11.get_xatom_by_name("MANAGER");
            msg_ev.xclient.format = 32;
            msg_ev.xclient.data.l[0] = this.timestamp;
            msg_ev.xclient.data.l[1] = (long) Gdk.X11.atom_to_xatom_for_display(
                this.get_display() as Gdk.X11.Display, atom__net_system_tray_sn
            );
            msg_ev.xclient.data.l[2] =
                (long) (this.manager_window as Gdk.X11.Window).get_xid();
            msg_ev.xclient.data.l[3] = 0;
            msg_ev.xclient.data.l[4] = 0;
            (this.get_display() as Gdk.X11.Display).get_xdisplay()
                .send_event(
                    msg_ev.xclient.window, false,
                    X.EventMask.StructureNotifyMask,
                    ref msg_ev
                );
            
            this.get_window().add_filter(this.filter_event);
            this.manager_window.show();
        }
    }
    
    public override void unrealize() {
        if (this.manager_window != null) {
            this.manager_window.destroy();
            this.manager_window = null;
        }
    }
    
    protected Gdk.FilterReturn filter_event(
        Gdk.XEvent xevent_gdk, Gdk.Event event
    ) {
        var xevent = (X.Event*) (&xevent_gdk);
        if (xevent->type != X.EventType.ClientMessage) {
            return Gdk.FilterReturn.CONTINUE;
        }
        var message_type = xevent->xclient.display.intern_atom(
            "_NET_SYSTEM_TRAY_OPCODE", false
        );
        if (xevent->xclient.message_type != message_type) {
            return Gdk.FilterReturn.CONTINUE;
        }
        if (
            xevent->xclient.window
            == (this.manager_window as Gdk.X11.Window).get_xid()
        ) {
            var xclientevent = (XFixes.ClientMessageEvent*) (&xevent->xclient);
            switch (xclientevent->data.l[1]) {
            case 0:  // SYSTEM_TRAY_REQUEST_DOCK
                var socket = new Gtk.Socket();
                socket.show();
                this.pack_start(socket, false, false, 0);
                socket.add_id((X.Window)xclientevent->data.l[2]);
                return Gdk.FilterReturn.REMOVE;
            }
        }
        return Gdk.FilterReturn.CONTINUE;
    }
}

}  // end namespace Gutter
