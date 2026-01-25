vim.api.nvim_create_user_command("HttpScratchpad", function()
  require("kulala").scratchpad()
end, {})

vim.api.nvim_create_user_command("Kulala", function()
  require("kulala").open()
end, {})
