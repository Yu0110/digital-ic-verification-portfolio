// 最小冒烟包仅包含工具链自检所需的基础测试，减少首次编译规模。
package fifo_uvm_smoke_pkg;

    import uvm_pkg::*;

    `include "uvm_macros.svh"

    `include "fifo_uvm_smoke_test.sv"

endpackage
