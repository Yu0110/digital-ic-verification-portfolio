// 记分板逐笔比较监视器的实际结果与独立参考模型的预测结果。
// 除总错误数外还分别统计字段错误，便于回归失败后快速定位。
class fifo_scoreboard #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
);

    typedef fifo_transaction #(DATA_WIDTH, DEPTH) tx_t;
    typedef fifo_reference_model #(DATA_WIDTH, DEPTH) reference_model_t;

    mailbox #(tx_t) observed_inbox;

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
    longint unsigned first_error_transaction_id;
    longint unsigned last_error_transaction_id;

    function new(
        mailbox #(tx_t) observed_mailbox_handle,
        reference_model_t reference_model_handle
    );
        this.observed_inbox  = observed_mailbox_handle;
        this.reference_model = reference_model_handle;
        this.compared_count  = 0;
        this.pass_count      = 0;
        this.error_count     = 0;

        this.transaction_id_mismatch_count = 0;
        this.sampled_mismatch_count        = 0;
        this.rd_data_mismatch_count        = 0;
        this.data_count_mismatch_count     = 0;
        this.empty_mismatch_count          = 0;
        this.full_mismatch_count           = 0;
        this.first_error_transaction_id    = 0;
        this.last_error_transaction_id     = 0;
    endfunction

    function int unsigned field_mismatch_count();
        return transaction_id_mismatch_count +
               sampled_mismatch_count +
               rd_data_mismatch_count +
               data_count_mismatch_count +
               empty_mismatch_count +
               full_mismatch_count;
    endfunction

    task automatic run(input int unsigned expected_count);
        tx_t actual_tx;
        tx_t expected_tx;
        bit mismatch;
        bit transaction_id_mismatch;
        bit sampled_mismatch;
        bit rd_data_mismatch;
        bit data_count_mismatch;
        bit empty_mismatch;
        bit full_mismatch;

        if (observed_inbox == null) begin
            $fatal(1, "fifo_scoreboard.run() requires a non-null observed mailbox");
        end

        if (reference_model == null) begin
            $fatal(1, "fifo_scoreboard.run() requires a non-null reference model");
        end

        repeat (expected_count) begin
            observed_inbox.get(actual_tx);

            if (actual_tx == null) begin
                error_count++;
                $error("fifo_scoreboard received a null transaction handle");
            end else begin
                compared_count++;

                // 参考模型只使用本笔请求生成期望响应，不查看 DUT 内部信号。
                expected_tx = reference_model.predict(actual_tx);

                transaction_id_mismatch =
                    (actual_tx.transaction_id != 64'(compared_count));
                sampled_mismatch = (actual_tx.sampled != 1'b1);
                rd_data_mismatch = (actual_tx.rd_data !== expected_tx.rd_data);
                data_count_mismatch =
                    (actual_tx.data_count !== expected_tx.data_count);
                empty_mismatch = (actual_tx.empty !== expected_tx.empty);
                full_mismatch  = (actual_tx.full  !== expected_tx.full);

                // 使用四态不等比较数据字段，X/Z 也必须作为验证失败处理。
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

                    if (error_count == 1) begin
                        first_error_transaction_id = actual_tx.transaction_id;
                    end
                    last_error_transaction_id = actual_tx.transaction_id;

                    $display(
                        "SCOREBOARD ERROR comparison=%0d fields: id=%0b sampled=%0b rd_data=%0b data_count=%0b empty=%0b full=%0b",
                        compared_count,
                        transaction_id_mismatch,
                        sampled_mismatch,
                        rd_data_mismatch,
                        data_count_mismatch,
                        empty_mismatch,
                        full_mismatch
                    );
                    actual_tx.print("ACTUAL_TX");
                    expected_tx.print("EXPECTED_TX");
                end else begin
                    pass_count++;
                    $display("SCOREBOARD PASS comparison=%0d op=%0s rd_data=0x%0h count=%0d empty=%b full=%b",
                             compared_count,
                             actual_tx.operation_name(),
                             actual_tx.rd_data,
                             actual_tx.data_count,
                             actual_tx.empty,
                             actual_tx.full);
                end
            end
        end
    endtask

endclass
