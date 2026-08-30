`ifndef FIFO_UVM_REFERENCE_MODEL_SV
`define FIFO_UVM_REFERENCE_MODEL_SV

// UVM 参考模型用软件队列独立预测 FIFO 行为，不访问 DUT 内部实现。
class fifo_uvm_reference_model #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
) extends uvm_object;

    localparam int COUNT_WIDTH = $clog2(DEPTH + 1);
    typedef fifo_uvm_sequence_item #(DATA_WIDTH, DEPTH) item_t;

    `uvm_object_param_utils(fifo_uvm_reference_model #(DATA_WIDTH, DEPTH))

    // 队列状态与 DUT 的指针、标志和存储阵列完全独立。
    bit [DATA_WIDTH-1:0] expected_queue[$];
    logic [DATA_WIDTH-1:0] expected_rd_data;
    int unsigned prediction_count;

    function new(string name = "fifo_uvm_reference_model");
        super.new(name);

        if (DATA_WIDTH <= 0) begin
            `uvm_fatal("FIFO_REF_DATA_WIDTH",
                       "reference model requires DATA_WIDTH greater than 0")
        end

        if (DEPTH < 2) begin
            `uvm_fatal("FIFO_REF_DEPTH",
                       "reference model requires DEPTH greater than or equal to 2")
        end

        reset_model();
    endfunction

    function void reset_model();
        expected_queue.delete();
        expected_rd_data = '0;
        prediction_count = 0;
    endfunction

    function item_t predict(input item_t observed_tx);
        item_t expected_tx;
        int unsigned count_before;
        bit write_accepted;
        bit read_accepted;

        if (observed_tx == null) begin
            `uvm_fatal("FIFO_REF_NULL",
                       "reference model received a null observed transaction")
            return null;
        end

        expected_tx = item_t::type_id::create(
            $sformatf("expected_tx_%0d", prediction_count + 1)
        );
        if (expected_tx == null) begin
            `uvm_fatal("FIFO_REF_FACTORY",
                       "factory returned a null expected transaction")
            return null;
        end

        count_before   = expected_queue.size();

        if (count_before > DEPTH) begin
            `uvm_fatal("FIFO_REF_PRE_RANGE",
                       $sformatf("reference queue size %0d exceeded DEPTH %0d before prediction",
                                 count_before,
                                 DEPTH))
        end

        // 接受条件按操作前状态计算，精确对应空时和满时的边界规格。
        write_accepted = observed_tx.wr_en && (count_before < DEPTH);
        read_accepted  = observed_tx.rd_en && (count_before > 0);

        // 同时读写时先取出旧队首，再把新数据加入队尾。
        if (read_accepted) begin
            expected_rd_data = expected_queue.pop_front();
        end

        if (write_accepted) begin
            expected_queue.push_back(observed_tx.wr_data);
        end

        if (expected_queue.size() > DEPTH) begin
            `uvm_fatal("FIFO_REF_POST_RANGE",
                       $sformatf("reference queue size %0d exceeded DEPTH %0d after prediction",
                                 expected_queue.size(),
                                 DEPTH))
        end

        expected_tx.transaction_id = observed_tx.transaction_id;
        expected_tx.wr_en          = observed_tx.wr_en;
        expected_tx.wr_data        = observed_tx.wr_data;
        expected_tx.rd_en          = observed_tx.rd_en;

        expected_tx.rd_data    = expected_rd_data;
        expected_tx.data_count = COUNT_WIDTH'(expected_queue.size());
        expected_tx.empty      = (expected_queue.size() == 0);
        expected_tx.full       = (expected_queue.size() == DEPTH);
        expected_tx.sampled    = 1'b1;

        prediction_count++;
        return expected_tx;
    endfunction

    function int unsigned queue_size();
        return expected_queue.size();
    endfunction

endclass

`endif
