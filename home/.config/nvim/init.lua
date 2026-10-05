-- Optional remote-plugin providers. This config is pure Lua (LazyVim + nvim-treesitter
-- main branch, whose parsers no longer need pynvim), so none of these hosts are used.
-- Declaring them unused keeps :checkhealth free of 6 warnings. To use one instead,
-- delete its line and install the binding it names in the warning.
vim.g.loaded_node_provider = 0 -- npm: -g neovim
vim.g.loaded_perl_provider = 0 -- cpan: Neovim::Ext
vim.g.loaded_python3_provider = 0 -- pip: neovim
vim.g.loaded_ruby_provider = 0 -- gem: neovim

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
