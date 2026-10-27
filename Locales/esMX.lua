-- esMX names for NodeSight, mapped to the English names in Names.lua, one table per kind
-- like the tables there. From Wowhead's WoW Forever object lists.
-- Keys are written like Plain() makes them.
--
-- Another language: copy this file as Locales\<locale>.lua (frFR, esES, ...), set
-- that locale in the GetLocale() line, put the client's names on the left (lowercase,
-- straight apostrophes), and list the file in NodeSight.toc before Names.lua.
-- Names left out are still learned by gathering.

if GetLocale() ~= "esMX" then return end
local _, ns = ...
local LOCALE = {}
ns.LOCALE = LOCALE

LOCALE.HERBS = {
    ["lágrimas de arthas"] = "arthas' tears",
    ["loto negro"] = "black lotus",
    ["carolina"] = "blindweed",
    ["brezospina"] = "briarthorn",
    ["hierba cardenal"] = "bruiseweed",
    ["apocalíseas"] = "doom weed",
    ["hojasueño"] = "dreamfoil",
    ["raíz onírica"] = "dreamroot",
    ["raíz de tierra"] = "earthroot",
    ["pálida"] = "fadeleaf",
    ["flor de fuego"] = "firebloom",
    ["champiñón fantasma"] = "ghost mushroom",
    ["hierba luminiscente"] = "gloom weed",
    ["sansam dorado"] = "golden sansam",
    ["espina de oro"] = "goldthorn",
    ["musgo de tumba"] = "grave moss",
    ["gromsanguina"] = "gromsblood",
    ["setelo"] = "icecap",
    ["mostacho de khadgar"] = "khadgar's whisker",
    ["sangrerregia"] = "kingsblood",
    ["vidarraíz"] = "liferoot",
    ["marregal"] = "mageroyal",
    ["lunarraíz"] = "moonroot",
    ["salviargenta de montaña"] = "mountain silversage",
    ["flor de paz"] = "peacebloom",
    ["flor de plaga"] = "plaguebloom",
    ["loto cárdeno"] = "purple lotus",
    ["hojaplata"] = "silverleaf",
    ["alga estranguladora"] = "stranglekelp",
    ["hojaplata atrofiada"] = "stunted silverleaf",
    ["solea"] = "sungrass",
    ["acérita salvaje"] = "wild steelbloom",
    ["flor de paz marchita"] = "wilted peacebloom",
    ["invernalia"] = "wintersbite",
}
-- New Forever herbs: their item names, not yet confirmed as node names.
LOCALE.ITEM_HERBS = {
    ["loto de la muerte"] = "death lotus",
    ["salvia demoníaca"] = "demonsage",
    ["liquen con volantes"] = "frilled lichen",
    ["cardo de colmena"] = "hive thistle",
    ["hojapesadilla"] = "marefoil",
    ["rosínea"] = "rosecap",
    ["estranguladora"] = "stranglevine",
}
LOCALE.ORE = {
    ["trozo de ámbar"] = "chunk of amber",
    ["filón de cobre"] = "copper vein",
    ["depósito de hierro negro"] = "dark iron deposit",
    ["filón de oro de tontos"] = "fool's gold vein",
    ["filón de oro"] = "gold vein",
    ["formación de piedra lunar grande"] = "greater moonstone formation",
    ["filón de incendicita"] = "incendicite mineral vein",
    ["filón de indurio"] = "indurium mineral vein",
    ["depósito de hierro"] = "iron deposit",
    ["trozo de ámbar grande"] = "large chunk of amber",
    ["depósito de sangrita inferior"] = "lesser bloodstone deposit",
    ["depósito de mitril"] = "mithril deposit",
    ["depósito de mitril cubierto de moco"] = "ooze covered mithril deposit",
    ["filón de torio enriquecido cubierto de moco"] = "ooze covered rich thorium vein",
    ["filón de torio cubierto de moco"] = "ooze covered thorium vein",
    ["vena de cobre escasa"] = "poor copper vein",
    ["filón de torio enriquecido"] = "rich thorium vein",
    ["filón de plata"] = "silver vein",
    ["filón pequeño de torio"] = "small thorium vein",
    ["filón de estaño"] = "tin vein",
    ["depósito de veraplata"] = "truesilver deposit",
}
-- Ley lines and elemental convergences of the new racials.
LOCALE.OTHER = {
    ["convergencia elemental"] = "elemental convergence",
    ["línea ley"] = "leyline",
}
LOCALE.TREASURE = {
    ["cofre de alexston"] = "alexston's chest",
    ["cofre de la alianza"] = "alliance chest",
    ["caja fuerte de la alianza"] = "alliance strongbox",
    ["arqueta de la arena"] = "arena treasure chest",
    ["cofre maltrecho"] = "battered chest",
    ["baúl maltrecho"] = "battered footlocker",
    ["cofre de benedict"] = "benedict's chest",
    ["caja fuerte de bucanero"] = "buccaneer's strongbox",
    ["cofre del capitán"] = "captain's chest",
    ["baúl de cozzle"] = "cozzle's footlocker",
    ["caja fuerte de dentomuerto"] = "dead-tooth's strongbox",
    ["caja fuerte de los defias"] = "defias strongbox",
    ["baúl abollado"] = "dented footlocker",
    ["cofre de bosque del ocaso"] = "duskwood chest",
    ["arcón de gallywix"] = "gallywix's lockbox",
    ["caja fuerte del general trenzado"] = "general twinbraid's strongbox",
    ["caja fuerte oculta"] = "hidden strongbox",
    ["cofre de la horda"] = "horde chest",
    ["caja fuerte de el intrépido cerrada"] = "intrepid's locked strongbox",
    ["cofre grande abollado"] = "large battered chest",
    ["cofre reforzado con hierro grande"] = "large iron bound chest",
    ["cofre reforzado con mitril grande"] = "large mithril bound chest",
    ["cofre macizo grande"] = "large solid chest",
    ["cofre cerrado"] = "locked chest",
    ["cofre del mariscal haggard"] = "marshal haggard's chest",
    ["arcón del halo de bruma"] = "mist veil's lockbox",
    ["baúl antiguo"] = "old footlocker",
    ["arcón del amanecer de plata"] = "silver dawning's lockbox",
    ["cofre macizo"] = "solid chest",
    ["cofre de hierro robado"] = "stolen iron chest",
    ["cofre de almacenamiento"] = "storage chest",
    ["arcón extraño"] = "strange lockbox",
    ["cofre sumergido"] = "sunken chest",
    ["cofre con marcas de agua"] = "waterlogged chest",
    ["baúl con marcas de agua"] = "waterlogged footlocker",
}
