`ifndef FIFO_UVM_COVERAGE_SV
`define FIFO_UVM_COVERAGE_SV

// 功能覆盖率收集器：统计操作类型、操作前状态和操作后数据量。
// 手工命中矩阵用于稳定的回归门槛，covergroup 用于标准覆盖率报告。
class fifo_uvm_coverage #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
) extends uvm_subscriber #(fifo_uvm_sequence_item #(DATA_WIDTH, DEPTH));

    typedef fifo_uvm_sequence_item #(DATA_WIDTH, DEPTH) item_t;

    `uvm_component_param_utils(fifo_uvm_coverage #(DATA_WIDTH, DEPTH))

    int unsigned count_before;
    int unsigned received_count;
    int unsigned sample_count;
    int unsigned error_count;
    int unsigned operation_state_hits[3][3];
    int unsigned count_after_hits[DEPTH + 1];

    // 交叉覆盖回答“每种操作是否在空、中间、满三种状态都发生过”。
    covergroup fifo_behavior_cg with function sample(
        bit [1:0] operation,
        int unsigned count_before_sample,
        int unsigned count_after_sample
    );
        option.per_instance = 1;

        operation_cp: coverpoint operation {
            bins read           = {2'b01};
            bins write          = {2'b10};
            bins write_and_read = {2'b11};
        }

        count_before_state_cp: coverpoint count_before_sample {
            bins empty  = {0};
            bins middle = {[1:DEPTH-1]};
            bins full   = {DEPTH};
        }

        count_after_cp: coverpoint count_after_sample {
            bins each_level[] = {[0:DEPTH]};
        }

        operation_state_cross: cross operation_cp, count_before_state_cp;
    endgroup

    function new(string name = "fifo_uvm_coverage",
                 uvm_component parent = null);
        int operation_index;
        int state_index;
        int count_index;

        super.new(name, parent);

        count_before   = 0;
        received_count = 0;
        sample_count   = 0;
        error_count    = 0;

        for (operation_index = 0; operation_index < 3; operation_index++) begin
            for (state_index = 0; state_index < 3; state_index++) begin
                operation_state_hits[operation_index][state_index] = 0;
            end
        end

        for (count_index = 0; count_index <= DEPTH; count_index++) begin
            count_after_hits[count_index] = 0;
        end

        fifo_behavior_cg = new();
    endfunction

    function int operation_to_index(input bit [1:0] operation);
        case (operation)
            2'b01: return 0;
            2'b10: return 1;
            2'b11: return 2;
            default: return -1;
        endcase
    endfunction

    function int count_to_state_index(input int unsigned count_value);
        if (count_value == 0) begin
            return 0;
        end

        if (count_value == DEPTH) begin
            return 2;
        end

        if (count_value < DEPTH) begin
            return 1;
        end

        return -1;
    endfunction

    virtual function void write(item_t actual_tx);
        bit [1:0] operation;
        int operation_index;
        int state_index;
        int unsigned count_after;

        received_count++;

        if (actual_tx == null) begin
            error_count++;
            `uvm_error("FIFO_COV_NULL",
                       "coverage collector received a null transaction")
            return;
        end

        operation = {actual_tx.wr_en, actual_tx.rd_en};

        if ($isunknown(actual_tx.data_count)) begin
            error_count++;
            `uvm_error("FIFO_COV_UNKNOWN",
                       $sformatf("coverage sample id=%0d contains X/Z in data_count",
                                 actual_tx.transaction_id))
            return;
        end

        count_after = 32'(actual_tx.data_count);

        // count_before 保存上一笔事务结束状态，即本笔事务开始状态。
        operation_index = operation_to_index(operation);
        state_index     = count_to_state_index(count_before);

        if (!actual_tx.sampled ||
            (operation_index < 0) ||
            (state_index < 0) ||
            (count_after > DEPTH)) begin
            error_count++;
            `uvm_error("FIFO_COV_INVALID",
                       $sformatf("invalid sample id=%0d sampled=%0b operation=%0b count_before=%0d count_after=%0d",
                                 actual_tx.transaction_id,
                                 actual_tx.sampled,
                                 operation,
                                 count_before,
                                 count_after))
            return;
        end

        fifo_behavior_cg.sample(operation, count_before, count_after);
        operation_state_hits[operation_index][state_index]++;
        count_after_hits[count_after]++;
        sample_count++;

        // 更新后状态成为下一笔事务的操作前状态。
        count_before = count_after;
    endfunction

    function real coverage_percent();
        return fifo_behavior_cg.get_inst_coverage();
    endfunction

    function int unsigned operation_state_hit_total();
        int operation_index;
        int state_index;
        int unsigned total;

        total = 0;
        // 所有操作/状态组合以及 0..DEPTH 每个数据量级别都必须命中。
        for (operation_index = 0; operation_index < 3; operation_index++) begin
            for (state_index = 0; state_index < 3; state_index++) begin
                total += operation_state_hits[operation_index][state_index];
            end
        end

        return total;
    endfunction

    function int unsigned count_after_hit_total();
        int count_index;
        int unsigned total;

        total = 0;
        for (count_index = 0; count_index <= DEPTH; count_index++) begin
            total += count_after_hits[count_index];
        end

        return total;
    endfunction

    function bit all_goals_hit();
        int operation_index;
        int state_index;
        int count_index;

        for (operation_index = 0; operation_index < 3; operation_index++) begin
            for (state_index = 0; state_index < 3; state_index++) begin
                if (operation_state_hits[operation_index][state_index] == 0) begin
                    return 1'b0;
                end
            end
        end

        for (count_index = 0; count_index <= DEPTH; count_index++) begin
            if (count_after_hits[count_index] == 0) begin
                return 1'b0;
            end
        end

        return 1'b1;
    endfunction

    function void report_coverage();
        int count_index;

        `uvm_info("FIFO_COV_MATRIX",
                  $sformatf("READ(empty/middle/full)=%0d/%0d/%0d WRITE=%0d/%0d/%0d WRITE_AND_READ=%0d/%0d/%0d",
                            operation_state_hits[0][0],
                            operation_state_hits[0][1],
                            operation_state_hits[0][2],
                            operation_state_hits[1][0],
                            operation_state_hits[1][1],
                            operation_state_hits[1][2],
                            operation_state_hits[2][0],
                            operation_state_hits[2][1],
                            operation_state_hits[2][2]),
                  UVM_NONE)

        for (count_index = 0; count_index <= DEPTH; count_index++) begin
            `uvm_info("FIFO_COV_COUNT",
                      $sformatf("count_after=%0d hits=%0d",
                                count_index,
                                count_after_hits[count_index]),
                      UVM_NONE)
        end

        `uvm_info("FIFO_COV_SUMMARY",
                  $sformatf("UVM COVERAGE SUMMARY: received=%0d samples=%0d covergroup=%0.2f%% goals_closed=%0b errors=%0d",
                            received_count,
                            sample_count,
                            coverage_percent(),
                            all_goals_hit(),
                            error_count),
                  UVM_NONE)
    endfunction

endclass

`endif
