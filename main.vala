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
