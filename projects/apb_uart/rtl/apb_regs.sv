// APB 寄存器外设：0x00 可读写，0x04 只读且固定返回 1。
module apb_regs #(
    // 每笔访问需要等待的拍数；0 表示首个访问上升沿即可完成。
    parameter int unsigned WAIT_CYCLES = 0,
    // 教学用故障开关：设为 1 故意提前写入；正常使用保持 0。
    parameter bit INJECT_EARLY_WRITE = 0,
    // 人为故障：0 正常；1 吞错误响应；2 写只读地址污染 DATA；
    // 3 复位值错误；4 DATA 读数据最低位翻转。仅用于验证检查器。
    parameter int unsigned INJECT_FAULT = 0
) (
    input  logic        pclk,     // 总线时钟
    input  logic        presetn,  // 低有效复位：0 表示复位
    input  logic        psel,     // 1 表示选中本外设
    input  logic        penable,  // 选中后，0 为准备阶段，1 为访问阶段
    input  logic        pwrite,   // 1 写，0 读
    input  logic [7:0]  paddr,    // 要访问的字节地址
    input  logic [31:0] pwdata,   // 发起方送来的写数据
    output logic [31:0] prdata,   // 外设返回的读数据
    output logic        pready,   // 访问阶段为 1：可在上升沿完成
    output logic        pslverr   // 完成时为 1：本次访问报错
);
    logic [31:0] data_reg; // 地址 0x00 对应的真实存储空间
    int unsigned wait_left; // 剩余等待拍数
    logic bad_access; // 1 表示地址不存在，或试图写只读地址

    // 组合逻辑：根据当前请求和计数产生响应，本段不保存数据。
    always_comb begin
        // 只允许访问 00 和 04；04 只允许读。
        bad_access = (paddr != 8'h00 && paddr != 8'h04) ||
                     (pwrite && paddr == 8'h04);
        pready = presetn && psel && penable && (wait_left == 0);
        // 报错仍然可以完成传输；不意味着继续等待。
        pslverr = pready && bad_access;
        if (INJECT_FAULT == 1) pslverr = 0;
        prdata = 32'h0;
        // 合法读：00 返回存储值，04 返回固定标识 1；其余默认返回 0。
        if (presetn && psel && !pwrite && !bad_access)
            prdata = (paddr == 8'h00) ? data_reg : 32'h1;
        if (INJECT_FAULT == 4 && presetn && psel && !pwrite && paddr == 0)
            prdata = data_reg ^ 32'h1;
    end

    // 时序逻辑：上升沿更新状态；复位拉低时无需等待时钟。
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            data_reg <= (INJECT_FAULT == 3) ? 32'h1 : 32'h0;
            wait_left <= 0;
        end else begin
            // 准备阶段装入等待数，访问阶段每等一拍减 1。
            if (psel && !penable)
                wait_left <= WAIT_CYCLES;
            else if (psel && penable && wait_left != 0)
                wait_left <= wait_left - 1;

            // 只有“完成 + 写操作 + 合法访问”才能修改 DATA。
            // 无需再判断地址为 00：bad_access 已排除了其他写地址。
            // 条件不成立时没有赋值，data_reg 保留原值。
            if (psel && penable && pready && pwrite && !bad_access)
                data_reg <= pwdata;
            if (INJECT_FAULT == 2 && psel && penable && pready && pwrite && paddr == 4)
                data_reg <= pwdata;
            // 人为错误：准备阶段就写入，用来验证测试能否发现提前写。
            // 这不是正常功能，第一次阅读可先跳过此分支。
            if (INJECT_EARLY_WRITE && psel && !penable && pwrite && !bad_access)
                data_reg <= pwdata;
        end
    end
endmodule
