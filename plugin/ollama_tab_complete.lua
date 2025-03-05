-- plugin/ollama_tab_complete.lua

vim.cmd([[
  help ollama-tab-complete
]])

local core = require('ollama_tab_complete.core')

core.setup()
