-- lua/ollama_tab_complete/lua/ollama_tab_complete/prompt.lua

local config = require('ollama_tab_complete.config')
local ui = require('ollama_tab_complete.ui')
local UI_TEXT = config.config.ui_text -- Access UI_TEXT for concise code


local M = {}

local prompt_history = {} -- History moved to prompt module
local last_comment_line = nil -- Last comment line also relevant to prompt context


function M.register_preset_commands(core_module)
  local presets = config.config.prompt_presets
  for name, preset in pairs(presets) do
    vim.api.nvim_create_user_command(name:gsub("_", " "):gsub("%w+", string.upper), -- Command name from preset key
      function(opts)
        M.handle_preset_command(core_module, preset, opts)
      end,
      {
        nargs = '0',
        desc = preset.description,
      }
    )
  end
end


function M.handle_preset_command(core_module, preset, command_opts)
  local selection = M.get_visual_selection()

  if not selection then
    ui.notify_warn(UI_TEXT.preset_no_visual_selection_warning .. preset.description) -- Use ui.notify_warn helper
    return
  end

  local prompt_text = string.gsub(preset.prompt, "{{selection}}", selection)

  if preset.command == "Prompt" then
    core_module.send_prompt(prompt_text, function(completion, error_message)
      if completion then
        ui.show_completion_popup(completion)
      else
        ui.notify_error("Preset Prompt failed: " .. (error_message or "Unknown error")) -- Use ui.notify_error helper
      end
    end)
  elseif preset.command == "PromptCode" then
    core_module.send_prompt(prompt_text, function(completion, error_message)
      if completion then
        ui.insert_code_into_buffer(completion)
      else
        ui.notify_error("Preset PromptCode failed: " .. (error_message or "Unknown error")) -- Use ui.notify_error helper
      end
    end, { code_only = true })
  end
end


function M.get_visual_selection()
  local visual_mode = vim.fn.mode(true):sub(1, 1)
  if visual_mode ~= 'v' and visual_mode ~= 'V' and visual_mode ~= '^V' then
    return nil
  end

  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  local start_line = start_pos[2]
  local start_col = start_pos[3]
  local end_line = end_pos[2]
  local end_col = end_pos[3]

  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  local selection_lines = {}

  for i, line in ipairs(lines) do
    local start_col_for_line = (i == 1) and start_col or 1
    local end_col_for_line = (i == #lines) and end_col or -1

    local selected_part = string.sub(line, start_col_for_line, end_col_for_line)
    table.insert(selection_lines, selected_part)
  end

  return table.concat(selection_lines, "\n")
end


function M.create_completion_prompt(context_data)
  return string.format(config.config.completion_prompt_template,
                       context_data.filetype, context_data.context, context_data.current_line)
end


function M.add_to_history(prompt_text, response)
  table.insert(prompt_history, { prompt = prompt_text, response = response })
  if #prompt_history > 20 then
    table.remove(prompt_history, 1)
  end
end


function M.show_history(ui_module, opts)
  if #prompt_history == 0 then
    ui.notify_info(UI_TEXT.no_ollama_history_yet) -- Use ui.notify_info helper
    return
  end

  local history_items = {}
  for i = #prompt_history, 1, -1 do
    local item = prompt_history[i]
    table.insert(history_items, ("Prompt: %s\nResponse: %s"):format(item.prompt, item.response))
  end

  vim.ui.select(history_items, {
    prompt = UI_TEXT.ollama_prompt_history_popup_prompt,
    format_item = function(item) return item end,
  }, function(choice)
    if choice then
      local selected_history_item = prompt_history[#prompt_history - vim.tbl_index(history_items, choice) + 1]

      if selected_history_item then
          vim.ui.select({ "Re-run Prompt", "View Response" }, {}, function(action_choice)
              if action_choice == "Re-run Prompt" then
                  require('ollama_tab_complete.core').send_prompt(selected_history_item.prompt, function(completion, error)
                      if completion then
                          ui.show_completion_popup(completion)
                      else
                          ui.notify_error(UI_TEXT.re_run_prompt_failed .. (error or "Unknown error")) -- Use ui.notify_error helper
                      end
                  end)
              elseif action_choice == "View Response" then
                  ui.show_completion_popup(selected_history_item.response)
              end
          end)
      end
    end
  end)
end


function M.handle_history_command(ui_module, opts)
  M.show_history(ui_module, opts)
end


function M.on_text_changed_for_comment_function(core_module)
  if not M.is_comment_line() then
    last_comment_line = nil
    return
  end

  local current_line = vim.api.nvim_get_current_line()
  local comment_prefix = config.config.comment_prefixes[vim.bo.filetype]
  if type(comment_prefix) == "table" then
    comment_prefix = comment_prefix[1]
  end
  comment_prefix = comment_prefix or ""

  local comment_text = string.sub(current_line, #comment_prefix + 1)

  if last_comment_line == vim.api.nvim_win_get_cursor(0)[1] then
    if M.is_function_comment(comment_text) then
      local context_data = require('ollama_tab_complete.core').get_context()

      local function_prompt = string.format([[You are a code generating MLM.
Filetype: %s
Generate code based on the following comment describing a function:

Comment: %s

Function code:]], vim.bo.filetype, comment_text)

      core_module.send_prompt(function_prompt, function(completion, error_message)
        if completion then
          if type(completion) == 'string' and #completion > 0 then
            ui.show_inline_suggestion(completion)
          else
            ui.notify_warn(UI_TEXT.ollama_returned_invalid_function_code) -- Use ui.notify_warn helper
          end
        else
          ui.notify_error(UI_TEXT.function_generation_from_comment_failed .. (error_message or "Unknown error")) -- Use ui.notify_error helper
        end
      end, { code_only = true })
    end
  end

  last_comment_line = vim.api.nvim_win_get_cursor(0)[1]
end


function M.is_comment_line()
  local filetype = vim.bo.filetype
  local current_line = vim.api.nvim_get_current_line()
  local prefixes = config.config.comment_prefixes[filetype]

  if prefixes then
    if type(prefixes) == "string" then
      return string.sub(current_line, 1, #prefixes) == prefixes
    elseif type(prefixes) == "table" then
      for _, prefix in ipairs(prefixes) do
        if string.sub(current_line, 1, #prefix) == prefix then
          return true
        end
      end
    end
  end
  return false
end


function M.is_function_comment(comment_text)
  local lower_comment = string.lower(comment_text)
  for _, keyword in ipairs(config.config.function_comment_keywords) do
    if string.find(lower_comment, keyword) then
      return true
    end
  end
  return false
end


return M
