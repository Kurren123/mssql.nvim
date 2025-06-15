local mssql = require("mssql")
local utils = require("mssql.utils")
local test_utils = require("tests.utils")

return {
  test_name = "Canceled query receives confirmation and completion; manager stays connected.",
  run_test_async = function()
    local query = "WAITFOR DELAY '00:00:30' SELECT 1 AS test"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { query })
    utils.wait_for_schedule_async()
    mssql.execute_query()
    local client = vim.lsp.get_clients({ name = "mssql_ls", bufnr = 0 })[1]
    local buf = vim.api.nvim_get_current_buf()
    local qm = vim.b[buf].query_manager

    -- client sends "query/cancel" method with ownerUri as only param
    mssql.cancel_query()

    -- gets a "result" return from server with a null message assume this is the results for the canceled query
    -- also gets a "query/message" method from server with message "Query was canceled by user"
    local result, msg_verify_err = utils.wait_for_notification_async(buf, client, "query/message", 30000)
    if msg_verify_err then
      error(msg_verify_err.message)
    end

    assert(result == "Query was canceled by user", "Returned message does not indicate canceled query")

    -- lastly server send a "query/batchComplete" and "query/complete" method, we check for the final complete message to confirm completion of cancelation
    local _, err = utils.wait_for_notification_async(buf, client, "query/complete", 30000)
    if err then
      error(err.message)
    end

    -- ensure we're still connected after cancelation
    local state = qm.get_state()
    assert(state == "Connected", "Query manager not in Connected state after cancelation")

    test_utils.defer_async(2000)
    vim.cmd("bdelete")
  end,
}
