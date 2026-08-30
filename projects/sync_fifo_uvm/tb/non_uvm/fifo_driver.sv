// 驱动器从 mailbox 取出事务，并按接口 clocking block 规定的时刻施加请求。
class fifo_driver #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
);

    typedef fifo_transaction #(DATA_WIDTH, DEPTH) tx_t;

    mailbox #(tx_t) gen_to_drv;

    virtual fifo_if #(DATA_WIDTH, DEPTH) vif;

    bit interface_connected;
    int unsigned received_count;
    int unsigned error_count;

    // 仅接收模式用于隔离检查 mailbox 通信，不会驱动被测设计。
    tx_t receive_only_history[$];

    function new(mailbox #(tx_t) mailbox_handle);
        this.gen_to_drv     = mailbox_handle;
        this.received_count = 0;
        this.error_count    = 0;
        this.interface_connected = 1'b0;
        this.receive_only_history.delete();
    endfunction

    function void connect_interface(
        virtual fifo_if #(DATA_WIDTH, DEPTH) interface_handle
    );
        this.vif = interface_handle;
        this.interface_connected = 1'b1;
    endfunction

    task automatic run_receive_only(input int unsigned expected_count);
        tx_t rx_tx;

        repeat (expected_count) begin
            $display("[DRIVER    t=%0t] waiting for next transaction", $time);

            gen_to_drv.get(rx_tx);

            if (rx_tx == null) begin
                error_count++;
                $error("fifo_driver received a null transaction handle");
            end else begin
                receive_only_history.push_back(rx_tx);
                received_count++;
                rx_tx.print("DRIVER_RX");
            end
        end
    endtask

    task automatic reset_dut();
        // 先制造一次复位下降沿，再在时钟下降沿释放，避免靠近采样沿。
        vif.rst_n   <= 1'b1;
        vif.wr_en   <= 1'b0;
        vif.wr_data <= '0;
        vif.rd_en   <= 1'b0;

        #2;
        vif.rst_n <= 1'b0;

        #1;
        @(negedge vif.clk);
        vif.rst_n <= 1'b1;

        $display("[DRIVER    t=%0t] DUT reset released", $time);
    endtask

    task automatic drive_transaction(input tx_t tx);
        // 下降沿驱动请求，上升沿等待被测设计完成一次状态更新。
        @(vif.drv_cb);

        vif.drv_cb.wr_en   <= tx.wr_en;
        vif.drv_cb.wr_data <= tx.wr_data;
        vif.drv_cb.rd_en   <= tx.rd_en;

        $display("[DRIVER    t=%0t] driving id=%0d op=%0s wr_data=0x%0h",
                 $time,
                 tx.transaction_id,
                 tx.operation_name(),
                 tx.wr_data);

        @(vif.mon_cb);

        received_count++;
    endtask

    task automatic run(input int unsigned expected_count);
        tx_t rx_tx;

        if (!interface_connected) begin
            $fatal(1, "fifo_driver.run() requires a connected virtual interface");
        end

        reset_dut();

        repeat (expected_count) begin
            gen_to_drv.get(rx_tx);

            if (rx_tx == null) begin
                error_count++;
                $error("fifo_driver received a null transaction handle");
            end else begin
                rx_tx.print("DRIVER_DRIVE");
                drive_transaction(rx_tx);
            end
        end

        // 所有事务结束后撤销请求，避免最后一笔操作被重复执行。
        @(vif.drv_cb);
        vif.drv_cb.wr_en   <= 1'b0;
        vif.drv_cb.wr_data <= '0;
        vif.drv_cb.rd_en   <= 1'b0;
    endtask

endclass
