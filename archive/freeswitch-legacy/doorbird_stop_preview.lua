-- Stop any running playback app on the answered leg so bridged live media can flow.

if not session or not session:ready() then
  freeswitch.consoleLog("WARNING", "doorbird_stop_preview.lua: no active session\n")
  return
end

local uuid = session:get_uuid() or "n/a"
freeswitch.consoleLog("NOTICE", "doorbird_stop_preview.lua: uuid=" .. uuid .. " break all\n")
session:execute("break", "all")
