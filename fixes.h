#ifndef _GUTTER_FIXES_H
#define _GUTTER_FIXES_H

typedef union {
    char b[20];
    short s[10];
    long l[5];
} XClientMessageEventData;

typedef struct {
        int type;
        unsigned long serial;   /* # of last request processed by server */
        Bool send_event;        /* true if this came from a SendEvent request */
        Display *display;       /* Display the event was read from */
        Window window;
        Atom message_type;
        int format;
        XClientMessageEventData data;
} XFixesClientMessageEvent;

#endif
