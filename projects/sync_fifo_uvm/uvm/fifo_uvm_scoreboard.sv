`ifndef FIFO_UVM_SCOREBOARD_SV
`define FIFO_UVM_SCOREBOARD_SV

class fifo_uvm_scoreboard #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
) extends uvm_subscriber #(fifo_uvm_sequence_item #(DATA_WIDTH, DEPTH));

    typedef fifo_uvm_sequence_item #(DATA_WIDTH, DEPTH) item_t;
    typedef fifo_uvm_reference_model #(DATA_WIDTH, DEPTH) reference_model_t;

    `uvm_component_param_utils(fifo_uvm_scoreboard #(DATA_WIDTH, DEPTH))

    reference_model_t reference_model;

    int unsigned compared_count;
    int unsigned pass_count;
    int unsigned error_count;
    int unsigned transaction_id_mismatch_count;
    int unsigned sampled_mismatch_count;
    int unsigned rd_data_mismatch_count;
    int unsigned data_count_mismatch_count;
    int unsigned empty_mismatch_count;
    int unsigned full_mismatch_count;

    item_t last_actual_tx;
    item_t last_expected_tx;

    function new(string name = "fifo_uvm_scoreboard",
                 uvm_component parent = null);
        super.new(name, parent);
        compared_count   = 0;
        pass_count       = 0;
        error_count      = 0;
        transaction_id_mismatch_count = 0;
        sampled_mismatch_count        = 0;
        rd_data_mismatch_count        = 0;
        data_count_mismatch_count     = 0;
        empty_mismatch_count          = 0;
        full_mismatch_count           = 0;
        last_actual_tx   = null;
        last_expected_tx = null;
    endfunction

    function int unsigned field_mismatch_count();
        return transaction_id_mismatch_count +
               sampled_mismatch_count +
               rd_data_mismatch_count +
               data_count_mismatch_count +
               empty_mismatch_count +
               full_mismatch_count;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        reference_model = reference_model_t::type_id::create("reference_model");
        if (reference_model == null) begin
            `uvm_fatal("FIFO_SCB_NO_REF",
                       "scoreboard could not create the reference model")
        end
    endfunction

    virtual function void write(item_t actual_tx);
        item_t expected_tx;
        longint unsigned expected_id;
        bit mismatch;
        bit transaction_id_mismatch;
        bit sampled_mismatch;
        bit rd_data_mismatch;
        bit data_count_mismatch;
        bit empty_mismatch;
        bit full_mismatch;

        if (actual_tx == null) begin
            error_count++;
            `uvm_error("FIFO_SCB_NULL",
                       "scoreboard received a null actual transaction")
            return;
        end

        compared_count++;
        expected_id = {32'b0, compared_count};

        expected_tx = reference_model.predict(actual_tx);
        if (expected_tx == null) begin
            error_count++;
            `uvm_error("FIFO_SCB_EXPECTED_NULL",
                       "reference model returned a null expected transaction")
            return;
        end

        last_actual_tx   = actual_tx;
        last_expected_tx = expected_tx;

        transaction_id_mismatch =
            (actual_tx.transaction_id != expected_id);
        sampled_mismatch = (actual_tx.sampled != 1'b1);
        rd_data_mismatch = (actual_tx.rd_data !== expected_tx.rd_data);
        data_count_mismatch =
            (actual_tx.data_count !== expected_tx.data_count);
        empty_mismatch = (actual_tx.empty !== expected_tx.empty);
        full_mismatch  = (actual_tx.full  !== expected_tx.full);

        mismatch = transaction_id_mismatch ||
                   sampled_mismatch ||
                   rd_data_mismatch ||
                   data_count_mismatch ||
                   empty_mismatch ||
                   full_mismatch;

        if (mismatch) begin
            error_count++;

            transaction_id_mismatch_count += transaction_id_mismatch;
            sampled_mismatch_count        += sampled_mismatch;
            rd_data_mismatch_count        += rd_data_mismatch;
            data_count_mismatch_count     += data_count_mismatch;
            empty_mismatch_count          += empty_mismatch;
            full_mismatch_count           += full_mismatch;

            `uvm_error("FIFO_SCB_MISMATCH",
                       $sformatf("comparison=%0d fields: id=%0b sampled=%0b rd_data=%0b data_count=%0b empty=%0b full=%0b | op=%0s data=0x%0h | actual: id=%0d sampled=%0b rd_data=0x%0h count=%0d empty=%0b full=%0b | expected: id=%0d sampled=1 rd_data=0x%0h count=%0d empty=%0b full=%0b",
                                 compared_count,
                                 transaction_id_mismatch,
                                 sampled_mismatch,
                                 rd_data_mismatch,
                                 data_count_mismatch,
                                 empty_mismatch,
                                 full_mismatch,
                                 actual_tx.operation_name(),
                                 actual_tx.wr_data,
                                 actual_tx.transaction_id,
                                 actual_tx.sampled,
                                 actual_tx.rd_data,
                                 actual_tx.data_count,
                                 actual_tx.empty,
                                 actual_tx.full,
                                 expected_id,
                                 expected_tx.rd_data,
                                 expected_tx.data_count,
                                 expected_tx.empty,
                                 expected_tx.full))
        end else begin
            pass_count++;
            `uvm_info("FIFO_SCB_PASS",
                      $sformatf("comparison=%0d op=%0s rd_data=0x%0h count=%0d empty=%0b full=%0b",
                                compared_count,
                                actual_tx.operation_name(),
                                actual_tx.rd_data,
                                actual_tx.data_count,
                                actual_tx.empty,
                                actual_tx.full),
                      UVM_LOW)
        end
    endfunction

endclass

`endif
