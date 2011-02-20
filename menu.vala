namespace Gutter {

public class Menu: Gtk.MenuBar {
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
        var elts = garcon_menu.get_elements().copy();
        elts.sort((e1, e2) => {
            return
                ((Garcon.MenuElement)e1).get_name()
                    .collate(((Garcon.MenuElement)e2).get_name());
        });
        foreach (var elt in elts) {
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
            else if (elt is Garcon.MenuItem) {
                // FIXME: When we make a closure that references ‘elt’, the data
                // block for that closure never gets initialized.
                var garcon_mi = (Garcon.MenuItem) elt;
                item.activate.connect((mi) => {
                    on_menu_item_activate(mi, garcon_mi);
                });
            }
            item.show();
            menu.append(item);
        }
    }
    
    static void on_menu_item_activate(
        Gtk.MenuItem gtk_item, Garcon.MenuItem item
    ) {
        return_if_fail(item.command != null);
        
        string[] args;
        try {
            Shell.parse_argv(item.command, out args);
        }
        catch (ShellError err) {
            // TODO: Graphical error message?  (See also every other error
            // handler in this function.)
            warning(
                "Unable to parse command line ‘%s’: %s",
                item.command, err.message
            );
            return;
        }
        
        //Regex percent_escape;
        //try {
        //    percent_escape = new Regex("%.");
        //}
        //catch (RegexError err) {
        //    return_if_reached();
        //}
        
        string?[] new_args = new string[0];
        foreach (var arg in args) {
            if (arg == "%F" || arg == "%U") continue;  // Ignore these
            if (arg == "%i") {
                if (item.icon_name != null) {
                    new_args += "--icon";
                    new_args += item.icon_name;
                }
                continue;
            }
            
            unowned string rem = arg;
            var new_arg = new StringBuilder.sized(arg.length);
            while (rem != "") {
                var next_percent = rem.str("%");
                if (next_percent == null) {
                    new_arg.append(rem);
                    break;
                }
                new_arg.append_len(
                    rem, (ssize_t) ((char*)next_percent-(char*)rem)
                );
                rem = next_percent.next_char();
                if (rem == "") break;
                
                switch (rem[0]) {
                case '%':
                    new_arg.append_c('%');
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
                    new_arg.append(item.name);
                    break;
                case 'k':
                    new_arg.append(item.file.get_path());
                    break;
                default:
                    warning("Invalid field code in command line");
                    return;
                }
                
                rem = rem.next_char();
            }
            //bool err = false;
            //string? new_arg;
            //try {
            //    new_arg = percent_escape.replace_eval(
            //        arg, arg.length, 0, 0,
            //        (match, result) => {
            //            switch (match.fetch(0)[1]) {
            //            case '%':
            //                result.append_c('%');
            //                break;
            //            case 'f':
            //            case 'u':
            //            case 'd':
            //            case 'D':
            //            case 'n':
            //            case 'N':
            //            case 'v':
            //            case 'm':
            //                // Ignore these
            //                break;
            //            case 'c':
            //                result.append(item.name);
            //                break;
            //            case 'k':
            //                result.append(item.file.get_path());
            //                break;
            //            default:
            //                warning("Invalid field code in command line");
            //                err = true;
            //                return true;
            //            }
            //            return false;
            //        }
            //    );
            //}
            //catch (RegexError err) {
            //    // TODO: More error reporting?
            //    return;
            //}
            //if (err) return;
            new_args += new_arg.str;
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

}  // end namespace Gutter
