class fifo_monitor #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
);

    typedef fifo_transaction #(DATA_WIDTH, DEPTH) tx_t;

    mailbox #(tx_t) observed_outbox;

    mailbox #(tx_t) coverage_outbox;
    bit coverage_connected;

    virtual fifo_if #(DATA_WIDTH, DEPTH) vif;
    bit interface_connected;
    int unsigned observed_count;

    function new(mailbox #(tx_t) observed_mailbox_handle);
        this.observed_outbox     = observed_mailbox_handle;
        this.interface_connected = 1'b0;
        this.coverage_connected  = 1'b0;
        this.observed_count      = 0;
    endfunction

    function void connect_interface(
        virtual fifo_if #(DATA_WIDTH, DEPTH) interface_handle
    );
        this.vif = interface_handle;
        this.interface_connected = 1'b1;
    endfunction

    function void connect_coverage_mailbox(
        mailbox #(tx_t) coverage_mailbox_handle
    );
        this.coverage_outbox    = coverage_mailbox_handle;
        this.coverage_connected = 1'b1;
    endfunction

    task automatic run(input int unsigned expected_count);
        tx_t observed_tx;

        if (!interface_connected) begin
            $fatal(1, "fifo_monitor.run() requires a connected virtual interface");
        end

        while (observed_count < expected_count) begin
            @(vif.mon_cb);

            if (vif.mon_cb.rst_n &&
                (vif.mon_cb.wr_en || vif.mon_cb.rd_en)) begin

                observed_tx = new();

                observed_tx.transaction_id = 64'(observed_count) + 64'd1;

                observed_tx.wr_en   = vif.mon_cb.wr_en;
                observed_tx.wr_data = vif.mon_cb.wr_data;
                observed_tx.rd_en   = vif.mon_cb.rd_en;

                observed_tx.rd_data    = vif.mon_cb.rd_data;
                observed_tx.empty      = vif.mon_cb.empty;
                observed_tx.full       = vif.mon_cb.full;
                observed_tx.data_count = vif.mon_cb.data_count;
                observed_tx.sampled    = 1'b1;

                observed_count++;

                observed_tx.print("MONITOR_TX");
                observed_outbox.put(observed_tx);

                if (coverage_connected) begin
                    coverage_outbox.put(observed_tx);
                end
            end
        end
    endtask

endclass
