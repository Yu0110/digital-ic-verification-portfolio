`ifndef FIFO_UVM_RANDOM_SEQUENCE_SV
`define FIFO_UVM_RANDOM_SEQUENCE_SV

// 约束随机序列：生成可配置数量的随机读写事务，并在末尾排空 FIFO。
// request_digest 用于确认同一随机种子能够稳定重放同一组请求。
class fifo_uvm_random_sequence #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
) extends uvm_sequence #(fifo_uvm_sequence_item #(DATA_WIDTH, DEPTH));

    typedef fifo_uvm_sequence_item #(DATA_WIDTH, DEPTH) item_t;

    `uvm_object_param_utils(fifo_uvm_random_sequence #(DATA_WIDTH, DEPTH))

    int unsigned random_transaction_count;
    int unsigned produced_count;
    int unsigned randomized_count;
    int unsigned drain_count;
    int unsigned random_read_count;
    int unsigned random_write_count;
    int unsigned random_simultaneous_count;
    int unsigned randomization_error_count;
    longint unsigned request_digest;

    function new(string name = "fifo_uvm_random_sequence");
        super.new(name);

        random_transaction_count      = 200;
        produced_count                = 0;
        randomized_count              = 0;
        drain_count                   = 0;
        random_read_count             = 0;
        random_write_count            = 0;
        random_simultaneous_count     = 0;
        randomization_error_count     = 0;
        request_digest                = 64'hCBF29CE484222325;
    endfunction

    function bit is_decimal_text(input string value_text);
        int character_index;
        byte character_code;

        if (value_text.len() == 0) begin
            return 1'b0;
        end

        for (character_index = 0;
             character_index < value_text.len();
             character_index++) begin
            character_code = value_text.getc(character_index);
            if ((character_code < 8'd48) || (character_code > 8'd57)) begin
                return 1'b0;
            end
        end

        return 1'b1;
    endfunction

    virtual task body();
        int unsigned index;
        int requested_transaction_count;
        int plusarg_status;
        string transaction_count_text;

        produced_count            = 0;
        randomized_count          = 0;
        drain_count               = 0;
        random_read_count         = 0;
        random_write_count        = 0;
        random_simultaneous_count = 0;
        randomization_error_count = 0;
        request_digest            = 64'hCBF29CE484222325;

        requested_transaction_count = 200;
        transaction_count_text      = "";
        plusarg_status              = 0;

        // 命令行参数允许回归脚本调整随机事务数量，并严格拒绝非法文本。
        if ($test$plusargs("UVM_RANDOM_TRANSACTIONS")) begin
            plusarg_status = $value$plusargs(
                "UVM_RANDOM_TRANSACTIONS=%s",
                transaction_count_text
            );

            if ((plusarg_status != 1) ||
                !is_decimal_text(transaction_count_text)) begin
                `uvm_fatal("FIFO_RAND_COUNT_FORMAT",
                           "UVM_RANDOM_TRANSACTIONS must contain only decimal digits")
                return;
            end

            plusarg_status = $sscanf(
                transaction_count_text,
                "%d",
                requested_transaction_count
            );
            if (plusarg_status != 1) begin
                `uvm_fatal("FIFO_RAND_COUNT_PARSE",
                           "UVM_RANDOM_TRANSACTIONS decimal conversion failed")
                return;
            end
        end

        if (requested_transaction_count <= 0) begin
            `uvm_fatal("FIFO_RAND_COUNT",
                       "UVM_RANDOM_TRANSACTIONS must be greater than zero")
            return;
        end

        random_transaction_count = requested_transaction_count;

        repeat (random_transaction_count) begin
            send_random_request();
        end

        for (index = 0; index < DEPTH; index++) begin
            send_drain_request(index);
        end

        if (random_operation_count() != randomized_count) begin
            `uvm_fatal("FIFO_RAND_OPERATION_COUNT",
                       $sformatf("random operation counters sum to %0d, randomized_count=%0d",
                                 random_operation_count(),
                                 randomized_count))
        end
    endtask

    function int unsigned random_operation_count();
        return random_read_count +
               random_write_count +
               random_simultaneous_count;
    endfunction

    virtual task send_random_request();
        item_t request;

        request = item_t::type_id::create(
            $sformatf("random_request_%0d", randomized_count + 1)
        );
        if (request == null) begin
            `uvm_fatal("FIFO_RAND_FACTORY",
                       "factory returned a null random sequence item")
            return;
        end

        start_item(request);

        if (request.randomize() != 1) begin
            randomization_error_count++;
            `uvm_fatal("FIFO_RAND_SOLVE",
                       $sformatf("randomization failed after %0d transactions",
                                 randomized_count))
            return;
        end

        request.transaction_id = {32'b0, produced_count} + 64'd1;

        case ({request.wr_en, request.rd_en})
            2'b01: random_read_count++;
            2'b10: random_write_count++;
            2'b11: random_simultaneous_count++;
            default: begin
                randomization_error_count++;
                `uvm_fatal("FIFO_RAND_IDLE",
                           "constraint produced an unexpected IDLE item")
                return;
            end
        endcase

        // 对操作、数据和事务编号计算轻量摘要，供随机重放一致性检查。
        request_digest =
            (request_digest * 64'd1099511628211) ^
            64'(request.wr_data) ^
            {62'b0, request.wr_en, request.rd_en} ^
            request.transaction_id;

        finish_item(request);
        randomized_count++;
        produced_count++;
    endtask

    virtual task send_drain_request(input int unsigned index);
        item_t request;

        request = item_t::type_id::create($sformatf("drain_request_%0d", index));
        if (request == null) begin
            `uvm_fatal("FIFO_DRAIN_FACTORY",
                       "factory returned a null drain sequence item")
            return;
        end

        // 最多发送 DEPTH 个只读事务，使任意合法随机结束状态都能排空。
        start_item(request);
        request.transaction_id = {32'b0, produced_count} + 64'd1;
        request.wr_en           = 1'b0;
        request.wr_data         = '0;
        request.rd_en           = 1'b1;
        finish_item(request);
        drain_count++;
        produced_count++;
    endtask

endclass

`endif
