class fifo_reference_model #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
);

    localparam int COUNT_WIDTH = (DEPTH >= 1) ? $clog2(DEPTH + 1) : 1;
    typedef fifo_transaction #(DATA_WIDTH, DEPTH) tx_t;
    bit [DATA_WIDTH-1:0] expected_queue[$];
    logic [DATA_WIDTH-1:0] expected_rd_data;
    int unsigned prediction_count;

    function new();
        expected_queue.delete();
        expected_rd_data = '0;
        prediction_count = 0;
    endfunction

    function tx_t predict(input tx_t request_tx);
        tx_t expected_tx;
        int unsigned count_before;
        bit write_accepted;
        bit read_accepted;

        if (request_tx == null) begin
            $fatal(1, "fifo_reference_model.predict() received a null transaction handle");
        end

        expected_tx = new();

        count_before  = expected_queue.size();
        write_accepted = request_tx.wr_en && (count_before < DEPTH);
        read_accepted  = request_tx.rd_en && (count_before > 0);

        if (read_accepted) begin
            expected_rd_data = expected_queue.pop_front();
        end

        if (write_accepted) begin
            expected_queue.push_back(request_tx.wr_data);
        end

        expected_tx.transaction_id = request_tx.transaction_id;
        expected_tx.wr_en          = request_tx.wr_en;
        expected_tx.wr_data        = request_tx.wr_data;
        expected_tx.rd_en          = request_tx.rd_en;

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
