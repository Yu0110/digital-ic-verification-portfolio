// SVA 检查器并行验证五类关键边界行为，同时记录每条性质是否真正触发。
// 只有“零失败且全部触发”才能证明本次回归有效覆盖了这些性质。
module fifo_sva_checker #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
) (
    input logic                         clk,
    input logic                         rst_n,
    input logic                         wr_en,
    input logic                         rd_en,
    input logic [DATA_WIDTH-1:0]        rd_data,
    input logic                         empty,
    input logic                         full,
    input logic [$clog2(DEPTH + 1)-1:0] data_count
);

    localparam int COUNT_WIDTH = $clog2(DEPTH + 1);
    int unsigned assertion_failure_count;
    int unsigned middle_simultaneous_failure_count;
    int unsigned empty_read_failure_count;
    int unsigned full_write_failure_count;
    int unsigned empty_simultaneous_failure_count;
    int unsigned full_simultaneous_failure_count;
    int unsigned middle_simultaneous_hit_count;
    int unsigned empty_read_hit_count;
    int unsigned full_write_hit_count;
    int unsigned empty_simultaneous_hit_count;
    int unsigned full_simultaneous_hit_count;

    initial begin
        assertion_failure_count       = 0;
        middle_simultaneous_failure_count = 0;
        empty_read_failure_count          = 0;
        full_write_failure_count          = 0;
        empty_simultaneous_failure_count  = 0;
        full_simultaneous_failure_count   = 0;
        middle_simultaneous_hit_count = 0;
        empty_read_hit_count          = 0;
        full_write_hit_count          = 0;
        empty_simultaneous_hit_count  = 0;
        full_simultaneous_hit_count   = 0;
    end

    // 命中计数用于区分“断言通过”和“断言从未被激励触发”。
    always @(posedge clk) begin
        if (rst_n) begin
            if (wr_en && rd_en && !empty && !full) begin
                middle_simultaneous_hit_count <= middle_simultaneous_hit_count + 1;
            end

            if (!wr_en && rd_en && empty) begin
                empty_read_hit_count <= empty_read_hit_count + 1;
            end

            if (wr_en && !rd_en && full) begin
                full_write_hit_count <= full_write_hit_count + 1;
            end

            if (wr_en && rd_en && empty) begin
                empty_simultaneous_hit_count <= empty_simultaneous_hit_count + 1;
            end

            if (wr_en && rd_en && full) begin
                full_simultaneous_hit_count <= full_simultaneous_hit_count + 1;
            end
        end
    end

    // 非空非满时同时读写，两项操作都成功，数据量应保持不变。
    property p_middle_simultaneous_count_holds;
        @(posedge clk) disable iff (!rst_n)
        (wr_en && rd_en && !empty && !full)
        |=> (data_count == $past(data_count));
    endproperty

    a_middle_simultaneous_count_holds:
        assert property (p_middle_simultaneous_count_holds)
        else begin
            assertion_failure_count++;
            middle_simultaneous_failure_count++;
            $display("SVA ERROR p_middle_simultaneous_count_holds: previous_count=%0d current_count=%0d",
                     $past(data_count), data_count);
        end

    // 空读被拒绝，数量、空标志和读数据都应保持。
    property p_empty_read_holds_state;
        @(posedge clk) disable iff (!rst_n)
        (!wr_en && rd_en && empty)
        |=> ((data_count == '0) &&
             empty &&
             (rd_data == $past(rd_data)));
    endproperty

    a_empty_read_holds_state:
        assert property (p_empty_read_holds_state)
        else begin
            assertion_failure_count++;
            empty_read_failure_count++;
            $display("SVA ERROR p_empty_read_holds_state: previous_rd_data=0x%0h current_rd_data=0x%0h current_count=%0d empty=%b",
                     $past(rd_data), rd_data, data_count, empty);
        end

    // 满写被拒绝，不能改变有效数据数量或读数据输出。
    property p_full_write_holds_state;
        @(posedge clk) disable iff (!rst_n)
        (wr_en && !rd_en && full)
        |=> ((data_count == $past(data_count)) &&
             full &&
             (rd_data == $past(rd_data)));
    endproperty

    a_full_write_holds_state:
        assert property (p_full_write_holds_state)
        else begin
            assertion_failure_count++;
            full_write_failure_count++;
            $display("SVA ERROR p_full_write_holds_state: previous_count=%0d current_count=%0d full=%b",
                     $past(data_count), data_count, full);
        end

    // 空状态同时读写时只接受写入，因此下一周期数量为 1。
    property p_empty_simultaneous_accepts_write_only;
        @(posedge clk) disable iff (!rst_n)
        (wr_en && rd_en && empty)
        |=> ((data_count == COUNT_WIDTH'(1)) &&
             (rd_data == $past(rd_data)));
    endproperty

    a_empty_simultaneous_accepts_write_only:
        assert property (p_empty_simultaneous_accepts_write_only)
        else begin
            assertion_failure_count++;
            empty_simultaneous_failure_count++;
            $display("SVA ERROR p_empty_simultaneous_accepts_write_only: current_count=%0d previous_rd_data=0x%0h current_rd_data=0x%0h",
                     data_count, $past(rd_data), rd_data);
        end

    // 满状态同时读写时只接受读取，因此下一周期数量减一。
    property p_full_simultaneous_accepts_read_only;
        @(posedge clk) disable iff (!rst_n)
        (wr_en && rd_en && full)
        |=> (data_count == COUNT_WIDTH'(DEPTH - 1));
    endproperty

    a_full_simultaneous_accepts_read_only:
        assert property (p_full_simultaneous_accepts_read_only)
        else begin
            assertion_failure_count++;
            full_simultaneous_failure_count++;
            $display("SVA ERROR p_full_simultaneous_accepts_read_only: expected_count=%0d current_count=%0d",
                     DEPTH - 1, data_count);
        end

    function bit all_properties_exercised();
        return
            (middle_simultaneous_hit_count > 0) &&
            (empty_read_hit_count          > 0) &&
            (full_write_hit_count          > 0) &&
            (empty_simultaneous_hit_count  > 0) &&
            (full_simultaneous_hit_count   > 0);
    endfunction

    function int unsigned property_failure_count();
        return middle_simultaneous_failure_count +
               empty_read_failure_count +
               full_write_failure_count +
               empty_simultaneous_failure_count +
               full_simultaneous_failure_count;
    endfunction

    function void report();
        $display("SVA SUMMARY: failures=%0d all_exercised=%0b middle_sim=%0d empty_read=%0d full_write=%0d empty_sim=%0d full_sim=%0d failure_breakdown=%0d,%0d,%0d,%0d,%0d failure_sum=%0d",
                 assertion_failure_count,
                 all_properties_exercised(),
                 middle_simultaneous_hit_count,
                 empty_read_hit_count,
                 full_write_hit_count,
                 empty_simultaneous_hit_count,
                 full_simultaneous_hit_count,
                 middle_simultaneous_failure_count,
                 empty_read_failure_count,
                 full_write_failure_count,
                 empty_simultaneous_failure_count,
                 full_simultaneous_failure_count,
                 property_failure_count());
    endfunction

endmodule
