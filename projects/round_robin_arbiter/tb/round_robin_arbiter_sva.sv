// 接口级时序断言：只观察公开端口，不依赖 DUT 内部实现。
module round_robin_arbiter_sva (
    input logic       clk,
    input logic       rst_n,
    input logic [3:0] req,
    input logic [3:0] grant
);

    timeunit 1ns;
    timeprecision 1ps;

    // 复位期间禁止向共享资源发出授权。
    property p_reset_blocks_grant;
        @(posedge clk) !rst_n |-> (grant == 4'b0000);
    endproperty

    // 正常工作时，授权必须为全零或独热编码。
    property p_grant_is_onehot0;
        @(posedge clk) disable iff (!rst_n) $onehot0(grant);
    endproperty

    // 每一个授权位都必须有对应的请求位。
    property p_grant_has_request;
        @(posedge clk) disable iff (!rst_n) ((grant & ~req) == 4'b0000);
    endproperty

    // 非空请求不能被组合选择逻辑整体漏掉。
    property p_nonempty_request_gets_grant;
        @(posedge clk) disable iff (!rst_n)
            (req != 4'b0000) |-> (grant != 4'b0000);
    endproperty

    a_reset_blocks_grant: assert property (p_reset_blocks_grant)
        else $error("SVA reset violation: grant=%b", grant);

    a_grant_is_onehot0: assert property (p_grant_is_onehot0)
        else $error("SVA one-hot violation: grant=%b", grant);

    a_grant_has_request: assert property (p_grant_has_request)
        else $error("SVA request/grant violation: req=%b grant=%b", req, grant);

    a_nonempty_request_gets_grant: assert property (p_nonempty_request_gets_grant)
        else $error("SVA dropped request: req=%b grant=%b", req, grant);

endmodule
