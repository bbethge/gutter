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
    X_ERROR,
    DOES_NOT_EXIST,
    WRONG_TYPE,
    WRONG_FORMAT
}

static GetWindowPropertyResult get_window_property(
    X.Display display,
    X.Window window,
    X.Atom property,
    bool @delete,
    X.Atom type,
    int format,
    out ulong count,
    out void *data,
    out int x_error
)
    // This is now just a helper for get_window_property{8,32}; avoid using it.
{
    X.Atom actual_type;
    int actual_format;
    ulong remaining_bytes;
    x_error = display.get_window_property(
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
    if (x_error != X.Success) {
        return GetWindowPropertyResult.X_ERROR;
    }
    if (actual_type == X.None) {
        return GetWindowPropertyResult.DOES_NOT_EXIST;
    }
    if (actual_type != type) {
        return GetWindowPropertyResult.WRONG_TYPE;
    }
    if (actual_format != format) {
        X.free(data);
        data = null;
        return GetWindowPropertyResult.WRONG_FORMAT;
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
    out XArray32 data,
    out int x_error
) {
    ulong count;
    void *data_ptr;
    GetWindowPropertyResult result;
    result = get_window_property(
        display, window, property, @delete, type, 32, out count, out data_ptr,
        out x_error
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
    out XArray8 data,
    out int x_error
) {
    ulong count;
    void *data_ptr;
    GetWindowPropertyResult result;
    result = get_window_property(
        display, window, property, @delete, type, 8, out count, out data_ptr,
        out x_error
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

class WindowButton: Gtk.RadioButton
    // A button representing a toplevel window on a TaskList
{
    protected Gtk.Widget? _image = null;
    protected Gtk.Label _label = new Gtk.Label(null);
    protected Gtk.HBox hbox = new Gtk.HBox(false, 0);
    
    public WindowButton(SList<Gtk.RadioButton>? group) {
        Object();
        if (group != null) {
            this.set_group(group);
        }
    }
    
    construct {
        this["draw-indicator"] = false;
        this.relief = Gtk.ReliefStyle.NONE;
        this.hbox.show();
        this.add(this.hbox);
        this._label.ellipsize = Pango.EllipsizeMode.END;
        this._label.xalign = 0.0f;
        this._label.show();
        this.hbox.pack_start(this._label, true, true, 0);
        this.update_spacing();
    }
    
    protected void update_spacing() {
        int spacing = 0;
        this.style_get("image-spacing", &spacing);
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
    
    HashTable<unowned WindowButton, ulong?> button_to_handler =
        new HashTable<unowned WindowButton, ulong?> (null, null);
    
    public TaskList() {
        Object(homogeneous: false);
    }
    
    construct {
        this.on_client_list_changed();
    }
    
    public override void dispose() {
        // Disconnect our handlers for window button toggled events and remove
        // them from button_to_handler so they won’t get disconnected twice.
        this.button_to_handler.foreach((b, h) => {
            ((Gtk.RadioButton)b).disconnect((!) (ulong?)h);
        });
        this.button_to_handler.remove_all();
        
        base.dispose();
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
        int xerror;
        switch (
            get_window_property32(
                xdisplay,
                xroot,
                this.xatom__net_client_list,
                false,
                X.XA_WINDOW,
                out windows,
                out xerror
            )
        ) {
        case GetWindowPropertyResult.X_ERROR:
            warning("Couldn't retrieve window list: X error %d", xerror);
            break;
        case GetWindowPropertyResult.DOES_NOT_EXIST:
            warning(
                "Couldn't retrieve window list: "
                +"property _NET_CLIENT_LIST does not exist"
            );
            break;
        case GetWindowPropertyResult.WRONG_TYPE:
            warning(
                "Couldn't retrieve window list: "
                +"property _NET_CLIENT_LIST has wrong type"
            );
            break;
        case GetWindowPropertyResult.WRONG_FORMAT:
            warning(
                "Couldn't retrieve window list: "
                +"property _NET_CLIENT_LIST has wrong format"
            );
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
                        out state,
                        out xerror
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
                    button != null ? button.get_group() : null
                );
                this.button_to_handler.insert(
                    button,
                    button.button_release_event.connect(
                        this.on_window_button_button_release_event
                    )
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
                        out icon_data,
                        out xerror
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
                    ulong? handler = this.button_to_handler.lookup(dead_button);
                    if (handler != null) {
                        dead_button.disconnect(handler);
                        this.button_to_handler.remove(dead_button);
                    }
                    else warn_if_reached();
                    
                    this.remove(dead_button);
                }
                else warn_if_reached();
            }
            break;
        }
    }
    
    protected void on_active_window_changed() {
        XArray32 xwindow_arr;
        int xerror;
        if (
            get_window_property32(
                Gdk.x11_get_default_xdisplay(),
                Gdk.x11_get_default_root_xwindow(),
                this.xatom__net_active_window,
                false,
                X.XA_WINDOW,
                out xwindow_arr,
                out xerror
            ) == GetWindowPropertyResult.SUCCESS
            && xwindow_arr.length > 0
        ) {
            var xwindow = (X.Window) xwindow_arr[0];
            WindowButton? button = this.xwindow_to_button.lookup(xwindow);
            if (button != null) {
                var handler = this.button_to_handler.lookup(button);
                if (handler != null) {
                    SignalHandler.block(button, handler);
                }
                else warn_if_reached();
                button.active = true;
                if (handler != null) {
                    SignalHandler.unblock(button, handler);
                }
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
        
        XArray8 name_arr;
        X.Atom xatom_utf8_string = Gdk.x11_get_xatom_by_name("UTF8_STRING");
        unowned string? name = null;
        int xerror;
        if (
            get_window_property8(
                xdisplay,
                xwindow,
                Gdk.x11_get_xatom_by_name("_NET_WM_VISIBLE_NAME"),
                false,
                xatom_utf8_string,
                out name_arr,
                out xerror
            ) == GetWindowPropertyResult.SUCCESS
            ||
            get_window_property8(
                xdisplay,
                xwindow,
                Gdk.x11_get_xatom_by_name("_NET_WM_NAME"),
                false,
                xatom_utf8_string,
                out name_arr,
                out xerror
            ) == GetWindowPropertyResult.SUCCESS
            ||
            get_window_property8(
                xdisplay,
                xwindow,
                X.XA_WM_NAME,
                false,
                Gdk.x11_get_xatom_by_name("STRING"),
                out name_arr,
                out xerror
            ) == GetWindowPropertyResult.SUCCESS
        ) {
            name = name_arr.to_string();
        }
        
        button.wb_label = name ?? "Window 0x%lx".printf(xwindow);
    }
    
    protected bool on_window_button_button_release_event(
        Gtk.Widget widget, Gdk.EventButton event
    ) {
        // FIXME: If you click the button for the parent of a modal dialog, the
        // focus stays on the dialog, but the parent’s button is activated.
        
        assert(this.window != null);
        
        if (event.button != 1) return false;
        
        var button = widget as WindowButton;
        return_val_if_fail(button != null, false);
        X.Window? xwindow = this.xwindow_to_button.ilookup(button);
        return_val_if_fail(xwindow != null, false);
        
        var xroot =
            (X.Window) Gdk.x11_drawable_get_xid(this.get_root_window());
        var msg_ev = X.Event();
        msg_ev.type = X.EventType.ClientMessage;
        msg_ev.xclient.window = xwindow;
        msg_ev.xclient.format = 32;
        
        if (button.active) {
            // Iconify the corresponding toplevel window
            
            msg_ev.xclient.message_type =
                Gdk.x11_get_xatom_by_name("WM_CHANGE_STATE");
            msg_ev.xclient.data.l[0] = Fixes.X.IconicState;
            msg_ev.xclient.data.l[1] = 0;  // Unused
            msg_ev.xclient.data.l[2] = 0;  // Unused
        }
        else {
            // Activate the corresponding toplevel window
            
            msg_ev.xclient.message_type = this.xatom__net_active_window;
            msg_ev.xclient.data.l[0] = 2;  // Source (this program) is a pager
            msg_ev.xclient.data.l[1] = event.time;  // Timestamp
            msg_ev.xclient.data.l[2] =
                (long) Gdk.x11_drawable_get_xid(this.window);
        }
        msg_ev.xclient.data.l[3] = 0;  // Unused
        msg_ev.xclient.data.l[4] = 0;  // Unused
        
        var xdisplay = Gdk.x11_display_get_xdisplay(this.get_display());
        xdisplay.send_event(
            xroot, false,
            X.EventMask.SubstructureNotifyMask
                | X.EventMask.SubstructureRedirectMask,
            ref msg_ev
        );
        
        return false;
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
        var time_str = time.format("%l:%M %P").chug();
        var date_str = @"$(time.format("%b")) $(time.get_day_of_month())";
        this.set_markup(@"<big><big>$time_str</big></big>\n$date_str");
            // TODO: make format locale-sensitive or customizable
        
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

class Window: Gtk.Window {
    protected ulong width = 150;
    
    public enum Side {
        LEFT,
        RIGHT
    }
    protected Side side = Side.RIGHT;
    
    public Window() {
        Object(type: Gtk.WindowType.TOPLEVEL);
    }
    
    construct {
        this.title = _("Gutter");
        this.gravity =
            this.side == Side.RIGHT
            ? Gdk.Gravity.NORTH_EAST : Gdk.Gravity.NORTH_WEST;
        this.skip_taskbar_hint = true;
        this.skip_pager_hint = true;
        
        var frame = new Gtk.Frame(null);
        frame.shadow_type = Gtk.ShadowType.OUT;
        frame.show();
        this.add(frame);
        
        var vbox = new Gtk.VBox(false, 5);  // TODO: remove hard-coded size
        vbox.show();
        frame.add(vbox);
        
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
    
    public override void realize() {
        base.realize();
        
        this.window.set_type_hint(Gdk.WindowTypeHint.DOCK);
        
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
}

} // end namespace Gutter

int main(string[] args) {
    Gtk.init(ref args);
    
    var window = new Gutter.Window();
    window.hide.connect((win) => Gtk.main_quit());
    window.show();
    
    Gtk.main();
    return 0;
}
