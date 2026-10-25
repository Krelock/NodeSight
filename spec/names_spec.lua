local wow = require("helpers.wow")

local ICONS = "Interface\\Icons\\"

-- " (why)" for a case's reason, or nothing.
local function Why(case)
    return case.why and (" (" .. case.why .. ")") or ""
end

describe("Names.lua on an English client", function()
    local ns

    before_each(function()
        ns = wow.Load({ locale = "enUS", api = { C_SkillInfo = wow.Skill(50) } })
    end)

    local KINDS = {
        { name = "Copper Vein", kind = "ore" },
        { name = "Battered Chest", kind = "treasure" },
        { name = "Kupfervorkommen", kind = nil, why = "German names stay unknown" },
    }
    for _, case in ipairs(KINDS) do
        it(("knows %q as %s%s"):format(case.name, tostring(case.kind), Why(case)), function()
            assert.are.equal(case.kind, ns.NodeKind(case.name))
        end)
    end

    it("gives copper its ore icon", function()
        assert.are.equal(ICONS .. "inv_ore_copper_01", ns.NodeIcon("Copper Vein"))
    end)

    it("finds iron too hard at skill 50", function()
        assert.is_true(ns.TooHard("Iron Deposit", "ore"))
    end)
end)

describe("Names.lua on a German client", function()
    local ns

    before_each(function()
        ns = wow.Load({ locale = "deDE", api = { C_SkillInfo = wow.Skill(50) } })
    end)

    describe("NodeKind", function()
        local CASES = {
            { name = "Kupfervorkommen", kind = "ore" },
            { name = "Mageres Kupfervorkommen", kind = "ore", why = "new in Forever" },
            { name = "Bernbrocken", kind = "ore" },
            { name = "Friedensblume", kind = "herbs" },
            { name = "Düsterkraut", kind = "herbs" },
            { name = "Ramponierte Truhe", kind = "treasure" },
            { name = "Verbeulte Schließkiste", kind = "treasure" },
            { name = "Übungsschließkassette", kind = "treasure", why = "capital umlaut, which lower() keeps" },
            { name = "Geldkassette der Defias", kind = "treasure", why = "owner after the chest" },
            { name = "Verstaubte Kiste", kind = "treasure", why = "exact chest name" },
            { name = "Briefkasten", kind = nil, why = "a mailbox is no chest" },
            { name = "Waffenkiste", kind = nil, why = "a crate is no chest" },
            { name = "Leylinie", kind = "leyline" },
            { name = "Elementarkonvergenz", kind = "convergence" },
            { name = "Friedensblume 3/8", kind = nil, why = "quest progress" },
            { name = "Copper Vein", kind = "ore", why = "English names still work" },
        }
        for _, case in ipairs(CASES) do
            it(("knows %q as %s%s"):format(case.name, tostring(case.kind), Why(case)), function()
                assert.are.equal(case.kind, ns.NodeKind(case.name))
            end)
        end
    end)

    describe("NodeIcon", function()
        local CASES = {
            { name = "Kupfervorkommen", icon = "inv_ore_copper_01" },
            { name = "Friedensblume", icon = "inv_misc_flower_02" },
            { name = "Arthas\226\128\153 Tränen", icon = "inv_misc_herb_13", why = "curly apostrophe" },
        }
        for _, case in ipairs(CASES) do
            it(("gives %q the icon %s%s"):format(case.name, case.icon, Why(case)), function()
                assert.are.equal(ICONS .. case.icon, ns.NodeIcon(case.name))
            end)
        end
    end)

    describe("NodeSkill", function()
        local CASES = {
            { name = "Mithrilablagerung", kind = "ore", need = 175 },
            { name = "Brühschlammbedeckte Echtsilberablagerung", kind = "ore", need = 230 },
            { name = "Wilddornrose", kind = "herbs", need = 70 },
            { name = "Alptraummoos", kind = "herbs", need = 125, why = "kind known only after gathering" },
        }
        for _, case in ipairs(CASES) do
            it(("needs %d for %q%s"):format(case.need, case.name, Why(case)), function()
                local need = ns.NodeSkill(case.name, case.kind)

                assert.are.equal(case.need, need)
            end)
        end
    end)

    describe("TooHard", function()
        local CASES = {
            { name = "Eisenvorkommen", kind = "ore", skill = 50, want = true },
            { name = "Zinnvorkommen", kind = "ore", skill = 65, want = false },
            { name = "Golddorn", kind = "herbs", skill = 50, want = true },
        }
        for _, case in ipairs(CASES) do
            it(("is %s for %q at skill %d"):format(tostring(case.want), case.name, case.skill), function()
                local de = wow.Load({ locale = "deDE", api = { C_SkillInfo = wow.Skill(case.skill) } })

                local tooHard = de.TooHard(case.name, case.kind)

                assert.are.equal(case.want, tooHard)
            end)
        end
    end)
end)
