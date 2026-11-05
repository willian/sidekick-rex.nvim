-- Run by tests/smoke.sh, which puts a fake `rex` on PATH and a fake claude process in $FAKE_CLAUDE_PID
vim.opt.rtp:prepend(vim.env.SIDEKICK_PATH)
vim.opt.rtp:prepend(vim.env.REPO)

local errors = {}
vim.notify = function(msg, level)
  if level == vim.log.levels.ERROR then
    errors[#errors + 1] = msg
  end
end

require("sidekick-rex").setup()
require("sidekick").setup({ cli = { mux = { enabled = true, backend = "rex", split = { size = 0.4 } } } })
vim.wait(50) -- sidekick validates its options on the next tick
assert(#errors == 0, table.concat(errors, "\n"))

local Session = require("sidekick.cli.session")
local backend = require("sidekick-rex.backend")
assert(Session.backends.rex == backend, "rex backend not registered")

local s = Session.new({ tool = "claude", cwd = vim.env.REPO })
s:start()
assert(s.id == "rex block:runner", "id: " .. tostring(s.id))
assert(s.rex_pid == tonumber(vim.env.FAKE_CLAUDE_PID), "rex_pid: " .. tostring(s.rex_pid))
assert(s:is_running(), "not running")

s:send("hello\n")
s:submit()
assert(s:dump() == "line 1\nline 2", "dump: " .. vim.inspect(s:dump()))

local found = backend.sessions()
assert(#found == 1 and found[1].tool.name == "claude" and found[1].rex_block_id == "block:runner", vim.inspect(found))

print("ok")
