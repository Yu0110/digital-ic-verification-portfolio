`ifndef FIFO_UVM_SEQUENCER_SV
`define FIFO_UVM_SEQUENCER_SV

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
