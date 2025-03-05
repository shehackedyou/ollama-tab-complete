-- lua/ollama_tab_complete/lua/ollama_tab_complete/config.lua

local M = {}

M.default_config = {
  ollama_url = "http://localhost:11434/api/generate",
  model_name = "deepseek-coder-r2",
  trigger_key = "<C-Space>",
  max_context_lines = 10,
  completion_prompt_template = [[You are a code completion AI. Complete the following code.
Filetype: %s
Context (Previous Lines):
%s

Function Definitions in Context:
%s

Class Definitions in Context:
%s

Import Statements in Context:
%s

Current line prefix: %s
%s  -- NEW: Placeholder for Type Hint Prompt Part (Argument Type-Specific Instructions will be inserted here)
Completion:]],
  code_only_prompt_suffix = [[
Please provide only the code, without any explanation or surrounding text.]],
  automatic_completion_trigger = true,
  automatic_trigger_debounce_ms = 300,
  function_comment_keywords = { "function to ", "write a function", "create a function", "^function:" },
  comment_prefixes = {
    python = "# ",
    javascript = "// ",
    lua = "-- ",
    cpp = "// ",
    c = "// ",
    typescript = "// ",
    go = "// ",
    ruby = "# ",
    markdown = "<!-- ",
    html = "<!-- ",
    css = "/* ",
    sh = "# ",
    bash = "# ",
    zsh = "# ",
    php = { "// ", "/* ", "# " },
    rust = "// ",
  },
  automatic_ollama_startup = true,
  automatic_model_startup = true,
  ollama_command = "ollama serve",
  model_run_command = "ollama run deepseek-coder-r2",
  automatic_model_shutdown = true,
  automatic_server_shutdown = false,
  model_stop_command = "ollama stop deepseek-coder-r2",
  ollama_shutdown_command = "pkill ollama serve",
  prompt_presets = {
    explain_code = {
      command = "Prompt",
      prompt = "Explain the following code:\n{{selection}}",
      description = "Explain selected code",
    },
    refactor_code = {
      command = "PromptCode",
      prompt = "Refactor the following code to be more efficient:\n{{selection}}",
      description = "Refactor selected code",
    },
    write_tests = {
      command = "PromptCode",
      prompt = "Write unit tests for the following code:\n{{selection}}",
      description = "Write unit tests for selected code",
    },
  },
  automatic_model_sleep_mode = true,
  model_sleep_timeout_ms = 30000,
  ui_colors = { -- New section: UI Color Palette (Pastel Pinks)
    info = "#FAD0E9",    -- Pastel Pink - Info messages
    warn = "#FFB6C1",    -- Light Pink - Warning messages
    error = "#FF69B4",   -- Hot Pink - Error messages
    ready = "#FFE4E1",   -- Misty Rose - Ready state
    generating = "#FFD1DC", -- Light Hot Pink - Generating state
    sleeping = "#F08080",  -- Light Coral - Sleeping state
    waking_up = "#FA8072", -- Salmon - Waking Up state
  },
}

M.config = vim.deepcopy(M.default_config)

function M.setup(user_config)
  if user_config and type(user_config) ~= 'table' then
    vim.notify("Invalid user configuration provided. Expected a table.", vim.log.levels.WARN)
    return
  end
  M.config = vim.tbl_deep_extend("force", M.config, user_config or {})
end

return M
