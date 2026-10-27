-- zhTW names for NodeSight, mapped to the English names in Names.lua, one table per kind
-- like the tables there. From Wowhead's WoW Forever object lists.
-- Keys are written like Plain() makes them.
--
-- Another language: copy this file as Locales\<locale>.lua (frFR, esES, ...), set
-- that locale in the GetLocale() line, put the client's names on the left (lowercase,
-- straight apostrophes), and list the file in NodeSight.toc before Names.lua.
-- Names left out are still learned by gathering.

if GetLocale() ~= "zhTW" then return end
local _, ns = ...
local LOCALE = {}
ns.LOCALE = LOCALE

LOCALE.HERBS = {
    ["阿薩斯之淚"] = "arthas' tears",
    ["黑蓮花"] = "black lotus",
    ["盲目草"] = "blindweed",
    ["石南草"] = "briarthorn",
    ["跌打草"] = "bruiseweed",
    ["末日草"] = "doom weed",
    ["夢葉草"] = "dreamfoil",
    ["地根草"] = "earthroot",
    ["枯葉草"] = "fadeleaf",
    ["火焰花"] = "firebloom",
    ["幽靈菇"] = "ghost mushroom",
    ["陰暗草"] = "gloom weed",
    ["黃金蔘"] = "golden sansam",
    ["金棘草"] = "goldthorn",
    ["墓地苔"] = "grave moss",
    ["格羅姆高之血"] = "gromsblood",
    ["冰蓋草"] = "icecap",
    ["卡德加的鬍鬚"] = "khadgar's whisker",
    ["皇血草"] = "kingsblood",
    ["活根草"] = "liferoot",
    ["魔皇草"] = "mageroyal",
    ["月之根"] = "moonroot",
    ["山鼠草"] = "mountain silversage",
    ["夢魘苔"] = "nightmare moss",
    ["寧神花"] = "peacebloom",
    ["瘟疫花"] = "plaguebloom",
    ["紫蓮花"] = "purple lotus",
    ["銀葉草"] = "silverleaf",
    ["星蓮花"] = "star lotus",
    ["荊棘藻"] = "stranglekelp",
    ["貧弱的銀葉草"] = "stunted silverleaf",
    ["太陽草"] = "sungrass",
    ["野鋼花"] = "wild steelbloom",
    ["凋謝的寧神花"] = "wilted peacebloom",
    ["冬刺草"] = "wintersbite",
}
-- New Forever herbs: their item names, not yet confirmed as node names.
LOCALE.ITEM_HERBS = {
    ["死亡蓮花"] = "death lotus",
    ["魔鼠草"] = "demonsage",
    ["褶邊地衣"] = "frilled lichen",
    ["蟲巢薊"] = "hive thistle",
    ["惡夢葉草"] = "marefoil",
    ["玫瑰冠草"] = "rosecap",
    ["窒息藤蔓"] = "stranglevine",
}
LOCALE.ORE = {
    ["冷鐵礦床"] = "cold iron deposit",
    ["銅礦"] = "copper vein",
    ["黑鐵礦脈"] = "dark iron deposit",
    ["愚人的黃金礦脈"] = "fool's gold vein",
    ["金礦石"] = "gold vein",
    ["金礦脈"] = "gold vein",
    ["強效月亮石陣"] = "greater moonstone formation",
    ["哈卡萊瑟銀礦脈"] = "hakkari thorium vein",
    ["精鐵礦脈"] = "indurium mineral vein",
    ["鐵礦床"] = "iron deposit",
    ["大黑曜石塊"] = "large obsidian chunk",
    ["次級血石礦脈"] = "lesser bloodstone deposit",
    ["祕銀礦床"] = "mithril deposit",
    ["祕銀礦脈"] = "mithril deposit",
    ["軟泥覆蓋的祕銀礦脈"] = "ooze covered mithril deposit",
    ["軟泥覆蓋的富瑟銀礦脈"] = "ooze covered rich thorium vein",
    ["軟泥覆蓋的瑟銀礦脈"] = "ooze covered thorium vein",
    ["軟泥覆蓋的真銀礦脈"] = "ooze covered truesilver deposit",
    ["貧瘠的銅礦"] = "poor copper vein",
    ["富瑟銀礦"] = "rich thorium vein",
    ["銀礦"] = "silver vein",
    ["小黑曜石塊"] = "small obsidian chunk",
    ["瑟銀礦脈"] = "small thorium vein",
    ["星銀礦脈"] = "starsilver vein",
    ["錫礦"] = "tin vein",
    ["真銀礦床"] = "truesilver deposit",
    ["真銀礦石"] = "truesilver deposit",
}
-- Ley lines and elemental convergences of the new racials.
LOCALE.OTHER = {
    ["元素匯聚"] = "elemental convergence",
    ["地脈"] = "leyline",
}
LOCALE.TREASURE = {
    ["艾力克斯頓的箱子"] = "alexston's chest",
    ["聯盟寶箱"] = "alliance chest",
    ["聯盟保險箱"] = "alliance strongbox",
    ["安伯米爾保險箱"] = "ambermill strongbox",
    ["破損的箱子"] = "battered chest",
    ["破碎的提箱"] = "battered footlocker",
    ["本尼迪克的箱子"] = "benedict's chest",
    ["書呆子赫羅德的保險箱"] = "bookie herod's strongbox",
    ["海盜的保險箱"] = "buccaneer's strongbox",
    ["船長的手提箱"] = "captain's footlocker",
    ["考茲爾的箱子"] = "cozzle's footlocker",
    ["蛀牙傑克的箱子"] = "dead-tooth's strongbox",
    ["迪菲亞保險箱"] = "defias strongbox",
    ["凹陷的箱子"] = "dented chest",
    ["暮色森林的箱子"] = "duskwood chest",
    ["塔文布萊德將軍的箱子"] = "general twinbraid's strongbox",
    ["隱蔽的保險箱"] = "hidden strongbox",
    ["部落儲物箱"] = "horde chest",
    ["保險箱"] = "intrepid's locked strongbox",
    ["破碎的大箱子"] = "large battered chest",
    ["大型鐵箍儲物箱"] = "large iron bound chest",
    ["大型祕銀儲物箱"] = "large mithril bound chest",
    ["堅固的大箱子"] = "large solid chest",
    ["瑪雷姆的箱子"] = "malem chest",
    ["哈加德的箱子"] = "marshal haggard's chest",
    ["派瑞恩的箱子"] = "perrine's chest",
    ["堅固的箱子"] = "solid chest",
    ["被偷走的鐵箱"] = "stolen iron chest",
    ["儲物箱"] = "storage chest",
    ["奇怪的保險箱"] = "strange lockbox",
    ["沉沒的箱子"] = "sunken chest",
    ["浸水的提箱"] = "waterlogged footlocker",
}
