# Gutter
This is a project I started for no apparent reason to make a fast, monolithic desktop panel that looks good on the right edge of the screen.

**Caution**: Since I never really used it exclusively, there is a quit button that terminates the panel (although you might think it would log you out).  So, don’t click it if you are trying to use this as your exclusive panel. ☺

At the time I thought making it monolithic (i.e., no rearrangeable applets) would make it fast, but now I’m not so sure.  My main motivation was thinking that we should not have tabs inside things like text editors because the window switcher is already designed to help us switch between documents.  I also thought we shouldn’t have multiple desktops for some reason (paradoxically, it may have been because I was still using browser tabs and the need to use the web browser for multiple activities kept pulling me back to the same desktop).  Thus, I needed space for a lot of window buttons in the switcher, which can be achieved with a vertical panel.  The [XFCE](https://xfce.org/) panel doesn’t support this very well, so I made my own.

So far the main distinctive feature is that the window switcher buttons share all the vertical space (to make them as easy as possible to click) and they pop out to show you the full title when you hover over them.

## Compiling
Currently this uses a custom `Makefile` requiring GNU make.  **Note** that, since `xfce4-vala` is not available as a Debian package, you will probably have to check it out from [the git repository](https://git.xfce.org/bindings/xfce4-vala/) and specify the directory containing `garcon-1.vapi` on the `configure` commandline using `VALAFLAGS=--vapidir=`*path*.
