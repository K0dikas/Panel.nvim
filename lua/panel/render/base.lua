local M = {}

local namespace = vim.api.nvim_create_namespace("nvim-panel")

function M.namespace()
	return namespace
end

return M
