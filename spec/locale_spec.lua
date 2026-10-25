local wow = require("helpers.wow")

-- Each table of Locales/deDE.lua and the kinds its English names must have.
local TABLES = {
    { name = "HERBS", kinds = { herbs = true } },
    { name = "ITEM_HERBS", kinds = { herbs = true } },
    { name = "ORE", kinds = { ore = true } },
    { name = "OTHER", kinds = { leyline = true, convergence = true } },
    { name = "TREASURE", kinds = { treasure = true } },
}

-- The keys of a table for which test(key, value) is false, sorted.
local function Offenders(entries, test)
    local bad = {}
    for key, value in pairs(entries) do
        if not test(key, value) then bad[#bad + 1] = key end
    end
    table.sort(bad)
    return bad
end

describe("Locales/deDE.lua", function()
    local de, en

    before_each(function()
        de = wow.Load({ locale = "deDE" })
        en = wow.Load({ locale = "enUS" })
    end)

    it("loads on German clients", function()
        assert.are.equal("table", type(de.LOCALE))
    end)

    it("does not load on English clients", function()
        assert.is_nil(en.LOCALE)
    end)

    for _, entry in ipairs(TABLES) do
        describe(entry.name, function()
            it("exists", function()
                assert.are.equal("table", type(de.LOCALE[entry.name]))
            end)

            it("has keys written like Plain()", function()
                assert.are.same({}, Offenders(de.LOCALE[entry.name], function(key) return de.Plain(key) == key end))
            end)

            it("has no digit, ':' or '/' in a key", function()
                assert.are.same({}, Offenders(de.LOCALE[entry.name], function(key) return not key:find("[%d:/]") end))
            end)

            -- or names NodeKind does not know but NEEDED does: their kind is learned by gathering.
            it("maps to English names of its kind, or with a skill need of its kind", function()
                assert.are.same({}, Offenders(de.LOCALE[entry.name], function(_, english)
                    if entry.kinds[en.NodeKind(english)] then return true end
                    for kind in pairs(entry.kinds) do
                        if en.NodeSkill(english, kind) then return true end
                    end
                    return false
                end))
            end)

            it("gives each German name the kind of its English one", function()
                assert.are.same({}, Offenders(de.LOCALE[entry.name], function(key, english)
                    return de.NodeKind(key) == en.NodeKind(english)
                end))
            end)
        end)
    end
end)
