`ifndef FIFO_UVM_DRIVER_SV
`define FIFO_UVM_DRIVER_SV

// UVM 驱动器：把抽象事务转换为 FIFO 接口上的逐周期信号。
class fifo_uvm_driver #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
) extends uvm_driver #(fifo_uvm_sequence_item #(DATA_WIDTH, DEPTH));

    typedef fifo_uvm_sequence_item #(DATA_WIDTH, DEPTH) item_t;
    typedef virtual fifo_if #(DATA_WIDTH, DEPTH)        virtual_if_t;

    `uvm_component_param_utils(fifo_uvm_driver #(DATA_WIDTH, DEPTH))

    virtual_if_t vif;

    int unsigned driven_count;

    function new(string name = "fifo_uvm_driver",
                 uvm_component parent = null);
        super.new(name, parent);
        driven_count = 0;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // 虚接口由顶层通过 config_db 注入，驱动器不依赖固定层次路径。
        if (!uvm_config_db #(virtual_if_t)::get(this, "", "vif", vif)) begin
            `uvm_fatal("FIFO_DRV_NO_VIF",
                       "fifo_uvm_driver could not get virtual interface 'vif'")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        item_t request;

        reset_dut();

        forever begin
            // get_next_item/item_done 构成 driver 与 sequencer 的阻塞式握手。
            seq_item_port.get_next_item(request);

            if (request == null) begin
                `uvm_fatal("FIFO_DRV_NULL", "driver received a null sequence item")
            end

            drive_one(request);
            driven_count++;
            seq_item_port.item_done();
        end
    endtask

    virtual task reset_dut();
        // 制造异步复位下降沿，并在驱动时钟块事件上同步释放。
        vif.rst_n   <= 1'b1;
        vif.wr_en   <= 1'b0;
        vif.wr_data <= '0;
        vif.rd_en   <= 1'b0;

        #2ns;
        vif.rst_n <= 1'b0;

        #1ns;
        @(vif.drv_cb);
        vif.rst_n <= 1'b1;

        `uvm_info("FIFO_DRV_RESET",
                  $sformatf("asynchronous reset released at t=%0t", $time),
                  UVM_LOW)
    endtask

    virtual task drive_one(item_t request);
        // 下降沿驱动，上升沿等待响应，再撤销请求，确保每笔事务只占一个周期。
        @(vif.drv_cb);
        vif.drv_cb.wr_en   <= request.wr_en;
        vif.drv_cb.wr_data <= request.wr_data;
        vif.drv_cb.rd_en   <= request.rd_en;

        `uvm_info("FIFO_DRV_ITEM",
                  $sformatf("driving id=%0d op=%0s data=0x%0h at t=%0t",
                            request.transaction_id,
                            request.operation_name(),
                            request.wr_data,
                            $time),
                  UVM_LOW)

        @(vif.mon_cb);

        @(vif.drv_cb);
        vif.drv_cb.wr_en   <= 1'b0;
        vif.drv_cb.wr_data <= '0;
        vif.drv_cb.rd_en   <= 1'b0;
    endtask

endclass

`endif
