namespace Gutter {

public class Clock: Gtk.Label {
    construct {
        this.justify = Gtk.Justification.CENTER;
    }
    
    public override void map() {
        base.map();
        
        this.on_timeout();
    }
    
    protected bool on_timeout() {
        var time = new DateTime.now_local();
        // TODO: This is horribly US-specific and non-customizable.
        int hour = (time.get_hour()+23) % 12 + 1;
        string minute = "%02d".printf(time.get_minute());
        string ampm = time.format("%P");
        string month = time.format("%b");
        int dom = time.get_day_of_month();
        this.set_markup(
            @"<big><big>$hour:$minute $ampm</big></big>\n$month $dom"
        );
        
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

}  // end namespace Gutter
