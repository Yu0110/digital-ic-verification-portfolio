// 本项目单外设 APB3 检查器：在上升沿比较当前值与前一个采样点。
// 使用过程式即时断言，不是并发 property；编译必须启用 --assert。
module apb_protocol_checker (
    input logic clk, rst_n, psel, penable, pwrite, pready,
    input logic [7:0] paddr,
    input logic [31:0] pwdata
);
    bit prev_setup = 0, prev_wait = 0, prev_done = 0;
    logic prev_write;
    logic [7:0] prev_addr;
    logic [31:0] prev_data;
    int setup_checks = 0, wait_checks = 0, done_checks = 0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 复位取消尚未完成的检查义务；累计命中数保留，方便验证检查实际执行。
            prev_setup = 0; prev_wait = 0; prev_done = 0;
        end else begin
            if (prev_setup || prev_wait) begin
                // 等待后的这个沿可以是完成沿，但请求仍必须保持到该沿。
                assert (psel && penable) else $fatal(1, "PROTO_PHASE_HOLD");
                assert (paddr === prev_addr) else $fatal(1, "PROTO_ADDR_STABLE");
                assert (pwrite === prev_write) else $fatal(1, "PROTO_DIR_STABLE");
                if (prev_write)
                    assert (pwdata === prev_data) else $fatal(1, "PROTO_DATA_STABLE");
                if (prev_setup) setup_checks++;
                if (prev_wait) wait_checks++;
            end
            if (prev_done) begin
                assert (!penable) else $fatal(1, "PROTO_EXIT_ACCESS");
                done_checks++;
            end
            // 访问阶段只能来自上一拍准备阶段或未完成的访问阶段。
            if (psel && penable)
                assert (prev_setup || prev_wait) else $fatal(1, "PROTO_NO_SETUP");
            // 针对本项目单外设总线的约束，不用于直接套到多外设共享 PENABLE。
            assert (!penable || psel) else $fatal(1, "PROTO_ENABLE_WITHOUT_SELECT");

            prev_setup = psel && !penable;
            prev_wait = psel && penable && !pready;
            prev_done = psel && penable && pready;
            prev_addr = paddr; prev_write = pwrite; prev_data = pwdata;
        end
    end
endmodule
