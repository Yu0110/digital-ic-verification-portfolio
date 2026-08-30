`ifndef FIFO_UVM_MONITOR_SV
`define FIFO_UVM_MONITOR_SV

// UVM 监视器：被动采样接口，并通过 analysis port 广播完整事务。
class fifo_uvm_monitor #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
) extends uvm_monitor;

    typedef fifo_uvm_sequence_item #(DATA_WIDTH, DEPTH) item_t;
    typedef virtual fifo_if #(DATA_WIDTH, DEPTH)        virtual_if_t;

    `uvm_component_param_utils(fifo_uvm_monitor #(DATA_WIDTH, DEPTH))

    virtual_if_t vif;

    uvm_analysis_port #(item_t) observed_ap;

    int unsigned observed_count;

    function new(string name = "fifo_uvm_monitor",
                 uvm_component parent = null);
        super.new(name, parent);

        observed_ap    = new("observed_ap", this);
        observed_count = 0;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db #(virtual_if_t)::get(this, "", "vif", vif)) begin
            `uvm_fatal("FIFO_MON_NO_VIF",
                       "fifo_uvm_monitor could not get virtual interface 'vif'")
        end
    endfunction

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);

        // 没有订阅者意味着采样结果无人检查，应在仿真开始前直接报错。
        if (observed_ap.size() == 0) begin
            `uvm_fatal("FIFO_MON_NO_SUBSCRIBER",
                       "fifo_uvm_monitor analysis port has no subscriber")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        item_t observed_tx;

        `uvm_info("FIFO_MON_START",
                  "fifo_uvm_monitor entered run_phase and is waiting on mon_cb",
                  UVM_LOW)

        forever begin
            @(vif.mon_cb);

            // 工具兼容说明：在 Verilator 5.050 中，虚拟 clocking block
            // 输入可能滞后一拍，因此等待 mon_cb 事件后直接读取接口信号。
            if ($isunknown({vif.rst_n,
                            vif.wr_en,
                            vif.wr_data,
                            vif.rd_en,
                            vif.rd_data,
                            vif.empty,
                            vif.full,
                            vif.data_count})) begin
                `uvm_fatal("FIFO_MON_UNKNOWN",
                           $sformatf("monitor sampled X/Z on FIFO interface at t=%0t",
                                     $time))
            end

            if ((vif.rst_n === 1'b1) &&
                ((vif.wr_en === 1'b1) || (vif.rd_en === 1'b1))) begin

                observed_tx = item_t::type_id::create(
                    $sformatf("observed_tx_%0d", observed_count + 1)
                );

                if (observed_tx == null) begin
                    `uvm_fatal("FIFO_MON_FACTORY",
                               "factory returned a null observed transaction")
                end

                observed_tx.transaction_id = {32'b0, observed_count} + 64'd1;

                observed_tx.wr_en   = vif.wr_en;
                observed_tx.wr_data = vif.wr_data;
                observed_tx.rd_en   = vif.rd_en;

                observed_tx.rd_data    = vif.rd_data;
                observed_tx.empty      = vif.empty;
                observed_tx.full       = vif.full;
                observed_tx.data_count = vif.data_count;
                observed_tx.sampled    = 1'b1;

                observed_count++;

                `uvm_info("FIFO_MON_ITEM",
                          $sformatf("observed id=%0d op=%0s wr_data=0x%0h rd_data=0x%0h count=%0d empty=%0b full=%0b",
                                    observed_tx.transaction_id,
                                    observed_tx.operation_name(),
                                    observed_tx.wr_data,
                                    observed_tx.rd_data,
                                    observed_tx.data_count,
                                    observed_tx.empty,
                                    observed_tx.full),
                          UVM_LOW)

                // analysis port 会把同一笔只读事务广播给记分板和覆盖率收集器。
                observed_ap.write(observed_tx);
            end
        end
    endtask

endclass

`endif
