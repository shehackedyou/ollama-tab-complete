# ollama-tab-complete

A Neovim plugin providing Copilot-like code completion and prompt interaction using local Ollama models, specifically designed for `deepseek-coder-r2`.  This plugin leverages a local Machine Learning Model (MLM) to provide intelligent code suggestions and assists with various coding tasks directly within Neovim.

## Features

- **Code Completion:**
    - **Broad Language Support:** Code completion and comment-based generation support Python, JavaScript, Ruby, Go, HTML, CSS, C++, C, TypeScript, Shell scripts (Bash, Zsh), and PHP.
    - **Automatic Inline "Ghost Text" Suggestions:** As-you-type code completion using a local MLM, displayed as subtle ghost text.
    - **Manual Completion Popup:** Triggered by `<C-Space>`, provides a Neovim-native completion menu with MLM suggestions.
    - **Intelligent Triggers:** Uses Treesitter for context-aware automatic completion triggering in Python, JavaScript, Ruby, Go, HTML, CSS, and C++, Shell scripts (Bash, Zsh), and PHP. Triggers are refined for different code contexts and language syntax.
    - **Type-Aware Argument Completions (Go):** Provides enhanced, type-aware code completions specifically for Go function arguments, offering more relevant suggestions based on the expected argument type.
    - **Rich Completion Menu Items:** Neovim-native completion menu items are enhanced with:
        - **Icons:**  Icons to visually represent completion item types (requires compatible colorscheme or icon plugin).
        - **Menu Text:**  Menu column text indicating the source of completion (e.g., "[Ollama]", "[Snippet]").
        - **Documentation Preview:** A preview window in the completion menu displays documentation or descriptions for selected items (e.g., snippet descriptions).
    - **Acceptance and Retry:** Accept ghost text suggestions or completion menu selections with `<Tab>`. Retry inline suggestions with `<S-Tab>`.
    - **Visual Separation in Completion Menu:** Completion menu items are visually separated into "Code Snippets" and "MLM Completions" sections for better organization.

- **Comment-Based Function Generation:** Automatically generate function code from function description comments. Inline suggestions appear as grey ghost text and can be accepted with `<Tab>` or retried with `<S-Tab>`. Supports multiple languages.

- **`:Prompt` Command:** Send arbitrary prompts to Ollama and view the response in a Neovim popup menu.

- **`:PromptCode` Command:** Send prompts specifically for code generation to Ollama, optimized for code-only responses, and insert the code directly into the buffer.

- **`:OllamaHistory` Command:** View a history of your recent prompts and Ollama's responses within Neovim, with options to re-run prompts or view responses in a popup.

- **Prompt Presets:** Predefined commands (e.g., `:ExplainCode`, `:RefactorCode`, `:WriteTests`) for common tasks, working with visual selections.  These commands send pre-configured prompts to Ollama related to code understanding, refactoring, and testing.

- **Code Actions/Refactorings (Example - Python):** Includes an example `:OllamaExtractVariable` command that demonstrates basic code refactoring capabilities, extracting selected Python code into a variable.  This is a starting point for more advanced code actions in future versions.

- **Automatic Ollama Lifecycle Management (Optional):**
    - Automatically starts Ollama server and model on Neovim startup.
    - Gracefully shuts down the model (and optionally the server) on Neovim exit, even on forceful termination (Ctrl+C, kill).
    - Automatic Model Sleep Mode: Puts the Ollama model to sleep after a configurable period of inactivity to conserve resources, and automatically wakes it up when you resume activity in Neovim.

- **Informative Statusline:**
    - Concise Status Summary: Displays a clear and concise summary of the plugin's status, including the plugin name, model name, current state (Ready, Generating, Sleeping, etc.), and error indicators.
    - Statusline Spinner:  A subtle spinner animation in the statusline provides visual feedback during Ollama API requests and other longer operations.
    - Custom Highlight Groups: Uses custom highlight groups for statusline elements to ensure visual consistency with Neovim colorschemes.

- **Customizable UI:**
    - Pastel Pink Color Palette: Uses a soft pastel pink color palette for notifications, providing a visually appealing and less intrusive user interface.
    - Configurable UI Colors: Users can customize the pastel pink color palette in the plugin configuration.
    - Configurable UI Text:  All user-facing text strings in the UI (statusline messages, notifications, popup prompts) are centralized in the configuration and can be easily customized or translated.

- **Highly Configurable:** Extensive configuration options to tailor the plugin to your preferences, including: Ollama connection settings, model name, keybindings, context lines, prompt templates, automatic behavior, UI colors, and more.

## Prerequisites

- **Ollama:** You need to have Ollama installed and running on your system.  Follow the installation instructions at [https://ollama.com/](https://ollama.com/).
- **`deepseek-coder-r2` Model:**  Ensure you have pulled the `deepseek-coder-r2` model in Ollama by running `ollama run deepseek-coder-r2` in your terminal at least once.
- **Neovim:**  Requires Neovim 0.5 or higher, **compiled with LuaJIT for Treesitter support**.
- **`curl`:**  The plugin uses `curl` to communicate with the Ollama API. Ensure `curl` is installed on your system.
- **Treesitter Parsers:** For enhanced automatic completion triggers, ensure you have Treesitter parsers installed for Python, JavaScript, Ruby, Go, HTML, CSS, C++, C, TypeScript, and Shell scripts in Neovim (install with `:TSInstall all` or `:TSInstall <language>` for individual languages).
- **Optional (for enhanced UI):**
    - **nvim-web-devicons:** For displaying icons in the completion menu (requires a Nerd Font).
    - **telescope.nvim:** For using the `:OllamaPresets` command and browsing prompt presets in a popup menu.

## Installation with vim-plug

1. **Install vim-plug:** If you don't have vim-plug installed, follow the instructions at [https://github.com/junegunn/vim-plug](https://github.com/junegunn/vim-plug).

2. **Add plugin to your `init.vim` or `init.lua`:**

   **For `init.vim`:**

```vim
    call plug#begin('~/.config/nvim/plugged')
    ...
    Plug 'shehackedyou/ollama-tab-complete' 
    ...
    call plug#end()
```

```lua
    vim.call('plug#begin', '~/.config/nvim/plugged')
    ...
    vim.call('plug#', 'shehackedyou/ollama-tab-complete') 
    ...
    vim.call('plug#end')
```
