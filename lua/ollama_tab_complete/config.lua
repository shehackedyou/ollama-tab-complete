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
    zsh = "-- ", -- Zsh uses Lua style comments, more common in modern configs
    php = { "// ", "/* ", "# " },
    rust = "// ",
  },
  automatic_ollama_startup = false, -- Disable automatic Ollama startup
  automatic_model_startup = false,  -- Disable automatic model startup
  automatic_model_shutdown = true, -- Enable automatic model shutdown on Neovim exit
  automatic_server_shutdown = false, -- Disable automatic server shutdown (use with caution!)
  ollama_command = "ollama serve",        -- Customize Ollama serve command
  model_run_command = "ollama run codellama:7b", -- Customize model run command
  model_stop_command = "ollama stop codellama:7b", -- Customize model stop command
  ollama_shutdown_command = "pkill ollama serve", -- Customize server shutdown command (pkill is a forceful example)
  prompt_presets = { -- Customize or add more prompt presets
    explain_code = {
      command = "Prompt",
      prompt = "Explain the following code:\n{{selection}}",
      description = "Explain selected code (popup)",
    },
    refactor_code = {
      command = "PromptCode",
      prompt = "Refactor the following code to be more efficient:\n{{selection}}",
      description = "Refactor selected code (insert)",
    },
    write_tests = {
      command = "PromptCode",
      prompt = "Write unit tests for the following code:\n{{selection}}",
      description = "Write unit tests for selected code (insert)",
    },
     -- Add more presets here
  },
  automatic_model_sleep_mode = true,
  model_sleep_timeout_ms = 30000,
  ui_colors = { -- Customize the pastel pink color palette
    info = "#FAD0E9",
    warn = "#FFB6C1",
    error = "#FF69B4",
    ready = "#FFE4E1",
    generating = "#FFD1DC",
    sleeping = "#F08080",
    waking_up = "#FA8072",
  },
  ui_text = { -- Centralized UI Text
    status_ready = "✨ Ollama Ready ✨",
    status_generating = "💫 MLM Generating... 💫",
    status_sleeping = "😴 Ollama Sleeping 😴",
    status_waking_up = "⏳ Ollama Waking Up ⏳",
    status_error = "⚠️ MLM Error ⚠️",
    status_idle = "Ollama: Idle",
    status_completing = "MLM Completing...",
    status_function_completion = "Function Completion...",
    status_prompting = "Prompting Ollama...",
    status_history_loading = "History Loading...",
    ollama_output_popup_prompt = "Ollama Output:",
    ollama_prompt_history_popup_prompt = "Ollama Prompt History (latest first):",
    ollama_completion_popup_prompt = "MLM Completion:",
    preset_no_visual_selection_warning = "No visual selection made for preset command: ",
    ollama_returned_empty_completion = "Ollama returned empty or invalid completion.",
    ollama_returned_invalid_function_code = "Ollama returned empty or invalid function code.",
    ollama_returned_empty_function_code_on_retry = "Ollama returned empty or invalid function code on retry.",
    function_generation_from_comment_failed = "Function generation from comment failed: ",
    function_generation_retry_from_comment_failed = "Function generation retry from comment failed: ",
    automatic_completion_failed = "Automatic completion failed: ",
    re_run_prompt_failed = "Re-run prompt failed: ",
    no_ollama_history_yet = "No Ollama prompt history yet.",
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
