namespace Gutter {

public class Monitor: Gtk.Box
    // A widget to display system resource usage
{
    protected Gtk.ProgressBar cpu = new Gtk.ProgressBar();
    protected Gtk.ProgressBar memory = new Gtk.ProgressBar();
    protected Gtk.ProgressBar swap = new Gtk.ProgressBar();
    protected LogarithmicIndicator net_up = new LogarithmicIndicator();
    protected LogarithmicIndicator net_down = new LogarithmicIndicator();
    // For debugging
    //protected LogarithmicIndicator test = new LogarithmicIndicator();
    
    protected TimeVal last_update_time = TimeVal();
    protected ulong cpu_time = get_cpu_time();
    private static long user_hz = Posix.sysconf(Posix._SC_CLK_TCK);
    
    protected ulong rx_bytes;
    protected ulong tx_bytes;
    
    public Monitor() {
        Object(
            orientation: Gtk.Orientation.HORIZONTAL, homogeneous: false,
            spacing: 1
        );
    }
    
    construct {
        get_net_info(out rx_bytes, out tx_bytes);
        
        int icon_w, icon_h;
        Gtk.icon_size_lookup(
            Gtk.IconSize.LARGE_TOOLBAR, out icon_w, out icon_h
        );
        int meter_h = icon_h;
        int meter_w = meter_h / 2;
        
        this.cpu.orientation = Gtk.Orientation.VERTICAL;
        this.cpu.inverted = true;
        this.cpu.set_size_request(meter_w, meter_h);
        this.cpu.text = Q_("Single-letter abbr. for CPU|c");
        this.cpu.show();
        this.pack_start(this.cpu, false, false, 0);
        
        this.memory.orientation = Gtk.Orientation.VERTICAL;
        this.memory.inverted = true;
        this.memory.set_size_request(meter_w, meter_h);
        this.memory.text = Q_("Single-letter abbr. for system memory|m");
        this.memory.show();
        this.pack_start(this.memory, false, false, 0);
        
        this.swap.orientation = Gtk.Orientation.VERTICAL;
        this.swap.inverted = true;
        this.swap.set_size_request(meter_w, meter_h);
        this.swap.text = Q_("Single-letter abbr. for swap space|s");
        this.swap.show();
        this.pack_start(this.swap, false, false, 0);
        
        this.net_up.orientation = Gtk.Orientation.VERTICAL;
        this.net_up.inverted = true;
        this.net_up.set_size_request(meter_w, meter_h);
        this.net_up.text = "↥";
        this.net_up.show();
        this.pack_start(this.net_up, false, false, 0);
        
        this.net_down.orientation = Gtk.Orientation.VERTICAL;
        this.net_down.inverted = true;
        this.net_down.set_size_request(meter_w, meter_h);
        this.net_down.text = "⤓";
        this.net_down.show();
        this.pack_start(this.net_down, false, false, 0);
        
        // For debugging
        //this.test.orientation = Gtk.Orientation.VERTICAL;
        //this.test.inverted = true;
        //this.test.set_size_request(meter_w, meter_h);
        //this.test.text = "?";
        //this.test.@value = 1.0;
        //this.test.show();
        //this.pack_start(this.test, false, false, 0);
        
//        Timeout.add(1000/60, () => {
//            this.test.@value *= 1.02;
//            if (this.test.@value > 1e10) {
//                this.test.@value = 1.0;
//            }
//            return true;
//        });
        
        Timeout.add_seconds(1, () => {
            TimeVal current_time = TimeVal();
            double interval =
                (double) (current_time.tv_sec - this.last_update_time.tv_sec)
                + (double)(current_time.tv_usec - this.last_update_time.tv_usec)
                    / 1000000.0;
            this.last_update_time = current_time;
            
            ulong new_cpu_time = get_cpu_time();
            if (new_cpu_time > 0) {
                this.cpu.fraction =
                    ((double)(new_cpu_time-this.cpu_time) / user_hz / interval)
                        .clamp(0.0, 1.0);
                this.cpu_time = new_cpu_time;
            }
            
            double mem_fraction, swap_fraction;
            get_memory_info(out mem_fraction, out swap_fraction);
            this.memory.fraction = mem_fraction;
            this.swap.fraction = swap_fraction;
            
            ulong new_rx_bytes, new_tx_bytes;
            get_net_info(out new_rx_bytes, out new_tx_bytes);
            this.net_up.@value =
                ((double)(new_tx_bytes-this.tx_bytes) / 1000.0 / interval);
                // use SI kB/s
            this.net_down.@value =
                ((double)(new_rx_bytes-this.rx_bytes) / 1000.0 / interval);
                // use SI kB/s
            this.tx_bytes = new_tx_bytes;
            this.rx_bytes = new_rx_bytes;
            
            return true;
        });
    }
    
    public override void get_preferred_height(
        out int minimum, out int natural
    ) {
        int height;
        this.cpu.get_size_request(null, out height);
        minimum = height;
        natural = height;
    }
    
    private static ulong get_cpu_time() {
        var stat_file = FileStream.open("/proc/stat", "r");
        if (stat_file == null) return 0;
        
        while (!stat_file.eof()) {
            ulong user, nice=0, system=0, irq=0, softirq=0;
            int items_read = stat_file.scanf(
                "cpu %lu %lu %lu %*u %*u %lu %lu",
                out user, out nice, out system, out irq, out softirq
            );
            if (items_read != FileStream.EOF && items_read > 0) {
                return user + nice + system + irq + softirq;
            }
            stat_file.scanf("%*[^\n]\n");
        }
        return 0;
    }
    
    private static void get_memory_info(
        out double mem_fraction, out double swap_fraction
    ) {
        mem_fraction = 0.0;
        swap_fraction = 0.0;
        
        var meminfo_file = FileStream.open("/proc/meminfo", "r");
        if (meminfo_file == null) return;
        
        ulong mem_total=0, mem_free=0, buffers=0, cached=0;
        ulong swap_cached=0, swap_total=0, swap_free=0;
        while (!meminfo_file.eof()) {
            var line = meminfo_file.read_line();
            if (line == null) break;
            if (line.scanf("MemTotal: %lu kB", out mem_total) == 1) continue;
            if (line.scanf("MemFree: %lu kB", out mem_free) == 1) continue;
            if (line.scanf("Buffers: %lu kB", out buffers) == 1) continue;
            if (line.scanf("Cached: %lu kB", out cached) == 1) continue;
            if (line.scanf("SwapCached: %lu kB", out swap_cached)==1) continue;
            if (line.scanf("SwapTotal: %lu kB", out swap_total) == 1) continue;
            line.scanf("SwapFree: %lu kB", out swap_free);
        }
        if (mem_total != 0) {
            mem_fraction =
                (double)(mem_total-mem_free-buffers-cached) / mem_total;
        }
        if (swap_total != 0) {
            swap_fraction =
                (double)(swap_total-swap_free-swap_cached) / swap_total;
        }
    }
    
    private static void get_net_info(out ulong rx_bytes, out ulong tx_bytes) {
        rx_bytes = 0;
        tx_bytes = 0;
        
        var net_dev_file = FileStream.open("/proc/net/dev", "r");
        warn_if_fail(net_dev_file != null);
        if (net_dev_file == null) return;
        
        while (!net_dev_file.eof()) {
            char iface_char[32] = { 0 };
            ulong iface_rx=0, iface_tx=0;
            int items_read = net_dev_file.scanf(
                " %31[a-zA-Z0-9_-] : %lu %*u %*u %*u %*u %*u %*u %*u %lu",
                ref iface_char, ref iface_rx, ref iface_tx
            );
            unowned string iface = (string) iface_char;
            net_dev_file.scanf("%*[^\n]\n");  // skip rest of line
            if (
                items_read != 3
                || iface.has_prefix("lo")
                || iface.has_prefix("bond")
            ) {
                continue;
            }
            rx_bytes += iface_rx;
            tx_bytes += iface_tx;
        }
    }
}

protected class LogarithmicIndicator: Gtk.ProgressBar {
    protected const uint n_colors = 10;
    
    public double @value {
        get { return this._value; }
        set construct {
            uint level;
            compute_level_and_fraction(this._value, out level, null);
            this.get_style_context().remove_class(@"logarithmic$level");
            
            this._value = value;
            
            double fraction;
            compute_level_and_fraction(this._value, out level, out fraction);
            this.fraction = fraction;
            this.get_style_context().add_class(@"logarithmic$level");
        }
    }
    
    protected double _value;
    
    public override void realize() {
        base.realize();
        var css_provider = new Gtk.CssProvider();
        css_provider.parsing_error.connect((p, s, e) => {
            warning("Error in hard-coded CSS: %s", e.message);
        });
        try {
            css_provider.load_from_data(
"""
@define-color level0 #373737;  /* black */
@define-color level1 #755A24;  /* brown */
@define-color level2 #AF2F2F;  /* red */
@define-color level3 #EB9A2F;  /* orange */
@define-color level4 #EBEB44;  /* yellow */
@define-color level5 #55B755;  /* green */
@define-color level6 #3A3A8E;  /* blue */
@define-color level7 #8C48CF;  /* violet */
@define-color level8 #808080;  /* gray */
@define-color level9 #EFEFEF;  /* white */

progressbar > trough,
progressbar > trough > progress {
    background-image: none;
}

progressbar.logarithmic0 > text { color: grey; }
progressbar.logarithmic1 > text { color: white; }
progressbar.logarithmic2 > text { color: white; }
progressbar.logarithmic3 > text { color: black; }
progressbar.logarithmic4 > text { color: black; }
progressbar.logarithmic5 > text { color: white; }
progressbar.logarithmic6 > text { color: white; }
progressbar.logarithmic7 > text { color: black; }
progressbar.logarithmic8 > text { color: black; }
progressbar.logarithmic9 > text { color: black; }

progressbar.logarithmic0 > trough > progress,
progressbar.logarithmic1 > trough {
    background-color: @level0;
    border-color: shade(@level0, 0.9);
}
progressbar.logarithmic1 > trough > progress,
progressbar.logarithmic2 > trough {
    background-color: @level1;
    border-color: shade(@level1, 0.9);
}
progressbar.logarithmic2 > trough > progress,
progressbar.logarithmic3 > trough {
    background-color: @level2;
    border-color: shade(@level2, 0.9);
}
progressbar.logarithmic3 > trough > progress,
progressbar.logarithmic4 > trough {
    background-color: @level3;
    border-color: shade(@level3, 0.9);
}
progressbar.logarithmic4 > trough > progress,
progressbar.logarithmic5 > trough {
    background-color: @level4;
    border-color: shade(@level4, 0.9);
}
progressbar.logarithmic5 > trough > progress,
progressbar.logarithmic6 > trough {
    background-color: @level5;
    border-color: shade(@level5, 0.9);
}
progressbar.logarithmic6 > trough > progress,
progressbar.logarithmic7 > trough {
    background-color: @level6;
    border-color: shade(@level6, 0.9);
}
progressbar.logarithmic7 > trough > progress,
progressbar.logarithmic8 > trough {
    background-color: @level7;
    border-color: shade(@level7, 0.9);
}
progressbar.logarithmic8 > trough > progress,
progressbar.logarithmic9 > trough {
    background-color: @level8;
    border-color: shade(@level8, 0.9);
}
progressbar.logarithmic9 > trough > progress,
progressbar.logarithmic0 > trough {
    background-color: @level9;
    border-color: shade(@level9, 0.9);
}
"""
            );
        }
        catch (Error e) {
            warning("Unexpected error while parsing CSS: %s", e.message);
        }
        this.get_style_context().add_provider(
            css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
    }
    
    protected static void compute_level_and_fraction(
        double @value, out uint level, out double? fraction
    ) {
        var log_val = Math.log10(@value).clamp(0, n_colors);
        level = uint.min((uint)log_val, n_colors-1);
        assert(0 <= level <= log_val <= level+1 <= n_colors);
        fraction = log_val - level;
    }
}

}  // end namespace Gutter
