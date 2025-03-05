-- lua/ollama_tab_complete/lua/ollama_tab_complete/core.lua

local config = require('ollama_tab_complete.config')
local api = require('ollama_tab_complete.api')
local prompt = require('ollama_tab_complete.prompt')
local ui = require('ollama_tab_complete.ui')
local lifecycle = require('ollama_tab_complete.lifecycle')
local completion = require('ollama_tab_complete.completion')
local UI_TEXT = config.config.ui_text

local M = {}

local prompt_history = {}
local last_comment_line = nil
local current_ghost_text_id = nil
local automatic_completion_debounce = nil

function M.setup(user_config)
  config.setup(user_config)
  M.map_keys()
  M.register_commands()
  M.setup_autocommands()
  ui.ensure_highlight_group()
  lifecycle.check_and_start_ollama()
  lifecycle.setup_shutdown_autocommand()
  lifecycle.register_signal_handler()

  ui.setup_statusline()
  ui.set_statusline_indicator_text(UI_TEXT.status_idle)
  completion.setup_completion_menu()
end

function M.map_keys()
  vim.keymap.set('n', config.config.trigger_key, M.trigger_completion, { desc = "Trigger Ollama Completion" })
  vim.keymap.set('i', '<Tab>', ui.accept_ghost_text, { desc = "Accept Ollama Ghost Text", silent = true, noremap = true })
  vim.keymap.set('i', '<S-Tab>', ui.retry_ghost_text, { desc = "Retry Ollama Ghost Text", silent = true, noremap = true })
end


function M.register_commands()
  vim.api.nvim_create_user_command('Prompt', M.handle_prompt_command, {
    nargs = '+',
    desc = 'Send a prompt to Ollama (popup)',
  })
  vim.api.nvim_create_user_command('PromptCode', M.handle_prompt_code_command, {
    nargs = '+',
    desc = 'Send a prompt to Ollama and insert code',
  })
  vim.api.nvim_create_user_command('OllamaHistory', M.handle_history_command, {
    nargs = '*',
    desc = 'Show Ollama Prompt History',
  })
end


function M.setup_autocommands()
  vim.api.nvim_create_autocmd("TextChangedI", {
    group = vim.api.nvim_create_augroup("OllamaTabCompleteTriggers", { clear = true }),
    callback = M.on_text_changed_for_comment_function,
    pattern = "*",
  })
  vim.api.nvim_create_autocmd("TextChangedI", { -- Automatic Completion Trigger
    group = "OllamaTabCompleteTriggers",
    callback = M.on_text_changed_for_auto_completion,
    pattern = "*",
  })
  vim.api.nvim_create_autocmd({ "CursorMovedI", "TextChangedI", "InsertLeave", "FocusLost" }, {
    group = vim.api.nvim_create_augroup("OllamaTabCompleteGhostTextClear", { clear = true }),
    callback = ui.clear_ghost_text,
    pattern = "*",
  })
end


function M.on_text_changed_for_comment_function()
  prompt.on_text_changed_for_comment_function(M, ui)
end

function M.on_text_changed_for_auto_completion()
  completion.on_text_changed_for_auto_completion(M, ui, prompt)
end


function M.get_context()
  local current_line = vim.api.nvim_get_current_line()
  local filetype = vim.bo.filetype
  local context_lines = {}

  local current_line_nr = vim.api.nvim_win_get_cursor(0)[1]
  local start_line = math.max(1, current_line_nr - config.config.max_context_lines)
  local end_line = current_line_nr - 1

  if start_line <= end_line then
    for line_nr = start_line, end_line do
      local line = vim.api.nvim_buf_get_lines(0, line_nr - 1, line_nr, false)[1]
      if line then
        table.insert(context_lines, line)
      end
    end
  end

  local context = table.concat(context_lines, "\n")
  return {
    current_line = current_line,
    context = context,
    filetype = filetype,
  }
end


-- Function to generate the completion prompt using the configurable template
local function create_completion_prompt(context_data)
  return prompt.create_completion_prompt(context_data)
end


function M.trigger_completion()
  ui.clear_ghost_text()
  ui.set_statusline_indicator_text(UI_TEXT.status_completing)
  local context_data = M.get_context()
  local prompt = create_completion_prompt(context_data)

  completion.trigger_completion(M, ui, prompt, prompt)
end


-- Generic function to send a prompt to Ollama and handle the response
function M.send_prompt(prompt_text, callback, options)
  options = options or {}

  local final_prompt = prompt_text
  if options.code_only then
    final_prompt = final_prompt .. config.config.code_only_prompt_suffix
  end

  ui.set_statusline_error_indicator("")
  ui.set_statusline_indicator_text(UI_TEXT.status_generating)

  api.request_completion(final_prompt, config.config, function(completion, error_message)
    ui.stop_statusline_spinner()
    ui.set_statusline_indicator_text(UI_TEXT.status_ready)

    if callback then
      if completion then
        callback(completion, nil)
        prompt.add_to_history(final_prompt, completion)
      else
        ui.set_statusline_error_indicator(UI_TEXT.status_error)
        ui.notify_warn("Ollama Completion Request: No completion received. " .. (error_message or "Please check `:messages` for details."))
      end
    else -- No callback function provided (unlikely scenario, but handle defensively)
      if error_message then
        -- **ENHANCED: Log error even if no callback is provided (defensive)**
        ui.set_statusline_error_indicator("Error")
        vim.log.error("Ollama Completion Request Failed (No Callback): " .. (error_message or "Unknown error"))
      end
    end
  end)
end


-- Command handler for :Prompt (popup version)
function M.handle_prompt_command(line)
  M.wakeup_model()
  ui.set_statusline_indicator_text(UI_TEXT.status_prompting)
  local prompt_text = line
  M.send_prompt(prompt_text, function(completion, error_message)
    if completion then
      ui.show_completion_popup(completion)
      ui.set_statusline_indicator_text(UI_TEXT.status_ready)
    else
      ui.set_statusline_error_indicator(UI_TEXT.status_error)
      ui.notify_error(UI_TEXT.prompt_failed)
    end
  end)
end



-- Command handler for :PromptCode (insert code directly)
--function M.handle_prompt_code_command(line)
--  M.wakeup_model()
--  ui.set_statusline_indicator_text(UI_TEXT.status_prompting)
--  local prompt_text = line
--  M.send_prompt(prompt_text, function(completion, error_message)
--    if completion then
--      ui.insert_code_into_buffer(completion)
--      ui.set_statusline_indicator_text(UI_TEXT.status_ready)
--    else
--      ui.set_statusline_error_indicator(UI_TEXT.status_error)
--      ui.notify_error(UI_TEXT.prompt_code_failed)
--    end
--    }, { code_only = true })
--end

function M.handle_prompt_code_command(line)
  M.wakeup_model()
  ui.set_statusline_indicator_text(UI_TEXT.status_generating)
  local prompt_text = line
  local prompt_options = { code_only = true } -- Options table assigned to variable
  M.send_prompt(prompt_text, handle_prompt_code_response, prompt_options) -- Call send_prompt with named callback and options variable
end

local function handle_prompt_code_response(completion, error_message)
  if completion then
    ui.insert_code_into_buffer(completion)
    ui.set_statusline_indicator_text(UI_TEXT.status_ready)
  else
    ui.set_statusline_error_indicator(UI_TEXT.status_error)
    ui.notify_error(UI_TEXT.prompt_code_failed)
  end
end


-- Command handler for :OllamaHistory
function M.handle_history_command(opts)
  M.wakeup_model()
  ui.set_statusline_indicator_text(UI_TEXT.status_history_loading)
  prompt.handle_history_command(ui, opts, M)
  ui.set_statusline_indicator_text(UI_TEXT.status_ready)
end


-- Function to retry ghost text (Shift+Tab)
function M.retry_ghost_text()
  M.wakeup_model()
  ui.set_statusline_indicator_text(UI_TEXT.status_function_completion)
  if ui.current_ghost_text_id then
    ui.clear_ghost_text()
    M.on_text_changed_for_comment_function()
  end
  ui.set_statusline_indicator_text(UI_TEXT.status_ready)
  return '<S-Tab>'
end

-- Function to detect if the current line is a comment based on filetype (moved to prompt module)
function M.is_comment_line()
  return prompt.is_comment_line()
end


-- Function to check if a comment looks like a function description (moved to prompt module)
function M.is_function_comment(comment_text)
  return prompt.is_function_comment(comment_text)
end


return M
