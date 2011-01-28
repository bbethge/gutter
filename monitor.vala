namespace Gutter {

public class Monitor: Gtk.HBox
    // A widget to display system resource usage
{
    protected Gtk.ProgressBar cpu = new Gtk.ProgressBar();
    protected Gtk.ProgressBar memory = new Gtk.ProgressBar();
    protected Gtk.ProgressBar swap = new Gtk.ProgressBar();
    protected LogarithmicIndicator net_up = new LogarithmicIndicator();
    protected LogarithmicIndicator net_down = new LogarithmicIndicator();
    
    protected ulong cpu_time = get_cpu_time();
    private static const long user_hz = Posix.sysconf(Posix._SC_CLK_TCK);
    
    protected ulong rx_bytes;
    protected ulong tx_bytes;
    
    public Monitor() {
        Object(homogeneous: false, spacing: 1);
    }
    
    construct {
        get_net_info(out rx_bytes, out tx_bytes);
        
        int icon_w, icon_h;
        Gtk.icon_size_lookup(
            Gtk.IconSize.LARGE_TOOLBAR, out icon_w, out icon_h
        );
        int meter_h = icon_h;
        int meter_w = meter_h / 2;
        
        this.cpu.orientation = Gtk.ProgressBarOrientation.BOTTOM_TO_TOP;
        this.cpu.set_size_request(meter_w, meter_h);
        this.cpu.text = Q_("Single-letter abbr. for CPU|c");
        this.cpu.show();
        this.pack_start(this.cpu, false, false, 0);
        
        this.memory.orientation = Gtk.ProgressBarOrientation.BOTTOM_TO_TOP;
        this.memory.set_size_request(meter_w, meter_h);
        this.memory.text = Q_("Single-letter abbr. for system memory|m");
        this.memory.show();
        this.pack_start(this.memory, false, false, 0);
        
        this.swap.orientation = Gtk.ProgressBarOrientation.BOTTOM_TO_TOP;
        this.swap.set_size_request(meter_w, meter_h);
        this.swap.text = Q_("Single-letter abbr. for swap space|s");
        this.swap.show();
        this.pack_start(this.swap, false, false, 0);
        
        this.net_up.orientation = Gtk.ProgressBarOrientation.BOTTOM_TO_TOP;
        this.net_up.set_size_request(meter_w, meter_h);
        this.net_up.text = "↑";
        this.net_up.show();
        this.pack_start(this.net_up, false, false, 0);
        
        this.net_down.orientation = Gtk.ProgressBarOrientation.BOTTOM_TO_TOP;
        this.net_down.set_size_request(meter_w, meter_h);
        this.net_down.text = "↓";
        this.net_down.show();
        this.pack_start(this.net_down, false, false, 0);
        
        Timeout.add_seconds(1, () => {
            // TODO: account for unpredictable time interval
            ulong new_cpu_time = get_cpu_time();
            if (new_cpu_time > 0) {
                this.cpu.fraction =
                    (double)(new_cpu_time-this.cpu_time) / user_hz;
                this.cpu_time = new_cpu_time;
            }
            
            double mem_fraction, swap_fraction;
            get_memory_info(out mem_fraction, out swap_fraction);
            this.memory.fraction = mem_fraction;
            this.swap.fraction = swap_fraction;
            
            ulong new_rx_bytes, new_tx_bytes;
            get_net_info(out new_rx_bytes, out new_tx_bytes);
            this.net_up.indicated_value =
                (double)(new_tx_bytes-this.tx_bytes) / 1000.0;  // use SI kB/s
            this.net_down.indicated_value =
                (double)(new_rx_bytes-this.rx_bytes) / 1000.0;  // use SI kB/s
            this.tx_bytes = new_tx_bytes;
            this.rx_bytes = new_rx_bytes;
            
            return true;
        });
    }
    
    private static ulong get_cpu_time() {
        var stat_file = FileStream.open("/proc/stat", "r");
        if (stat_file == null) return 0;
        
        while (!stat_file.eof()) {
            ulong user, nice=0, system=0, irq=0, softirq=0;
            int items_read = stat_file.scanf(
                "cpu %ul %ul %ul %*ul %*ul %ul %ul",
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
        if (net_dev_file == null) return;
        
        while (!net_dev_file.eof()) {
            char iface_char[32] = { 0 };
            ulong iface_rx=0, iface_tx=0;
            int items_read = net_dev_file.scanf(
                " %31[a-zA-Z0-9_-]:"
                +" %lu %*lu %*lu %*lu %*lu %*lu %*lu %*lu %lu",
                ref iface_char, ref iface_rx, ref iface_tx
            );
            net_dev_file.scanf("%*[^\n]\n");
            unowned string iface = (string) iface_char;
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
    public double indicated_value {
        get { return this._value; }
        set {
            this._value = value;
            
            if (this._value > 0.0) {
                var log_val = Math.log10(this._value);
                var level = ((int)log_val).clamp(0, 10/*colors.length*/-1);
                
                this.fraction =
                    double.min(1.0, Math.exp(Math.LN10 * (log_val-level-1)));
                    // (exp10 is less standard than log10)
                this.modify_bg(Gtk.StateType.SELECTED, colors[level]);
                this.modify_fg(Gtk.StateType.NORMAL, colors[level]);
                if (level > 0) {
                    this.modify_bg(Gtk.StateType.NORMAL, colors[level-1]);
                    this.modify_fg(Gtk.StateType.SELECTED, colors[level-1]);
                }
                else {
                    this.modify_bg(Gtk.StateType.NORMAL, null);
                    this.modify_fg(Gtk.StateType.SELECTED, null);
                }
            }
            else {
                this.fraction = 0.0;
                this.modify_bg(Gtk.StateType.SELECTED, null);
                this.modify_fg(Gtk.StateType.SELECTED, null);
                this.modify_bg(Gtk.StateType.NORMAL, null);
                this.modify_fg(Gtk.StateType.NORMAL, null);
            }
        }
    }
    
    protected double _value;
    
    protected class Gdk.Color[] colors = {
        Gdk.Color() { red=0x3737, green=0x3737, blue=0x3737 },  // black
        Gdk.Color() { red=0x7575, green=0x5A5A, blue=0x2424 },  // brown
        Gdk.Color() { red=0xCCCC, green=0x4747, blue=0x4747 },  // red
        Gdk.Color() { red=0xFFFF, green=0xAAAA, blue=0x3939 },  // orange
        Gdk.Color() { red=0xDCDC, green=0xDCDC, blue=0x4040 },  // yellow
        Gdk.Color() { red=0x5555, green=0xB7B7, blue=0x5555 },  // green
        Gdk.Color() { red=0x3A3A, green=0x3A3A, blue=0x8E8E },  // blue
        Gdk.Color() { red=0x8C8C, green=0x4848, blue=0xCFCF },  // violet
        Gdk.Color() { red=0x8080, green=0x8080, blue=0x8080 },  // gray
        Gdk.Color() { red=0xEFEF, green=0xEFEF, blue=0xEFEF }   // white
    };
}

}  // end namespace Gutter
