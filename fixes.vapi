[CCode (cprefix = "", lower_case_cprefix = "", cheader_filename = "X11/Xutil.h,X11/Xlib.h")]
namespace XFixes {
    public const long IconicState;
    
    [CCode (cname = "XSendEvent")]
    public X.Status send_event(
        X.Display display, X.Window w, bool propagate,
        long event_mask, X.Event event_send
    );
}
