-- FreeSWITCH Lua: trigger baresip dual preview calls on DoorBird ring.
--
-- This is intentionally NOT bridging the DoorBird call to the G1 panels.
-- G1 doesn't "merge" two simultaneous calls, so we keep only ONE call path:
--   DoorBird -> FreeSWITCH (trigger only) -> baresip -> G1 panels (video preview via RTSP)
--
-- De-duplication:
-- - Uses flock to avoid multiple concurrent runs (double presses / retries).
--
-- Secrets:
-- - No credentials are stored or logged here. RTSP creds live in the baresip config on the Pi.

local function log(level, msg)
  freeswitch.consoleLog(level, "doorbird_trigger_preview.lua: " .. msg .. "\n")
end

local function append_file(path, line)
  local f = io.open(path, "a")
  if not f then return false end
  f:write(line)
  f:close()
  return true
end

-- Basic guard: only run when we have a session.
if not session or not session:ready() then
  log("WARNING", "no active session; nothing to do")
  return
end

-- FreeSWITCH runs as user "freeswitch" and typically cannot access /home/config.
-- We therefore use a root-owned wrapper with a minimal sudoers allow-list.
-- Wrapper drops privileges to "config", takes a lock, and time-bounds execution.
local wrapper = "/usr/local/bin/doorbird_preview_dual.sh"

-- Marker file so we can confirm the dialplan actually executed this script.
-- No secrets are written here.
local ts = os.date("!%Y-%m-%dT%H:%M:%SZ")
local from_ip = session:getVariable("sip_network_ip") or ""
local from_user = session:getVariable("sip_from_user") or ""
append_file("/tmp/doorbird_trigger_preview.ran", ts .. " from_ip=" .. from_ip .. " from_user=" .. from_user .. "\n")

local cmd =
  "nohup /usr/bin/sudo -n " .. wrapper ..
  " >/dev/null 2>&1 &"

log("NOTICE", "triggering dual preview calls (bg via sudo wrapper)")
os.execute(cmd)
