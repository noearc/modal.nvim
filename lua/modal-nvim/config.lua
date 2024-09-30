---@class modal._config
local default = {
   keymaps = {
      eval_line = "<leader>l",
      eval_visual = "<leader>e",
      boot = "<leader>bb",
   },
}

---@class modal.config
---@field keymaps? table<string, string>

---@type modal.config
---@diagnostic disable-next-line: assign-type-mismatch
local config = vim.tbl_deep_extend("force", default, vim.g.modal or {})

return config
