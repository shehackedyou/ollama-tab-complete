-- lua/ollama_tab_complete/lua/ollama_tab_complete/completion.lua

local config = require('ollama_tab_complete.config')
local ui = require('ollama_tab_complete.ui')

local M = {}

M.automatic_completion_debounce = nil

function M.setup_completion_menu()
  vim.o.completeopt = 'menu,menuone,noselect,preview' -- Added 'preview' to completeopt
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

  -- (More Robust) - Iterate captures, find parameter type at the cursor's column
  for _, capture in ipairs(captures) do
    if capture.name == "parameter-list-captured" then -- Check for parameter-list-def captures (from function declaration)
      local parameter_list_node = capture.node
      local parameters = parameter_list_node:children()
       if #parameters > 0 then
          local first_param_type_node = parameters[1]:child(0) -- Get first parameter's type
          if first_param_type_node then
            return vim.treesitter.get_node_text(first_param_type_node, 0) .. " value" -- Example: "int value", "string value"
          end
       end
       break -- Exit after finding the first matching parameter list
    end
  end


  return argument_type_hint -- Return default/fallback type hint if no specific parameter type is found at cursor
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
    local prompt = create_completion_prompt(context_data)

    M.send_prompt(prompt, function(completion, error_message, streaming_chunk)
      if completion then
        if type(completion) == 'string' and #completion > 0 then
          M.show_inline_suggestion(completion)
        else
          vim.notify("Ollama returned empty or invalid completion.", vim.log.levels.WARN)
        end
      else
        vim.notify("Automatic completion failed: " .. (error_message or "Unknown error"), vim.log.levels.ERROR)
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
        for _, line in ipairs(lines) do
          table.insert(items, { label = line, insertText = line, kind = "Text" })
        end
        vim.fn.complete(vim.fn.getcurpos()[2], items)
      else
        vim.notify("Ollama returned empty or invalid completion.", vim.log.levels.WARN)
      end
    else
      vim.notify("Completion failed: " .. (error_message or "Unknown error"), vim.log.levels.ERROR)
    end
  end, false) -- Request non-streaming completion for manual trigger
end


return M
