return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      filesystem = {
        filtered_items = {
          visible = true, -- 显示隐藏文件
          hide_dotfiles = false,
          hide_gitignored = false,
        },
      },
    },
  },
}
