-- On answer, force media renegotiation + video refresh on both legs.
-- Goal: if answered G1 had no preview, request fresh video path/keyframe anyway.

if not session or not session:ready() then
  freeswitch.consoleLog("WARNING", "doorbird_on_answer_video_fix.lua: no active session\n")
  return
end

local b_uuid = session:get_uuid() or ""
local a_uuid = session:getVariable("bridge_uuid") or ""
local api = freeswitch.API()

local function run(cmd)
  local out = api:executeString(cmd) or ""
  freeswitch.consoleLog("NOTICE", "doorbird_on_answer_video_fix.lua: " .. cmd .. " => " .. out .. "\n")
end

if b_uuid ~= "" then
  run("uuid_media_reneg " .. b_uuid .. " =PCMU,H264")
  run("uuid_video_refresh " .. b_uuid)
end

if a_uuid ~= "" then
  run("uuid_media_reneg " .. a_uuid .. " =PCMU,H264")
  run("uuid_video_refresh " .. a_uuid)
end
