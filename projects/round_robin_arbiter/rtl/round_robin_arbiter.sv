// 四请求者轮询仲裁器。
// grant 为组合输出；每次非零授权都被视为本周期已完成服务。
module round_robin_arbiter (
    input  logic       clk,      // 时钟信号，上升沿保存新的轮询起点。
    input  logic       rst_n,    // 低电平有效异步复位信号。
    input  logic [3:0] req,      // req[3:0] 分别代表四个请求者的请求。
    output logic [3:0] grant     // grant[3:0] 是独热授权结果，最多一位为 1。
);

    timeunit 1ns;
    timeprecision 1ps;

    // priority_ptr 保存当前轮询起点：
    // 00 从请求者 0 开始，01 从请求者 1 开始，
    // 10 从请求者 2 开始，11 从请求者 3 开始。
    logic [1:0] priority_ptr;

    // priority_ptr_next 是组合逻辑计算出的下一轮搜索起点。
    // 它会在下一个时钟上升沿被保存到 priority_ptr。
    logic [1:0] priority_ptr_next;

    // 从当前起点开始循环搜索，只选择遇到的第一个有效请求。
    // 使用完整敏感列表写法，保证 Icarus Verilog 与商业工具均可直接运行。
    always @(*) begin
        // 默认不授权任何人。
        // 默认保持轮询起点，保证无请求时指针不会移动，
        // 同时保证组合逻辑的所有执行路径都有明确赋值。
        grant             = 4'b0000;
        priority_ptr_next = priority_ptr;

        // 复位期间不允许产生任何授权，并让下一轮起点为 0。
        if (rst_n == 1'b0) begin
            grant             = 4'b0000;
            priority_ptr_next = 2'b00;
        end else begin
            // priority_ptr 决定本轮从哪个请求者开始搜索。
            case (priority_ptr)
                // 从请求者 0 开始，搜索顺序为 0 -> 1 -> 2 -> 3。
                2'b00: begin
                    if (req[0] == 1'b1) begin
                        grant             = 4'b0001;
                        priority_ptr_next = 2'b01;
                    end else if (req[1] == 1'b1) begin
                        grant             = 4'b0010;
                        priority_ptr_next = 2'b10;
                    end else if (req[2] == 1'b1) begin
                        grant             = 4'b0100;
                        priority_ptr_next = 2'b11;
                    end else if (req[3] == 1'b1) begin
                        grant             = 4'b1000;
                        priority_ptr_next = 2'b00;
                    end
                end

                // 从请求者 1 开始，搜索顺序为 1 -> 2 -> 3 -> 0。
                2'b01: begin
                    if (req[1] == 1'b1) begin
                        grant             = 4'b0010;
                        priority_ptr_next = 2'b10;
                    end else if (req[2] == 1'b1) begin
                        grant             = 4'b0100;
                        priority_ptr_next = 2'b11;
                    end else if (req[3] == 1'b1) begin
                        grant             = 4'b1000;
                        priority_ptr_next = 2'b00;
                    end else if (req[0] == 1'b1) begin
                        grant             = 4'b0001;
                        priority_ptr_next = 2'b01;
                    end
                end

                // 从请求者 2 开始，搜索顺序为 2 -> 3 -> 0 -> 1。
                2'b10: begin
                    if (req[2] == 1'b1) begin
                        grant             = 4'b0100;
                        priority_ptr_next = 2'b11;
                    end else if (req[3] == 1'b1) begin
                        grant             = 4'b1000;
                        priority_ptr_next = 2'b00;
                    end else if (req[0] == 1'b1) begin
                        grant             = 4'b0001;
                        priority_ptr_next = 2'b01;
                    end else if (req[1] == 1'b1) begin
                        grant             = 4'b0010;
                        priority_ptr_next = 2'b10;
                    end
                end

                // 从请求者 3 开始，搜索顺序为 3 -> 0 -> 1 -> 2。
                2'b11: begin
                    if (req[3] == 1'b1) begin
                        grant             = 4'b1000;
                        priority_ptr_next = 2'b00;
                    end else if (req[0] == 1'b1) begin
                        grant             = 4'b0001;
                        priority_ptr_next = 2'b01;
                    end else if (req[1] == 1'b1) begin
                        grant             = 4'b0010;
                        priority_ptr_next = 2'b10;
                    end else if (req[2] == 1'b1) begin
                        grant             = 4'b0100;
                        priority_ptr_next = 2'b11;
                    end
                end

                // X 态传播或异常状态下不产生授权，并恢复到起点 0。
                default: begin
                    grant             = 4'b0000;
                    priority_ptr_next = 2'b00;
                end
            endcase
        end
    end

    // 轮询起点在时钟上升沿推进，并由低有效复位异步清零。
    always_ff @(posedge clk or negedge rst_n) begin
        if (rst_n == 1'b0) begin
            priority_ptr <= 2'b00;
        end else begin
            priority_ptr <= priority_ptr_next;
        end
    end

endmodule
