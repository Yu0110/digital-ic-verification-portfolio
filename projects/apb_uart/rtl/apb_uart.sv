// 独立的 APB3 + 8N1 UART 外设；保留原 apb_regs 教学基线不变。
module apb_uart #(
    parameter int unsigned BAUD_DIV = 16,
    parameter int unsigned WAIT_CYCLES = 0
) (
    input  logic        pclk,
    input  logic        presetn,
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [7:0]  paddr,
    input  logic [31:0] pwdata,
    output logic [31:0] prdata,
    output logic        pready,
    output logic        pslverr,
    input  logic        rx_i,
    output logic        tx_o
);
    localparam int unsigned TIMER_W = $clog2(BAUD_DIV + 1);

    typedef enum logic [1:0] {TX_IDLE, TX_START, TX_DATA, TX_STOP} tx_state_t;
    typedef enum logic [1:0] {RX_IDLE, RX_START, RX_DATA, RX_STOP} rx_state_t;

    tx_state_t tx_state;
    rx_state_t rx_state;
    logic [TIMER_W-1:0] tx_timer, rx_timer;
    logic [2:0] tx_bit_index, rx_bit_index;
    logic [7:0] tx_shift, rx_shift, rx_data;
    logic rx_meta, rx_sync, rx_valid, rx_overrun, framing_error;
    int unsigned wait_left;
    logic bad_access, tx_start, rx_pop;

    initial begin
        assert (BAUD_DIV >= 8) else $fatal(1, "BAUD_DIV must be at least 8");
    end

    always_comb begin
        pready = presetn && psel && penable && (wait_left == 0);
        bad_access = 1'b0;
        case (paddr)
            8'h00: bad_access = !pwrite || (tx_state != TX_IDLE) || (|pwdata[31:8]);
            8'h04, 8'h08, 8'h0c: bad_access = pwrite;
            default: bad_access = 1'b1;
        endcase
        pslverr = pready && bad_access;
        tx_start = pready && pwrite && !bad_access && (paddr == 8'h00);
        rx_pop = pready && !pwrite && !bad_access && (paddr == 8'h04);

        prdata = 32'b0;
        if (presetn && psel && !pwrite && !bad_access) begin
            case (paddr)
                8'h04: if (rx_valid) prdata[7:0] = rx_data;
                8'h08: begin
                    prdata[0] = (tx_state != TX_IDLE);
                    prdata[1] = rx_valid;
                    prdata[2] = rx_overrun;
                    prdata[3] = framing_error;
                end
                8'h0c: prdata = 32'(BAUD_DIV);
                default: ;
            endcase
        end

        tx_o = 1'b1;
        case (tx_state)
            TX_START: tx_o = 1'b0;
            TX_DATA: tx_o = tx_shift[tx_bit_index];
            default: ;
        endcase
    end

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            wait_left <= 0;
            tx_state <= TX_IDLE;
            tx_timer <= '0;
            tx_bit_index <= '0;
            tx_shift <= '0;
            rx_state <= RX_IDLE;
            rx_timer <= '0;
            rx_bit_index <= '0;
            rx_shift <= '0;
            rx_data <= '0;
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
            rx_valid <= 1'b0;
            rx_overrun <= 1'b0;
            framing_error <= 1'b0;
        end else begin
            // 串口输入与 pclk 不同步，先过两级寄存器再判断起始位。
            rx_meta <= rx_i;
            rx_sync <= rx_meta;

            if (psel && !penable)
                wait_left <= WAIT_CYCLES;
            else if (psel && penable && wait_left != 0)
                wait_left <= wait_left - 1;

            if (rx_pop) rx_valid <= 1'b0;

            // 每个状态持续 BAUD_DIV 拍，数据从 bit0 到 bit7 依次输出。
            case (tx_state)
                TX_IDLE: if (tx_start) begin
                    tx_shift <= pwdata[7:0];
                    tx_bit_index <= '0;
                    tx_timer <= TIMER_W'(BAUD_DIV - 1);
                    tx_state <= TX_START;
                end
                TX_START, TX_DATA, TX_STOP: begin
                    if (tx_timer != 0) begin
                        tx_timer <= tx_timer - 1'b1;
                    end else begin
                        tx_timer <= TIMER_W'(BAUD_DIV - 1);
                        case (tx_state)
                            TX_START: tx_state <= TX_DATA;
                            TX_DATA: if (tx_bit_index == 3'd7)
                                tx_state <= TX_STOP;
                            else
                                tx_bit_index <= tx_bit_index + 1'b1;
                            TX_STOP: tx_state <= TX_IDLE;
                            default: ;
                        endcase
                    end
                end
                default: tx_state <= TX_IDLE;
            endcase

            // 在起始位中点确认低电平，之后每隔一个位周期采样。
            case (rx_state)
                RX_IDLE: if (!rx_sync) begin
                    rx_timer <= TIMER_W'(BAUD_DIV / 2 - 1);
                    rx_state <= RX_START;
                end
                RX_START, RX_DATA, RX_STOP: begin
                    if (rx_timer != 0) begin
                        rx_timer <= rx_timer - 1'b1;
                    end else begin
                        rx_timer <= TIMER_W'(BAUD_DIV - 1);
                        case (rx_state)
                            RX_START: if (!rx_sync) begin
                                rx_bit_index <= '0;
                                rx_state <= RX_DATA;
                            end else begin
                                rx_state <= RX_IDLE;
                            end
                            RX_DATA: begin
                                rx_shift[rx_bit_index] <= rx_sync;
                                if (rx_bit_index == 3'd7)
                                    rx_state <= RX_STOP;
                                else
                                    rx_bit_index <= rx_bit_index + 1'b1;
                            end
                            RX_STOP: begin
                                rx_state <= RX_IDLE;
                                if (!rx_sync) begin
                                    framing_error <= 1'b1;
                                end else if (rx_valid && !rx_pop) begin
                                    // 单字节缓冲未读时丢弃新帧，保留旧数据。
                                    rx_overrun <= 1'b1;
                                end else begin
                                    rx_data <= rx_shift;
                                    rx_valid <= 1'b1;
                                end
                            end
                            default: ;
                        endcase
                    end
                end
                default: rx_state <= RX_IDLE;
            endcase
        end
    end
endmodule
