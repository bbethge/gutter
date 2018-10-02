// This is a manually written file to make up for deficiencies in Vala bindings.

[CCode (cprefix = "", lower_case_cprefix = "", cheader_filename = "X11/X.h,X11/Xutil.h,X11/Xlib.h,fixes.h")]
namespace XFixes  // Not to be confused with the XFixes X extension, I guess.
{
    public const long IconicState;
    
    public const int PropertyNewValue;
    public const int PropertyDelete;
    
    public const int BadAlloc;
    public const int BadAtom;
    public const int BadValue;
    public const int BadWindow;
    
    [CCode (cname = "XFixesClientMessageEvent", has_type_id = false)]
	public struct ClientMessageEvent {
		public int type;
		public ulong serial;	/* # of last request processed by server */
		public bool send_event;	/* true if this came from a SendEvent request */
		public unowned X.Display display;	/* Display the event was read from */
		public X.Window window;
		public X.Atom message_type;
		public int format;
		public ClientMessageEventData data;
	}
	
	[CCode (cname = "XClientMessageEventData", has_type_id = false)]
	public struct ClientMessageEventData {
	    [CCode (array_length = false)]
		public unowned char[] b;
	    [CCode (array_length = false)]
		public unowned short[] s;
	    [CCode (array_length = false)]
		public unowned long[] l;
	}
	
    [CCode (cname = "XSendEvent")]
    public X.Status send_event(
        X.Display display, X.Window w, bool propagate,
        long event_mask, X.Event event_send
    );
}
