return {
  'stevearc/oil.nvim',
  opts = {},
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  config = function()
    require('oil').setup {
      default_file_explorer = false,
    }
    vim.keymap.set('n', '-', '<CMD>Oil<CR>', { desc = 'Open parent directory' })
  end,
}

-- Keeping neo-tree disabled for now
-- return {
--   'nvim-neo-tree/neo-tree.nvim',
--   branch = 'v3.x',
--   dependencies = {
--     'nvim-lua/plenary.nvim',
--     'nvim-tree/nvim-web-devicons',
--     'MunifTanjim/nui.nvim',
--   },
--   config = function()
--     local renderer = require 'neo-tree.ui.renderer'
--     local cc = require 'neo-tree.sources.common.commands'
--     require('neo-tree').setup {
--       filesystem = {
--         hijack_netrw_behavior = 'disabled',
--         window = {
--           mappings = {
--             ['l'] = 'open',
--             ['h'] = function(state)
--               local node = state.tree:get_node()
--
--               if node:has_children() and node:is_expanded() then
--                 cc.close_node(state)
--                 return
--               end
--
--               local depth = node:get_depth()
--               if depth == 1 then
--                 return
--               end
--
--               renderer.focus_node(state, node:get_parent_id())
--             end,
--           },
--         },
--       },
--       event_handlers = {
--         {
--           event = 'neo_tree_popup_input_ready',
--           ---@param args { bufnr: integer, winid: integer }
--           handler = function(args)
--             -- map <esc> to enter normal mode (by default closes prompt)
--             -- don't forget `opts.buffer` to specify the buffer of the popup.
--             vim.keymap.set('i', '<esc>', vim.cmd.stopinsert, { noremap = true, buffer = args.bufnr })
--           end,
--         },
--       },
--     }
--     -- vim.keymap.set('n', '<leader>pe', ':Neotree toggle left dir=./ reveal_force_cwd<CR>', { desc = 'Project Explorer' })
--   end,
-- }
