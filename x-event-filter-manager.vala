namespace Gutter {

public delegate bool XEventFilter(X.Event event);

public class XEventFilterManager {
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

}  // end namespace Gutter
