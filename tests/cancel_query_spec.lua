local mssql = require("mssql")
local test_utils = require("tests.utils")

return {
  test_name = "Cancelling a query returns the query manager to a Connected state.",
  run_test_async = function()
    local query = "WAITFOR DELAY '00:00:30' SELECT 1 AS test"
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { query })

    mssql.execute_query()
    mssql.cancel_query()
    test_utils.defer_async(1000)

    local qm = vim.b.query_manager

    -- ensure we're still connected after cancelation
    local state = qm.get_state()
    assert(state == "connected", "Query manager should be 'Connected' after cancellation, but was '" .. state .. "'")

    test_utils.defer_async(2000)
    vim.cmd("bdelete!")
  end,
}
