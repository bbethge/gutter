namespace Gutter {

public enum GetWindowPropertyResult {
    SUCCESS,
    FAILURE,
    BAD_WINDOW
        // An invalid window isn’t really a failure because it’s nobody’s fault
        // if the window got destroyed before you could retrieve the property
}

private GetWindowPropertyResult get_window_property(
    X.Display display,
    X.Window window,
    X.Atom property,
    bool @delete,
    X.Atom type,
    int format,
    out ulong count,
    out void *data
)
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

public GetWindowPropertyResult get_window_property32(
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

public GetWindowPropertyResult get_window_property8(
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

}  // end namespace Gutter
