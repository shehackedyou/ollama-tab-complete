-- lua/ollama_tab_complete/lua/ollama_tab_complete/ui.lua

local config = require('ollama_tab_complete.config')
local UI_TEXT = config.config.ui_text

local M = {}

local current_ghost_text_id = nil
local virtual_text_hl_group = "OllamaInlineSuggestion"
local statusline_indicator_text = UI_TEXT.status_ready
local statusline_error_indicator = ""
M.automatic_completion_debounce = nil
local ghost_text_lines = {}

-- Centralized UI Text (moved from ui.lua to config.lua)
local UI_TEXT = config.config.ui_text


--function M.ensure_highlight_group()
--  local group_exists = vim.api.nvim_get_hl_id(virtual_text_hl_group) ~= 0
--  if not group_exists then
--    vim.api.nvim_command("highlight! link " .. virtual_text_hl_group .. " Comment")
--  end
--  M.ensure_notification_highlights()
--end


function M.ensure_notification_highlights()
  vim.api.nvim_command("highlight! OllamaNotifyInfo guifg=" .. config.config.ui_colors.info)
  vim.api.nvim_command("highlight! OllamaNotifyWarn guifg=" .. config.config.ui_colors.warn)
  vim.api.nvim_command("highlight! OllamaNotifyError guifg=" .. config.config.ui_colors.error)
end


-- **NEW: Helper functions for notifications (DRY - Encapsulate vim.notify calls)**

function M.notify_info(message)
  vim.notify(message, vim.log.levels.INFO, { title = "Ollama Tab Complete", highlight = "OllamaNotifyInfo" })
end

function M.notify_warn(message)
  vim.notify(message, vim.log.levels.WARN, { title = "Ollama Tab Complete", highlight = "OllamaNotifyWarn" })
end

function M.notify_error(message)
  vim.notify(message, vim.log.levels.ERROR, { title = "Ollama Tab Complete", highlight = "OllamaNotifyError" })
end


function M.show_ghost_text(completion_text)
  local lines = vim.split(completion_text, '\n')
  vim.ui.select(lines, {
    prompt = "Ollama Completion:",
    format_item = function(item) return item end,
  }, function(choice)
    if choice then
      local cursor_pos = vim.api.nvim_win_get_cursor(0)
      local current_line = vim.api.nvim_get_current_line()
      local col = #current_line

      local lines_to_insert = vim.split(choice, '\n')
      vim.api.nvim_buf_set_text(0, cursor_pos[1] - 1, col, cursor_pos[1] - 1, col, lines_to_insert)
      vim.api.nvim_win_set_cursor(0, {cursor_pos[1] + #lines_to_insert - 1, col}) -- Move cursor to end of inserted text
    end
  end)
end


function M.clear_inline_suggestion()
  if current_ghost_text_id then
    vim.api.nvim_buf_clear_namespace(0, "ollama_inline_suggestion", 0, -1) -- Clear namespace for the buffer
    current_ghost_text_id = nil
  end
end


function M.accept_ghost_text()
  if current_ghost_text then
    local code_text = current_ghost_text.code_text
    M.clear_inline_suggestion() -- Clear virtual text
    M.insert_code_into_buffer(code_text) -- Insert the code into the buffer
  end
  return '<Tab>' -- Still perform default Tab behavior if no suggestion active (e.g., indent)
end


function M.retry_ghost_text()
  if current_ghost_text then
    M.clear_inline_suggestion() -- Clear current suggestion
    -- Re-trigger function generation based on the last comment line and comment text
    if last_comment_line then
      local line = vim.api.nvim_buf_get_lines(0, last_comment_line - 1, last_line, false)[1] -- Get the comment line again
      local comment_prefix = ""
      if vim.bo.filetype == "python" then
        comment_prefix = "# "
      elseif vim.bo.filetype == "cpp" or vim.bo.filetype == "c" or vim.bo.filetype == "javascript" or vim.bo.filetype == "typescript" or vim.bo.filetype == "go" then
        comment_prefix = "// "
      elseif vim.bo.filetype == "lua" then
        comment_prefix = "-- "
      end
      local comment_text = string.sub(line, #comment_prefix + 1)
      if is_function_comment(comment_text) then
         local function_prompt = string.format([[You are a code generating AI.
        Filetype: %s
        Generate code based on the following comment describing a function:

        Comment: %s

        Function code:]], vim.bo.filetype, comment_text)

        M.send_prompt(function_prompt, function(completion, error_message)
          if completion then
            if type(completion) == 'string' and #completion > 0 then
              M.show_inline_suggestion(completion) -- Show new inline suggestion
            else
              vim.notify("Ollama returned empty or invalid function code on retry.", vim.log.levels.WARN)
            end
          else
            vim.notify("Function generation retry from comment failed: " .. (error_message or "Unknown error"), vim.log.levels.ERROR)
          end
        end, { code_only = true })
      end
    end
  end
  return '<S-Tab>' -- Still perform default Shift+Tab behavior if no suggestion active
end


return M
