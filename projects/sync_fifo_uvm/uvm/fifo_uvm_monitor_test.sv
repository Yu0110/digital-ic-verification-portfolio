`ifndef FIFO_UVM_MONITOR_TEST_SV
`define FIFO_UVM_MONITOR_TEST_SV

// 主检查器核对 monitor 发布的事务内容、编号和采样时刻。
class fifo_uvm_monitor_checker #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4,
    parameter int EXPECTED_ITEMS = 5
) extends uvm_subscriber #(fifo_uvm_sequence_item #(DATA_WIDTH, DEPTH));

    localparam int COUNT_WIDTH = $clog2(DEPTH + 1);
    typedef fifo_uvm_sequence_item #(DATA_WIDTH, DEPTH) item_t;

    `uvm_component_param_utils(fifo_uvm_monitor_checker #(
        DATA_WIDTH,
        DEPTH,
        EXPECTED_ITEMS
    ))

    int unsigned received_count;
    int unsigned error_count;
    int unsigned object_instance_ids[EXPECTED_ITEMS];
    item_t      received_handles[EXPECTED_ITEMS];
    time        receive_times[EXPECTED_ITEMS];

    function new(string name = "fifo_uvm_monitor_checker",
                 uvm_component parent = null);
        super.new(name, parent);
        received_count = 0;
        error_count    = 0;

        for (int unsigned index = 0; index < EXPECTED_ITEMS; index++) begin
            object_instance_ids[index] = 0;
            received_handles[index]    = null;
            receive_times[index]       = 0ns;
        end
    endfunction

    virtual function void write(item_t observed_tx);
        longint unsigned             expected_id;
        bit                          expected_wr_en;
        bit [DATA_WIDTH-1:0]         expected_wr_data;
        bit                          expected_rd_en;
        logic [DATA_WIDTH-1:0]       expected_rd_data;
        logic [COUNT_WIDTH-1:0]      expected_count;
        logic                        expected_empty;
        logic                        expected_full;
        bit                          mismatch;
        string                       expected_name;
        int unsigned                 current_instance_id;
        time                         expected_receive_time;

        if (observed_tx == null) begin
            error_count++;
            `uvm_error("FIFO_MON_NULL", "monitor checker received a null transaction")
            return;
        end

        if (received_count >= EXPECTED_ITEMS) begin
            error_count++;
            `uvm_error("FIFO_MON_EXTRA",
                       $sformatf("monitor published unexpected item %0d",
                                 received_count + 1))
            received_count++;
            return;
        end

        case (received_count)
            0: begin
                expected_id      = 64'd1;
                expected_wr_en   = 1'b1;
                expected_wr_data = DATA_WIDTH'(8'hA5);
                expected_rd_en   = 1'b0;
                expected_rd_data = '0;
                expected_count   = COUNT_WIDTH'(1);
                expected_empty   = 1'b0;
                expected_full    = 1'b0;
                expected_name    = "observed_tx_1";
                expected_receive_time = 25ns;
            end
            1: begin
                expected_id      = 64'd2;
                expected_wr_en   = 1'b1;
                expected_wr_data = DATA_WIDTH'(8'h3C);
                expected_rd_en   = 1'b0;
                expected_rd_data = '0;
                expected_count   = COUNT_WIDTH'(2);
                expected_empty   = 1'b0;
                expected_full    = 1'b0;
                expected_name    = "observed_tx_2";
                expected_receive_time = 45ns;
            end
            2: begin
                expected_id      = 64'd3;
                expected_wr_en   = 1'b0;
                expected_wr_data = '0;
                expected_rd_en   = 1'b1;
                expected_rd_data = DATA_WIDTH'(8'hA5);
                expected_count   = COUNT_WIDTH'(1);
                expected_empty   = 1'b0;
                expected_full    = 1'b0;
                expected_name    = "observed_tx_3";
                expected_receive_time = 65ns;
            end
            3: begin
                expected_id      = 64'd4;
                expected_wr_en   = 1'b1;
                expected_wr_data = DATA_WIDTH'(8'h7E);
                expected_rd_en   = 1'b1;
                expected_rd_data = DATA_WIDTH'(8'h3C);
                expected_count   = COUNT_WIDTH'(1);
                expected_empty   = 1'b0;
                expected_full    = 1'b0;
                expected_name    = "observed_tx_4";
                expected_receive_time = 85ns;
            end
            4: begin
                expected_id      = 64'd5;
                expected_wr_en   = 1'b0;
                expected_wr_data = '0;
                expected_rd_en   = 1'b1;
                expected_rd_data = DATA_WIDTH'(8'h7E);
                expected_count   = '0;
                expected_empty   = 1'b1;
                expected_full    = 1'b0;
                expected_name    = "observed_tx_5";
                expected_receive_time = 105ns;
            end
            default: begin
                expected_id      = '0;
                expected_wr_en   = 1'b0;
                expected_wr_data = '0;
                expected_rd_en   = 1'b0;
                expected_rd_data = '0;
                expected_count   = '0;
                expected_empty   = 1'b0;
                expected_full    = 1'b0;
                expected_name    = "UNREACHABLE";
                expected_receive_time = 0ns;
            end
        endcase

        mismatch =
            ($time                     != expected_receive_time) ||
            (observed_tx.get_name()    != expected_name)         ||
            (observed_tx.transaction_id !== expected_id)          ||
            (observed_tx.wr_en          != expected_wr_en)   ||
            (observed_tx.wr_data        != expected_wr_data) ||
            (observed_tx.rd_en          != expected_rd_en)   ||
            (observed_tx.sampled        != 1'b1)             ||
            (observed_tx.rd_data        !== expected_rd_data)||
            (observed_tx.data_count     !== expected_count)  ||
            (observed_tx.empty          !== expected_empty)  ||
            (observed_tx.full           !== expected_full);

        if (mismatch) begin
            error_count++;
            `uvm_error("FIFO_MON_MISMATCH",
                       $sformatf("item %0d mismatch | actual: time=%0t name=%0s id=%0d wr_en=%0b wr_data=0x%0h rd_en=%0b sampled=%0b rd_data=0x%0h count=%0d empty=%0b full=%0b | expected: time=%0t name=%0s id=%0d wr_en=%0b wr_data=0x%0h rd_en=%0b sampled=1 rd_data=0x%0h count=%0d empty=%0b full=%0b",
                                 received_count + 1,
                                 $time,
                                 observed_tx.get_name(),
                                 observed_tx.transaction_id,
                                 observed_tx.wr_en,
                                 observed_tx.wr_data,
                                 observed_tx.rd_en,
                                 observed_tx.sampled,
                                 observed_tx.rd_data,
                                 observed_tx.data_count,
                                 observed_tx.empty,
                                 observed_tx.full,
                                 expected_receive_time,
                                 expected_name,
                                 expected_id,
                                 expected_wr_en,
                                 expected_wr_data,
                                 expected_rd_en,
                                 expected_rd_data,
                                 expected_count,
                                 expected_empty,
                                 expected_full))
        end else begin
            `uvm_info("FIFO_MON_CHECK",
                      $sformatf("item %0d pass: rd_data=0x%0h count=%0d empty=%0b full=%0b",
                                received_count + 1,
                                observed_tx.rd_data,
                                observed_tx.data_count,
                                observed_tx.empty,
                                observed_tx.full),
                      UVM_LOW)
        end

        current_instance_id = observed_tx.get_inst_id();
        for (int unsigned previous = 0;
             previous < received_count;
             previous++) begin
            if (current_instance_id == object_instance_ids[previous]) begin
                error_count++;
                `uvm_error("FIFO_MON_OBJECT_REUSE",
                           $sformatf("items %0d and %0d reused object instance id %0d",
                                     previous + 1,
                                     received_count + 1,
                                     current_instance_id))
            end
        end

        object_instance_ids[received_count] = current_instance_id;
        received_handles[received_count]    = observed_tx;
        receive_times[received_count]       = $time;

        received_count++;
    endfunction

endclass

// 第二订阅者保存事务句柄，用于验证 analysis port 的广播行为。
class fifo_uvm_monitor_audit_tap #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4,
    parameter int EXPECTED_ITEMS = 5
) extends uvm_subscriber #(fifo_uvm_sequence_item #(DATA_WIDTH, DEPTH));

    typedef fifo_uvm_sequence_item #(DATA_WIDTH, DEPTH) item_t;

    `uvm_component_param_utils(fifo_uvm_monitor_audit_tap #(
        DATA_WIDTH,
        DEPTH,
        EXPECTED_ITEMS
    ))

    int unsigned received_count;
    int unsigned error_count;
    item_t received_handles[EXPECTED_ITEMS];
    time   receive_times[EXPECTED_ITEMS];

    function new(string name = "fifo_uvm_monitor_audit_tap",
                 uvm_component parent = null);
        super.new(name, parent);
        received_count = 0;
        error_count    = 0;

        for (int unsigned index = 0; index < EXPECTED_ITEMS; index++) begin
            received_handles[index] = null;
            receive_times[index]    = 0ns;
        end
    endfunction

    virtual function void write(item_t observed_tx);
        if (observed_tx == null) begin
            error_count++;
            `uvm_error("FIFO_MON_TAP_NULL", "audit tap received a null transaction")
            return;
        end

        if (received_count >= EXPECTED_ITEMS) begin
            error_count++;
            `uvm_error("FIFO_MON_TAP_EXTRA", "audit tap received too many transactions")
            received_count++;
            return;
        end

        received_handles[received_count] = observed_tx;
        receive_times[received_count]    = $time;
        received_count++;
    endfunction

endclass

// Monitor 集成测试：确认一份采样结果能无损到达两个独立订阅者。
class fifo_uvm_monitor_test extends uvm_test;

    localparam int DATA_WIDTH = 8;
    localparam int DEPTH      = 4;
    localparam int EXPECTED_ITEMS = 5;
    typedef fifo_uvm_sequencer #(DATA_WIDTH, DEPTH)       sequencer_t;
    typedef fifo_uvm_driver #(DATA_WIDTH, DEPTH)          driver_t;
    typedef fifo_uvm_monitor #(DATA_WIDTH, DEPTH)         monitor_t;
    typedef fifo_uvm_monitor_checker #(
        DATA_WIDTH,
        DEPTH,
        EXPECTED_ITEMS
    ) checker_t;
    typedef fifo_uvm_monitor_audit_tap #(
        DATA_WIDTH,
        DEPTH,
        EXPECTED_ITEMS
    ) audit_tap_t;
    typedef fifo_uvm_basic_sequence #(DATA_WIDTH, DEPTH)  sequence_t;

    `uvm_component_utils(fifo_uvm_monitor_test)

    sequencer_t sequencer;
    driver_t    driver;
    monitor_t   monitor;
    checker_t   result_checker;
    audit_tap_t audit_tap;

    function new(string name = "fifo_uvm_monitor_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        sequencer = sequencer_t::type_id::create("sequencer", this);
        driver    = driver_t::type_id::create("driver", this);
        monitor   = monitor_t::type_id::create("monitor", this);
        result_checker = checker_t::type_id::create("result_checker", this);
        audit_tap = audit_tap_t::type_id::create("audit_tap", this);

        if ((sequencer == null) ||
            (driver == null) ||
            (monitor == null) ||
            (result_checker == null) ||
            (audit_tap == null)) begin
            `uvm_fatal("FIFO_MON_COMPONENT_NULL",
                       "monitor test factory returned a null component")
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        driver.seq_item_port.connect(sequencer.seq_item_export);

        monitor.observed_ap.connect(result_checker.analysis_export);
        monitor.observed_ap.connect(audit_tap.analysis_export);
    endfunction

    virtual task run_phase(uvm_phase phase);
        sequence_t basic_seq;
        time expected_receive_time;

        phase.raise_objection(this, "FIFO UVM monitor integration started");

        basic_seq = sequence_t::type_id::create("basic_seq");
        if (basic_seq == null) begin
            `uvm_fatal("FIFO_MON_SEQ_NULL", "factory returned a null basic sequence")
        end

        if (monitor.observed_ap.size() != 2) begin
            `uvm_fatal("FIFO_MON_PORT_SIZE",
                       $sformatf("expected 2 analysis subscribers, got %0d",
                                 monitor.observed_ap.size()))
        end

        basic_seq.start(sequencer);

        if ((basic_seq.produced_count != EXPECTED_ITEMS) ||
            (driver.driven_count     != EXPECTED_ITEMS) ||
            (monitor.observed_count  != EXPECTED_ITEMS) ||
            (result_checker.received_count != EXPECTED_ITEMS) ||
            (audit_tap.received_count      != EXPECTED_ITEMS) ||
            (result_checker.error_count    != 0) ||
            (audit_tap.error_count         != 0)) begin
            `uvm_fatal("FIFO_MON_SUMMARY",
                       $sformatf("expected 5/5/5/5/5 with zero errors, got produced=%0d driven=%0d observed=%0d checked=%0d tapped=%0d checker_errors=%0d tap_errors=%0d",
                                 basic_seq.produced_count,
                                 driver.driven_count,
                                 monitor.observed_count,
                                 result_checker.received_count,
                                 audit_tap.received_count,
                                 result_checker.error_count,
                                 audit_tap.error_count))
            return;
        end

        for (int unsigned index = 0; index < EXPECTED_ITEMS; index++) begin
            case (index)
                0: expected_receive_time = 25ns;
                1: expected_receive_time = 45ns;
                2: expected_receive_time = 65ns;
                3: expected_receive_time = 85ns;
                4: expected_receive_time = 105ns;
                default: expected_receive_time = 0ns;
            endcase
            if ((result_checker.received_handles[index] == null) ||
                (audit_tap.received_handles[index]      == null) ||
                (result_checker.received_handles[index] !=
                 audit_tap.received_handles[index]) ||
                (result_checker.receive_times[index] != expected_receive_time) ||
                (audit_tap.receive_times[index]      != expected_receive_time)) begin
                `uvm_fatal("FIFO_MON_BROADCAST",
                           $sformatf("analysis broadcast mismatch for item %0d",
                                     index + 1))
            end
        end

        `uvm_info("FIFO_MONITOR_PASS",
                  "UVM MONITOR PASS: 5 unique timed transactions and all FIFO responses reached 2 subscribers as identical handles",
                  UVM_NONE)

        phase.drop_objection(this, "FIFO UVM monitor integration completed");
    endtask

endclass

`endif
