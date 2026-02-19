-- FreeSWITCH Lua: start DoorBird RTSP playback (video) on the current channel.
-- The RTSP URL is stored locally on the Pi (not in repo) in a root-readable file.
--
-- Intended usage: execute_on_pre_answer=lua doorbird_preview.lua on the G1 B-leg.
-- This allows "preview while ringing" (early media) if the far-end supports it.

local url_path = "/etc/freeswitch/doorbird_rtsp_url.txt"

local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  if not s then return nil end
  -- trim whitespace/newlines
  s = s:gsub("%s+$", ""):gsub("^%s+", "")
  if s == "" then return nil end
  return s
end

if not session or not session:ready() then
  freeswitch.consoleLog("WARNING", "doorbird_preview.lua: no active session\n")
  return
end

local url = read_file(url_path)
if not url then
  freeswitch.consoleLog("ERR", "doorbird_preview.lua: missing/empty " .. url_path .. "\n")
  return
end

local redacted = url:gsub("//[^@]+@", "//***@")
freeswitch.consoleLog("NOTICE", "doorbird_preview.lua: starting playback (url_len=" .. tostring(#url) .. ", url=" .. redacted .. ")\n")

-- Don't let DTMF interrupt the stream.
session:execute("set", "playback_terminators=none")

-- Start streaming. RTSP is handled by mod_av.
-- This will run until hangup or until the stream ends.
session:execute("playback", url)
