// =============================================================================
// macOS compatibility shim for the Verilator-compatible UVM DPI library
// =============================================================================
//
// UVM = Universal Verification Methodology, the standard reusable verification
// methodology; 通用验证方法学。
// DPI = Direct Programming Interface, the SystemVerilog and C/C++ interoperation
// interface; 直接编程接口。
//
// Linux commonly exposes malloc declarations through <malloc.h>.
// macOS exposes malloc, calloc, realloc and free through <stdlib.h> and does not
// provide <malloc.h>. The pinned UVM 2020-3.1 Verilator branch includes the
// Linux header name, so the compiler searches this project directory first and
// reaches the portable standard header without modifying third-party sources.
// =============================================================================

#ifndef DIGITAL_IC_UVM_COMPAT_MALLOC_H
#define DIGITAL_IC_UVM_COMPAT_MALLOC_H

#include <stdlib.h>

#endif
