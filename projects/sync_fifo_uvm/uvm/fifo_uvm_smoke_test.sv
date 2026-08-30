`ifndef FIFO_UVM_SMOKE_TEST_SV
`define FIFO_UVM_SMOKE_TEST_SV

class fifo_uvm_smoke_test extends uvm_test;

    `uvm_component_utils(fifo_uvm_smoke_test)

    static bit build_phase_seen;
    static bit run_phase_seen;

    function new(string name = "fifo_uvm_smoke_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        build_phase_seen = 1'b1;

        `uvm_info("FIFO_BUILD",
                  "fifo_uvm_smoke_test entered build_phase",
                  UVM_LOW)
    endfunction

    virtual task run_phase(uvm_phase phase);
        if (!build_phase_seen) begin
            `uvm_fatal("FIFO_PHASE_ORDER",
                       "run_phase started before build_phase was observed")
        end

        phase.raise_objection(this, "UVM smoke test started");

        `uvm_info("FIFO_RUN",
                  "fifo_uvm_smoke_test entered run_phase",
                  UVM_LOW)

        #1ns;
        run_phase_seen = 1'b1;

        `uvm_info("FIFO_SMOKE_PASS",
                  "UVM SMOKE PASS: factory, build_phase, run_phase, and objection all worked",
                  UVM_NONE)

        phase.drop_objection(this, "UVM smoke test completed");
    endtask

endclass

`endif
