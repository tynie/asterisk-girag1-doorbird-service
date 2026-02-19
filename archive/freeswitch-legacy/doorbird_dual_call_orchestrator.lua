-- DoorBird -> FS (A-leg) orchestrator:
-- - start two independent outbound calls to both G1 panels
-- - each outbound call gets preview on pre-answer
-- - first answered call wins
-- - loser leg is terminated
-- - A-leg is bridged to winner leg

local api = freeswitch.API()

local function log(level, msg)
  freeswitch.consoleLog(level, "doorbird_dual_call_orchestrator.lua: " .. msg .. "\n")
end

local function trim(s)
  if not s then return "" end
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function run(cmd)
  local out = api:executeString(cmd) or ""
  return trim(out)
end

local function new_uuid()
  return run("create_uuid")
end

local function uuid_exists(u)
  if not u or u == "" then return false end
  return run("uuid_exists " .. u) == "true"
end

local function answer_epoch(u)
  if not uuid_exists(u) then return "" end
  return run("uuid_getvar " .. u .. " answer_epoch")
end

local function call_state(u)
  if not uuid_exists(u) then return "" end
  local out = run("show channels like " .. u)
  if out == "" then return "" end
  -- CSV row contains callstate column near the end (e.g. ",EARLY," or ",ACTIVE,")
  if string.find(out, ",ACTIVE,", 1, true) then return "ACTIVE" end
  if string.find(out, ",EARLY,", 1, true) then return "EARLY" end
  if string.find(out, ",RINGING,", 1, true) then return "RINGING" end
  return out
end

local function is_answered_active(u)
  if not uuid_exists(u) then return false end
  return call_state(u) == "ACTIVE"
end

local function safe_kill(u, cause)
  if uuid_exists(u) then
    run("uuid_kill " .. u .. " " .. (cause or "NORMAL_CLEARING"))
  end
end

if not session or not session:ready() then
  log("WARNING", "no active session")
  return
end

local a_uuid = session:get_uuid() or ""
if a_uuid == "" then
  log("ERR", "missing a-leg uuid")
  return
end

local g1_23 = "sofia/internal/7000@192.168.11.23:5060"
local g1_53 = "sofia/internal/7000@192.168.11.53:5060"

local b1 = new_uuid()
local b2 = new_uuid()
if b1 == "" or b2 == "" then
  log("ERR", "failed to allocate originate uuids")
  return
end

local ov =
  "{originate_timeout=45,leg_timeout=45,ignore_early_media=false," ..
  "bridge_early_media=true,hangup_after_bridge=true,continue_on_fail=true," ..
  "origination_caller_id_name=doorbird,origination_caller_id_number=doorbird," ..
  "codec_string=PCMU,H264,absolute_codec_string=PCMU,H264," ..
  "rtp_disable_video=false,bypass_media=false,proxy_media=true,"
local cmd1 = "bgapi originate " .. ov ..
  "execute_on_pre_answer='lua /usr/share/freeswitch/scripts/doorbird_preview_multicast.lua 23'," ..
  "origination_uuid=" .. b1 .. "}" .. g1_23 .. " &park()"
local cmd2 = "bgapi originate " .. ov ..
  "execute_on_pre_answer='lua /usr/share/freeswitch/scripts/doorbird_preview_multicast.lua 53'," ..
  "origination_uuid=" .. b2 .. "}" .. g1_53 .. " &park()"

log("NOTICE", "start legs a=" .. a_uuid .. " b1=" .. b1 .. " b2=" .. b2)
run(cmd1)
run(cmd2)

local winner = ""
local loser = ""
local max_wait_ms = 45000
local slept = 0
local last_dbg = -1000

while slept < max_wait_ms do
  if not session:ready() then
    log("NOTICE", "a-leg not ready while waiting; abort")
    safe_kill(b1, "ORIGINATOR_CANCEL")
    safe_kill(b2, "ORIGINATOR_CANCEL")
    return
  end

  if is_answered_active(b1) then
    winner = b1
    loser = b2
    break
  end
  if is_answered_active(b2) then
    winner = b2
    loser = b1
    break
  end

  if (slept - last_dbg) >= 1000 then
    local s1 = call_state(b1)
    local s2 = call_state(b2)
    local a1 = answer_epoch(b1)
    local a2 = answer_epoch(b2)
    log("NOTICE", "wait t=" .. tostring(slept) .. " b1=" .. s1 .. "/" .. a1 .. " b2=" .. s2 .. "/" .. a2)
    last_dbg = slept
  end

  -- both legs gone and no answer: stop
  if (not uuid_exists(b1)) and (not uuid_exists(b2)) then
    break
  end

  session:sleep(100)
  slept = slept + 100
end

if winner == "" then
  log("NOTICE", "no answer; cleanup")
  safe_kill(b1, "NO_ANSWER")
  safe_kill(b2, "NO_ANSWER")
  return
end

log("NOTICE", "winner=" .. winner .. " loser=" .. loser .. " bridge a-leg")
safe_kill(loser, "LOSE_RACE")
-- Stop any lingering preview playback before bridging media legs.
run("uuid_break " .. winner .. " all")
session:sleep(100)
if session:ready() then
  session:execute("bridge", "uuid:" .. winner)
  log("NOTICE", "session bridge executed to winner=" .. winner)
else
  log("ERR", "a-leg not ready before final bridge")
end
