-- lua/ollama_tab_complete/lua/ollama_tab_complete/lifecycle.lua

local config = require('ollama_tab_complete.config')
local ui = require('ollama_tab_complete.ui')
local UI_TEXT = config.config.ui_text

local M = {}

local ollama_server_job_id = nil -- Track Ollama server job ID for graceful shutdown

function M.check_and_start_ollama()
  if not config.config.automatic_ollama_startup then
    --vim.log.info("Automatic Ollama startup disabled by configuration.")
    return
  end

  M.is_ollama_running(function(running)
    if running then
      vim.log.info("Ollama server is already running.")
      if config.config.automatic_model_startup then
        M.check_and_start_model()
      end
    else
      vim.log.info("Ollama server is not running. Attempting to start...")
      M.start_ollama_server(function(success)
        if success then
          ui.notify_info("Ollama server started successfully.") -- Use ui.notify_info helper
          if config.config.automatic_model_startup then
            M.check_and_start_model()
          end
        else
          ui.notify_error("Failed to start Ollama server automatically. Please ensure Ollama is running, hun.") -- Use ui.notify_error helper
        end
      end)
    end
  end)
end


function M.is_ollama_running(callback)
  require('ollama_tab_complete.api').request_completion("Say hi to check model status", config.config, callback)
end


function M.start_ollama_server(callback)
  local job_id = vim.fn.jobstart(config.config.ollama_command, { -- Capture job ID
    on_stdout = callback,
    on_stderr = function(_, data, _, _)
      if data then
        vim.log.error("Ollama Server Start Error (stderr): " .. table.concat(data))
      end
    end,
    detach = true,
  })
  ollama_server_job_id = job_id -- Store job ID when server starts
end


function M.check_and_start_model()
  if not config.config.automatic_model_startup then
    vim.log.info("Automatic model startup disabled by configuration.")
    return
  end

  M.is_model_running(function(running)
    if running then
      vim.log.info("Model '" .. config.config.model_name .. "' is already running.")
    else
      vim.log.info("Model '" .. config.config.model_name .. "' is not running. Attempting to start...")
      M.start_model(function(success)
        if success then
          ui.notify_info("Model '" .. config.config.model_name .. "' started successfully.") -- Use ui.notify_info helper
        else
          ui.notify_error("Failed to start model '" .. config.config.model_name .. "' automatically. Please ensure it's running in Ollama.") -- Use ui.notify_error helper
        end
      end)
    end
  end)
end


function M.is_model_running(callback)
  require('ollama_tab_complete.api').request_completion("Say hi to check model status", config.config, callback)
end


function M.start_model(callback)
  -- Simplified model start - using 'ollama run' command (configurable)
  vim.fn.jobstart(config.config.model_run_command, {
    on_stdout = callback,
    on_stderr = function(_, data, _, _)
      if data then
        vim.log.error("Model Start Error (stderr): " .. table.concat(data))
      end
    end,
    detach = true,
  })
end


function M.setup_shutdown_autocommand()
  vim.api.nvim_create_autocmd("VimLeave", { -- VimLeave event for normal Neovim exit
    group = vim.api.nvim_create_augroup("OllamaTabCompleteShutdown", { clear = true }),
    callback = M.shutdown_ollama_components, -- Call shutdown function on VimLeave
    pattern = "*",
  })
end

function M.register_signal_handler()
  vim.loop.signal('SIGINT', function() -- Ctrl+C signal
    vim.schedule(function() -- Schedule within Neovim loop
      vim.log.warn("SIGINT (Ctrl+C) received. Shutting down Ollama components...")
      M.shutdown_ollama_components()
      vim.cmd("qall!") -- Force quit Neovim after shutdown attempts
    end)
  end)

  vim.loop.signal('SIGTERM', function() -- Kill signal
    vim.schedule(function() -- Schedule within Neovim loop
      vim.log.warn("SIGTERM received (kill command). Shutting down Ollama components...")
      M.shutdown_ollama_components()
      vim.cmd("qall!") -- Force quit Neovim after shutdown attempts
    end)
  end)
end


function M.shutdown_ollama_components()
  if config.config.automatic_model_shutdown then
    M.stop_model() -- Stop model on exit if enabled
  else
    vim.log.info("Automatic model shutdown disabled by configuration.")
  end

  if config.config.automatic_server_shutdown then -- Server shutdown is optional and off by default
    M.stop_ollama_server_graceful() -- Try graceful server shutdown first
  else
    vim.log.info("Automatic Ollama server shutdown disabled by configuration.")
  end
end


M.stop_ollama_server_forceful = M.stop_ollama_server -- Alias forceful shutdown (pkill)
function M.stop_ollama_server_graceful()
  if ollama_server_job_id then
    vim.log.info("Attempting graceful Ollama server shutdown via API...")
    -- Attempt graceful shutdown via Ollama API (if API supports it - currently no direct shutdown API in Ollama)
    -- For now, fall back to forceful shutdown (you could potentially add API-based shutdown if Ollama adds it in future)
    M.stop_ollama_server_forceful() -- Fallback to forceful shutdown if no graceful API method
  else
    M.stop_ollama_server_forceful() -- Fallback to forceful shutdown if no job ID tracked
  end
end


function M.stop_model()
  vim.log.info("Stopping Ollama model '" .. config.config.model_name .. "'...")
  vim.fn.jobstart(config.config.model_stop_command, {
    on_stdout = callback,
    on_stderr = function(_, data, _, _)
      if data then
        vim.log.error("Model Start Error (stderr): " .. table.concat(data))
      end
    end,
    detach = true,
  })
end


return M

