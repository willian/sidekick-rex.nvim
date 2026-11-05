-- sidekick.nvim session backend for Rex: runs CLI tools in a Rex split, like
-- sidekick's tmux backend with `mux.create = "split"`. Registered by setup().
local Config = require("sidekick.config")
local Util = require("sidekick.util")

---@class sidekick.cli.muxer.Rex: sidekick.cli.Session
---@field rex_block_id string
---@field rex_pid number pid of the pane's root process, alive as long as the pane
local M = {}
M.__index = M
M.priority = 10
M.external = true

local function rex(args, opts)
  return Util.exec(vim.list_extend({ "rex", "-s", vim.env.REX_SESSION }, args), opts)
end

-- Every terminal pane in this Rex session with its process info, in one call
local LIST = [[
local terminal, ret = "com.superlogical.terminal", {}
for _, b in ipairs(rex.call("session.list_blocks", { session_id = rex.session_id }).blocks or {}) do
  if b.creator_name == terminal then
    local p = rex.block.call(terminal, "process", { block_id = b.block_id })
    if p and p.child and p.foreground then
      ret[#ret + 1] = { block_id = b.block_id, pid = p.child.pid, fg = p.foreground }
    end
  end
end
return ret]]

-- Runs a rex command and decodes its JSON output, or returns nil
local function rex_json(args, opts)
  local _, out = rex(args, opts)
  local ok, ret = pcall(vim.json.decode, out or "")
  return ok and type(ret) == "table" and ret or nil
end

local function panes()
  return rex_json({ "do", "-e", LIST, "--json" }, { notify = false }) or {}
end

function M:start()
  local split = Config.cli.mux.split
  local cmd = { "split", "-b", vim.env.REX_BLOCK, "--focus=false", "-c", self.cwd, "--json", "--label", self.tool.name }
  cmd[#cmd + 1] = "--split=" .. (split.vertical and "right" or "below")
  if split.size <= 1 then
    vim.list_extend(cmd, { "--ratio", tostring(math.floor(split.size * 100)) })
  end
  cmd[#cmd + 1] = "--"
  if self.tool.env and next(self.tool.env) then
    cmd[#cmd + 1] = "env"
    for key, value in pairs(self.tool.env) do
      vim.list_extend(cmd, value == false and { "-u", key } or { ("%s=%s"):format(key, tostring(value)) })
    end
  end
  vim.list_extend(cmd, self.tool.cmd)

  local res = rex_json(cmd, { notify = true })
  local block_id = res and res.block_ids and res.block_ids[1]
  if not block_id then
    return
  end
  local proc = rex_json({ "do", "com.superlogical.terminal.process", "block_id=" .. block_id, "--json" }, { notify = false })
  self.rex_pid = proc and proc.child and proc.child.pid
  self.id = "rex " .. block_id
  self.rex_block_id = block_id
  self.mux_session = vim.env.REX_SESSION
  self.started = true
  Util.info(("Started **%s** in a new Rex split"):format(self.tool.name))
end

function M:is_running()
  return self.rex_pid ~= nil and vim.api.nvim_get_proc(self.rex_pid) ~= nil
end

function M.sessions()
  local ret = {} ---@type sidekick.cli.session.State[]
  local tools = Config.tools()
  local Procs = require("sidekick.cli.procs")
  local procs = Procs.new()
  for _, pane in ipairs(panes()) do
    procs:walk(pane.fg.pid, function(proc)
      for _, tool in pairs(tools) do
        if tool:is_proc(proc) then
          ret[#ret + 1] = {
            id = "rex " .. pane.block_id,
            cwd = pane.fg.cwd,
            tool = tool,
            rex_block_id = pane.block_id,
            rex_pid = pane.pid,
            mux_session = vim.env.REX_SESSION,
            pids = Procs.pids(pane.fg.pid), -- the pane's root (login) is root-owned, so start at the foreground
          }
          return true
        end
      end
    end)
  end
  return ret
end

function M:send(text)
  local function send()
    rex({ "send", "-b", self.rex_block_id, text })
  end
  if self.tool.mux_focus then
    rex({ "send", "-b", self.rex_block_id, "\27[I" }) -- focus-in event, for tools that ignore input unfocused
    vim.defer_fn(send, 50)
  else
    send()
  end
end

function M:submit()
  rex({ "send-key", "-b", self.rex_block_id, "enter" })
end

function M:dump()
  local lines = rex({ "capture", "-b", self.rex_block_id, "--format=vt" })
  if not lines then
    return
  end
  return table.concat(vim.list_slice(lines, math.max(1, #lines - Config.cli.mux.dump + 1)), "\n")
end

return M
