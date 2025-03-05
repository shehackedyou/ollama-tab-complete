-- lua/ollama_tab_complete/lua/ollama_tab_complete/api.lua

local M = {}

-- Define a function to make API requests, taking request options as a table
local function make_api_request(request_options, callback)
  local data = vim.json.encode({
    model = request_options.model,
    prompt = request_options.prompt,
    stream = request_options.stream,
  })

  local cmd = {
    "curl", "-X", "POST",
    "-H", "Content-Type: application/json",
    "--data", data,
    request_options.url, -- Use URL from options
  }

  local cmd_string = table.concat(vim.tbl_flatten(cmd), " ") -- Create command string for logging
  vim.log.info("Ollama Request Command: " .. cmd_string) -- Log the curl command

  local handle = io.popen(cmd_string .. " 2>&1") -- **NEW: Redirect stderr to stdout for combined output**
  if not handle then
    local error_message = "Failed to start curl process."
    vim.log.error(error_message .. " Command: " .. cmd_string)
    callback(nil, "Failed to start curl process")
    return
  end

  local response_body = handle:read("*a")
  local exit_code = handle:close()

  local http_status_code = nil -- Variable to store HTTP status code (if extracted)
  local status_match = string.match(response_body, "HTTP[/%d.]+ (%d%d%d)") -- Regex to try to find HTTP status code
    if status_match then
      http_status_code = status_match
    end


  if exit_code ~= 0 then
    local error_message = "Ollama API request failed"
    if http_status_code then
      error_message = error_message .. " with HTTP status code: " .. http_status_code
    end
    error_message = error_message .. ". Exit code: " .. exit_code .. ". Response body: " .. response_body

    vim.log.error("Ollama API Error: " .. error_message .. ". Command: " .. cmd_string)
    callback(nil, error_message)
    return
  end

  local response
  local success, err = pcall(vim.json.decode, response_body)
  if not success then
    local error_message = "Failed to decode JSON response: " .. err .. ". Response body: " .. response_body
    vim.log.error("JSON Decode Error: " .. error_message .. ". Response body: " .. response_body)
    callback(nil, error_message)
    return
  end
  response = err
  local decoded_response = response

  if decoded_response and decoded_response.response then
    callback(decoded_response.response)
  else
    callback(nil, "Invalid Ollama response format. Response: " .. response_body)
  end
end


function M.request_completion(prompt, config, callback, stream)
  local request_options = { -- Group request options in a table
    model = config.model_name,
    prompt = prompt,
    stream = stream, -- Use stream parameter
    url = config.ollama_url,
  }
  make_api_request(request_options, callback) -- Call the reusable request function
end

return M

