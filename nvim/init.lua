-- 1. BOOTSTRAP (Scaricamento automatico di lazy.nvim)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- 2. OPZIONI E TASTO LEADER
vim.g.mapleader = " "           -- Impostiamo lo Spazio come leader
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.termguicolors = true
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

-- 3. PLUGIN (Gestiti tutti da Lazy)
require("lazy").setup({
  -- TEMA
  { "folke/tokyonight.nvim", lazy = false, priority = 1000, config = function() vim.cmd[[colorscheme tokyonight-storm]] end },

  -- ESPLORATORE FILE
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function() require("nvim-tree").setup() end
  },

  -- LSP (Versione stabile e compatibile pre-0.11)
  { "williamboman/mason.nvim" },
  { 
    "williamboman/mason-lspconfig.nvim",
    version = "1.29.0" 
  },
  { 
    "neovim/nvim-lspconfig",
    tag = "v0.1.8" 
  },

  -- EVIDENZIAZIONE SINTASSI
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },

  -- TELESCOPE
  { 'nvim-telescope/telescope.nvim', dependencies = { 'nvim-lua/plenary.nvim' } },

  -- AGENTE AI: GEN.NVIM
  {
    "David-Kunz/gen.nvim",
    config = function()
      require("gen").setup({
        model = "qwen2.5-coder:3b", -- Il modello ottimizzato per la tua CPU
        host = "localhost",
        port = "11434",
        display_mode = "split",     -- Mostra la risposta in una finestra divisa
        show_prompt = true,
        show_model = true,
      })
    end
  }
}) -- <-- Chiusura di Lazy Setup

-- 4. CONFIGURAZIONE ESPLORATORE (NvimTree)
require("nvim-tree").setup({
  view = {
    width = 30,
    side = "left",
  },
  filters = {
    dotfiles = false,
  },
})

-- 5. SCORCIATOIE (Keymaps)
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })

-- Esploratore file (Spazio + e)
vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>', { noremap = true, silent = true, desc = 'Toggle NvimTree' })

-- Scorciatoia AI: Spazio + cc apre il menu di Gen.nvim
vim.keymap.set({ 'n', 'v' }, '<leader>cc', ':Gen<CR>', { noremap = true, silent = true, desc = 'Apri menu AI (Gen)' })
