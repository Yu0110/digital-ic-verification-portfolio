// 生成器只负责创建事务，不接触接口信号。
// 事务通过 mailbox 发送给驱动器，实现激励生成与时序驱动解耦。
class fifo_generator #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
);

    typedef fifo_transaction #(DATA_WIDTH, DEPTH) tx_t;

    mailbox #(tx_t) gen_to_drv;

    int unsigned sent_count;
    int unsigned randomized_count;
    int unsigned random_read_count;
    int unsigned random_write_count;
    int unsigned random_simultaneous_count;
    int unsigned randomization_error_count;

    function new(mailbox #(tx_t) mailbox_handle);
        this.gen_to_drv = mailbox_handle;
        this.sent_count = 0;
        this.randomized_count           = 0;
        this.random_read_count          = 0;
        this.random_write_count         = 0;
        this.random_simultaneous_count  = 0;
        this.randomization_error_count  = 0;
    endfunction

    task automatic send_request(
        input longint unsigned        transaction_id,
        input bit                     wr_en,
        input bit [DATA_WIDTH-1:0]    wr_data,
        input bit                     rd_en
    );
        tx_t tx;

        tx = new();
        tx.transaction_id = transaction_id;
        tx.wr_en          = wr_en;
        tx.wr_data        = wr_data;
        tx.rd_en          = rd_en;

        $display("[GENERATOR t=%0t] sending id=%0d op=%0s",
                 $time, tx.transaction_id, tx.operation_name());

        gen_to_drv.put(tx);
        sent_count++;
    endtask

    task automatic send_random_request();
        tx_t tx;

        tx = new();

        // 随机化失败必须立即终止，不能把无效事务送入后续组件。
        if (tx.randomize() != 1) begin
            randomization_error_count++;
            $fatal(1,
                   "FIFO transaction randomization failed after %0d successful random transactions",
                   randomized_count);
        end

        tx.transaction_id = 64'(sent_count) + 64'd1;

        case ({tx.wr_en, tx.rd_en})
            2'b01: random_read_count++;
            2'b10: random_write_count++;
            2'b11: random_simultaneous_count++;
            default: begin
                randomization_error_count++;
                $fatal(1,
                       "Random constraint produced an unexpected IDLE transaction");
            end
        endcase

        $display("[GENERATOR t=%0t] random id=%0d op=%0s wr_data=0x%0h",
                 $time,
                 tx.transaction_id,
                 tx.operation_name(),
                 tx.wr_data);

        gen_to_drv.put(tx);
        randomized_count++;
        sent_count++;
    endtask

    task automatic send_next_request(
        input bit                  wr_en,
        input bit [DATA_WIDTH-1:0] wr_data,
        input bit                  rd_en
    );
        send_request(64'(sent_count) + 64'd1, wr_en, wr_data, rd_en);
    endtask

    task automatic run();
        send_next_request(1'b1, DATA_WIDTH'(8'ha5), 1'b0);

        send_next_request(1'b1, DATA_WIDTH'(8'h3c), 1'b0);

        send_next_request(1'b0, '0, 1'b1);

        send_next_request(1'b1, DATA_WIDTH'(8'h7e), 1'b1);

        send_next_request(1'b0, '0, 1'b1);
    endtask

    task automatic run_boundary();
        int unsigned index;

        // 依次覆盖空读、空时并发、填满、满写、满时并发和多次指针回卷。
        send_next_request(1'b0, '0, 1'b1);

        send_next_request(1'b1, DATA_WIDTH'(8'ha0), 1'b1);

        send_next_request(1'b0, '0, 1'b1);

        for (index = 0; index < DEPTH; index++) begin
            send_next_request(
                1'b1,
                DATA_WIDTH'(8'h40 + index),
                1'b0
            );
        end

        send_next_request(1'b1, DATA_WIDTH'(8'hee), 1'b0);

        send_next_request(1'b1, DATA_WIDTH'(8'hf0), 1'b1);

        send_next_request(1'b1, DATA_WIDTH'(8'hc0), 1'b1);

        for (index = 0; index < DEPTH - 1; index++) begin
            send_next_request(1'b0, '0, 1'b1);
        end

        send_next_request(1'b0, '0, 1'b1);

        send_next_request(1'b1, DATA_WIDTH'(8'h10), 1'b0);

        for (index = 0; index < (3 * DEPTH); index++) begin
            send_next_request(
                1'b1,
                DATA_WIDTH'(8'h20 + index),
                1'b1
            );
        end

        send_next_request(1'b0, '0, 1'b1);
    endtask

    task automatic run_random(input int unsigned random_transaction_count);
        int unsigned index;

        repeat (random_transaction_count) begin
            send_random_request();
        end

        // 随机激励结束后最多读取 DEPTH 次，确保参考模型最终排空。
        for (index = 0; index < DEPTH; index++) begin
            send_next_request(1'b0, '0, 1'b1);
        end
    endtask

endclass
