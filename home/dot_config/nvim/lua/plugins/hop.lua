return {
  {
    "smoka7/hop.nvim",
    init = function()
      require("hop").setup()
      vim.keymap.set("n", "m", ":HopWord<cr>", { silent = true })
    end,
  },
}
