local M = {}

-- Register the "rex" backend with sidekick, so `cli.mux.backend = "rex"` works.
-- Does nothing outside Rex.
function M.setup()
  if not (vim.env.REX_SESSION and vim.env.REX_BLOCK) then
    return
  end
  require("sidekick.cli.session").register("rex", require("sidekick-rex.backend"))

  -- sidekick checks the backend name against its own list ("tmux", "zellij")
  local Config = require("sidekick.config")
  local validate = Config.validate
  Config.validate = function(key, t)
    if key == "cli.mux.backend" and type(t) == "table" then
      t = vim.list_extend({ "rex" }, t)
    end
    return validate(key, t)
  end
end

return M
