# Matching Executed Requests to the Plan

[简体中文](request_matching.md) | **English**

`submit` saves a request in `pending` before `drive` sends it. The monitor samples completed transfers, `match_request` compares them with the oldest planned request, and `score` checks responses and updates the expected state.

The plan is independent of DUT state and observed bus signals. A driver error must not change the original plan.

- Plan plus completion: compare address, direction, and write data. Ignore write data on reads.
- Completion without a plan: `REQUEST_UNEXPECTED`.
- Requests still pending at the end: `REQUEST_MISSING`.

`planned` counts registered requests, `matched` counts successful matches, and `received` counts observations that pass functional checks. In the directed test all three must be 9, with an empty queue. Counts alone cannot detect a wrong address.

| Injection | Altered behavior | Expected diagnostic |
|---|---|---|
| address | First planned write to 00 is sent to 04 | REQUEST_ADDR |
| direction | First planned write is sent as a read | REQUEST_DIR |
| data | First planned 2A write sends 2B | REQUEST_DATA |
| drop | Final request is planned but not sent | REQUEST_MISSING |
| duplicate | Final completed transfer is repeated without a new plan | REQUEST_UNEXPECTED |

All five faults preserve the plan and run at wait=0/1/3. They test the driver/request-matching path, not commercial DUT defects or proof that every intended request is always generated.

Reset occurs only after planned requests have completed. The queue must be empty before reset; counters and pending requests are not silently discarded. Mid-transfer cancellation is not implemented in this environment.

FIFO-order matching suits this single-requester, non-pipelined APB setup. There is no separate reordering injection. Identical requests have no bus transaction ID, so their internal identities cannot be distinguished from bus values alone.

Read `request_t`, `pending[$]`, `submit`, `match_request`, then the final queue/count checks in `tb/apb_roles_tb.sv`.
