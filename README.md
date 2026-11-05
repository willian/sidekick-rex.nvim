# sidekick-rex.nvim

A [sidekick.nvim](https://github.com/folke/sidekick.nvim) backend that runs AI CLI tools in a [Rex](https://rex.superlogical.com) pane.

It works like sidekick's tmux backend with `mux.create = "split"`: the tool starts in a Rex split beside the editor, in the project directory, without moving focus. Prompts you send from Neovim are typed into that pane, and sidekick finds tools already running in the current Rex session.

Requires Neovim, sidekick.nvim, the `rex` CLI, and an editor running inside Rex (`REX_SESSION` and `REX_BLOCK` set). Outside Rex, `setup()` does nothing, so the same config works everywhere.

## Configuration

For Neovim (LazyVim):

```lua
{
  "folke/sidekick.nvim",
  dependencies = {
    "willian/sidekick-rex.nvim",
  },
  config = function(_, opts)
    require("sidekick-rex").setup()
    require("sidekick").setup(opts)
  end,
  opts = {
    cli = {
      mux = {
        enabled = true,
        backend = vim.env.REX_SESSION and "rex" or "tmux",
        create = "split",
        split = { size = 0.4 },
      },
    },
  },
}
```

The split follows sidekick's `cli.mux.split` options: `vertical` (the default) opens it on the right, otherwise below, and a `size` from 0 to 1 sets its share of the space.

`setup()` registers the `rex` backend and adds `rex` to the backend names sidekick accepts in `cli.mux.backend`.

## Notes

- Toggling a tool that's already running does nothing, as with sidekick's tmux backend: sidekick only shows and hides terminals it runs inside Neovim. Use Rex to move between panes.
- Only tools in the current Rex session are found.
- The backend uses sidekick internals (its session backends and process helpers), so a sidekick update may need a matching update here.

## Tests

```sh
tests/smoke.sh
```

It runs the backend in Neovim against a fake `rex` that records each call. It uses the sidekick.nvim in `SIDEKICK_PATH`, or clones it into a temporary directory.
