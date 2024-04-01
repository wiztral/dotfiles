return { -- Fuzzy Finder (files, lsp, etc)
  'nvim-telescope/telescope.nvim',
  event = 'VimEnter',
  branch = '0.1.x',
  dependencies = {
    'nvim-lua/plenary.nvim',
    { -- If encountering errors, see telescope-fzf-native README for installation instructions
      'nvim-telescope/telescope-fzf-native.nvim',

      -- `build` is used to run some command when the plugin is installed/updated.
      -- This is only run then, not every time Neovim starts up.
      build = 'make',

      -- `cond` is a condition used to determine whether this plugin should be
      -- installed and loaded.
      cond = function()
        return vim.fn.executable 'make' == 1
      end,
    },
    { 'nvim-telescope/telescope-ui-select.nvim' },

    -- Useful for getting pretty icons, but requires a Nerd Font.
    { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
  },
  config = function()
    -- some utility functions
    local is_buf_modified = function(bufnr)
      return vim.api.nvim_buf_get_option(bufnr, 'modified')
    end

    local table_contains = function(t, value)
      for _, cur in pairs(t) do
        if cur == value then
          return true
        end
      end
    end

    local action_state = require 'telescope.actions.state'
    local action_utils = require 'telescope.actions.utils'
    local finders = require 'telescope.finders'
    local actions = {}

    actions.write_changes = function(prompt_bufnr)
      local current_picker = action_state.get_current_picker(prompt_bufnr)

      -- extract modified buffers in the selection
      local bufnrs = {}

      action_utils.map_selections(prompt_bufnr, function(entry, _)
        if is_buf_modified(entry.bufnr) then
          table.insert(bufnrs, entry.bufnr)
        end
      end)

      if next(bufnrs) == nil then
        local cursor_entry = action_state.get_selected_entry()
        if is_buf_modified(cursor_entry.bufnr) then
          table.insert(bufnrs, cursor_entry.bufnr)
        end
      end

      if next(bufnrs) ~= nil then
        for _, bufnr in ipairs(bufnrs) do
          vim.api.nvim_buf_call(bufnr, function()
            vim.cmd ':w'
          end)
        end

        local results = {}
        for cur_entry in current_picker.manager:iter() do
          table.insert(results, cur_entry)
        end

        -- find and replace "+" in the indicator string of the saved buffer
        local new_finder = finders.new_table {
          results = results,
          entry_maker = function(x)
            if table_contains(bufnrs, x.bufnr) and not is_buf_modified(x.bufnr) then
              x.indicator = x.indicator:gsub('(.+)%+', '%1 ')
            end
            return x
          end,
        }

        current_picker:refresh(new_finder)
      end
    end

    -- [[ Configure Telescope ]]
    -- See `:help telescope` and `:help telescope.setup()`
    require('telescope').setup {
      pickers = {
        buffers = {
          mappings = {
            n = {
              ['<C-s>'] = actions.write_changes,
            },
          },
        },
      },
      extensions = {
        ['ui-select'] = {
          require('telescope.themes').get_dropdown(),
        },
      },
    }

    -- Enable Telescope extensions if they are installed
    pcall(require('telescope').load_extension, 'fzf')
    pcall(require('telescope').load_extension, 'ui-select')

    -- See `:help telescope.builtin`
    local builtin = require 'telescope.builtin'
    vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
    vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
    vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
    vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
    vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
    vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
    vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
    vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
    vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
    vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })

    -- Slightly advanced example of overriding default behavior and theme
    vim.keymap.set('n', '<leader>/', function()
      -- You can pass additional configuration to Telescope to change the theme, layout, etc.
      builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
        winblend = 10,
        previewer = false,
      })
    end, { desc = '[/] Fuzzily search in current buffer' })

    -- It's also possible to pass additional configuration options.
    --  See `:help telescope.builtin.live_grep()` for information about particular keys
    vim.keymap.set('n', '<leader>s/', function()
      builtin.live_grep {
        grep_open_files = true,
        prompt_title = 'Live Grep in Open Files',
      }
    end, { desc = '[S]earch [/] in Open Files' })

    -- Shortcut for searching your Neovim configuration files
    vim.keymap.set('n', '<leader>sn', function()
      builtin.find_files { cwd = vim.fn.stdpath 'config' }
    end, { desc = '[S]earch [N]eovim files' })
  end,
}
