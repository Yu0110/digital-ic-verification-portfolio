`ifndef FIFO_UVM_ITEM_TEST_SV
`define FIFO_UVM_ITEM_TEST_SV

// 事务对象单元测试：检查工厂创建、字段自动化、复制、比较和随机约束。
class fifo_uvm_item_test extends uvm_test;

    `uvm_component_utils(fifo_uvm_item_test)

    localparam int DATA_WIDTH = 8;
    localparam int DEPTH      = 4;
    localparam int COUNT_WIDTH = $clog2(DEPTH + 1);
    localparam int ACTIVE_ONLY_SAMPLES = 256;
    localparam int RANDOM_SAMPLES = 1000;
    localparam int NON_POWER_DATA_WIDTH = 16;
    localparam int NON_POWER_DEPTH      = 5;
    localparam int NON_POWER_COUNT_WIDTH = $clog2(NON_POWER_DEPTH + 1);
    typedef fifo_uvm_sequence_item #(DATA_WIDTH, DEPTH) item_t;
    typedef fifo_uvm_sequence_item #(
        NON_POWER_DATA_WIDTH,
        NON_POWER_DEPTH
    ) non_power_item_t;

    function new(string name = "fifo_uvm_item_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void expect_compare_mismatch(
        item_t lhs,
        item_t rhs,
        string field_name
    );
        uvm_comparer mismatch_comparer;

        mismatch_comparer = new({"mismatch_", field_name});
        mismatch_comparer.set_verbosity(UVM_DEBUG);

        if (lhs.compare(rhs, mismatch_comparer)) begin
            `uvm_fatal("FIFO_ITEM_COMPARE_NEGATIVE",
                       $sformatf("compare missed changed field %0s", field_name))
        end

        if (mismatch_comparer.get_result() == 0) begin
            `uvm_fatal("FIFO_ITEM_COMPARE_COUNT",
                       $sformatf("comparer recorded no mismatch for field %0s", field_name))
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        item_t write_item;
        item_t copy_item;
        item_t random_item;
        non_power_item_t non_power_item;
        int unsigned operation_counts[4];
        int unsigned sample_index;

        phase.raise_objection(this, "FIFO UVM item test started");

        write_item = item_t::type_id::create("write_item");

        if (write_item == null) begin
            `uvm_fatal("FIFO_ITEM_FACTORY", "factory returned a null write_item")
        end

        if ((write_item.transaction_id !== 64'd0) ||
            (write_item.wr_en          !== 1'b0)  ||
            (write_item.wr_data        !== '0)    ||
            (write_item.rd_en          !== 1'b0)  ||
            (write_item.rd_data        !== '0)    ||
            (write_item.empty          !== 1'b0)  ||
            (write_item.full           !== 1'b0)  ||
            (write_item.data_count     !== '0)    ||
            (write_item.sampled        !== 1'b0)) begin
            `uvm_fatal("FIFO_ITEM_DEFAULTS",
                       "new sequence item did not initialize every field to zero")
        end

        write_item.transaction_id = 64'h0123_4567_89AB_CDEF;
        write_item.wr_en           = 1'b1;
        write_item.wr_data         = 8'hA5;
        write_item.rd_en           = 1'b0;
        write_item.sampled         = 1'b1;
        write_item.rd_data         = 8'h3C;
        write_item.empty           = 1'b0;
        write_item.full            = 1'b1;
        write_item.data_count      = COUNT_WIDTH'(DEPTH);

        if ((write_item.operation_name() != "WRITE") ||
            (write_item.wr_data          != 8'hA5) ||
            (write_item.data_count       != COUNT_WIDTH'(DEPTH))) begin
            `uvm_fatal("FIFO_ITEM_FIELDS",
                       "write_item did not preserve the expected FIFO fields")
        end

        copy_item = item_t::type_id::create("copy_item");

        if (copy_item == null) begin
            `uvm_fatal("FIFO_ITEM_FACTORY", "factory returned a null copy_item")
        end

        copy_item.transaction_id = 64'hFEDC_BA98_7654_3210;
        copy_item.wr_en           = 1'b0;
        copy_item.wr_data         = 8'h5A;
        copy_item.rd_en           = 1'b1;
        copy_item.rd_data         = 8'hC3;
        copy_item.empty           = 1'b1;
        copy_item.full            = 1'b0;
        copy_item.data_count      = '0;
        copy_item.sampled         = 1'b0;

        copy_item.copy(write_item);

        if ((copy_item.transaction_id !== write_item.transaction_id) ||
            (copy_item.wr_en          !== write_item.wr_en)          ||
            (copy_item.wr_data        !== write_item.wr_data)        ||
            (copy_item.rd_en          !== write_item.rd_en)          ||
            (copy_item.rd_data        !== write_item.rd_data)        ||
            (copy_item.empty          !== write_item.empty)          ||
            (copy_item.full           !== write_item.full)           ||
            (copy_item.data_count     !== write_item.data_count)     ||
            (copy_item.sampled        !== write_item.sampled)) begin
            `uvm_fatal("FIFO_ITEM_COPY_FIELDS",
                       "copy() did not transfer every registered sequence item field")
        end

        if (!copy_item.compare(write_item)) begin
            `uvm_fatal("FIFO_ITEM_COPY", "UVM copy/compare did not preserve all fields")
        end

        copy_item.transaction_id ^= 64'd1;
        expect_compare_mismatch(copy_item, write_item, "transaction_id");
        copy_item.transaction_id = write_item.transaction_id;

        copy_item.wr_en = !copy_item.wr_en;
        expect_compare_mismatch(copy_item, write_item, "wr_en");
        copy_item.wr_en = write_item.wr_en;

        copy_item.wr_data ^= 8'h01;
        expect_compare_mismatch(copy_item, write_item, "wr_data");
        copy_item.wr_data = write_item.wr_data;

        copy_item.rd_en = !copy_item.rd_en;
        expect_compare_mismatch(copy_item, write_item, "rd_en");
        copy_item.rd_en = write_item.rd_en;

        copy_item.rd_data ^= 8'h01;
        expect_compare_mismatch(copy_item, write_item, "rd_data");
        copy_item.rd_data = write_item.rd_data;

        copy_item.empty = !copy_item.empty;
        expect_compare_mismatch(copy_item, write_item, "empty");
        copy_item.empty = write_item.empty;

        copy_item.full = !copy_item.full;
        expect_compare_mismatch(copy_item, write_item, "full");
        copy_item.full = write_item.full;

        copy_item.data_count ^= 1;
        expect_compare_mismatch(copy_item, write_item, "data_count");
        copy_item.data_count = write_item.data_count;

        copy_item.sampled = !copy_item.sampled;
        expect_compare_mismatch(copy_item, write_item, "sampled");
        copy_item.sampled = write_item.sampled;

        if (!copy_item.compare(write_item)) begin
            `uvm_fatal("FIFO_ITEM_COMPARE_RESTORE",
                       "restored copy_item no longer matched write_item")
        end

        random_item = item_t::type_id::create("random_item");

        if (random_item == null) begin
            `uvm_fatal("FIFO_ITEM_FACTORY", "factory returned a null random_item")
        end

        random_item.operation_mix_c.constraint_mode(0);

        if ((random_item.randomize() with {
                wr_en == 1'b0;
                rd_en == 1'b1;
            }) != 1) begin
            `uvm_fatal("FIFO_ITEM_CONSTRAINT",
                       "legal READ operation could not be randomized")
        end
        if (random_item.operation_name() != "READ") begin
            `uvm_fatal("FIFO_ITEM_OPERATION_NAME", "01 was not named READ")
        end

        if ((random_item.randomize() with {
                wr_en == 1'b1;
                rd_en == 1'b0;
            }) != 1) begin
            `uvm_fatal("FIFO_ITEM_CONSTRAINT",
                       "legal WRITE operation could not be randomized")
        end
        if (random_item.operation_name() != "WRITE") begin
            `uvm_fatal("FIFO_ITEM_OPERATION_NAME", "10 was not named WRITE")
        end

        if ((random_item.randomize() with {
                wr_en == 1'b1;
                rd_en == 1'b1;
            }) != 1) begin
            `uvm_fatal("FIFO_ITEM_CONSTRAINT",
                       "legal WRITE_AND_READ operation could not be randomized")
        end
        if (random_item.operation_name() != "WRITE_AND_READ") begin
            `uvm_fatal("FIFO_ITEM_OPERATION_NAME", "11 was not named WRITE_AND_READ")
        end

        for (sample_index = 0;
             sample_index < ACTIVE_ONLY_SAMPLES;
             sample_index++) begin
            if (random_item.randomize() != 1) begin
                `uvm_fatal("FIFO_ITEM_ACTIVE_RANDOMIZE",
                           $sformatf("active-only randomization failed at sample %0d",
                                     sample_index))
            end

            if ({random_item.wr_en, random_item.rd_en} == 2'b00) begin
                `uvm_fatal("FIFO_ITEM_IDLE_REJECTION",
                           $sformatf("active_operation_c produced IDLE at sample %0d",
                                     sample_index))
            end
        end

        random_item.active_operation_c.constraint_mode(0);
        if ((random_item.randomize() with {
                wr_en == 1'b0;
                rd_en == 1'b0;
            }) != 1) begin
            `uvm_fatal("FIFO_ITEM_IDLE_CONTROL",
                       "IDLE could not be generated after active constraint was disabled")
        end
        if (random_item.operation_name() != "IDLE") begin
            `uvm_fatal("FIFO_ITEM_OPERATION_NAME", "00 was not named IDLE")
        end

        random_item.active_operation_c.constraint_mode(1);
        random_item.operation_mix_c.constraint_mode(1);

        operation_counts[0] = 0;
        operation_counts[1] = 0;
        operation_counts[2] = 0;
        operation_counts[3] = 0;

        for (sample_index = 0; sample_index < RANDOM_SAMPLES; sample_index++) begin
            if (random_item.randomize() != 1) begin
                `uvm_fatal("FIFO_ITEM_RANDOMIZE",
                           $sformatf("randomization failed at sample %0d", sample_index))
            end

            operation_counts[{random_item.wr_en, random_item.rd_en}]++;
        end

        if (operation_counts[0] != 0) begin
            `uvm_fatal("FIFO_ITEM_DISTRIBUTION",
                       $sformatf("IDLE appeared %0d times", operation_counts[0]))
        end

        if ((operation_counts[1] < 250) || (operation_counts[1] > 550) ||
            (operation_counts[2] < 250) || (operation_counts[2] > 550) ||
            (operation_counts[3] < 100) || (operation_counts[3] > 350)) begin
            `uvm_fatal("FIFO_ITEM_DISTRIBUTION",
                       $sformatf("4:4:2 distribution out of bounds: read=%0d write=%0d both=%0d",
                                 operation_counts[1],
                                 operation_counts[2],
                                 operation_counts[3]))
        end

        non_power_item = non_power_item_t::type_id::create("non_power_item");

        if (non_power_item == null) begin
            `uvm_fatal("FIFO_ITEM_FACTORY", "factory returned a null non_power_item")
        end

        if ($bits(non_power_item.wr_data) != NON_POWER_DATA_WIDTH) begin
            `uvm_fatal("FIFO_ITEM_DATA_WIDTH", "parameterized wr_data width is incorrect")
        end

        if ($bits(non_power_item.data_count) != $clog2(NON_POWER_DEPTH + 1)) begin
            `uvm_fatal("FIFO_ITEM_COUNT_WIDTH", "non-power-of-two data_count width is incorrect")
        end

        non_power_item.data_count = NON_POWER_COUNT_WIDTH'(NON_POWER_DEPTH);
        if (non_power_item.data_count != NON_POWER_COUNT_WIDTH'(NON_POWER_DEPTH)) begin
            `uvm_fatal("FIFO_ITEM_COUNT_VALUE", "data_count could not represent DEPTH=5")
        end

        `uvm_info("FIFO_ITEM",
                  $sformatf("factory id=0x%0h op=%0s; samples read=%0d write=%0d both=%0d; depth5_count_bits=%0d",
                            write_item.transaction_id,
                            write_item.operation_name(),
                            operation_counts[1],
                            operation_counts[2],
                            operation_counts[3],
                            $bits(non_power_item.data_count)),
                  UVM_LOW)

        `uvm_info("FIFO_ITEM_PASS",
                  "UVM SEQUENCE ITEM PASS: factory, defaults, fields, copy, compare negatives, isolated constraints, distribution, and parameters worked",
                  UVM_NONE)

        phase.drop_objection(this, "FIFO UVM item test completed");
    endtask

endclass

`endif
