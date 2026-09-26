`timescale 1ns/1ps
// 专门验证检查器：直接构造总线轨迹，不把这些故意违规当作 DUT 缺陷。
module apb_protocol_tb;
    logic clk = 0;
    always #5 clk = ~clk;
    logic rst_n = 0, psel = 0, penable = 0, pwrite = 0, pready = 0;
    logic [7:0] paddr = 0;
    logic [31:0] pwdata = 0;
    string scenario;
    apb_protocol_checker checker_i(.*);

    // 每次在下降沿驱动，等待随后上升沿检查完再返回。
    task automatic step(input bit sel, en, wr, ready,
                        input logic [7:0] addr, input logic [31:0] data);
        @(negedge clk);
        psel = sel; penable = en; pwrite = wr; pready = ready;
        paddr = addr; pwdata = data;
        @(posedge clk); #1;
    endtask

    initial begin
        if (!$value$plusargs("case=%s", scenario)) scenario = "legal";
        @(negedge clk); rst_n = 1;
        if (scenario == "no_setup") begin
            step(1, 1, 1, 1, 0, 32'h2a);
        end else if (scenario == "enable_only") begin
            step(0, 1, 0, 0, 0, 0);
        end else begin
            step(1, 0, 1, 0, 0, 32'h2a);
            if (scenario == "setup_addr")
                step(1, 1, 1, 1, 4, 32'h2a);
            else if (scenario == "setup_stuck")
                step(1, 0, 1, 0, 0, 32'h2a);
            else begin
                step(1, 1, 1, 0, 0, 32'h2a);
                case (scenario)
                    "wait_addr": step(1, 1, 1, 0, 4, 32'h2a);
                    "wait_data": step(1, 1, 1, 0, 0, 32'h55);
                    "wait_dir": step(1, 1, 0, 0, 0, 32'h2a);
                    "wait_drop": step(0, 0, 1, 0, 0, 32'h2a);
                    "done_addr": step(1, 1, 1, 1, 4, 32'h2a);
                    default: begin
                        if (scenario != "legal" && scenario != "done_stuck")
                            $fatal(1, "UNKNOWN_CASE");
                        step(1, 1, 1, 1, 0, 32'h2a);
                        if (scenario == "done_stuck")
                            step(1, 1, 1, 1, 0, 32'h2a);
                        else begin
                            // 背靠背读：读请求的写数据无意义，允许变化。
                            step(1, 0, 0, 0, 4, 0);
                            step(1, 1, 0, 0, 4, 32'h55);
                            step(1, 1, 0, 1, 4, 32'haa);
                            step(0, 0, 0, 0, 0, 0);
                            // 等待中复位应取消保持要求，不应误报。
                            step(1, 0, 1, 0, 0, 32'h36);
                            step(1, 1, 1, 0, 0, 32'h36);
                            @(negedge clk);
                            rst_n = 0; psel = 0; penable = 0; paddr = 4;
                            @(negedge clk); rst_n = 1;
                            step(0, 0, 0, 0, 0, 0);
                            // 复位后零等待访问仍需先准备。
                            step(1, 0, 0, 0, 0, 0);
                            step(1, 1, 0, 1, 0, 0);
                            step(0, 0, 0, 0, 0, 0);
                        end
                    end
                endcase
            end
        end
        if (scenario != "legal") $fatal(1, "MISSED_EXPECTED_ERROR");
        if (checker_i.setup_checks != 4 || checker_i.wait_checks != 2 ||
            checker_i.done_checks != 3) $fatal(1, "CHECKER_NOT_EXERCISED");
        $display("PROTOCOL_PASS setup=4 wait=2 done=3");
        $finish;
    end
    initial begin
        #10000; $fatal(1, "TIMEOUT");
    end
endmodule
