-- zhCN names for NodeSight, mapped to the English names in Names.lua, one table per kind
-- like the tables there. From Wowhead's WoW Forever object lists.
-- Keys are written like Plain() makes them.
--
-- Another language: copy this file as Locales\<locale>.lua (frFR, esES, ...), set
-- that locale in the GetLocale() line, put the client's names on the left (lowercase,
-- straight apostrophes), and list the file in NodeSight.toc before Names.lua.
-- Names left out are still learned by gathering.

if GetLocale() ~= "zhCN" then return end
local _, ns = ...
local LOCALE = {}
ns.LOCALE = LOCALE

LOCALE.HERBS = {
    ["阿尔萨斯之泪"] = "arthas' tears",
    ["黑莲花"] = "black lotus",
    ["盲目草"] = "blindweed",
    ["石南草"] = "briarthorn",
    ["跌打草"] = "bruiseweed",
    ["末日草"] = "doom weed",
    ["梦叶草"] = "dreamfoil",
    ["梦之根"] = "dreamroot",
    ["地根草"] = "earthroot",
    ["枯叶草"] = "fadeleaf",
    ["火焰花"] = "firebloom",
    ["幽灵菇"] = "ghost mushroom",
    ["阴暗草"] = "gloom weed",
    ["黄金参"] = "golden sansam",
    ["金棘草"] = "goldthorn",
    ["墓地苔"] = "grave moss",
    ["格罗姆之血"] = "gromsblood",
    ["冰盖草"] = "icecap",
    ["卡德加的胡须"] = "khadgar's whisker",
    ["皇血草"] = "kingsblood",
    ["活根草"] = "liferoot",
    ["魔皇草"] = "mageroyal",
    ["山鼠草"] = "mountain silversage",
    ["宁神花"] = "peacebloom",
    ["瘟疫花"] = "plaguebloom",
    ["紫莲花"] = "purple lotus",
    ["银叶草"] = "silverleaf",
    ["荆棘藻"] = "stranglekelp",
    ["矮小的银叶草"] = "stunted silverleaf",
    ["太阳草"] = "sungrass",
    ["野钢花"] = "wild steelbloom",
    ["枯萎的宁神花"] = "wilted peacebloom",
    ["冬刺草"] = "wintersbite",
}
-- New Forever herbs: their item names, not yet confirmed as node names.
LOCALE.ITEM_HERBS = {
    ["死亡莲花"] = "death lotus",
    ["恶魔贤者"] = "demonsage",
    ["褶皱地衣"] = "frilled lichen",
    ["巢生蓟"] = "hive thistle",
    ["梦魇草"] = "marefoil",
    ["玫瑰盖菇"] = "rosecap",
    ["窒息藤"] = "stranglevine",
}
LOCALE.ORE = {
    ["铜矿"] = "copper vein",
    ["黑铁矿脉"] = "dark iron deposit",
    ["愚人金矿脉"] = "fool's gold vein",
    ["金矿"] = "gold vein",
    ["金矿石"] = "gold vein",
    ["哈卡莱瑟银矿脉"] = "hakkari thorium vein",
    ["火岩矿脉"] = "incendicite mineral vein",
    ["精铁矿脉"] = "indurium mineral vein",
    ["铁矿石"] = "iron deposit",
    ["大型黑曜石碎块"] = "large obsidian chunk",
    ["次级血石矿脉"] = "lesser bloodstone deposit",
    ["秘银矿脉"] = "mithril deposit",
    ["软泥覆盖的金矿脉"] = "ooze covered gold vein",
    ["软泥覆盖的秘银矿脉"] = "ooze covered mithril deposit",
    ["软泥覆盖的富瑟银矿脉"] = "ooze covered rich thorium vein",
    ["软泥覆盖的瑟银矿脉"] = "ooze covered thorium vein",
    ["软泥覆盖的真银矿脉"] = "ooze covered truesilver deposit",
    ["劣质铜矿"] = "poor copper vein",
    ["富瑟银矿"] = "rich thorium vein",
    ["银矿"] = "silver vein",
    ["小型黑曜石碎块"] = "small obsidian chunk",
    ["瑟银矿脉"] = "small thorium vein",
    ["锡矿"] = "tin vein",
    ["真银矿石"] = "truesilver deposit",
    ["真银矿脉"] = "truesilver deposit",
}
-- Ley lines and elemental convergences of the new racials.
LOCALE.OTHER = {
    ["元素交汇"] = "elemental convergence",
}
LOCALE.TREASURE = {
    ["阿历克斯顿的箱子"] = "alexston's chest",
    ["联盟宝箱"] = "alliance chest",
    ["联盟保险箱"] = "alliance strongbox",
    ["破损的箱子"] = "battered chest",
    ["破碎的提箱"] = "battered footlocker",
    ["本尼迪克的箱子"] = "benedict's chest",
    ["书呆子赫罗德的保险箱"] = "bookie herod's strongbox",
    ["海盗的保险箱"] = "buccaneer's strongbox",
    ["船长的手提箱"] = "captain's footlocker",
    ["考兹尔的箱子"] = "cozzle's footlocker",
    ["蛀牙杰克的箱子"] = "dead-tooth's strongbox",
    ["迪菲亚保险箱"] = "defias strongbox",
    ["凹陷的箱子"] = "dented chest",
    ["杜安的保险箱"] = "doan's strongbox",
    ["暮色森林的箱子"] = "duskwood chest",
    ["加里维克斯的保险箱"] = "gallywix's lockbox",
    ["隐蔽的保险箱"] = "hidden strongbox",
    ["部落储物箱"] = "horde chest",
    ["保险箱"] = "intrepid's locked strongbox",
    ["破碎的大箱子"] = "large battered chest",
    ["大型铁箍储物箱"] = "large iron bound chest",
    ["大型秘银储物箱"] = "large mithril bound chest",
    ["坚固的大箱子"] = "large solid chest",
    ["锁住的箱子"] = "locked chest",
    ["玛雷姆的箱子"] = "malem chest",
    ["哈加德的箱子"] = "marshal haggard's chest",
    ["迷雾之纱号的保险箱"] = "mist veil's lockbox",
    ["派瑞恩的箱子"] = "perrine's chest",
    ["银色清晨号的保险箱"] = "silver dawning's lockbox",
    ["坚固的箱子"] = "solid chest",
    ["被偷走的铁箱"] = "stolen iron chest",
    ["储物箱"] = "storage chest",
    ["奇怪的保险箱"] = "strange lockbox",
    ["沉没的箱子"] = "sunken chest",
    ["浸水的提箱"] = "waterlogged footlocker",
}
