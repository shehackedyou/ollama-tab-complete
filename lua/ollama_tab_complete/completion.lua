-- lua/ollama_tab_complete/lua/ollama_tab_complete/completion.lua

local config = require('ollama_tab_complete.config')
local ui = require('ollama_tab_complete.ui')
local UI_TEXT = config.config.ui_text


local M = {}

M.automatic_completion_debounce = nil

function M.setup_completion_menu()
  vim.o.completeopt = 'menu,menuone,noselect,preview'
end


-- Helper function to get the Treesitter node at the cursor position
local function get_node_at_cursor(filetype, current_line_nr, cursor_col)
  local parser = vim.treesitter.get_parser(0, filetype)
  if not parser then return nil end -- Defensive: No parser

  local tree = parser:parse()
  if not tree then return nil end -- Defensive: Parsing failed

  local root = tree[1]:root()
  local node_at_cursor = root:query_nodes {
    range = {
      [1] = { vim.api.nvim_win_get_cursor(0)[1] - 1, cursor_col - 1 },
      [2] = { vim.api.nvim_win_get_cursor(0)[1] - 1, cursor_col - 1 },
    }
  }
  if not node_at_cursor or #node_at_cursor == 0 then return nil end -- Defensive: No node at cursor

  return node_at_cursor[1] -- Return the node if found
end


-- Helper function to extract parameter type hint from function signature
local function extract_parameter_type_hint_from_signature(argument_list_node, cursor_col)
  local filetype = "go"
  local function_declaration_query = vim.treesitter.query.get(filetype, [[
    (function_declaration
      name: (identifier) @function-name
      parameters: (parameter_list
        (parameter_declaration
          type: (_) @param-type              ; Capture parameter type node
          name: (identifier)                ; Parameter name
        ) @param-declaration                ; Capture each parameter declaration as indexed-param
      ) @parameter-list-captured
    )
  ]]) -- More robust query for function declarations


  if not function_declaration_query then return nil end

  local captures = function_signature_query:captures(vim.api.nvim_get_current_buf(), 0, 0, vim.api.nvim_win_get_cursor(0)[1]-1)
  if not captures or #captures == 0 then return nil end


  local argument_type_hint = "Go value" -- Default hint
  local best_param_type_hint = nil    -- Variable to store the best type hint found
  local param_index_at_cursor = nil   -- Variable to track parameter index at cursor


  -- (More Robust) - Iterate captures, find parameter type at the cursor's column
  for _, capture in ipairs(captures) do
    if capture.name == "parameter-list-captured" then -- Check for parameter-list-def captures (from function declaration)
      local parameter_list_node = capture.node
      local parameters = parameter_list_node:children()

      for param_index, param_node in ipairs(parameters) do -- Iterate with index `param_index`
        local param_start_row = param_node:range().start_point.row + 1 -- Get parameter start row (1-based)
        local param_end_row = param_node:range().end_point.row + 1     -- Get parameter end row
        local param_start_col = param_node:range().start_point.col + 1 -- Get parameter start column (1-based)
        local param_end_col = param_node:range().end_point.col         -- Get parameter end column


        -- **NEW: More robust Cursor position check - including multi-line arguments, commas, spacing**
        -- Check if cursor is *after* the parameter's start and *before* or *at* the parameter's end column/row
        if  vim.api.nvim_win_get_cursor(0)[1] >= param_start_row and vim.api.nvim_win_get_cursor(0)[1] <= param_end_row and
            cursor_col >= param_start_col and cursor_col <= param_end_col then

          local type_node = param_node:child(0) -- Get parameter type node
          if type_node then
            local current_param_type_hint = vim.treesitter.get_node_text(type_node, 0) .. " value" -- Extract type text for THIS parameter
            if not best_param_type_hint then -- Store the *first* matching type hint found (for simplicity in this example)
              best_param_type_hint = current_param_type_hint
              param_index_at_cursor = param_index -- **NEW: Store the parameter index as well**
            end
             vim.log.info(("Cursor is in parameter index: %d, type hint: %s, argument range: %s:%s - %s:%s, cursor col: %d"):format(
              param_index, current_param_type_hint,
              param_start_row, param_start_col, param_end_row, param_end_col, cursor_col)) -- DEBUG logging with param_index and range

          end
          -- Continue checking other parameters in case of multi-line arguments and complex layouts, to find the *closest* matching parameter to the cursor
        end
      end
      -- If cursor is not within any parameter's range in *this* parameter_list, continue to next capture (if any)
    end
  end


  if best_param_type_hint then -- Return the *best* type hint found (if any)
    return best_param_type_hint
  else
    return argument_type_hint -- Return default/fallback type hint if no specific parameter type is found at cursor
  end
end


function M.on_text_changed_for_auto_completion(core_module, ui_module, prompt_module)
  if not config.config.automatic_completion_trigger then
    return
  end

  local current_line = vim.api.nvim_get_current_line()
  local cursor_col = vim.api.nvim_win_get_cursor(0)[2]
  local filetype = vim.bo.filetype

  local trigger_condition = false

  if filetype == "python" then
    trigger_condition = M.get_python_trigger_condition(current_line, cursor_col)
  elseif filetype == "javascript" then
    trigger_condition = M.get_javascript_trigger_condition(current_line, cursor_col)
  elseif filetype == "ruby" then
    trigger_condition = M.get_ruby_trigger_condition(current_line, cursor_col)
  elseif filetype == "go" then
    trigger_condition = M.get_go_trigger_condition(current_line, cursor_col)
  elseif filetype == "html" then
    trigger_condition = M.get_html_trigger_condition(current_line, cursor_col)
  elseif filetype == "css" then
    trigger_condition = M.get_css_trigger_condition(current_line, cursor_col)
  elseif filetype == "c" then
    trigger_condition = M.get_c_trigger_condition(current_line, cursor_col)
  elseif filetype == "typescript" then
    trigger_condition = M.get_typescript_trigger_condition(current_line, cursor_col)
  elseif filetype == "sh" or filetype == "bash" or filetype == "zsh" then
    trigger_condition = M.get_shell_trigger_condition(current_line, cursor_col)
  else
    trigger_condition = true
  end

  if not trigger_condition then
    return
  end

  if M.automatic_completion_debounce then
    vim.defer_cancel(M.automatic_completion_debounce)
    M.automatic_completion_debounce = nil
  end

  M.automatic_completion_debounce = vim.defer_fn(function()
    M.automatic_completion_debounce = nil

    ui_module.set_statusline_error_indicator("")
    ui_module.set_statusline_indicator_text(config.config.ui_text.status_generating)

    local context_data = core_module.get_context()
    local prompt = prompt_module.create_completion_prompt(context_data)

    M.send_prompt(prompt, function(completion, error_message, streaming_chunk)
      if completion then
        if type(completion) == 'string' and #completion > 0 then
          M.show_inline_suggestion(completion)
        else
          ui_module.notify_warn(UI_TEXT.ollama_returned_empty_completion)
        end
      else
        ui_module.set_statusline_error_indicator("Error")
        ui.notify_error(UI_TEXT.automatic_completion_failed .. (error_message or "Unknown error"))
      end
      if not streaming_chunk then
         ui_module.set_statusline_indicator_text(config.config.ui_text.status_ready)
      end
    end, true)
  end, config.config.automatic_trigger_debounce_ms)
end



function M.trigger_completion(core_module, ui_module, prompt_module, prompt_text)
  local items = {}

  core_module.send_prompt(prompt_text, function(completion, error_message)
    if completion then
      if type(completion) == 'string' and #completion > 0 then
        local lines = vim.split(completion, '\n')
        for _, line in ipairs(items) do
          table.insert(items, { label = line, insertText = line, kind = "Text" })
        end
        vim.fn.complete(vim.api.nvim_win_get_cursor(0)[2], items)
      else
        ui.notify_warn(UI_TEXT.ollama_returned_empty_completion)
      end
    else
      ui_module.set_statusline_error_indicator("Error")
      ui.notify_error("Completion failed: " .. (error_message or "Unknown error"))
    end
  end, false) -- Request non-streaming completion for manual trigger
end


return M
