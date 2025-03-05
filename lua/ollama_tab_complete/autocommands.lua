-- lua/ollama_tab_complete/lua/ollama_tab_complete/autocommands.lua

local M = {}

function M.setup_autocommands(core_module, ui_module, prompt_module, completion_module)
  vim.api.nvim_create_autocmd("TextChangedI", {
    group = vim.api.nvim_create_augroup("OllamaTabCompleteTriggers", { clear = true }),
    callback = function() core_module.on_text_changed_for_comment_function() end,
    pattern = "*",
  })
  vim.api.nvim_create_autocmd("TextChangedI", { -- Automatic Completion Trigger
    group = "OllamaCompleteTriggers",
    callback = function() core_module.on_text_changed_for_auto_completion() end,
    pattern = "*",
  })
  vim.api.nvim_create_autocmd({ "CursorMovedI", "TextChangedI", "InsertLeave", "FocusLost" }, {
    group = vim.api.nvim_create_augroup("OllamaTabCompleteGhostTextClear", { clear = true }),
    callback = ui_module.clear_ghost_text,
    pattern = "*",
  })
end


return M
