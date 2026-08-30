`ifndef FIFO_UVM_SEQUENCER_SV
`define FIFO_UVM_SEQUENCER_SV

// Sequencer 负责仲裁 sequence 产生的事务，并通过标准端口交给 driver。
// 当前只有一条主序列，因此无需增加额外调度策略。
class fifo_uvm_sequencer #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 4
) extends uvm_sequencer #(fifo_uvm_sequence_item #(DATA_WIDTH, DEPTH));

    `uvm_component_param_utils(fifo_uvm_sequencer #(DATA_WIDTH, DEPTH))

    function new(string name = "fifo_uvm_sequencer",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass

`endif
