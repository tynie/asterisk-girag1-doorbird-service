-- FreeSWITCH Lua: inject preview stream from local multicast into a ringing leg.
-- Intended usage: execute_on_pre_answer=lua doorbird_preview_multicast.lua
--
-- Why this exists:
-- - DoorBird early-media on forked legs is not deterministic.
-- - We provide our own preview source on the Pi so both G1 legs can render preview.

local default_url_path = "/etc/freeswitch/doorbird_preview_url.txt"
local url_path_23 = "/etc/freeswitch/doorbird_preview_url_23.txt"
local url_path_53 = "/etc/freeswitch/doorbird_preview_url_53.txt"

local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  if not s then return nil end
  s = s:gsub("%s+$", ""):gsub("^%s+", "")
  if s == "" then return nil end
  return s
end

if not session or not session:ready() then
  freeswitch.consoleLog("WARNING", "doorbird_preview_multicast.lua: no active session\n")
  return
end

local leg = nil
if argv and argv[1] then
  leg = tostring(argv[1])
end

local url_path = default_url_path
if leg == "23" then
  url_path = url_path_23
elseif leg == "53" then
  url_path = url_path_53
end

local url = read_file(url_path)
if not url then
  freeswitch.consoleLog("ERR", "doorbird_preview_multicast.lua: missing/empty " .. url_path .. "\n")
  return
end

local playback_url = url
if url:match("^udp://") or url:match("^rtsp://") or url:match("^http://") or url:match("^https://") then
  -- Force FFmpeg-backed file interface; plain playback(udp://...) can degrade to black frames.
  playback_url = "av://" .. url
end

local uuid = session:get_uuid() or "n/a"
local redacted = url:gsub("//[^@]+@", "//***@")
local redacted_playback = playback_url:gsub("//[^@]+@", "//***@")
freeswitch.consoleLog("NOTICE", "doorbird_preview_multicast.lua: uuid=" .. uuid .. " leg=" .. (leg or "default") .. " url=" .. redacted .. " playback=" .. redacted_playback .. "\n")

-- Prevent accidental stop via DTMF while ringing.
session:execute("set", "playback_terminators=none")

-- Stream preview media into the leg.
session:execute("playback", playback_url)
