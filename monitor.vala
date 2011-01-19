namespace Gutter {

class Monitor: Gtk.HBox
    // A widget to display system resource usage
{
    protected Gtk.ProgressBar cpu = new Gtk.ProgressBar();
    protected Gtk.ProgressBar memory = new Gtk.ProgressBar();
    protected Gtk.ProgressBar swap = new Gtk.ProgressBar();
    
    protected ulong cpu_time = get_cpu_time();
    private static const long user_hz = Posix.sysconf(Posix._SC_CLK_TCK);
    
    construct {
        int icon_w, icon_h;
        Gtk.icon_size_lookup(
            Gtk.IconSize.LARGE_TOOLBAR, out icon_w, out icon_h
        );
        int meter_h = icon_h;
        int meter_w = meter_h / 2;
        
        this.cpu.orientation = Gtk.ProgressBarOrientation.BOTTOM_TO_TOP;
        this.cpu.set_size_request(meter_w, meter_h);
        this.cpu.show();
        this.pack_start(this.cpu, false, false, 0);
        
        this.memory.orientation = Gtk.ProgressBarOrientation.BOTTOM_TO_TOP;
        this.memory.set_size_request(meter_w, meter_h);
        this.memory.show();
        this.pack_start(this.memory, false, false, 0);
        
        this.swap.orientation = Gtk.ProgressBarOrientation.BOTTOM_TO_TOP;
        this.swap.set_size_request(meter_w, meter_h);
        this.swap.show();
        this.pack_start(this.swap, false, false, 0);
        
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
}

}  // end namespace Gutter
