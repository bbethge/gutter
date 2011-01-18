public class Bimap<D, R> {
    [Compact]
    protected class Record<D, R> {
        public D input;
        public R output;
    }
    
    protected SList<Record<D, R> > records = new SList<Record<D, R> > ();
    protected EqualFunc input_equal_func;
    protected EqualFunc output_equal_func;
    
    public Bimap(
        EqualFunc input_equal_func, EqualFunc output_equal_func
    ) {
        this.input_equal_func = input_equal_func;
        this.output_equal_func = output_equal_func;
    }
    
    public unowned R? lookup(D input) {
        for (
            unowned SList<Record<D, R> > iter = this.records;
            iter != null;
            iter = iter.next
        ) {
            if (this.input_equal_func(iter.data.input, input)) {
                return iter.data.output;
            }
        }
        return null;
    }
    
    public unowned D? ilookup(R output) {
        for (
            unowned SList<Record<D, R> > iter = this.records;
            iter != null;
            iter = iter.next
        ) {
            if (this.output_equal_func(iter.data.output, output)) {
                return iter.data.input;
            }
        }
        return null;
    }
    
    public void insert(D input, R output) {
        this.remove(input);
        this.iremove(output);
        var record = new Record<D, R> ();
        record.input = input;
        record.output = output;
        this.records.prepend((owned) record);
    }
    
    public void remove(D input) {
        for (
            unowned SList<Record<D, R> > iter = this.records;
            iter != null;
            iter = iter.next
        ) {
            if (this.input_equal_func(iter.data.input, input)) {
                iter.data = null;
                this.records.delete_link(iter);
                // Note that ‘iter’ is now invalid, so we don’t use it any more
                break;
            }
        }
    }
    
    public void iremove(R output) {
        for (
            unowned SList<Record<D, R> > iter = this.records;
            iter != null;
            iter = iter.next
        ) {
            if (this.output_equal_func(iter.data.output, output)) {
                iter.data = null;
                this.records.delete_link(iter);
                // Note that ‘iter’ is now invalid, so we don’t use it any more
                break;
            }
        }
    }
    
    [Compact]
    public class Iterator<D, R> {
        protected unowned SList<Record<D, R> > link;
        
        public Iterator(SList<Record<D, R> > start) {
            this.link = start;
        }
        
        public unowned D? next_value() {
            unowned D? result = null;
            if (this.link != null) {
                result = this.link.data.input;
                this.link = this.link.next;
            }
            return result;
        }
    }
    
    public Iterator<D, R> iterator() {
        return new Iterator<D, R> (this.records);
    }
}
