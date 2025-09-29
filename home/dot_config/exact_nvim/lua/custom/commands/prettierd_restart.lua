vim.api.nvim_create_user_command("PrettierdRestart", function()
  vim.system({ vim.fn.exepath("prettierd"), "stop" })
  vim.notify("prettierd stopped (will restart on next format)", vim.log.levels.INFO)
end, {})
