-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local out = vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    '--branch=stable',
    'https://github.com/folke/lazy.nvim.git',
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { 'Failed to clone lazy.nvim:\n', 'ErrorMsg' },
      { out, 'WarningMsg' },
      { '\nPress any key to exit...' },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before loading lazy.nvim so that mappings
-- are correct. This is also a good place to set up other settings (vim.opt).
vim.g.mapleader = ' '
vim.g.maplocalleader = '\\'

----------------------------------------------------------------------------------------------------
-- General config
----------------------------------------------------------------------------------------------------

vim.o.termguicolors = true -- Enable 24-bit RGB for the terminal
vim.o.number = true -- Line numbers
vim.o.relativenumber = true -- Make line numbers relative to the cursor
vim.o.ignorecase = true -- Make searches case insensitive...
vim.o.smartcase = true -- ...unless they contain a capital letter
vim.o.shellcmdflag = '-i -c' -- Load full normal shell configuration for shell commands (slower)
vim.o.foldmethod = 'indent' -- Fold by indent level (unless changed later by treesitter config)
vim.o.foldenable = false -- Don't immediately fold by default
vim.o.list = true -- Indicators for trailing whitespace
vim.o.listchars = 'trail:·,tab:  ' -- Specify characters for tabs and trailing whitespace

-- General key bindings
vim.keymap.set('n', '<F8>', '20<C-y>')
vim.keymap.set('n', '<F9>', '20<C-e>')
vim.keymap.set({ 'n', 'i', 'v', 'x', 's', 'o', 'c', 't' }, '<F10>', '<Esc>')
vim.keymap.set('i', '<F12>', '<C-o>A')
vim.keymap.set('n', '<F12>', '<C-w>w')

vim.keymap.set('n', 'W', '20w')
vim.keymap.set('n', 'B', '20b')

-- `K` has similar behavior by default but is overridden when using LSPs
vim.keymap.set('n', '<leader>m', function()
  local word = vim.fn.expand('<cword>')
  vim.fn.system({ 'man', '-w', word })
  if vim.v.shell_error == 0 then
    vim.cmd('Man ' .. word)
  else
    vim.notify(string.format('No man page found for "%s"', word), vim.log.levels.WARN)
  end
end, { desc = 'Open man page for word under cursor' })

-- General commands
vim.api.nvim_create_user_command('Bx', 'w | bd', { desc = 'Write and close buffer' })
vim.cmd('cnoreabbrev bx Bx')

-- Show diagnostics inline
vim.diagnostic.config({
  virtual_text = true,
  update_in_insert = true,
  severity_sort = true,
  float = { border = 'rounded' },
})
-- Setting this manually makes the pop-up show
vim.keymap.set('n', ']d', vim.diagnostic.goto_next)
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)

-- Helper function for coloring solid column ranges
local function colorcolumn_inclusive_range(start_col, end_col)
  local range = {}
  for i = start_col, end_col do
    table.insert(range, tostring(i))
  end
  return table.concat(range, ',')
end

-- Color different columns depending on the file type
local filetype_colorcolumn = {
  c = '80',
  cpp = '100',
  css = '100',
  ['dap-repl'] = '',
  gitcommit = colorcolumn_inclusive_range(51, 72), -- 50 char title, 72 col body
  go = '100', -- Should be used in combination with golines due to different tab display sizes
  html = '100',
  json = '100',
  jsonc = '100',
  just = '100', -- Could be 80 for a more traditional make style
  lua = '100',
  make = '80', -- 80 matches C, but could be 100
  man = '',
  markdown = '',
  python = '72,88', -- 88 as per Black/Ruff, 72 for docstrings/comments
  rust = '100',
  sql = '100', -- Could be 80 if more traditional
  text = '80',
  typescript = '100',
  typescriptreact = '100',
}

vim.api.nvim_create_autocmd('FileType', {
  pattern = '*',
  callback = function()
    vim.opt_local.colorcolumn = filetype_colorcolumn[vim.bo.filetype] or '80,100'
  end,
})

-- Indentation rules for file types where the LSP/formatter doesn't seem to change this in insert
-- mode
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'lua', 'typescript', 'typescriptreact', 'html', 'css', 'json', 'markdown', 'cpp' },
  callback = function()
    vim.bo.expandtab = true
    vim.bo.shiftwidth = 2
    vim.bo.tabstop = 2
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'sql', 'python', 'c' },
  callback = function()
    vim.bo.expandtab = true
    vim.bo.shiftwidth = 4
    vim.bo.tabstop = 4
  end,
})

-- Indentation preferences for Go (especially with the indent-blankline plugin and the golines
-- formatter)
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'go' },
  callback = function()
    vim.opt_local.list = false -- So indent-blankline will display
    vim.bo.expandtab = false
    -- Set tabs to display as 4 columns here for readability, but break lines as if tabs were 8
    -- columns using golines (via null-ls/none-ls plugin)
    vim.bo.shiftwidth = 4
    vim.bo.tabstop = 4
  end,
})

----------------------------------------------------------------------------------------------------
-- Plugins (managed with lazy.nvim)
----------------------------------------------------------------------------------------------------

-- Set up lazy.nvim
require('lazy').setup({
  spec = { -- Plugins go here
    { -- External package manager
      'mason-org/mason.nvim',
      opts = {},
      -- Update the Mason registry when Mason is updated (doesn't install updates)
      build = ':MasonUpdate',
    },
    -- Basic LSP support
    { 'neovim/nvim-lspconfig' },
    { -- Bridge between mason.nvim and nvim-lspconfig
      'mason-org/mason-lspconfig.nvim',
      dependencies = { 'mason-org/mason.nvim', 'neovim/nvim-lspconfig' },
      opts = {
        automatic_enable = false, -- Customize on_attach, capabilities, and such later
        ensure_installed = { 'cssls', 'eslint', 'html', 'jsonls', 'lua_ls', 'pyright', 'ts_ls' },
      },
    },
    { -- Enhanced LSP features
      'nvimdev/lspsaga.nvim',
      event = 'LspAttach',
      config = function()
        require('lspsaga').setup({ lightbulb = { enable = false }, finder = { max_height = 0.85 } })
        vim.keymap.set('n', '<leader>hd', '<cmd>Lspsaga hover_doc<CR>')
        vim.keymap.set('n', '<leader>rn', '<cmd>Lspsaga rename<CR>')
        vim.keymap.set('n', '<leader>gd', '<cmd>Lspsaga goto_definition<CR>')
        vim.keymap.set('n', '<leader>fr', '<cmd>Lspsaga finder<CR>')
      end,
    },
    { -- Auto-completion
      'hrsh7th/nvim-cmp',
      event = 'InsertEnter',
      dependencies = { 'hrsh7th/cmp-nvim-lsp', 'L3MON4D3/LuaSnip' }, -- LSP source and snippets
      config = function()
        local cmp = require('cmp')
        cmp.setup({
          mapping = cmp.mapping.preset.insert({
            ['<F8>'] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
            ['<F9>'] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
            ['<CR>'] = cmp.mapping.confirm({ select = true }),
          }),
          sources = { { name = 'nvim_lsp' } },
        })
      end,
    },
    { -- Formatting and linting
      'nvimtools/none-ls.nvim',
      -- Spell checking with cspell uses the cspell npm package
      dependencies = { 'nvim-lua/plenary.nvim', 'davidmh/cspell.nvim' },
      -- cspell setup
      opts = function(_, opts)
        local cspell = require('cspell')
        opts.sources = opts.sources or {}
        table.insert(
          opts.sources,
          cspell.diagnostics.with({
            diagnostics_postprocess = function(diagnostic)
              diagnostic.severity = vim.diagnostic.severity.HINT
            end,
          })
        )
        table.insert(opts.sources, cspell.code_actions)
      end,
      -- General none-ls/null-ls setup
      config = function()
        local null_ls = require('null-ls') -- Actually none-ls but called null-ls
        local cspell = require('cspell')
        local cspell_config = { cspell_config_dirs = { '~/.config/CSPELL_GLOBAL/' } }
        local sources = {
          -- Built-ins seem to need to go first
          null_ls.builtins.formatting.prettierd, -- TypeScript and many others
          null_ls.builtins.formatting.stylua,
          -- 100 columns, considering tabs to be 8 columns
          null_ls.builtins.formatting.golines.with({ extra_args = { '-m', '100', '-t', '8' } }),
          cspell.diagnostics.with({ config = cspell_config }),
          cspell.code_actions.with({ config = cspell_config }),
          null_ls.register({ -- Reorder Python imports using Ruff
            name = 'ruff_imports',
            method = null_ls.methods.FORMATTING,
            filetypes = { 'python' },
            generator = null_ls.formatter({
              command = 'ruff',
              args = { 'check', '-', '--select', 'I', '--fix' },
              to_stdin = true,
            }),
          }),
        }
        null_ls.setup({ sources = sources })
      end,
    },
    { -- Bridge between mason.nvim and null-ls (none-ls)
      'jay-babu/mason-null-ls.nvim',
      event = { 'BufReadPre', 'BufNewFile' },
      dependencies = { 'mason-org/mason.nvim', 'nvimtools/none-ls.nvim' },
      opts = {
        ensure_installed = { 'stylua', 'prettierd', 'golines' },
        automatic_installation = true,
      },
    },
    { -- Syntax parser
      'nvim-treesitter/nvim-treesitter',
      branch = 'master',
      lazy = false,
      build = ':TSUpdate',
      config = function()
        require('nvim-treesitter.configs').setup({
          ensure_installed = {
            'c',
            'cpp',
            'css',
            'go',
            'html',
            'lua',
            'markdown_inline',
            'markdown',
            'python',
            'rust',
            'tsx',
            'typescript',
          },
          highlight = { enable = true },
        })
        vim.wo.foldmethod = 'expr'
        vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
      end,
    },
    { -- Fuzzy finder
      'nvim-telescope/telescope.nvim',
      branch = '0.1.x',
      -- Also uses external dependencies fd and ripgrep
      dependencies = { 'nvim-lua/plenary.nvim', 'nvim-treesitter/nvim-treesitter' },
      config = function()
        local builtin = require('telescope.builtin')
        require('telescope').setup({
          defaults = {
            layout_strategy = 'vertical',
            mappings = { i = { ['<F10>'] = require('telescope.actions').close } },
          },
        })
        vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Find files' })
        vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Live grep' })
        vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Find buffers' })
        vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Find help' })
        -- Stop colorcolumn from showing in Telescope popups
        vim.api.nvim_create_autocmd('FileType', {
          pattern = { 'TelescopePrompt', 'TelescopeResults', 'TelescopePreview' },
          callback = function() vim.wo.colorcolumn = '' end,
        })
      end,
    },
    { -- Replacement for deprecated Telescope code actions popup
      'aznhe21/actions-preview.nvim',
      event = 'LspAttach',
      dependencies = { 'nvim-telescope/telescope.nvim' },
      config = function()
        local actions_preview = require('actions-preview')
        actions_preview.setup({ telescope = { layout_strategy = 'vertical' } })
        vim.keymap.set('n', '<leader>ca', actions_preview.code_actions, { silent = true })
      end,
    },
    { -- Debugger frontend
      'mfussenegger/nvim-dap',
      config = function()
        local dap = require('dap')
        dap.adapters.codelldb = { type = 'executable', command = 'codelldb' }
        dap.configurations.rust = {
          {
            name = 'Launch',
            type = 'codelldb',
            request = 'launch',
            program = function()
              return vim.fn.input(
                'Path to executable: ',
                vim.fn.getcwd() .. '/target/debug/',
                'file'
              )
            end,
            cwd = '${workspaceFolder}',
            stopOnEntry = false,
            -- Pretty printing for Rust types
            initCommands = {
              'command script import '
                .. '~/.rustup/toolchains/stable-aarch64-apple-darwin/lib/rustlib/etc/lldb_lookup.py',
              'command source -s 0 '
                .. '~/.rustup/toolchains/stable-aarch64-apple-darwin/lib/rustlib/etc/lldb_commands',
            },
          },
        }
        vim.keymap.set('n', '<F5>', dap.continue)
        vim.keymap.set('n', '<F6>', function()
          dap.repl.open()
          vim.cmd('winc w | startinsert')
        end)
        vim.keymap.set('n', '<leader>b', dap.toggle_breakpoint, { desc = 'Toggle breakpoint' })
        vim.keymap.set('n', '<leader>dr', dap.repl.toggle, { desc = 'Toggle debugger REPL' })
      end,
    },
    { -- Bridge between mason.nvim and nvim-dap
      'jay-babu/mason-nvim-dap.nvim',
      dependencies = { 'mason-org/mason.nvim', 'mfussenegger/nvim-dap' },
      config = function() require('mason-nvim-dap').setup({ ensure_installed = { 'codelldb' } }) end,
    },
    { -- Display inline values for nvim-dap
      'theHamsta/nvim-dap-virtual-text',
      dependencies = { 'mfussenegger/nvim-dap', 'nvim-treesitter/nvim-treesitter' },
      event = 'VeryLazy',
      config = function() require('nvim-dap-virtual-text').setup() end,
    },
    { -- Markdown renderer
      'MeanderingProgrammer/render-markdown.nvim',
      dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
      ft = { 'markdown' },
      config = function()
        require('render-markdown').setup({ completions = { lsp = { enabled = true } } })
      end,
    },
    { -- Auto-close and auto-rename HTML tags
      'windwp/nvim-ts-autotag',
      event = 'InsertEnter',
      dependencies = 'nvim-treesitter/nvim-treesitter',
      config = true,
    },
    -- Auto-close punctuation pairs
    { 'windwp/nvim-autopairs', event = 'InsertEnter', config = true },
    -- Surround words/expressions/etc with punctuation pairs
    { 'kylechui/nvim-surround', version = '*', event = 'InsertEnter', config = true },
    -- Git gutter visualization
    { 'lewis6991/gitsigns.nvim', event = 'VeryLazy', config = true },
    { -- Indentation guides
      'lukas-reineke/indent-blankline.nvim',
      event = 'VeryLazy',
      main = 'ibl',
      config = function() require('ibl').setup() end,
    },
    { -- Color scheme
      'Shatur/neovim-ayu',
      lazy = false,
      priority = 1000,
      config = function()
        local colors = require('ayu.colors')
        colors.generate(true) -- Mirage colors
        require('ayu').setup({
          overrides = {
            Normal = { bg = 'None' },
            SignColumn = { bg = 'None' },
            Folded = { bg = 'None', fg = colors.fg, bold = true, italic = true },
            FoldColumn = { bg = 'None' },
            CursorLine = { bg = 'None' },
            CursorColumn = { bg = 'None' },
            VertSplit = { bg = 'None' },
            TelescopeNormal = { bg = colors.bg }, -- Make Telescope pop-ups opaque
            -- For theHamsta/nvim-dap-virtual-text
            NvimDapVirtualText = { fg = colors.comment, italic = true },
          },
        })
        vim.cmd.colorscheme('ayu-mirage')
      end,
    },
  },
  -- Configure any other settings here. See the documentation for more details.
  install = { colorscheme = { 'habamax' } }, -- Color scheme used when installing plugins
  checker = { enabled = true }, -- Automatically check for plugin updates
})

----------------------------------------------------------------------------------------------------
-- LSPs
----------------------------------------------------------------------------------------------------

-- General LSP setup
local capabilities = require('cmp_nvim_lsp').default_capabilities()
local disable_lsp_fmt = function(client)
  client.server_capabilities.documentFormattingProvider = false -- Defer to null-ls
end

-- rust-analyzer with clippy and rustfmt
vim.lsp.config('rust_analyzer', {
  capabilities = capabilities,
  settings = {
    ['rust-analyzer'] = {
      check = { command = 'clippy' },
      -- Fix completions inside procedural macros like `#[tokio::test]` (slower)
      procMacro = { enable = true },
      -- Use nightly for formatting only
      rustfmt = { overrideCommand = { 'rustfmt', '+nightly', '--edition=2024' } },
    },
  },
})
vim.lsp.enable('rust_analyzer')

-- Pyright and Ruff LSPs (Ruff also formats)
vim.lsp.config('pyright', {
  capabilities = capabilities,
  settings = { python = { analysis = { typeCheckingMode = 'strict' } } },
})
vim.lsp.enable('pyright')

vim.lsp.config('ruff', { capabilities = capabilities })
vim.lsp.enable('ruff')

-- Lua LSP
vim.lsp.config('lua_ls', {
  capabilities = capabilities,
  on_attach = disable_lsp_fmt,
  settings = { Lua = { diagnostics = { globals = { 'vim' } }, telemetry = false } },
})
vim.lsp.enable('lua_ls')

-- Go LSP (also formats)
vim.lsp.config('gopls', {
  capabilities = capabilities,
  settings = { gopls = { staticcheck = true, buildFlags = { '-tags=dev' } } },
})
vim.lsp.enable('gopls')

local ts_js_filetypes = { 'typescript', 'typescriptreact', 'javascript', 'javascriptreact' }

-- TS(X) LSP for Node/tsc
vim.lsp.config('tsserver', {
  cmd = { 'typescript-language-server', '--stdio' },
  filetypes = ts_js_filetypes,
  root_markers = { 'package.json', 'tsconfig.json' },
  capabilities = capabilities,
  on_attach = disable_lsp_fmt,
  -- Prefer absolute import paths such as '@/pages/Home'
  init_options = { preferences = { importModuleSpecifierPreference = 'non-relative' } },
})

-- Deno LSP (also formats)
vim.lsp.config('denols', {
  cmd = { 'deno', 'lsp' },
  filetypes = ts_js_filetypes,
  root_markers = { 'deno.json', 'deno.jsonc', 'deno.lock' },
  capabilities = capabilities,
})

-- Only enable denols or tsserver depending on the project type
vim.api.nvim_create_autocmd('FileType', {
  pattern = ts_js_filetypes,
  callback = function(args)
    if vim.fs.root(args.buf, { 'deno.json', 'deno.jsonc' }) then
      vim.lsp.enable('denols', args.buf)
    else
      vim.lsp.enable('tsserver', args.buf)
    end
  end,
})

-- HTML, CSS, JSON, and ESLint LSPs
vim.lsp.config('html', { capabilities = capabilities, on_attach = disable_lsp_fmt })
vim.lsp.enable('html')

vim.lsp.config('cssls', { capabilities = capabilities, on_attach = disable_lsp_fmt })
vim.lsp.enable('cssls')

vim.lsp.config('jsonls', { capabilities = capabilities, on_attach = disable_lsp_fmt })
vim.lsp.enable('jsonls')

vim.lsp.config('eslint', { capabilities = capabilities })
vim.lsp.enable('eslint')

-- C and C++ LSP (also formats with clang-format and lints with clang-tidy)
vim.lsp.config('clangd', { capabilities = capabilities })
vim.lsp.enable('clangd')

----------------------------------------------------------------------------------------------------
-- Formatting on save
----------------------------------------------------------------------------------------------------

-- Format files with these extensions on save
vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = {
    '*.c',
    '*.cpp',
    '*.css',
    '*.go',
    '*.h',
    '*.hpp',
    '*.html',
    '*.js',
    '*.json',
    '*.jsonc',
    '*.lua',
    '*.mts',
    '*.rs',
    '*.ts',
    '*.tsx',
  },
  callback = function() vim.lsp.buf.format({ async = false }) end,
})

-- Format Python files on save even if the .py is removed
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'python',
  callback = function(args)
    vim.api.nvim_create_autocmd('BufWritePre', {
      buffer = args.buf,
      callback = function() vim.lsp.buf.format({ async = false }) end,
    })
  end,
})
