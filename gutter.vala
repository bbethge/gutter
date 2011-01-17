public class Bimap<D, R> {
    [Compact]
    private class Record<D, R> {
        public D input;
        public R output;
    }
    
    protected SList<Record<D, R> > records = new SList<Record<D, R> > ();
    protected EqualFunc input_equal_func;
    protected EqualFunc output_equal_func;
    
    public Bimap(
        EqualFunc input_equal_func, EqualFunc output_equal_func
    ) {
        this.input_equal_func = input_equal_func;
        this.output_equal_func = output_equal_func;
    }
    
    public unowned R? lookup(D input) {
        for (
            unowned SList<Record<D, R> > iter = this.records;
            iter != null;
            iter = iter.next
        ) {
            if (this.input_equal_func(iter.data.input, input)) {
                return iter.data.output;
            }
        }
        return null;
    }
    
    public unowned D? ilookup(R output) {
        for (
            unowned SList<Record<D, R> > iter = this.records;
            iter != null;
            iter = iter.next
        ) {
            if (this.output_equal_func(iter.data.output, output)) {
                return iter.data.input;
            }
        }
        return null;
    }
    
    public void insert(D input, R output) {
        this.remove(input);
        this.iremove(output);
        var record = new Record<D, R> ();
        record.input = input;
        record.output = output;
        this.records.prepend((owned) record);
    }
    
    public void remove(D input) {
        for (
            unowned SList<Record<D, R> > iter = this.records;
            iter != null;
            iter = iter.next
        ) {
            if (this.input_equal_func(iter.data.input, input)) {
                iter.data = null;
                this.records.delete_link(iter);
                // Note that ‘iter’ is now invalid, so we don’t use it any more
                break;
            }
        }
    }
    
    public void iremove(R output) {
        for (
            unowned SList<Record<D, R> > iter = this.records;
            iter != null;
            iter = iter.next
        ) {
            if (this.output_equal_func(iter.data.output, output)) {
                iter.data = null;
                this.records.delete_link(iter);
                // Note that ‘iter’ is now invalid, so we don’t use it any more
                break;
            }
        }
    }
    
    [Compact]
    public class Iterator<D, R> {
        protected unowned SList<Record<D, R> > link;
        
        public Iterator(SList<Record<D, R> > start) {
            this.link = start;
        }
        
        public unowned D? next_value() {
            unowned D? result = null;
            if (this.link != null) {
                result = this.link.data.input;
                this.link = this.link.next;
            }
            return result;
        }
    }
    
    public Iterator<D, R> iterator() {
        return new Iterator<D, R> (this.records);
    }
}

namespace Gutter {

enum GetWindowPropertyResult {
    SUCCESS,
    FAILURE,
    BAD_WINDOW
        // An invalid window isn’t really a failure because it’s nobody’s fault
        // if the window got destroyed before you could retrieve the property
}

static GetWindowPropertyResult get_window_property(
    X.Display display,
    X.Window window,
    X.Atom property,
    bool @delete,
    X.Atom type,
    int format,
    out ulong count,
    out void *data
)
    // This is now just a helper for get_window_property{8,32}; avoid using it.
    
    // Nobody wants to say what is the correct way to handle the various
    // possible outcomes of XGetWindowProperty.  This may well repeat the same
    // (unspecified) mistakes that gdk_window_property_get made, but I don’t
    // care.  It just factors out common code for many of the property
    // retrievals in this program.
    
    // Specifically, it assumes that you want to pretend the property doesn’t
    // exist if it has the wrong type or format, if the server ran out of
    // memory, if this function makes wrong assumptions, or if you passed an
    // invalid atom (though in these last two cases it logs an error).  The
    // caller *is* notified if the window was invalid, because foreign
    // windows can be destroyed at any time without anyone doing anything wrong,
    // and it is impossible to know that a foreign window will still exist when
    // the server receives the request unless it is the root window.
{
    X.Atom actual_type;
    int actual_format;
    ulong remaining_bytes;
    
    Gdk.error_trap_push();
    int status = display.get_window_property(
        window,
        property,
        0L, long.MAX,
        @delete,
        type,
        out actual_type, out actual_format,
        out count,
        out remaining_bytes,
        out data
    );
    // Flushing shouldn’t be necessary because this X request returns data.
    int x_error = Gdk.error_trap_pop();
    
    if (unlikely(x_error != 0)) {
        switch (x_error) {
        case XFixes.BadWindow:
            return GetWindowPropertyResult.BAD_WINDOW;
        case XFixes.BadAlloc:
            break;
        case XFixes.BadAtom:
            warning("get_window_property received invalid atom");
            break;
        case XFixes.BadValue:
            warning("get_window_property sent invalid value to X server");
            break;
        default:
            warning("XGetWindowProperty caused unexpected error");
            break;
        }
        return GetWindowPropertyResult.FAILURE;
    }
    return_val_if_fail(
        status == X.Success, GetWindowPropertyResult.FAILURE
    );  // I think status == X.Success means no X error, so this should not fail
    
    if (actual_type == X.None || actual_type != type) {
        return GetWindowPropertyResult.FAILURE;
    }
    if (actual_format != format) {
        X.free(data);
        data = null;
        return GetWindowPropertyResult.FAILURE;
    }
    return GetWindowPropertyResult.SUCCESS;
}

[Compact]
public class XArray32
    // A wrapper for arrays returned from X.Display.get_window_property with
    // format 32, which causes them to be freed correctly.
    // (It’s public to avoid warnings about unused methods.)
{
    public ulong length {
        get { return this._length; }
        private set { this._length = value; }
    }
    protected ulong _length;
    
    protected ulong *data;
        // Fun fact: X.Display.get_window_property returns items the size of
        // longs when the format is 32, even if long is not 32 bits.
    
    public XArray32(ulong length, void *data)
        // length and data should have been returned from
        // X.Display.get_window_property.
    {
        this.length = length;
        this.data = (ulong*) data;
    }
    
    ~XArray32() {
        if (data != null) {
            X.free(data);
        }
    }
    
    public ulong get(ulong index)
        requires (index < this.length)
    {
        return this.data[index];
    }
    
    public void set(ulong index, ulong item)
        requires (index < this.length)
    {
        this.data[index] = item;
    }
    
    public bool contains(ulong needle) {
        foreach (ulong? item in this) {
            if (item == needle) {
                return true;
            }
        }
        return false;
    }
    
    public Iterator iterator() {
        return new Iterator(this);
    }
    
    [Compact]
    public class Iterator {
        protected ulong index;
        protected unowned XArray32 array;
        
        public Iterator(XArray32 array) {
            this.array = array;
        }
        
        public ulong? next_value() {
            this.index++;
            if (this.index < this.array.length) {
                return this.array[this.index];
            }
            return null;
        }
    }
}

[Compact]
public class XArray8
    // A wrapper for arrays returned from X.Display.get_window_property with
    // format 8, which causes them to be freed correctly.
    // (It’s public to avoid warnings about unused methods.)
{
    public ulong length {
        get { return this._length; }
        private set { this._length = value; }
    }
    protected ulong _length;
    
    protected uint8 *data;
    
    public XArray8(ulong length, void *data)
        // length and data should have been returned from
        // X.Display.get_window_property.
    {
        this.length = length;
        this.data = (uint8*) data;
    }
    
    ~XArray8() {
        if (data != null) {
            X.free(data);
        }
    }
    
    public uint8 get(ulong index)
        requires (index < this.length)
    {
        return this.data[index];
    }
    
    public void set(ulong index, uint8 item)
        requires (index < this.length)
    {
        this.data[index] = item;
    }
    
    public unowned string to_string() {
        return_val_if_fail(this.data != null, "");
        // I guess this is probably supported
        return (string) this.data;
    }
    
    public Iterator iterator() {
        return new Iterator(this);
    }
    
    [Compact]
    public class Iterator {
        protected ulong index;
        protected unowned XArray8 array;
        
        public Iterator(XArray8 array) {
            this.array = array;
        }
        
        public uint8? next_value() {
            this.index++;
            if (this.index < this.array.length) {
                return this.array[this.index];
            }
            return null;
        }
    }
}

//[Compact]
//class List<T> {
//    [Compact]
//    public class Link<T> {
//        public Link<T>? next;
//        public T data;
//    }
//    
//    protected Link<T>? _first = null;
//    protected unowned Link<T>? _last = null;
//    
//    public void prepend(owned T data)
//        ensures (invariant())
//    {
//        var link = new Link<T> ();
//        link.next = this._first;
//        link.data = data;
//        this._first = link;
//        if (link.next == null) this._last = this._first;
//    }
//    
//    public void append(owned T data)
//        ensures (invariant())
//    {
//        var link = new Link<T> ();
//        link.next = null;
//        link.data = data;
//        if (this._last == null) this._first = link;
//        else this._last.next = link;
//        this._last = link;
//    }
//    
//    private bool invariant() {
//        return
//            (this._first == null) == (this._last == null)
//            &&
//            (this._last == null || this._last.next == null)
//            &&
//            (
//                this._first == null
//                || this._first.next != null || this._first == this._last
//            );
//    }
//}

static GetWindowPropertyResult get_window_property32(
    X.Display display,
    X.Window window,
    X.Atom property,
    bool @delete,
    X.Atom type,
    out XArray32 data
) {
    ulong count;
    void *data_ptr;
    GetWindowPropertyResult result;
    result = get_window_property(
        display, window, property, @delete, type, 32, out count, out data_ptr
    );
    data = new XArray32(count, data_ptr);
    return result;
}

static GetWindowPropertyResult get_window_property8(
    X.Display display,
    X.Window window,
    X.Atom property,
    bool @delete,
    X.Atom type,
    out XArray8 data
) {
    ulong count;
    void *data_ptr;
    GetWindowPropertyResult result;
    result = get_window_property(
        display, window, property, @delete, type, 8, out count, out data_ptr
    );
    data = new XArray8(count, data_ptr);
    return result;
}

public delegate bool XEventFilter(X.Event event);

class XEventFilterManager {
    public int type;
    public unowned XEventFilter filter;
    
    static Gee.MultiMap<X.Window?, unowned XEventFilterManager>
        xwindow_to_xefms =
        new Gee.HashMultiMap<X.Window?, unowned XEventFilterManager> (
            (a) => {
                var aa = (!)(X.Window?)a;
                return (uint) (((aa>>32)^aa) & 0xfffffffful);
            },
            (a, b) => { return (X.Window?)a == (X.Window?)b; }
        );
    
    protected static Gdk.FilterReturn wrapper(
        Gdk.XEvent xev_gdk, Gdk.Event ev
    ) {
        var result = Gdk.FilterReturn.CONTINUE;
        var xev = (X.Event*) (&xev_gdk);
        foreach (var xefm in xwindow_to_xefms[xev.xany.window]) {
            if (xev.type == xefm.type) {
                if (xefm.filter(*xev)) {
                    result = Gdk.FilterReturn.REMOVE;
                    break;
                }
            }
        }
        if (xev.type == X.EventType.DestroyNotify) {
            xwindow_to_xefms.remove_all(xev.xany.window);
            var window =
                Gdk.Window.foreign_new((Gdk.NativeWindow)xev.xany.window);
            window.remove_filter(wrapper);
            // TODO: anything else?
        }
        return result;
    }
    
    protected static Quark key = Quark.from_string("gutter_xevent_filter");
    
    public static void add(
        Gdk.Window window, int type, Object owner, XEventFilter filter
    ) {
        if (window.is_destroyed()) return;
        
        // This function may be called before its class is initialized, so it is
        // very important to create an instance (which initializes the class)
        // before using any other class methods or variables.
        var xefm = new XEventFilterManager();
        xefm.type = type;
        xefm.filter = filter;
        
        X.Window xwindow = (X.Window) Gdk.x11_drawable_get_xid(window);
        
        xwindow_to_xefms[xwindow] = xefm;
        X.Window? w2 = xwindow;
        warn_if_fail(xwindow_to_xefms[w2].contains(xefm));
        window.add_filter(wrapper);
        
        // Give ‘owner’ a reference to ‘xefm’ so that ‘xefm’ will be
        // automatically freed when ‘owner’ is destroyed.
        Gee.List<XEventFilterManager>? xefms =
            owner.get_qdata<Gee.List<XEventFilterManager>> (key);
        if (xefms == null) {
            xefms = new Gee.LinkedList<XEventFilterManager> ();
            owner.set_qdata<Gee.List<XEventFilterManager>> (key, xefms);
        }
        xefms.insert(0, xefm);
    }
}

class WindowButton: Gtk.Bin
    // A button representing a toplevel window on a TaskList
{
    protected Gtk.Widget? _image = null;
    protected Gtk.Label _label = new Gtk.Label(null);
    protected Gtk.HBox hbox = new Gtk.HBox(false, 0);
    protected bool is_popped_out = false;
    protected Gtk.RadioButton button = new Gtk.RadioButton(null);
    protected Gtk.Window? popup = null;
    protected bool popup_saw_enter_event;
        // Whether this.popup has received an enter event since we created it
    
    public X.Window xwindow { get; set construct; }
        // The toplevel window that is controlled through this widget
    
    public WindowButton(SList<Gtk.RadioButton>? group, X.Window xwindow) {
        Object(xwindow: xwindow);
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
        
        this.update_spacing();
    }
    
    protected void update_spacing() {
        int spacing = 0;
        this.button.style_get("image-spacing", &spacing);
        this.hbox.spacing = spacing;
    }
    
    public override void style_set(Gtk.Style? previous_style) {
        base.style_set(previous_style);
        this.update_spacing();
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
            Gtk.Requisition request;
            this.size_request(out request);
            this._label.ellipsize = prev_ellipsize;
            request.width =
                int.min(request.width, this.get_screen().get_width()/2);
            
            // If we currently have smaller width than we would request without
            // ellipsization (meaning that this._label is probably ellipsized),
            // create a popup to show more of this._label.
            Gtk.Allocation alloc;
            this.get_allocation(out alloc);
            if (request.width > alloc.width) {
                this.is_popped_out = true;
                this.popup = new Gtk.Window(Gtk.WindowType.POPUP);
                this.popup.add_events(Gdk.EventMask.STRUCTURE_MASK);
                this.popup.set_type_hint(Gdk.WindowTypeHint.POPUP_MENU);
                this.popup.destroy_with_parent = true;
                this.popup.transient_for = this.get_toplevel() as Gtk.Window;
                
                this.button.reparent(this.popup);
                this.popup.set_size_request(request.width, request.height);
                
                // FIXME: Make this work with Gutter on the left side?
                int x = this.get_screen().get_width() - request.width;
                
                Gtk.Widget toplevel = this.get_toplevel();
                int toplevel_y;
                toplevel.window.get_origin(null, out toplevel_y);
                int y_wrt_toplevel;
                bool succ = this.translate_coordinates(
                    toplevel, 0, 0, null, out y_wrt_toplevel
                ); return_if_fail(succ);
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
    
    public override void size_request(out Gtk.Requisition requisition) {
        // Request the same size as this.button even when it isn’t our child
        // (because it is in this.popup).
        this.button.size_request(out requisition);
    }
    
    public override void size_allocate(Gdk.Rectangle allocation) {
        base.size_allocate(allocation);
        
        Gtk.Widget? child = this.get_child();
        if (child != null && child.visible) {
            child.size_allocate(allocation);
        }
    }
    
    protected void hide_popup() {
        if (this.is_popped_out) {
            this.is_popped_out = false;
            this.button.reparent(this);
            this.popup.destroy();
            this.popup = null;
        }
    }
    
    protected bool on_button_button_release_event(
        Gtk.Widget widget, Gdk.EventButton event
    ) {
        // FIXME: If you click the button for the parent of a modal dialog, the
        // focus stays on the dialog, but the parent’s button is activated.
        
        assert(this.window != null);
        
        if (event.button != 1) return false;
        
        var msg_ev = X.Event();
        msg_ev.type = X.EventType.ClientMessage;
        msg_ev.xclient.window = this.xwindow;
        msg_ev.xclient.format = 32;
        
        if (button.active) {
            // Iconify the corresponding toplevel window
            
            msg_ev.xclient.message_type =
                Gdk.x11_get_xatom_by_name("WM_CHANGE_STATE");
            msg_ev.xclient.data.l[0] = XFixes.IconicState;
            msg_ev.xclient.data.l[1] = 0;  // Unused
            msg_ev.xclient.data.l[2] = 0;  // Unused
        }
        else {
            // Activate the corresponding toplevel window
            
            msg_ev.xclient.message_type =
                Gdk.x11_get_xatom_by_name("_NET_ACTIVE_WINDOW");
            msg_ev.xclient.data.l[0] = 2;  // Source (this program) is a pager
            msg_ev.xclient.data.l[1] = event.time;  // Timestamp
            msg_ev.xclient.data.l[2] =
                (long) Gdk.x11_drawable_get_xid(this.get_toplevel().window);
        }
        msg_ev.xclient.data.l[3] = 0;  // Unused
        msg_ev.xclient.data.l[4] = 0;  // Unused
        
        var xroot =
            (X.Window) Gdk.x11_drawable_get_xid(this.get_root_window());
        var xdisplay = Gdk.x11_display_get_xdisplay(this.get_display());
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

class TaskList: Gtk.VBox {
    static X.Atom xatom__net_client_list =
        Gdk.x11_get_xatom_by_name("_NET_CLIENT_LIST");
    static X.Atom xatom__net_active_window =
        Gdk.x11_get_xatom_by_name("_NET_ACTIVE_WINDOW");
    
    protected Bimap<X.Window?, unowned WindowButton> xwindow_to_button =
        new Bimap<X.Window?, unowned WindowButton> (
            (wa, wb) => { return *(X.Window*)wa == *(X.Window*)wb; },
            (ba, bb) => { return ba == bb; }
        );
    
    public TaskList() {
        Object(homogeneous: false);
    }
    
    construct {
        this.on_client_list_changed();
    }
    
    public override void realize() {
        base.realize();
        
        Gtk.Requisition req;
        this.size_request(out req);
        
        Gdk.Window root = this.get_root_window();
        root.set_events(root.get_events() | Gdk.EventMask.PROPERTY_CHANGE_MASK);
        root.add_filter(this.filter_root_window_xevent);
            // Apparently it is impossible to use a real closure for this,
            // but if you just need to reference ‘this’ it’s OK.
    }
    
    public override void unrealize() {
        Gdk.Window root = this.get_root_window();
        root.remove_filter(this.filter_root_window_xevent);
        
        base.unrealize();
    }
    
    private Gdk.FilterReturn filter_root_window_xevent(
        Gdk.XEvent xev_gdk, Gdk.Event ev
    ) {
        var xev = (X.Event*) (&xev_gdk);
            // I had to fight with the compiler on this one to make it not try
            // to dereference xev_gdk, so maybe this is not the right way to do
            // it, or the binding is wrong.
        
        var xroot = Gdk.x11_get_default_root_xwindow();
        if (
            xev->type == X.EventType.PropertyNotify
            && xev->xproperty.window == xroot
        ) {
            if (xev->xproperty.atom == this.xatom__net_client_list) {
                this.on_client_list_changed();
            }
            else if (xev->xproperty.atom == this.xatom__net_active_window) {
                this.on_active_window_changed();
            }
        }
        return Gdk.FilterReturn.CONTINUE;
    }
    
    protected void on_client_list_changed() {
        X.Display xdisplay = Gdk.x11_get_default_xdisplay();
        X.Window xroot = Gdk.x11_get_default_root_xwindow();
        XArray32 windows;
        switch (
            get_window_property32(
                xdisplay,
                xroot,
                this.xatom__net_client_list,
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
                        Gdk.x11_get_xatom_by_name("_NET_WM_STATE"),
                        false,
                        X.XA_ATOM,
                        out state
                    ) == GetWindowPropertyResult.SUCCESS
                    &&
                    Gdk.x11_get_xatom_by_name("_NET_WM_STATE_SKIP_TASKBAR")
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
                
                var window_gdk =
                    Gdk.Window.foreign_new((Gdk.NativeWindow)window);
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
                        Gdk.x11_get_xatom_by_name("_NET_WM_ICON"),
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
                Gdk.x11_get_default_xdisplay(),
                Gdk.x11_get_default_root_xwindow(),
                this.xatom__net_active_window,
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
                == Gdk.x11_get_xatom_by_name("_NET_WM_VISIBLE_NAME")
            ||
            xevent.xproperty.atom == Gdk.x11_get_xatom_by_name("_NET_WM_NAME")
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
        
        X.Atom xatom_utf8_string = Gdk.x11_get_xatom_by_name("UTF8_STRING");
        X.Atom props[6] = {
            Gdk.x11_get_xatom_by_name("_NET_WM_VISIBLE_NAME"),
                xatom_utf8_string,
            Gdk.x11_get_xatom_by_name("_NET_WM_NAME"), xatom_utf8_string,
            X.XA_WM_NAME, Gdk.x11_get_xatom_by_name("STRING")
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

class StatusArea: Gtk.HBox {
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
            switch (xevent.xclient.data.l[1]) {
            case 0:  // SYSTEM_TRAY_REQUEST_DOCK
                var socket = new Gtk.Socket();
                socket.show();
                this.pack_start(socket, false, false, 0);
                socket.add_id((Gdk.NativeWindow)xevent->xclient.data.l[2]);
                return Gdk.FilterReturn.REMOVE;
            }
        }
        return Gdk.FilterReturn.CONTINUE;
    }
}

class Clock: Gtk.Label {
    construct {
        this.justify = Gtk.Justification.CENTER;
    }
    
    public override void map() {
        base.map();
        
        this.on_timeout();
    }
    
    protected bool on_timeout() {
        var time = new DateTime.now_local();
        // TODO: This is horribly US-specific and non-customizable.
        int hour = (time.get_hour()+23) % 12 + 1;
        string minute = "%02d".printf(time.get_minute());
        string ampm = time.format("%P");
        string month = time.format("%b");
        int dom = time.get_day_of_month();
        this.set_markup(
            @"<big><big>$hour:$minute $ampm</big></big>\n$month $dom"
        );
        
        // Schedule this function to be called again in just over 60 seconds
        // (assuming it took less than 1 second to run…)
        if (this.get_mapped()) {
            Timeout.add_seconds(61 - time.get_second(), this.on_timeout);
        }
        
        // Do not automatically reschedule this timeout, since we just manually
        // rescheduled it.
        return false;
    }
}

class Menu: Gtk.MenuBar {
    protected Garcon.Menu? menu;
    
    construct {
        this.set_pack_direction(Gtk.PackDirection.TTB);
        
        this.menu = new Garcon.Menu.applications();
        try {
            this.menu.load(null);
        }
        catch (Error e) {
            warning(_("Error while loading applications menu: %s"), e.message);
            this.menu = null;
        }
        
        var appl_item = new Gtk.MenuItem.with_label(_("Applications"));
        appl_item.show();
        this.append(appl_item);
        
        var appl_menu = new Gtk.Menu();
        appl_item.set_submenu(appl_menu);
        
        if (this.menu != null) {
            build_menu(appl_menu, this.menu);
        }
    }
    
    protected static void build_menu(Gtk.Menu menu, Garcon.Menu garcon_menu) {
        foreach (var elt in garcon_menu.get_elements()) {
            if (!elt.get_visible()) continue;
            
            Gtk.MenuItem item;
            string? icon_name = elt.get_icon_name();
            Gtk.Image? image = null;
            if (icon_name != null && icon_name.length > 0) {
                if (icon_name[0] == '/') {
                    int w, h;
                    Gtk.icon_size_lookup(Gtk.IconSize.MENU, out w, out h);
                    try {
                        var pixbuf =
                            new Gdk.Pixbuf.from_file_at_size(icon_name, w, h);
                        image = new Gtk.Image.from_pixbuf(pixbuf);
                    }
                    catch (Error err) {
                        // Ignore, leaving image == null
                    }
                }
                else {
                    image = new Gtk.Image.from_icon_name(
                        icon_name, Gtk.IconSize.MENU
                    );
                }
            }
            if (image != null) {
                var img_item = new Gtk.ImageMenuItem.with_label(elt.get_name());
                img_item.image = image;
                item = img_item;
            }
            else {
                item = new Gtk.MenuItem.with_label(elt.get_name());
            }
            if (elt is Garcon.Menu) {
                var submenu = new Gtk.Menu();
                build_menu(submenu, (Garcon.Menu)elt);
                item.set_submenu(submenu);
            }
            //else if (elt is Garcon.MenuItem) {
            //    // FIXME: When we make a closure that references ‘elt’, the data
            //    // block for that closure never gets initialized.
            //    item.activate.connect((mi) => {
            //        on_menu_item_activate(mi, (Garcon.MenuItem)elt);
            //    });
            //}
            item.show();
            menu.append(item);
        }
    }
    
    static void on_menu_item_activate(
        Gtk.MenuItem gtk_item, Garcon.MenuItem item
    ) {
        return_if_fail(item.path != null);
        
        string[] args;
        try {
            Shell.parse_argv(item.path, out args);
        }
        catch (ShellError err) {
            // TODO: Graphical error message?  (See also every other error
            // handler in this function.)
            warning(
                "Unable to parse command line ‘%s’: %s", item.path, err.message
            );
            return;
        }
        
        Regex percent_escape;
        try {
            percent_escape = new Regex("%.");
        }
        catch (RegexError err) {
            return_if_reached();
        }
        
        string?[] new_args = new string[args.length];
        assert(new_args.length == 0);  // TODO: Remove
        foreach (var arg in args) {
            if (arg == "%F" || arg == "%U") continue;  // Ignore these
            if (arg == "%i") {
                if (item.icon_name != null) {
                    new_args += "--icon";
                    new_args += item.icon_name;
                }
                continue;
            }
            
            bool err = false;
            string? new_arg;
            try {
                new_arg = percent_escape.replace_eval(
                    arg, arg.length, 0, 0,
                    (match, result) => {
                        switch (match.fetch(0)[1]) {
                        case '%':
                            result.append_c('%');
                            break;
                        case 'f':
                        case 'u':
                        case 'd':
                        case 'D':
                        case 'n':
                        case 'N':
                        case 'v':
                        case 'm':
                            // Ignore these
                            break;
                        case 'c':
                            result.append(item.name);
                            break;
                        case 'k':
                            result.append(item.file.get_path());
                            break;
                        default:
                            warning("Invalid field code in command line");
                            err = true;
                            return true;
                        }
                        return false;
                    }
                );
            }
            catch (RegexError err) {
                // TODO: More error reporting?
                return;
            }
            if (err) return;
            new_args += new_arg;
        }
        new_args += null;
        
        int pid;
        try {
            Gdk.spawn_on_screen(
                gtk_item.get_screen(),
                item.path,
                new_args,
                null,
                SpawnFlags.SEARCH_PATH | SpawnFlags.STDOUT_TO_DEV_NULL,
                null,
                out pid
            );
        }
        catch (Error err) {
            warning("Error launching command: %s", err.message);
        }
    }
}

class Window: Gtk.Window {
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

int main(string[] args) {
    if (
        Intl.bindtextdomain("gutter", "intl") == null
            // TODO: Figure out where to actually install translations (to be
            // done after we actually have translations)
        && errno == Posix.ENOMEM
            // It seems like we should continue in the case of other errors,
            // since internationalization won’t work but the program may still
            // be useful
    ) {
        error("%s", strerror(errno));
    }
    
    if (
        Intl.bind_textdomain_codeset("gutter", "UTF8") == null
        && errno == Posix.ENOMEM
    ) {
        error("%s", strerror(errno));
    }
    
    Gtk.init(ref args);
    
    var window = new Gutter.Window();
    window.hide.connect((win) => Gtk.main_quit());
    window.show();
    
    Gtk.main();
    return 0;
}
