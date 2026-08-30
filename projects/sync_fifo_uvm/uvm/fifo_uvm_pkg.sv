// 统一编译 UVM 事务、组件、序列和测试，确保类型定义顺序稳定。
package fifo_uvm_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "fifo_uvm_sequence_item.sv"
    `include "fifo_uvm_sequencer.sv"
    `include "fifo_uvm_basic_sequence.sv"
    `include "fifo_uvm_coverage_sequence.sv"
    `include "fifo_uvm_random_sequence.sv"
    `include "fifo_uvm_driver.sv"
    `include "fifo_uvm_monitor.sv"
    `include "fifo_uvm_reference_model.sv"
    `include "fifo_uvm_scoreboard.sv"
    `include "fifo_uvm_coverage.sv"
    `include "fifo_uvm_agent.sv"
    `include "fifo_uvm_environment.sv"
    `include "fifo_uvm_smoke_test.sv"
    `include "fifo_uvm_item_test.sv"
    `include "fifo_uvm_sequence_test.sv"
    `include "fifo_uvm_driver_test.sv"
    `include "fifo_uvm_monitor_test.sv"
    `include "fifo_uvm_scoreboard_test.sv"
    `include "fifo_uvm_environment_test.sv"
    `include "fifo_uvm_coverage_test.sv"

endpackage
