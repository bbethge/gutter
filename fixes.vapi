// This is a manually written file to make up for deficiencies in Vala bindings.

[CCode (cprefix = "", lower_case_cprefix = "", cheader_filename = "X11/X.h,X11/Xutil.h,X11/Xlib.h")]
namespace XFixes  // Not to be confused with the XFixes X extension, I guess.
{
    public const long IconicState;
    
    public const int PropertyNewValue;
    public const int PropertyDelete;
    
    public const int BadAlloc;
    public const int BadAtom;
    public const int BadValue;
    public const int BadWindow;
    
    [CCode (cname = "XSendEvent")]
    public X.Status send_event(
        X.Display display, X.Window w, bool propagate,
        long event_mask, X.Event event_send
    );
}
