-- NodeSight's What's New dialog (the patch notes), a notice shown once, and the bug report.
--
-- Sections: After the fight, What's new (and the notice and the bug report).

local ADDON_NAME, ns = ...

local ipairs = ipairs

---------------------------------------------------------------------------
-- After the fight
---------------------------------------------------------------------------
-- Popups wait for the end of a fight, so none covers the screen in one. One of each name
-- waits (the newest). None with Popups off.
local waiting = {}
-- The saved settings in use, also before they load (the restart notice); nil without any.
local function Saved()
    local db = ns.db
    if not db or db == ns.defaults then
        db = type(NodeSightCharDB) == "table" and NodeSightCharDB.own ~= false and NodeSightCharDB or NodeSightDB
    end
    return type(db) == "table" and db or nil
end
local function PopupsOff()
    local db = Saved()
    return db ~= nil and db.popups == false
end
-- A popup's "Don't show this again": Popups off.
function ns.NoMorePopups()
    local db = Saved()
    if db then db.popups = false end
end
local fightEnd = CreateFrame("Frame")
fightEnd:SetScript("OnEvent", function()
    fightEnd:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local due = waiting
    waiting = {}
    if PopupsOff() then return end
    for _, show in pairs(due) do pcall(show) end
end)
function ns.AfterFight(name, show)
    if PopupsOff() then return end
    if not InCombatLockdown() then return show() end
    waiting[name] = show
    fightEnd:RegisterEvent("PLAYER_REGEN_ENABLED")
end

---------------------------------------------------------------------------
-- What's new
---------------------------------------------------------------------------
-- Newest version first; one without a version uses the .toc's.
local ShowWhatsNew, ShowNotice
do
    local WHATS_NEW = {
        { version = "2.0.5.1",
            { "Fixes", {
                { "Bug report button.", "Its report is shorter to paste, and says more about what was under the mouse" },
            } },
        },
        { version = "2.0.5",
            { "Fixes", {
                { "Scans with EllesmereUI.", "Scans no longer find nothing, or put symbols beside the nodes, when your mouse is near the edge of the screen" },
                { "An error with EllesmereUI.", "Hovering the minimap no longer shows a NodeSight error over and over" },
                { "Text on the minimap during a scan.", "A UI's clock and zone name (EllesmereUI's) stay in their place instead of disappearing or leaving an empty box. With Map while scanning on" },
            } },
        },
        { version = "2.0.4",
            { "New", {
                { "Wait to loot after fights (on by default).", "After a fight, Scan on a timer and Scan by distance wait a few seconds (3 by default, up to 10), so a scan doesn't hide the minimap while you loot. On the Scanning page" },
            } },
            { "Changes", {
                { "Scan after fights and landing.", "Removed. Scan on a timer and Scan by distance still scan as you go" },
                { "Symbols off the minimap.", "A symbol that has been off your minimap for 5 seconds is removed, so you don't come back to a symbol for a node that's already gone" },
                { "Stop when the mouse moves.", "Small movements of the mouse (under 15 pixels) no longer stop a scan" },
            } },
            { "Fixes", {
                { "Scanning with a controller.", "The symbols no longer turn back into plain dots when you scan with a controller button. While nothing is under the mouse, scans wait instead" },
                { "Symbols on the minimap.", "They no longer shift by a pixel against the nodes as you move" },
                { "After disabling NodeSight.", "The game settings it changes (the sparkles' interact settings, In-Game Navigation and the controller's hover) are put back at every reload and logout. Far away sparkles gives your map pin back on reload" },
            } },
        },
        { version = "2.0.3",
            { "New", {
                { "Popups (on by default).", "Turn off every NodeSight popup. On the main page" },
                { "Don't show this again.", "A button on each popup that turns Popups off" },
                { "Bug report.", "A button next to What's New. Copy it and send it with your bug report: it shows NodeSight's setup, CPU, memory and what its last scans did" },
                { "Stop when the mouse moves (off by default).", "An automatic scan stops as soon as you move the mouse, so what you move onto shows its tooltip right away. On the Scanning page, under Your mouse" },
                { "Hide frames that follow the minimap (Beta, on by default).", "During a scan, also hides other addons' frames that move with the minimap without being attached to it (ClassicUIForever's map buttons), so their tooltips don't pop up. On the Beta page" },
            } },
            { "Changes", {
                { "Performance.", "Scans use less than half the CPU, much less with Questie on, and far less memory. Scans finish sooner where NodeSight was slowing your frame rate" },
                { "Scan by distance (now on by default, every 25 yards).", "It replaces Scan on a timer (now off by default). If you still had the old settings, you're moved over once; settings you changed are kept" },
                { "Popups wait for the end of a fight.", "No NodeSight popup shows during combat" },
                { "Not with a mob under the mouse.", "Automatic scans also wait while any tooltip is open under your mouse (a herb, a chest, a mailbox)" },
                { "Scanning page.", "The mouse settings have their own Your mouse header. Edge scans while moving is on the Beta page now" },
                { "Zephras Isle.", "Map while scanning shows the island's own minimap picture" },
            } },
            { "Fixes", {
                { "Switch.", "It switches again with Scan the minimap off" },
                { "Tooltips after a scan.", "A mob's tooltip shows right after a scan, without moving off the mob and back" },
                { "Map icons during a scan.", "Questie's icons (and GatherMate2's, HandyNotes' and TomTom's) stay on their spot as you walk, instead of sliding along with you" },
                { "Mouse with a controller connected.", "Scans no longer change a controller setting while you use the mouse, which could hide the cursor or stop clicks" },
            } },
        },
        { version = "2.0.2",
            { "New", {
                { "Scan presets (Default).", "Default, Less intrusive or Most scans" },
                { "Only while the mouse is still (off by default).", "Automatic scans wait until your mouse stops" },
                { "Also while standing still (on by default).", "Scan on a timer scans while you stand too" },
                { "Scan after fights and landing (on by default).", "One scan as a fight ends, after landing or dismounting, and after a loading screen" },
                { "Edge scans while moving (Beta, off by default).", "Scans read only the new part of the minimap, about twice as fast" },
                { "Not with a mob under the mouse (on by default).", "No scan as you go to loot or click a mob" },
                { "Sparkles only for my professions (on by default).", "No herb, ore or corpse sparkles without Herbalism, Mining or Skinning" },
                { "Why scans aren't working.", "When scans can't run, a warning at the top of NodeSight's settings says why. Hover over it for what to do" },
            } },
            { "Changes", {
                { "Switch.", "It switches right before each automatic scan; its own distance and time are grayed out then" },
                { "Sparkle settings.", "A button on the main page opens the sparkle window" },
                { "Busy.", "No automatic scans while you cast, gather, loot or aim a spell" },
                { "Popups.", "One if an error stops scans (type /reload), one if the game needs a restart after an update" },
            } },
            { "Fixes", {
                { "Minimap buttons and markers.", "A closed button bag (MinimapButtonBag Reborn, Leatrix Plus) or a Questie marker could stay invisible after a scan until a /reload" },
            } },
        },
        { version = "2.0.1",
            { "New", {
                { "Lueur warning (always on).", "Lueur's Herb icons and Ore icons scan the minimap the same way NodeSight does, and with both on they break each other. If both are on, a popup after each login or reload says how to turn one off (typing /lueur nodes turns off Lueur's)" },
            } },
            { "Changes", {
                { "Fewer blinks (on by default).", "A mouse click during a scan now brings the minimap back at once, so your click registers (right-clicking a mob or a node). It still waits up to 2 seconds while your mouse is over a window. On the Scanning page" },
                { "Using your minimap mid-scan.", "Moving your mouse onto the minimap or the addon buttons around it stops the scan at once, so you can hover and click them" },
            } },
            { "Fixes", {
                { "Group Finder.", "While you're queued, the minimap no longer flickers and stops updating, and right-clicks near the minimap no longer get lost" },
            } },
        },
        { version = "2.0.0",
            { "New", {
                { "Real minimap ground (on by default).", "The map shown while a scan runs now uses the game's own minimap pictures, in the minimap's colors and with its arrow, so it looks like your minimap. Part of Map while scanning, on the Scanning page. Thanks to OpenMap for its list of the minimap's pictures" },
                { "Tracked icons while scanning (on by default).", "What you track shows on that map where it really is: innkeepers, mailboxes, bankers, auctioneers, vendors, trainers, stable masters, battlemasters and flight masters, plus your finished quests and rares or treasures. Part of Map while scanning, on the Scanning page" },
                { "Scan the minimap (on by default).", "Turns all scanning on or off. Off, NodeSight never touches your minimap and the sparkles still work. On the NodeSight page" },
            } },
            { "Changes", {
                { "Scan on a timer and Scan by distance (timer on, distance off by default).", "The automatic scans each have their own checkbox and slider now, the slider grayed out while it's off. Scan by distance was Scan as you move; your settings carry over. On the Scanning page" },
                { "Map while scanning (on by default).", "Turned on once for everyone, also if you had it off, for the new look. On the Scanning page" },
                { "Fade in and out (off by default).", "Turned off once for everyone: with the map looking like your minimap, a scan is hard to notice without it. On the Scanning page" },
                { "Minimap borders.", "Your UI's minimap border and buttons (EllesmereUI, Leatrix Plus) stay in place during a scan instead of fading out, and the map's edge is sharp" },
            } },
            { "Fixes", {
                { "Fade and symbols.", "The fade no longer stops working after a few scans, and herb and ore symbols no longer turn into the game's yellow dots as a scan starts" },
                { "Hidden addon buttons.", "Buttons Leatrix Plus hides until you hover the minimap no longer flash after a scan or show up during it, glow included" },
                { "First scan.", "The first scan after a login or reload no longer flashes the map" },
                { "Dots under the mouse.", "No more little white pixels around your cursor during a scan. Thank you to Ashakida for the fix" },
            } },
        },
        { version = "1.9.0",
            { "New", {
                { "Map while scanning (Beta) (on by default).", "While the minimap is hidden for a scan, the world map's picture of where you are shows in its place, moving as you walk. Not with a rotating minimap. On the Scanning page" },
                { "Fade in and out (on by default).", "The minimap and its buttons fade into the map picture before a scan and back after, instead of blinking. Each scan starts a moment later. On the Scanning page" },
                { "Fewer blinks (on by default).", "When your mouse goes over a window (your bags) or you hold a mouse button to turn mid-scan, the minimap stays hidden for a moment instead of flashing back: up to 2 seconds over a window, 1 while you hold a button. On the Scanning page" },
            } },
            { "Changes", {
                { "Scan every (seconds) (10 by default).", "Turned on at 10 once for everyone who had it off and doesn't use Scan as you move. On the Scanning page" },
                { "NPC windows.", "Scans wait while a vendor, quest giver, bank, mailbox, auction house or trade window is open, so addons that sell junk or turn in quests for you aren't interrupted" },
            } },
            { "Fixes", {
                { "EllesmereUI.", "Its coordinates and zoom buttons no longer show up under your mouse during a scan" },
                { "Mail icon.", "With Leatrix Plus or another minimap addon, the mail tooltip no longer pops up and pauses scans" },
                { "Minimap icons.", "Icons other addons put on or next to the minimap stay hidden and can't be hovered during a scan, including ones added mid-scan" },
                { "Buttons shown on hover.", "Addon buttons that only show when you hover the minimap (Leatrix Plus) no longer flash under your mouse at the start of a scan" },
                { "Day/night dial.", "It stays on top of the minimap's border during a scan, and hidden if your UI hides it" },
            } },
        },
        { version = "1.8.1",
            { "Changes", {
                { "Scan look.", "While a scan runs, the minimap's circle is see-through instead of dark, so you still see the world around your symbols" },
            } },
            { "Fixes", {
                { "Windows during a scan.", "Opening your bags or moving your mouse onto a window mid-scan pauses the scan, so your minimap comes right back and item tooltips show; it carries on if you're back within 2 seconds. The scan key does nothing while your mouse is over one" },
                { "Minimap buttons.", "A click during a scan no longer lands on another addon's button on the minimap (a calendar opening by itself, say)" },
            } },
        },
        { version = "1.8.0",
            { "New", {
                { "Scan the minimap (key binding).", "WoW Forever's latest update broke how NodeSight read the minimap, so it scans it now: press the key and your minimap is hidden for under a second while it reads where herbs and ore are. Your symbols, your arrow, the minimap's frame and the coordinates stay on screen meanwhile. Set the key with Scan key on the new Scanning page, or in Keybindings > AddOns > NodeSight" },
                { "Scan as you move (off by default).", "Scans each time you've moved Scan every (yards) (30 by default): not while flying, turning the camera or with your mouse over a window. On the Scanning page" },
                { "Scan every (seconds) (Off by default).", "Also scans once that many seconds have passed, as soon as you move, so herbs and ore that appear or are taken show up. On the Scanning page" },
                { "Not in cities and inns (on by default).", "No scans as you move or on the timer there. On the Scanning page" },
            } },
            { "Changes", {
                { "Scan in combat (off by default now).", "Turned off once for everyone who had it on. On the Scanning page" },
                { "Far away sparkles (Beta).", "They don't work as well since WoW Forever's latest update: whether a far herb is above or below you can't be read any more. They were turned off once for everyone; turn them back on under Beta" },
                { "Arrow.", "It lets go of a herb or ore as soon as it leaves the minimap" },
                { "Gathered nodes.", "A herb or ore someone else gathers loses its symbol at the next scan" },
                { "Scan the minimap checkbox.", "Gone: the scan only runs on its key, with Scan as you move or on its timer" },
            } },
        },
        { version = "1.7.0",
            { "New", {
                { "Sparkles on skinnable corpses (Beta) (off by default).", "A looted corpse you can skin sparkles, so you don't run past it. Turn it on in the Sparkle window's new Skinning tab" },
                { "Landing flies.", "A sparkle style for corpses: flies buzz around the corpse and land on it now and then. Pick it in the Skinning tab" },
                { "Far away sparkle size (150% by default).", "Far away sparkles are bigger and easier to see. Make them bigger or smaller under Beta" },
                { "Keep my tracked quest (less accurate sparkles) (off by default).", "Your tracked quest keeps the game's navigation, but Far away sparkles are much less accurate: they borrow the map pin for a moment after you turn or zoom. Under Beta" },
                { "Line up again every (5 seconds by default).", "How often Far away sparkles line up again with Keep my tracked quest on. Lower is more accurate, but your quest's arrow blinks more often. Under Beta" },
                { "Symbols near you (Shown by default).", "A symbol on top of your own arrow on the minimap can be see-through or hidden, so you still see which way you face. It replaces See-through near you, under Minimap" },
                { "Sound (Minimap ping by default).", "Pick which of the game's sounds Sound for new finds plays: Minimap ping, Coins, Whisper, Ready check, Raid warning or Auction bell. Under Sound for new finds on NodeSight's page" },
                { "Only for skill-ups (off by default).", "Sound for new finds only plays for herbs and ore you can still get a skill-up from. Under Sound for new finds on NodeSight's page" },
            } },
            { "Changes", {
                { "Settings.", "Easier to find your way around: Symbols is now Minimap, the pages have headings, and settings that need another one sit under it and only show while it's on. Shorter tooltips" },
                { "Rares on the minimap.", "No longer Beta, and it moved to Minimap with Rare symbol" },
                { "Arrow size.", "The arrow's name and distance now grow and shrink with the arrow" },
                { "Far away sparkles (Beta).", "They line up better on herbs above you, move smoothly when you turn the camera, no longer flicker and stay on in fights. Their map pin no longer shows on the world map" },
                { "Sparkles.", "Close-range sparkles fade in over a second instead of popping in, and far away sparkles fade out as you walk up, so the two blend" },
                { "What's New.", "The button glows after an update until you've opened the notes" },
            } },
            { "Fixes", {
                "Far away sparkles (Beta) could keep the map pin on a node someone else gathered while Switch between herbs and ore had its finder off",
            } },
        },
        { version = "1.6.3",
            { "New", {
                { "Switch page.", "Switch between herbs and ore has its own page in Options now, under NodeSight. Each switch costs a global cooldown, so it can wait for a better moment. Thanks to tester617 for all of it on GitHub" },
                { "Distance between switches (40% of the minimap by default).", "Measure it in percent of what your minimap shows, in yards or in seconds on the move, under Switch" },
                { "Pauses (on by default).", "No switch while you cast, gather, loot or have something on the cursor, while stealthed, near a herb or ore, for 3 seconds after your own spells or dismounting, or with an enemy targeted within about 40 yards. Each one can be set under Switch" },
                { "Where to switch (open world, dungeons and raids on, battlegrounds off).", "Plus Only while mounted (off by default), under Switch" },
            } },
            { "Changes", {
                { "Switch between herbs and ore.", "It no longer switches every 15 yards. It never switches while standing still, on a flight path, while dead or during the global cooldown, and after two switches in a row that didn't work it stops for a minute. Yards between switches is gone" },
                { "Minimap shape.", "Automatic shows what it found in brackets: Round, Square or Mixed. Thanks to tester617" },
            } },
        },
        { version = "1.6.2",
            { "Changes", {
                { "Quest objects you loot.", "An object that gave you an item for an unfinished quest sparkles from then on, its other spawns too, until the quest no longer needs the item. Shared by all your characters" },
            } },
            { "Fixes", {
                "Quest objects whose name has nothing in common with the quest item, like Alexston's Chest for A Simple Compass, never sparkled. NodeSight now knows about 400 of the old world's quest objects, in any language",
            } },
        },
        { version = "1.6.1",
            { "Fixes", {
                "Quest objects named like a quest item in the singular, like Cattail for Handful of Cattails, never sparkled. Plurals count now",
                "Quest objects you use or destroy, like a Scourge Cauldron for \"Scourge Cauldron destroyed\", never counted as quest objects. They do now",
            } },
        },
        { version = "1.6.0",
            { "New", {
                { "Settings for this character only (on by default).", "Each character keeps its own NodeSight settings, starting from the ones you have now. Untick it to share them with your other characters again. It's on NodeSight's main page in Options" },
                { "Enable All button for sparkles.", "On NodeSight's main page in Options. Turns every kind of sparkle on, or all of them off again" },
                { "Sparkles are off.", "The Sparkle window says so under the node when the shown sparkles are off, and the box that turns them on glows" },
                { "Enable Interact Key warning.", "Sparkles need the game's Enable Interact Key (Options > Controls). If it gets turned off, a dialog offers to turn it back on, and the Sparkle window shows a red line with an Enable button" },
                { "Required skill in tooltips (on by default).", "Untick it to leave out the \"Requires Herbalism (15)\" line NodeSight adds to herb and ore tooltips. It's on NodeSight's own page in Options" },
            } },
            { "Changes", {
                { "Sparkles on your fishing bobber.", "No longer Beta" },
            } },
            { "Fixes", {
                "Quest objects whose name isn't the quest item's, like Naxxramas Crystal Fragment and Agamand Weapon Rack, never sparkled. An object now counts as a quest object when its name shares a word with an unfinished quest item in your log",
                "Your own name or a party or raid member's could show up on the minimap as a herb or ore when it ended like one, like Bob Silverleaf. Players' names are left out now",
            } },
        },
        { version = "1.5.5",
            { "Fixes", {
                "Level-1 herbs and ore like Peacebloom, Silverleaf and Copper Vein changed color one skill point late. They're yellow at 25, green at 50 and gray at 100 now, as the game colors them",
            } },
        },
        { version = "1.5.4",
            { "Changes", {
                { "Skill colors.", "Gray now means a node gives no skill point: everything you can gather turns gray when your skill is at its training cap, until you train the next rank. Race and gear bonuses still count for whether you can gather a node, but not for the chance of a skill-up" },
            } },
            { "Fixes", {
                "Level-1 herbs and ore like Peacebloom, Silverleaf and Copper Vein showed red at a skill of 0. They're orange now. Thanks to DashiDoshi for reporting it",
                "Quest objects like Tirisfal Pumpkin never sparkled, because the game gives them the same icon as a chair. They're found by your quest log now",
                "Gloom Weed and Doom Weed never sparkled. They sparkle as herbs now",
                "Opening the sparkle window gave Lua errors since the game's launch update. The window still worked",
            } },
        },
        { version = "1.5.3",
            { "Changes", {
                { "Sparkle window.", "The preview shows the sparkles where and how big they are in the world next to each node, and the herbs are a little closer" },
                { "When gathered.", "The finish is a little quicker" },
                { "Height.", "The sparkles go down to -150 now" },
            } },
            { "Fixes", {
                "Silverleaf's sparkles floated over the plant: they sit 15 lower than other herbs' now (-75 at the default Height)",
                "Chunk of Amber and Large Chunk of Amber in Teldrassil showed an empty ring instead of their amber picture",
            } },
        },
        { version = "1.5.2",
            { "New", {
                { "Minimap shape (Automatic by default).", "Herbs and ore in the corners of a square minimap get symbols now: NodeSight asks your UI addon (EllesmereUI included) for the shape. If the corners stay empty, choose Square in Minimap shape under Symbols. Thanks to tester617 for this on GitHub" },
            } },
            { "Changes", {
                { "Far away sparkles (Beta).", "A new herb's sparkles fade in instead of popping up" },
            } },
            { "Fixes", {
                "Far away sparkles (Beta): your own map pin came back untracked after a herb was marked, even if you were tracking it",
            } },
        },
        { version = "1.5.1",
            { "New", {
                { "Colored ring and Colored gem (Red when too low by default).", "Symbols can show your chance of a skill-up in the profession window's colors: red when your skill is too low, then orange, yellow, green and gray. Pick one in Skill colors under Symbols" },
            } },
            { "Changes", {
                { "Skill colors.", "The Red symbols when too low checkbox is now a dropdown: Red when too low, Colored ring, Colored gem or Off. If you had it off, it stays off" },
                { "Herbs and ore in caves.", "Their symbols fade out now instead of turning dark gray" },
            } },
            { "Fixes", {
                "Nightmare Moss, Dreamroot and Star Lotus never got a symbol. Thanks to tester617 for this on GitHub",
                "An error in the minimap scan, the symbols, the arrow or Far away sparkles (Beta) could repeat on every frame. Now it shows once, and Far away sparkles stay off until a /reload. Thanks to tester617 for this on GitHub",
            } },
        },
        { version = "1.5.0",
            { "New", {
                { "Sparkle window.", "All the sparkle settings in one window, with a tab for each kind and a 3D preview of the node. It opens with the Sparkles page in Options" },
                { "Sparkle styles (Twinkle by default).", "13 new styles made from the game's own art. Glints, Pollen, Star crown, Wisp, Light beam, Settling dust and Fireflies work on everything. Butterflies, Pickaxe sparks, Spilling coins, Quest mark, Glowing mark and Bubbles are made for herbs, ore, chests, quest objects and your bobber" },
                { "Second color and color sets.", "Sparkles now support two colors" },
                { "Sparkles on chests and Sparkles on quest objects (on if you had Sparkles on other objects on).", "They have their own boxes now" },
                { "Sparkles on your fishing bobber (Beta) (off by default).", "Makes your bobber easier to spot on the water" },
                { "New sparkle settings:", "Brightness, Dimmer out of reach, Hide in combat, Hide in instances, Gray when your skill is too low, Rare nodes stand out, Sparkle sound, Dim while gathering and When gathered. Dim while gathering is on and When gathered is Fade away by default, the rest are off" },
            } },
            { "Changes", {
                { "Sparkles page.", "The sparkle settings are in the sparkle window now. With the gamepad UI on, the page has the basic settings instead" },
                { "Far away sparkles (Beta).", "They use the color and size of the herb or ore they're on" },
            } },
            { "Fixes", {
                "Gold ring symbols could look wrong after turning off High visibility tin and iron",
                "With Switch between herbs and ore on, standing still could leave minutes between scans",
                "The minimap scan no longer runs nonstop in dungeons when there's nothing to find",
                "A vein that also gave a gem could keep its symbol after you mined it with Switch between herbs and ore on",
                "A chest that only gave bars could show up as ore, and opening one could take away a nearby herb's or ore's symbol with Switch between herbs and ore on",
                "Far away sparkles (Beta): sparkles could stay on screen after being turned off, and the game's map marker could stay hidden after an error",
            } },
        },
        { version = "1.4.3",
            { "New", {
                { "Arrow size (40 by default).", "How big the arrow is, from 20 to 100. Change it under Arrow" },
                { "Node names in more languages (always on).", "French, Spanish, Portuguese, Korean and Chinese clients now get the symbols, red and skill line right away too, like German ones. Thanks to tester617 for adding them on GitHub" },
            } },
            { "Changes", {
                { "Rares on the minimap (Beta).", "Rares now show on every client, not only English ones. The first time you log in, they show once the game has loaded their names. Thanks to tester617 for this on GitHub" },
            } },
        },
        { version = "1.4.2",
            { "New", {
                { "German node names (always on).", "On German clients, herbs, ore, chests, leylines and convergences get their symbols, red and skill line right away, without gathering them first. Other languages still learn herbs and ore when you gather them once. Thanks to tester617 for adding them on GitHub" },
            } },
            { "Changes", {
                { "What's New button.", "Now there with the gamepad UI on too" },
            } },
            { "Fixes", {
                { "See-through near you", "Symbols far from you no longer stay see-through. It happened most with Switch between herbs and ore on" },
            } },
        },
        { version = "1.4.1",
            { "New", {
                { "Skill colors on herbs and ore (always on).", "Hover a herb or ore in the world to see the skill it needs, colored like on the minimap" },
                { "Keep the game's icons (off by default).", "The game's own icon stays over the herb, ore, chest or corpse you can interact with while sparkles are on. Turn it on under Sparkles" },
            } },
            { "Changes", {
                { "Switch between herbs and ore.", "No more click each time it switches" },
            } },
        },
        { version = "1.4.0",
            { "New", {
                { "Rares on the minimap (Beta) (on by default).", "Rare humanoids get a rare symbol now too, with Track Humanoids on (hunters and druids). Rares friendly to your faction don't get one. Turn it off under Beta" },
                { "Round, slim gold ring.", "A new Symbol shape" },
                { "Leylines and convergences (on by default).", "For Skyborne: High Order Skyborne get a symbol on leylines while Read Leyline is ready, Windshaper Skyborne on elemental convergences while Skysight is ready. Turn it off under Symbols. Thanks to Truth- for adding the leylines on GitHub" },
                { "Skill colors in the minimap tooltip (always on).", "Hover any herb or ore on the minimap to see the skill it needs, colored like the profession window. Red still means your skill is too low" },
                { "Arrow page.", "Every arrow setting in one place: what it points to, herbs and ore first (off by default) and skip the node you're at (on by default). Under Arrow" },
                { "Lock the arrow in place (off by default).", "The arrow can't be dragged by accident, and your clicks go through it. Turn it on under Arrow. Thanks to lug_2121 for the patch" },
                { "See-through near you (off by default).", "A symbol over your own arrow on the minimap is see-through, so you still see which way you're facing. Turn it on under Symbols" },
            } },
            { "Changes", {
                "Shorter setting names",
                { "Amber in Teldrassil.", "Chunk of Amber and Large Chunk of Amber, Teldrassil's new mining nodes, get a symbol with an amber picture" },
            } },
            { "Fixes", {
                { "Chests", "Crates, sacks and other things you open no longer get the chest symbol and the arrow, only chests do" },
                { "Rares on the minimap (Beta)", "No more Lua error when you change zones or call your pet while a rare beast is on the minimap" },
            } },
        },
        { version = "1.3.0",
            { "New", {
                { "Sparkles on far away herbs and ore (Beta) (off by default).", "Sparkles on the herb or ore you are facing, and on up to four more, from as far away as your minimap shows them. This does not work perfectly: on hills the sparkles can be above or below the herb, and it uses a lot more CPU than with it off. It will be improved in further updates. While it is on it uses the game's map pin and In-Game Navigation, in place of your own map pin and tracked quest. Turn it on under Beta, with Sparkles on herbs or Sparkles on ore on" },
                { "Rare beasts on the minimap (Beta) (on by default).", "For hunters. Track Beasts shows every beast as the same dot: with this on, a rare beast's dot gets a rare symbol (three to pick from), and the arrow, if you have it on, points to the nearest one. It needs Track Beasts on, and can be turned off under Beta. It knows the rare beasts by their English names" },
                { "Gray symbols in caves.", "A herb or ore in a cave has a gray symbol." },
                { "Sound when something new shows up (off by default).", "Plays a sound when a new herb, ore, chest or rare beast shows up on your minimap. Turn it on in NodeSight's settings" },
                { "Key binding for the symbols (no key set by default).", "Turns the herb and ore symbols on the minimap on and off with a key" },
            } },
            { "Changes", {
                "Switch between herbs and ore and Yards between switches are out of Beta and on NodeSight's own page",
                "The settings are sorted into pages. The basics are on NodeSight's own page, and Symbols, Sparkles and Beta have pages of their own under it",
                "What's New has arrows now: the right one shows the notes of the version before",
                "Small performance improvements",
            } },
        },
        { version = "1.2.0",
            { "New", {
                { "Switch between herbs and ore (Beta) (off by default).", "NodeSight turns on Find Herbs and Find Minerals on and off as you move so you find both without switching yourself. The symbols of the one that is off stay on your minimap, so you see herbs and ore together. You need both Find Herbs and Find Minerals, with one of them turned on, and it never switches in combat. Turn it on under Arrow and minimap. Thank you W8kingNightmare for the amazing suggestion" },
                { "Treasure chests for dwarves (Beta)", "With Find Treasure on, the chests on your minimap get a chest symbol the way herbs and ore get theirs, and the arrow points to the nearest one" },
                { "You can move the arrow now!", "Drag the arrow to put it where you want it" },
            } },
            { "Changes", {
                "While you stand still, NodeSight scans the minimap less and less",
                "With Sparkles on other objects on, mailboxes and things you only use, like chairs and doors no longer sparkle. Chests and quest objects still do",
            } },
            { "Fixes", {
                "The arrow no longer points to a herb or ore you don't have the skill for. It goes to the nearest one you can gather, and there is no arrow when you can't gather anything in sight.",
                "Minor fixes to the scanning logic",
                "NodeSight now only scans the minimap while Find Herbs, Find Minerals or Find Treasure is on. A character with none would still be scanning the minimap before",
                "Opening the game's Options no longer gives an error from NodeSight",
            } },
        },
    }
    -- No parent in CreateFrame (see NewSparkles in Sparkles.lua).
    local function NewFrame(kind, parent)
        local frame = CreateFrame(kind)
        frame:SetParent(parent)
        return frame
    end
    local function DialogButton(parent, text, onClick)
        local button = NewFrame("Button", parent)
        button:SetSize(128, 21) -- StaticPopupButtonTemplate's size
        button:SetNormalTexture("Interface\\Buttons\\UI-DialogBox-Button-Up")
        button:GetNormalTexture():SetTexCoord(0, 1, 0, 0.71875)
        button:SetPushedTexture("Interface\\Buttons\\UI-DialogBox-Button-Down")
        button:GetPushedTexture():SetTexCoord(0, 1, 0, 0.71875)
        button:SetHighlightTexture("Interface\\Buttons\\UI-DialogBox-Button-Highlight", "ADD")
        button:GetHighlightTexture():SetTexCoord(0, 1, 0, 0.71875)
        button:SetNormalFontObject(GameFontNormal)
        button:SetHighlightFontObject(GameFontHighlight)
        button:SetText(text)
        button:SetScript("OnClick", onClick)
        return button
    end
    local dialog = { page = 1 } -- the dialog's frames and current page
    local WIDTHS = { 480, 720, 960 } -- tried in turn until the notes fit on the screen
    -- Shows a version's notes, sizing the dialog to fit.
    function dialog.ShowPage()
        local notes = WHATS_NEW[dialog.page]
        local lines = { NORMAL_FONT_COLOR:WrapTextInColorCode(("NodeSight %s"):format(
            notes.version or C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version"))) }
        for _, section in ipairs(notes) do
            lines[#lines + 1] = "\n" .. NORMAL_FONT_COLOR:WrapTextInColorCode(section[1])
            for _, item in ipairs(section[2]) do
                if type(item) == "table" then item = NORMAL_FONT_COLOR:WrapTextInColorCode(item[1]) .. " " .. item[2] end
                lines[#lines + 1] = "- " .. item
            end
        end
        local frame, text = dialog.frame, dialog.text
        text:SetText(table.concat(lines, "\n"))
        for _, width in ipairs(WIDTHS) do
            frame:SetWidth(width)
            text:SetWidth(width - 40)
            if text:GetStringHeight() + 73 <= UIParent:GetHeight() - 145 then break end -- the dialog's top is 135 below the screen's
        end
        frame:SetHeight(text:GetStringHeight() + 73)
        dialog.older:SetEnabled(dialog.page < #WHATS_NEW)
        dialog.newer:SetEnabled(dialog.page > 1)
    end
    -- Page arrows: 1 = older, -1 = newer.
    function dialog.Turn(by)
        if not WHATS_NEW[dialog.page + by] then return end
        dialog.page = dialog.page + by
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        dialog.ShowPage()
    end
    function ShowWhatsNew()
        if not dialog.frame then
            local frame = NewFrame("Frame", UIParent)
            frame:SetFrameStrata("DIALOG")
            frame:SetToplevel(true)
            frame:EnableMouse(true)
            frame:SetPoint("TOP", UIParent, "TOP", 0, -135)
            local background = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
            background:SetAtlas("UI-DialogBox-Background-Dark", true)
            background:SetPoint("TOPLEFT", 7, -7)
            background:SetPoint("BOTTOMRIGHT", -7, 7)
            local edge = frame:CreateTexture(nil, "BACKGROUND", nil, -4)
            edge:SetAtlas("UI-DiamondDialogBox-Border", true)
            edge:SetAllPoints()
            local text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            text:SetPoint("TOP", 0, -20)
            text:SetJustifyH("LEFT")
            text:SetSpacing(3)
            text:SetIndentedWordWrap(true) -- indent wrapped lines
            -- Blizzard's page arrows, top right: right = older, left = newer.
            local function ArrowButton(way, by)
                local button = NewFrame("Button", frame)
                button:SetSize(32, 32)
                button:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. way .. "Page-Up")
                button:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. way .. "Page-Down")
                button:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. way .. "Page-Disabled")
                button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
                button:SetScript("OnClick", function() dialog.Turn(by) end)
                return button
            end
            dialog.frame, dialog.text = frame, text
            dialog.older = ArrowButton("Next", 1)
            dialog.older:SetPoint("TOPRIGHT", -14, -10)
            dialog.newer = ArrowButton("Prev", -1)
            dialog.newer:SetPoint("RIGHT", dialog.older, "LEFT", 0, 0)
            DialogButton(frame, OKAY, function() frame:Hide() end):SetPoint("BOTTOM", 0, 16)
        end
        dialog.page = 1 -- open on the newest
        dialog.ShowPage()
        dialog.frame:Show()
    end

    -- Notice: one message in the same look, with an OK button.
    local notice
    local function Show(title, body)
        if not notice then
            notice = NewFrame("Frame", UIParent)
            notice:SetFrameStrata("DIALOG")
            notice:SetToplevel(true)
            notice:EnableMouse(true)
            notice:SetPoint("TOP", UIParent, "TOP", 0, -135)
            notice:SetWidth(WIDTHS[1])
            local background = notice:CreateTexture(nil, "BACKGROUND", nil, -7)
            background:SetAtlas("UI-DialogBox-Background-Dark", true)
            background:SetPoint("TOPLEFT", 7, -7)
            background:SetPoint("BOTTOMRIGHT", -7, 7)
            local edge = notice:CreateTexture(nil, "BACKGROUND", nil, -4)
            edge:SetAtlas("UI-DiamondDialogBox-Border", true)
            edge:SetAllPoints()
            notice.text = notice:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            notice.text:SetPoint("TOP", 0, -20)
            notice.text:SetWidth(WIDTHS[1] - 40)
            notice.text:SetJustifyH("LEFT")
            notice.text:SetSpacing(3)
            DialogButton(notice, OKAY, function() notice:Hide() end):SetPoint("BOTTOMRIGHT", notice, "BOTTOM", -6, 16)
            local never = DialogButton(notice, CONFIRM_POPUP_DONT_SHOW_AGAIN, function()
                ns.NoMorePopups()
                notice:Hide()
            end)
            never:SetWidth(math.max(128, never:GetTextWidth() + 24))
            never:SetPoint("BOTTOMLEFT", notice, "BOTTOM", 6, 16)
        end
        notice.text:SetText(NORMAL_FONT_COLOR:WrapTextInColorCode(title) .. "\n\n" .. body)
        notice:SetHeight(notice.text:GetStringHeight() + 73)
        notice:Show()
    end
    function ShowNotice(title, body)
        ns.AfterFight("notice", function() Show(title, body) end)
    end

    -- Bug report: the text (ns.ReportText) all selected in a box, to copy with Ctrl+C (an
    -- addon can't copy to the clipboard itself). The mouse wheel scrolls it.
    local report
    function ns.ShowReport()
        if not report then
            report = NewFrame("Frame", UIParent)
            report:SetFrameStrata("DIALOG")
            report:SetToplevel(true)
            report:EnableMouse(true)
            report:SetPoint("TOP", UIParent, "TOP", 0, -135)
            report:SetSize(640, 440)
            local background = report:CreateTexture(nil, "BACKGROUND", nil, -7)
            background:SetAtlas("UI-DialogBox-Background-Dark", true)
            background:SetPoint("TOPLEFT", 7, -7)
            background:SetPoint("BOTTOMRIGHT", -7, 7)
            local edge = report:CreateTexture(nil, "BACKGROUND", nil, -4)
            edge:SetAtlas("UI-DiamondDialogBox-Border", true)
            edge:SetAllPoints()
            local title = report:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            title:SetPoint("TOP", 0, -20)
            title:SetText("NodeSight bug report")
            local hint = report:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            hint:SetPoint("TOP", title, "BOTTOM", 0, -6)
            hint:SetWidth(600)
            hint:SetText("Press Ctrl+C to copy it all. When reporting a bug, please send this with it.")
            local clip = NewFrame("Frame", report)
            clip:SetPoint("TOPLEFT", 20, -62)
            clip:SetPoint("BOTTOMRIGHT", -20, 48)
            clip:SetClipsChildren(true)
            local shade = clip:CreateTexture(nil, "BACKGROUND")
            shade:SetColorTexture(0, 0, 0, 0.5)
            shade:SetAllPoints()
            local box = NewFrame("EditBox", clip)
            box:SetMultiLine(true)
            box:SetAutoFocus(false)
            box:SetFontObject(GameFontHighlightSmall)
            box:SetWidth(590)
            box:SetPoint("TOPLEFT", 5, -5)
            box:SetScript("OnEscapePressed", function() report:Hide() end)
            -- Read only: typing puts the report back, all selected.
            box:SetScript("OnTextChanged", function(self, typed)
                if typed then
                    self:SetText(report.text)
                    self:HighlightText()
                end
            end)
            local offset = 0
            clip:EnableMouseWheel(true)
            clip:SetScript("OnMouseWheel", function(_, delta)
                offset = math.max(0, math.min(math.max(0, box:GetHeight() - clip:GetHeight() + 10), offset - delta * 40))
                box:SetPoint("TOPLEFT", 5, -5 + offset)
            end)
            DialogButton(report, CLOSE, function() report:Hide() end):SetPoint("BOTTOM", 0, 16)
            report.box = box
        end
        report.text = ns.ReportText()
        report.box:SetText(report.text)
        report:Show()
        report.box:SetFocus()
        report.box:HighlightText()
    end
end

ns.ShowWhatsNew, ns.ShowNotice = ShowWhatsNew, ShowNotice
