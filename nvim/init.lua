-- ========================================================================== --
--                             CONFIGURAZIONE NVIM                            --
-- ========================================================================== --

-- Soluzione di emergenza per la sintassi se Treesitter fallisce
vim.cmd([[syntax on]])

-- Disabilita netrw (il vecchio esploratore file) per nvim-tree
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- 1. BOOTSTRAP (Scaricamento automatico di lazy.nvim)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- 2. OPZIONI E TASTO LEADER
vim.g.mapleader = " "           -- Spazio come tasto Leader
vim.opt.number = true           -- Mostra numeri riga
vim.opt.relativenumber = true   -- Numeri relativi
vim.opt.termguicolors = true    -- Colori a 24-bit
vim.opt.shiftwidth = 4          -- Tabulazione a 4 spazi
vim.opt.expandtab = true        -- Trasforma tab in spazi
vim.opt.cursorline = true       -- Evidenzia la riga corrente

-- 3. PLUGIN (Gestiti da Lazy)
require("lazy").setup({

  -- TEMA (TokyoNight)
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd[[colorscheme tokyonight-storm]]
    end
  },

  -- ESPLORATORE FILE
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({
        view = { width = 30, side = "left" },
        filters = { dotfiles = false }
      })
    end
  },

  -- LSP: GESTIONE E CONFIGURAZIONE
  { "williamboman/mason.nvim", config = true },
  { "williamboman/mason-lspconfig.nvim" },

  {
    "neovim/nvim-lspconfig",
    version = "v2.*"
  },

  -- EVIDENZIAZIONE SINTASSI (Treesitter)
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      local status, ts = pcall(require, "nvim-treesitter.configs")
      if not status then return end
      ts.setup({
        ensure_installed = { "vim", "vimdoc", "query", "lua", "markdown", "markdown_inline", "python", "rust", "c", "cpp" },
        auto_install = true,
        highlight = { enable = true },
      })
    end
  },

  -- TELESCOPE (Ricerca file)
  {
    'nvim-telescope/telescope.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    tag = "0.1.8",
    config = true
  },

  -- AGENTE AI (Gen.nvim)
  {
    "David-Kunz/gen.nvim",
    opts = {
      model = "qwen2.5-coder:1.5b",
      host = "localhost",
      port = "11434",
      display_mode = "vertical-split",
      show_prompt = true,
      show_model = true,
    }
  },

  -- RENDER MARKDOWN (eventi del calendario resi con icone e colori)
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    ft = { "markdown" },
    opts = {
      heading = { sign = false },
      code = { sign = false },
    }
  },

  -- AUTOCOMPLETAMENTO (parole LSP, snippet, path, buffer) mentre scrivi
  {
    "saghen/blink.cmp",
    dependencies = { "rafamadriz/friendly-snippets" },
    version = "1.*",
    opts = {
      keymap = { preset = "default" }, -- <C-y> conferma, <C-n>/<C-p> naviga, <Tab> naviga snippet
      appearance = { nerd_font_variant = "mono" },
      completion = {
        documentation = { auto_show = true },
        menu = { auto_show = true },
        list = { selection = { preselect = false } },
        ghost_text = { enabled = true },
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
      },
      signature = { enabled = true },
    },
    opts_extend = { "sources.default" },
  },

  -- TERMINALE INTEGRATO (finestra in basso, come un vero IDE)
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    opts = {
      size = 15,
      open_mapping = [[<c-\>]],
      direction = "horizontal", -- finestra orizzontale in basso
      shade_terminals = true,
      start_in_insert = true,
      persist_size = true,
    }
  }
})

-- 4. CONFIGURAZIONE LSP (Dopo il setup dei plugin)
require("mason-lspconfig").setup({
  -- Lista dei server da installare e abilitare automaticamente
  ensure_installed = {
    "lua_ls",    -- Lua
    "pyright",   -- Python
    "rust_analyzer", -- Rust
    "clangd",    -- C / C++
  }
})

-- Setup specifico per Lua (toglie l'avviso di 'vim' globale sconosciuto)
vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      diagnostics = { globals = { "vim" } }
    }
  }
})

-- r_language_server non è gestito da mason, va abilitato manualmente
vim.lsp.enable("r_language_server")

-- 5. SCORCIATOIE (Keymaps)
local keymap = vim.keymap.set

-- Generale
keymap({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })

-- NvimTree (Spazio + e)
keymap('n', '<leader>e', ':NvimTreeToggle<CR>', { desc = 'Esplora File' })

-- Telescope (Ricerca Rapida)
keymap('n', '<leader>ff', ':Telescope find_files<CR>', { desc = 'Cerca File' })
keymap('n', '<leader>fg', ':Telescope live_grep<CR>', { desc = 'Cerca Testo' })

-- AI Gen.nvim (Spazio + cc)
keymap({ 'n', 'v' }, '<leader>cc', ':Gen<CR>', { desc = 'Menu AI' })

-- LSP: Scorciatoie Utili (quando il server è attivo)
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(ev)
    local opts = { buffer = ev.buf }
    keymap('n', 'gd', vim.lsp.buf.definition, opts)      -- 'gd' va alla definizione
    keymap('n', 'K', vim.lsp.buf.hover, opts)           -- 'K' mostra documentazione
    keymap('n', '<leader>rn', vim.lsp.buf.rename, opts) -- 'Spazio+rn' rinomina variabile
  end,
})
