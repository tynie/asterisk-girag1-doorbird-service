-- On answer, request fresh video keyframes on both call legs.
-- No codec/media renegotiation to avoid dropping video m-lines.

if not session or not session:ready() then
  freeswitch.consoleLog("WARNING", "doorbird_on_answer_refresh_only.lua: no active session\n")
  return
end

local b_uuid = session:get_uuid() or ""
local a_uuid = session:getVariable("bridge_uuid") or ""
local api = freeswitch.API()

local function run(cmd)
  local out = api:executeString(cmd) or ""
  freeswitch.consoleLog("NOTICE", "doorbird_on_answer_refresh_only.lua: " .. cmd .. " => " .. out .. "\n")
end

if b_uuid ~= "" then
  run("uuid_video_refresh " .. b_uuid)
end

if a_uuid ~= "" then
  run("uuid_video_refresh " .. a_uuid)
end
