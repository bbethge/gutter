namespace Gutter {

public class StatusArea: Gtk.HBox {
    protected Gdk.Window? manager_window = null;
    public uint32 timestamp;
    
    public StatusArea(uint32 time = 0) {
        Object(homogeneous: false);
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
        wa.wclass = Gdk.WindowClass.INPUT_ONLY;
        wa.window_type = Gdk.WindowType.CHILD;
        this.manager_window = new Gdk.Window(this.window, wa, 0);
        
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
            msg_ev.xclient.window = Gdk.x11_drawable_get_xid(
                this.get_screen().get_root_window()
            );
            msg_ev.xclient.message_type = Gdk.x11_get_xatom_by_name("MANAGER");
            msg_ev.xclient.format = 32;
            msg_ev.xclient.data.l[0] = this.timestamp;
            msg_ev.xclient.data.l[1] = (long) Gdk.x11_atom_to_xatom_for_display(
                this.get_display(), atom__net_system_tray_sn
            );
            msg_ev.xclient.data.l[2] =
                (long) Gdk.x11_drawable_get_xid(this.manager_window);
            msg_ev.xclient.data.l[3] = 0;
            msg_ev.xclient.data.l[4] = 0;
            Gdk.x11_display_get_xdisplay(this.get_display())
                .send_event(
                    msg_ev.xclient.window, false,
                    X.EventMask.StructureNotifyMask,
                    ref msg_ev
                );
            
            this.get_display().add_client_message_filter(
                Gdk.Atom.intern("_NET_SYSTEM_TRAY_OPCODE", false),
                this.filter_client_message
            );
            this.manager_window.show();
        }
    }
    
    public override void unrealize() {
        if (this.manager_window != null) {
            this.manager_window.destroy();
            this.manager_window = null;
        }
    }
    
    protected Gdk.FilterReturn filter_client_message(
        Gdk.XEvent xevent_gdk, Gdk.Event event
    ) {
        var xevent = (X.Event*) (&xevent_gdk);
        if (
            xevent->xclient.window
            == (X.Window) Gdk.x11_drawable_get_xid(this.manager_window)
        ) {
            var xclientevent = (XFixes.ClientMessageEvent*) (&xevent->xclient);
            switch (xclientevent->data.l[1]) {
            case 0:  // SYSTEM_TRAY_REQUEST_DOCK
                var socket = new Gtk.Socket();
                socket.show();
                this.pack_start(socket, false, false, 0);
                socket.add_id((Gdk.NativeWindow)xclientevent->data.l[2]);
                return Gdk.FilterReturn.REMOVE;
            }
        }
        return Gdk.FilterReturn.CONTINUE;
    }
}

}  // end namespace Gutter
