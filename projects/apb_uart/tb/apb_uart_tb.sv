`timescale 1ns/1ps

module apb_uart_tb #(
    parameter int unsigned BAUD_DIV = 8,
    parameter int unsigned WAIT_CYCLES = 0
);
    logic pclk = 0;
    always #5 pclk = ~pclk;

    logic presetn = 0;
    logic psel = 0, penable = 0, pwrite = 0;
    logic [7:0] paddr = 0;
    logic [31:0] pwdata = 0, prdata;
    logic pready, pslverr;
    logic rx_i, rx_drive = 1, loopback = 0, tx_o;
    int checks = 0, transfers = 0;

    assign rx_i = loopback ? tx_o : rx_drive;

    apb_uart #(.BAUD_DIV(BAUD_DIV), .WAIT_CYCLES(WAIT_CYCLES)) dut (.*);

    task automatic check(input bit condition, input string message);
        checks++;
        if (!condition) $fatal(1, "UART_CHECK_FAIL %s", message);
    endtask

    task automatic access(
        input bit write_request,
        input logic [7:0] address,
        input logic [31:0] write_data,
        input bit expected_error,
        output logic [31:0] read_data
    );
        int stalls;
        bit complete;
        bit error_response;
        @(negedge pclk);
        psel = 1;
        penable = 0;
        pwrite = write_request;
        paddr = address;
        pwdata = write_data;
        @(negedge pclk);
        penable = 1;
        stalls = 0;
        complete = 0;
        do begin
            @(posedge pclk);
            complete = pready;
            error_response = pslverr;
            read_data = prdata;
            if (!complete) stalls++;
            if (write_request && address == 8'h00 && !expected_error)
                check(tx_o == 1'b1, "TX changed before APB completion");
        end while (!complete);
        check(stalls == WAIT_CYCLES, "wrong APB wait count");
        check(error_response == expected_error, "wrong APB error response");
        transfers++;
        @(negedge pclk);
        psel = 0;
        penable = 0;
        pwrite = 0;
        paddr = 0;
        pwdata = 0;
    endtask

    task automatic read_reg(
        input logic [7:0] address,
        input logic [31:0] expected_data,
        input bit expected_error
    );
        logic [31:0] actual;
        access(0, address, 0, expected_error, actual);
        check(actual === expected_data, $sformatf("read addr=%02h got=%08h expected=%08h",
                                                address, actual, expected_data));
    endtask

    task automatic write_reg(
        input logic [7:0] address,
        input logic [31:0] data,
        input bit expected_error
    );
        logic [31:0] unused_data;
        access(1, address, data, expected_error, unused_data);
    endtask

    task automatic expect_tx(input logic [7:0] expected);
        @(negedge tx_o);
        #(BAUD_DIV * 5);
        check(tx_o == 0, "start bit");
        for (int i = 0; i < 8; i++) begin
            #(BAUD_DIV * 10);
            check(tx_o == expected[i], $sformatf("TX data bit %0d", i));
        end
        #(BAUD_DIV * 10);
        check(tx_o == 1, "stop bit");
        #(BAUD_DIV * 10);
        check(tx_o == 1, "idle after frame");
    endtask

    task automatic send_rx(input logic [7:0] data, input bit stop_bit);
        @(negedge pclk);
        rx_drive = 0;
        #(BAUD_DIV * 10);
        for (int i = 0; i < 8; i++) begin
            rx_drive = data[i];
            #(BAUD_DIV * 10);
        end
        rx_drive = stop_bit;
        #(BAUD_DIV * 10);
        rx_drive = 1;
        repeat (4) @(posedge pclk);
    endtask

    initial begin
        repeat (3) @(negedge pclk);
        presetn = 1;
        read_reg(8'h08, 0, 0);
        read_reg(8'h0c, 32'(BAUD_DIV), 0);
        read_reg(8'h04, 0, 0);
        read_reg(8'h00, 0, 1);
        read_reg(8'h10, 0, 1);
        write_reg(8'h04, 32'hff, 1);
        write_reg(8'h08, 32'hff, 1);
        write_reg(8'h00, 32'h100, 1);

        loopback = 1;
        fork
            expect_tx(8'ha5);
            write_reg(8'h00, 32'ha5, 0);
        join
        read_reg(8'h08, 2, 0);
        read_reg(8'h04, 32'ha5, 0);
        read_reg(8'h08, 0, 0);
        loopback = 0;

        write_reg(8'h00, 32'h3c, 0);
        read_reg(8'h08, 1, 0);
        write_reg(8'h00, 32'h5a, 1);
        repeat (BAUD_DIV * 10 + 2) @(posedge pclk);
        read_reg(8'h08, 0, 0);
        check(tx_o == 1, "TX idle after rejected busy write");

        send_rx(8'h96, 1);
        read_reg(8'h08, 2, 0);
        read_reg(8'h04, 32'h96, 0);
        read_reg(8'h08, 0, 0);
        read_reg(8'h04, 0, 0);

        send_rx(8'h11, 1);
        send_rx(8'h22, 1);
        read_reg(8'h08, 6, 0);
        read_reg(8'h04, 32'h11, 0);
        read_reg(8'h08, 4, 0);

        @(negedge pclk);
        presetn = 0;
        repeat (3) @(negedge pclk);
        presetn = 1;
        send_rx(8'h55, 0);
        read_reg(8'h08, 8, 0);
        read_reg(8'h04, 0, 0);

        write_reg(8'h00, 32'hc3, 0);
        repeat (3) @(negedge pclk);
        presetn = 0;
        #1;
        check(tx_o == 1, "asynchronous reset aborts TX");
        check(!pready && !pslverr && prdata == 0, "reset clears APB response");
        repeat (3) @(negedge pclk);
        presetn = 1;
        read_reg(8'h08, 0, 0);

        $display("UART_PASS baud_div=%0d wait=%0d transfers=%0d checks=%0d",
                 BAUD_DIV, WAIT_CYCLES, transfers, checks);
        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "UART_CHECK_FAIL timeout");
    end
endmodule
