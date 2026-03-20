-- BOOTSTRAP 
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- OPZIONI E TASTO LEADER
vim.g.mapleader = " "          
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.termguicolors = true
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

-- PLUGIN (Versioni compatibili con Neovim < 0.11)
require("lazy").setup({
  -- TEMA
  { "folke/tokyonight.nvim", lazy = false, priority = 1000, config = function() vim.cmd[[colorscheme tokyonight-storm]] end },

  -- ESPLORATORE FILE
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function() require("nvim-tree").setup() end
  },

-- LSP (Versione stabile e compatibile)
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
})

-- CONFIGURAZIONE ESPLORATORE (NvimTree)
require("nvim-tree").setup({
  view = {
    width = 30,
    side = "left",
  },
  filters = {
    dotfiles = false, -- mostra anche i file nascosti
  },
})

-- SCORCIATOIE (Keymaps)
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })

vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>', { noremap = true, silent = true, desc = 'Toggle NvimTree' })