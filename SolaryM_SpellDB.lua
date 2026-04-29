-- SolaryM_SpellDB.lua — Base de données des sorts

SM.SpellDB = {

    -- ════════════════════════════════════════════════════
    -- [RAID] The Voidspire
    -- ════════════════════════════════════════════════════
    {
        zone = "The Voidspire",
        type = "raid",
        bosses = {
            {
                encounterID = 3176,
                boss = "Imperator Averzian",
                spells = {
                    { id=1251361, en="ADDS SPAWN",           type="mechanic" },
                    { id=1262036, en="BEAMS DODGE",         type="mechanic" },
                    { id=1249262, en="SOAK TANK",           type="mechanic",
                        times  ={25.5,33,97.5,105,176.5,184,248.5,256,325.5,333},
                        times_m={37.5,45,117.5,125,223.5,231,303.5,311,407.5,415} },
                    { id=1280015, en="DISPEL IN BUBBLE",   type="mechanic" },
                    { id=1260712, en="DODGE",             type="mechanic" },
                    { id=1258883, en="KNOCKBACK",           type="mechanic" },
                    { id=1249251, en="RAID DAMAGE",         type="mechanic" },
                },
            },
            {
                encounterID = 3177,
                boss = "Vorasius",
                spells = {
                    { id=1256855, en="GO LEFT OR RIGHT", type="mechanic",
                        times={102, 223, 343} },
                    { id=1254199, en="SPAWN ADD DEFENSIVES",    type="mechanic" },
                    { id=1241692, en="TANK SOAK",           type="mechanic" },
                    { id=1260052, en="GRIP + KNOCK", type="mechanic",
                        times={12, 132, 252} },
                    { id=1259186, en="SPREAD OUT",              type="mechanic" },
                },
            },
            {
                encounterID = 3178,
                boss = "Vaelgor & Ezzorak",
                spells = {
                    { id=1262623, en="TANK FRONTAL VAELGOR",type="mechanic" },
                    { id=1244221, en="FEAR BREATH OUT",    type="mechanic",
                        times_m={5.3,70.3,133.8,145.9,191,248,316.6,360.7,420.7} },
                    { id=1265131, en="VAELGOR TANK BUSTER", type="mechanic" },
                    { id=1245391, en="ORB SOAK",           type="mechanic",
                        times_m={14.2,114.2,213,314.6,409.7} },
                    { id=1244917, en="ORBS SPAWN SPREAD",    type="mechanic",
                        times_m={37.7,77.7,170.5,205.5,245.5,285.5,307.1,373.2,418.2,450.2} },
                    { id=1245645, en="EZZORAK TANK BUSTER", type="mechanic" },
                    { id=1249748, en="RAID DAMAGE",         type="mechanic" },
                },
            },
            {
                encounterID = 3179,
                boss = "Fallen-King Salhadaar",
                spells = {
                    { id=1247738, en="KILL ORBS",           type="mechanic",
                        times  ={14.1,59.1,135,180.7,256.5,301.6},
                        times_m={18.1,63.1,141,186.7,262.5,307.6} },
                    { id=1246175, en="BEAMS ROTATE",       type="mechanic",
                        times={102.6, 224.2, 346} },
                    { id=1250803, en="SPIKES DONT HIT MELEE",    type="mechanic" },
                    { id=1254081, en="ADDS CUT + STUN",     type="mechanic",
                        times  ={20,65,141,187,263,308},
                        times_m={27.6,73,150.8,196.9,272.4,317.5} },
                    { id=1248697, en="POOLS OUT",         type="mechanic" },
                    { id=1250686, en="RAID DAMAGE",         type="mechanic" },
                },
            },
            {
                encounterID = 3180,
                boss = "Lightblinded Vanguard",
                spells = {
                    { id=1248449, en="VENEL AURA OUT",      type="mechanic" },
                    { id=1248983, en="SOAK X4",             type="mechanic" },
                    { id=1246749, en="RAID AOE DAMAGE",          type="mechanic" },
                    { id=1246736, en="JUDGMENT SWAP",       type="mechanic" },
                    { id=1246162, en="BELLAMY AURA OUT",    type="mechanic" },
                    { id=1248644, en="DODGE SHIELDS",    type="mechanic" },
                    { id=1251857, en="BELLAMY JUDGMENT SWAP",        type="mechanic" },
                    { id=1248451, en="SENN AURA OUT",       type="mechanic" },
                    { id=1248710, en="ABSORB HEAL",        type="mechanic",
                        times  ={147.3, 324.4},
                        times_m={54.4,162.6,212.5,322,372,481.5} },
                    { id=1255738, en="RAID DAMAGE",         type="mechanic",
                        times_m={22,40,58,76,112,130,166,184,202,220,274,292,310,328,346,364,382} },
                    { id=1248674, en="DODGE + SHIELD SENN",type="mechanic" },
                },
            },
            {
                encounterID = 3181,
                boss = "Crown of the Cosmos",
                spells = {
                    { id=1233602, en="ARROWS HIT ADDS",    type="mechanic", times_m={20, 37.5, 56.8, 75.8, 93.5, 119.6} },
                    { id=1233819, en="EXPLOSION IN",       type="mechanic", times_m={27, 67, 99.5, 126.6} },
                    { id=1232467, en="SHOTGUN RUN TO BOSS",   type="mechanic" },
                    { id=1255368, en="STACK AOE",           type="mechanic" },
                    { id=1233865, en="HEAL ABSORB DEBUFF", type="mechanic" },
                    { id=1237614, en="ARROW HIT ADDS", type="mechanic" },
                    { id=1237837, en="ADDS SPAWN GRIP",     type="mechanic" },
                    { id=1246918, en="RIFT SHIELD DPS",     type="mechanic" },
                    { id=1239080, en="TETHERS BREAK",      type="mechanic" },
                    { id=1238843, en="NEXT PLATFORM",type="mechanic" },
                    { id=1234569, en="DODGE BEAMS",      type="mechanic" },
                },
            },
        },
    },

    -- ════════════════════════════════════════════════════
    -- [RAID] March on Quel'Danas
    -- ════════════════════════════════════════════════════
    {
        zone = "March on Quel'Danas",
        type = "raid",
        bosses = {
            {
                encounterID = 3182,
                boss = "Belo'ren, Child of Al'ar",
                spells = {
                    { id=1242515, en="SWITCH COLOR IN",    type="mechanic" },
                    { id=1241282, en="SOAKS IN",           type="mechanic", times_m={18.8, 68.8} },
                    { id=1242981, en="ORBS WATCH",         type="mechanic" },
                    { id=1242260, en="QUILLS SOAK",        type="mechanic", times_m={27.4, 37.4, 47.4, 77.4, 87.4, 97.4} },
                    { id=1260763, en="TANK COMBO",         type="mechanic" },
                    { id=1244344, en="HEAL ABSORB",        type="mechanic" },
                    { id=1246709, en="OUT OF MIDDLE",      type="mechanic" },
                },
            },
            {
                encounterID = 3183,
                boss = "Midnight Falls",
                spells = {
                    { id=1253915, en="DODGE GLAIVES IN",  type="mechanic", times={38, 108, 178},  times_m={29, 91, 153} },
                    { id=1249620, en="MEMORY GAME IN",    type="mechanic", times={10, 80, 150},  times_m={33, 95, 157} },
                    { id=1249609, en="GET YOUR SPOT",       type="mechanic" },
                    { id=1251386, en="PRISM DPS",          type="mechanic" },
                    { id=1276525, en="USE CRYSTAL",         type="mechanic" },
                },
            },
        },
    },

    -- ════════════════════════════════════════════════════
    -- [RAID] The Dreamrift
    -- ════════════════════════════════════════════════════
    {
        zone = "The Dreamrift",
        type = "raid",
        bosses = {
            {
                encounterID = 3306,
                boss = "Chimaerus the Undreamt God",
                spells = {
                    { id=1262289, en="SOAK",                type="mechanic", cast="begincast" },
                    { id=1272726, en="DODGE FRONTAL",    type="mechanic", cast="begincast" },
                    { id=1258610, en="ADDS SPAWN",          type="mechanic" },
                    { id=1257087, en="DISPEL",              type="heal" },
                    { id=1257085, en="DISPEL",              type="heal" },
                    { id=1246653, en="RAID DAMAGE",         type="heal" },
                    { id=1245396, en="AOE INCOMING",       type="mechanic", cast="begincast" },
                    { id=1245486, en="DODGE BREATH",    type="mechanic" },
                    { id=1245406, en="TARGET INCOMING",     type="mechanic" },
                    { id=1264756, en="MADNESS",             type="mechanic" },
                },
            },
        },
    },

    -- ════════════════════════════════════════════════════
    -- [DUNGEON] Pit of Saron (WotLK)
    -- ════════════════════════════════════════════════════
    {
        zone = "Pit of Saron",
        type = "dungeon",
        bosses = {
            {
                encounterID = 1999,
                boss = "Forgemaster Garfrost",
                spells = {
                    { id=1261546, en="TANK BUSTER",         type="tank",     first=20.0, cd=41.5, cast="begincast" },
                    { id=1261847, en="AOE INCOMING",       type="mechanic", first=41.6, cd=41.5, cast="begincast" },
                    { id=1261299, en="DODGE",            type="mechanic", first=7.0,  cd=41.5, cast="begincast" },
                    { id=1262029, en="FIX CAMERA",          type="heal",     first=33.0, cd=41.5, cast="begincast" },
                },
            },
            {
                encounterID = 2001,
                boss = "Ick & Krick",
                spells = {
                    { id=1264363, en="TARGET INCOMING",     type="heal",     first=50.0, cd=82.8,           cast="begincast" },
                    { id=1264027, en="AOE INCOMING",       type="mechanic", first=0.0,  cd=82.8,           cast="begincast" },
                    { id=1264336, en="AOE INCOMING",       type="mechanic", first=21.0, cd={19.0, 63.8},   cast="begincast" },
                    { id=1264287, en="TANK BUSTER",         type="tank",     first=11.0, cd={19.0, 63.8},   cast="begincast" },
                    { id=1264453, en="TARGET INCOMING",     type="mechanic", first=54.8, cd={7.0,7.0,61.8}, cast="begincast" },
                },
            },
            {
                encounterID = 2000,
                boss = "Scourgelord Tyrannus",
                spells = {
                    { id=1262582, en="TANK KNOCKBACK",      type="tank",     first=14.0, cd={28.0, 57.1},   cast="begincast" },
                    { id=1263406, en="SWITCH ADDS",          type="heal",     first=52.0, cd=85.0,           cast="begincast" },
                    { id=1262745, en="FIND BEACON",      type="mechanic", first=7.0,  cd={28.0, 57.0},   cast="begincast" },
                    { id=1276648, en="AOE INCOMING",       type="mechanic", first=0.0,  cd=85.0,           cast="begincast" },
                    { id=1263756, en="DODGE",            type="tank",     first=24.0, cd=85.0,           cast="cast" },
                    { id=1276948, en="DODGE",            type="mechanic", first=69.0, cd=85.0,           cast="cast" },
                },
            },
        },
    },

    -- ════════════════════════════════════════════════════
    -- [DUNGEON] Skyreach (Draenor)
    -- ════════════════════════════════════════════════════
    {
        zone = "Skyreach",
        type = "dungeon",
        bosses = {
            {
                encounterID = 1698,
                boss = "Ranjit",
                spells = {
                    { id=1252690, en="KNOCKBACK",           type="mechanic", first=5.0,  cd=40.0,           cast="begincast" },
                    { id=153757,  en="AOE INCOMING",       type="mechanic", first=12.0, cd=20.0,           cast="begincast" },
                    { id=1258152, en="DODGE CHAKRAM",    type="mechanic", first=18.0, cd={10.0, 30.0},   cast="begincast" },
                    { id=156793,  en="DODGE",            type="heal",     first=35.0, cd=40.0,           cast="begincast" },
                },
            },
            {
                encounterID = 1699,
                boss = "Araknath",
                spells = {
                    { id=154113,  en="TANK BUSTER",         type="mechanic", first=5.0,  cd=15.0,           cast="begincast" },
                    { id=154162,  en="BLOCK LINE",       type="mechanic" },
                    { id=154135,  en="AOE INCOMING",       type="heal",     first=50.0, cd=54.0,           cast="begincast" },
                },
            },
            {
                encounterID = 1700,
                boss = "Rukhran",
                spells = {
                    { id=1253510, en="SWITCH ADDS",          type="mechanic", first=12.0, cd={21.0, 26.0},   cast="begincast" },
                    { id=1253519, en="TANK BUSTER",         type="mechanic", first=5.0,  cd={12.0, 35.0},   cast="begincast" },
                    { id=159382,  en="FIX CAMERA",          type="heal",     first=39.3, cd={46.7, 47.7},   cast="begincast" },
                },
            },
            {
                encounterID = 1701,
                boss = "High Sage Viryx",
                spells = {
                    { id=1253538, en="TARGET INCOMING",     type="mechanic", first=5.0,  cd={10.0,10.0,19.0},cast="cast" },
                    { id=153954,  en="SWITCH ADDS",          type="mechanic", first=12.0, cd=39.0,           cast="cast" },
                    { id=154396,  en="INTERRUPT NOW",           type="mechanic", first=8.0,  cd={12.0, 27.0},   cast="begincast" },
                    { id=1253840, en="PULL CHAIN",              type="heal",     first=30.0, cd=39.0,           cast="begincast" },
                },
            },
        },
    },

    -- ════════════════════════════════════════════════════
    -- [DUNGEON] Seat of the Triumvirate (Legion)
    -- ════════════════════════════════════════════════════
    {
        zone = "Seat of the Triumvirate",
        type = "dungeon",
        bosses = {
            {
                encounterID = 2065,
                boss = "Zuraal",
                spells = {
                    { id=1268916, en="DODGE FRONTAL",    type="mechanic", first=16.3, cd=57.1,           cast="begincast" },
                    { id=1263282, en="TARGET INCOMING",     type="mechanic", first=7.8,  cd=29.1,           cast="begincast" },
                    { id=1263399, en="ADDS SPAWN",          type="mechanic", first=22.4, cd=57.1,           cast="begincast" },
                    { id=1263440, en="TANK BUSTER",         type="mechanic", first=4.1,  cd=40.0,           cast="cast" },
                    { id=1263297, en="AOE INCOMING",       type="heal",     first=50.3, cd=57.1,           cast="begincast" },
                },
            },
            {
                encounterID = 2066,
                boss = "Saprish",
                spells = {
                    { id=1263509, en="CLEAR TRAP",       type="mechanic", first=20.0, cd=38.0,           cast="begincast" },
                    { id=248831,  en="INTERRUPT NOW",           type="mechanic", first=5.2,  cd=15.8,           cast="begincast" },
                    { id=245738,  en="TARGET INCOMING",     type="mechanic", first=8.6,  cd=12.1,           cast="cast" },
                    { id=1263523, en="AOE INCOMING",       type="heal",     first=32.0, cd=38.0,           cast="begincast" },
                },
            },
            {
                encounterID = 2067,
                boss = "Viceroy Nezhar",
                spells = {
                    { id=244750,  en="INTERRUPT",         type="mechanic", first=4.0,  cd=12.0,           cast="begincast" },
                    { id=1263542, en="AOE INCOMING",       type="mechanic", first=12.0, cd=65.0,           cast="begincast" },
                    { id=1263538, en="SWITCH ADDS",          type="mechanic", first=26.0, cd=65.0,           cast="begincast" },
                    { id=1263528, en="KNOCKBACK",           type="heal",     first=45.0, cd=65.0,           cast="begincast" },
                },
            },
            {
                encounterID = 2068,
                boss = "L'ura",
                spells = {
                    { id=1265421, en="AOE INCOMING",       type="mechanic", first=1.5,  cd=97.1,           cast="begincast" },
                    { id=1265463, en="TARGET INCOMING",     type="mechanic", first=24.0, cd=33.0,           cast="begincast" },
                    { id=1264196, en="DODGE",            type="mechanic", first=12.0, cd=33.0,           cast="begincast" },
                    { id=1265689, en="DODGE",            type="mechanic", first=35.0, cd=33.0,           cast="begincast" },
                    { id=1266003, en="PHASE CHANGE",    type="heal",     first=65.5, cd=33.0,           cast="begincast" },
                    { id=1266001, en="KNOCKBACK",           type="heal",     first=96.0, cd=33.4,           cast="cast" },
                },
            },
        },
    },

    -- ════════════════════════════════════════════════════
    -- [DUNGEON] Algeth'ar Academy (Dragonflight)
    -- ════════════════════════════════════════════════════
    {
        zone = "Algeth'ar Academy",
        type = "dungeon",
        bosses = {
            {
                encounterID = 2562,
                boss = "Vexamus",
                spells = {
                    { id=387691, en="BLOCK BALL",        type="mechanic", first=2.0,  cd={18.0, 26.0},   cast="cast" },
                    { id=386173, en="TARGET INCOMING",     type="mechanic", first=15.0, cd={18.0, 26.0},   cast="begincast" },
                    { id=385958, en="TANK BUSTER",         type="mechanic", first=5.0,  cd={18.0, 26.0},   cast="begincast" },
                    { id=388537, en="AOE INCOMING",       type="heal",     first=40.0, cd=44.0,           cast="begincast" },
                },
            },
            {
                encounterID = 2563,
                boss = "Overgrown Ancient",
                spells = {
                    { id=388544, en="TANK BUSTER",         type="mechanic", first=9.0,  cd=28.0,           cast="begincast" },
                    { id=388623, en="ADDS SPAWN",          type="mechanic", first=30.0, cd=56.0,           cast="begincast" },
                    { id=388796, en="STACK UP",               type="mechanic", first=18.0, cd={33.0, 23.0},   cast="cast" },
                    { id=388923, en="AOE INCOMING",       type="heal",     first=55.1, cd=56.0,           cast="begincast" },
                },
            },
            {
                encounterID = 2564,
                boss = "Crawth",
                spells = {
                    { id=376997, en="TANK BUSTER",         type="mechanic", first=5.0,  cd=24.0,           cast="begincast" },
                    { id=377004, en="AOE INCOMING",       type="mechanic", first=14.0, cd=24.0,           cast="begincast" },
                    { id=377034, en="DODGE FRONTAL",    type="mechanic", first=20.0, cd=24.0,           cast="begincast" },
                    { id=377182, en="CARRY BALL",         type="heal" },
                },
            },
            {
                encounterID = 2565,
                boss = "Echo of Doragosa",
                spells = {
                    { id=374343, en="DISPEL",              type="mechanic", first=14.0, cd=33.0,           cast="begincast" },
                    { id=388822, en="GRIP TARGET",          type="heal",     first=30.0, cd=33.0,           cast="begincast" },
                    { id=374361, en="TANK BUSTER",         type="tank",     first=9.0,  cd=12.0,           cast="begincast" },
                },
            },
        },
    },

    -- ════════════════════════════════════════════════════
    -- [DUNGEON] Nexus-Point Xenas (Midnight)
    -- ════════════════════════════════════════════════════
    {
        zone = "Nexus-Point Xenas",
        type = "dungeon",
        bosses = {
            {
                encounterID = 3328,
                boss = "Chief Corewright Kasreth",
                spells = {
                    { id=1257509, en="AOE INCOMING",       type="heal",     first=46.6, cd=52.1,           cast="begincast" },
                    { id=1251772, en="BREAK LINE",        type="heal",     first=5.7,  cd=12.1,           cast="begincast" },
                    { id=1251183, en="BREAK LINK",         type="heal" },
                    { id=1264048, en="DODGE",            type="tank",     first=10.5, cd=13.3,           cast="cast" },
                },
            },
            {
                encounterID = 3332,
                boss = "Corewarden Nysarra",
                spells = {
                    { id=1249027, en="TARGET INCOMING",     type="heal",     first=10.7, cd=19.0,           cast="begincast" },
                    { id=1264429, en="PHASE CHANGE",    type="heal",     first=36.8, cd=62.1,           cast="cast" },
                    { id=1247937, en="TANK BUSTER",         type="tank",     first=3.8,  cd=17.8,           cast="begincast" },
                    { id=1252703, en="SWITCH ADDS",          type="mechanic" },
                    { id=1264439, en="DODGE",            type="mechanic" },
                },
            },
            {
                encounterID = 3333,
                boss = "Lothraxion",
                spells = {
                    { id=1253855, en="TARGET INCOMING",     type="heal",     first=11.1, cd=25.1,           cast="begincast" },
                    { id=1257601, en="PHASE CHANGE",    type="heal",     first=60.5, cd=64.3,           cast="begincast" },
                    { id=1253950, en="TANK BUSTER",         type="tank",     first=2.2,  cd=26.9,           cast="begincast" },
                    { id=1269222, en="DODGE",            type="tank",     first=29.3, cd=10.7,           cast="cast" },
                    { id=1255531, en="PHASE CHANGE",    type="heal" },
                },
            },
        },
    },

    -- ════════════════════════════════════════════════════
    -- [DUNGEON] Windrunner Spire (Midnight)
    -- ════════════════════════════════════════════════════
    {
        zone = "Windrunner Spire",
        type = "dungeon",
        bosses = {
            {
                encounterID = 3056,
                boss = "Emberdawn",
                spells = {
                    { id=466064,  en="TANK BUSTER",         type="tank",     first=10.9, cd=40.1,           cast="begincast" },
                    { id=466556,  en="TARGET INCOMING",     type="mechanic", first=6.1,  cd=40.1,           cast="begincast" },
                    { id=467040,  en="AOE INCOMING",       type="heal",     first=16.2, cd=54.3,           cast="begincast" },
                },
            },
            {
                encounterID = 3057,
                boss = "Derelict Duo",
                spells = {
                    { id=472888,  en="TANK BUSTER",         type="tank",     first=17.4, cd=58.0,           cast="begincast" },
                    { id=474105,  en="DISPEL",              type="mechanic", first=22.7, cd=58.0,           cast="begincast" },
                    { id=472736,  en="AOE INCOMING",       type="mechanic" },
                    { id=472745,  en="DROP WATER",           type="mechanic", first=8.0,  cd=27.3,           cast="begincast" },
                    { id=472795,  en="HOOK TARGET",          type="heal",     first=48.0, cd=58.1,           cast="begincast" },
                },
            },
            {
                encounterID = 3058,
                boss = "Commander Kroluk",
                spells = {
                    { id=467620,  en="TANK BUSTER",         type="tank",     first=3.2,  cd=52.2,           cast="begincast" },
                    { id=1253026, en="STACK UP",               type="heal",     first=18.2, cd=82.3,           cast="begincast" },
                    { id=472053,  en="TARGET INCOMING",     type="mechanic", first=10.5, cd=3.4,            cast="begincast" },
                    { id=472043,  en="PHASE CHANGE",    type="heal",     first=51.9, cd=10.8,           cast="begincast" },
                    { id=1271676, en="AWAY FROM BOSS",        type="mechanic", first=56.7, cd=9.0,            cast="begincast" },
                },
            },
            {
                encounterID = 3059,
                boss = "Restless Heart",
                spells = {
                    { id=468429,  en="STEP TRAP",               type="heal",     first=25.5, cd=65.0,           cast="begincast" },
                    { id=474528,  en="TARGET INCOMING",     type="mechanic", first=75.1, cd=65.0,           cast="begincast" },
                    { id=472556,  en="DODGE",            type="mechanic" },
                    { id=472662,  en="TANK BUSTER",         type="tank",     first=57.0, cd=65.0,           cast="begincast" },
                    { id=1253986, en="CLEAR WATER",         type="mechanic", first=60.0, cd=65.0,           cast="cast" },
                },
            },
        },
    },

    -- ════════════════════════════════════════════════════
    -- [DUNGEON] Magister's Terrace (Midnight)
    -- ════════════════════════════════════════════════════
    {
        zone = "Magister's Terrace",
        type = "dungeon",
        bosses = {
            {
                encounterID = 3071,
                boss = "Arcanotron Custos",
                spells = {
                    { id=474345,  en="PHASE CHANGE",    type="heal",     first=45.1, cd=69.2,           cast="begincast" },
                    { id=474496,  en="TANK BUSTER",         type="tank",     first=5.0,  cd=23.1,           cast="begincast" },
                    { id=1214032, en="DISPEL",              type="tank",     first=22.0, cd=69.2,           cast="cast" },
                    { id=1214081, en="AOE INCOMING",       type="mechanic", first=16.0, cd=23.1,           cast="begincast" },
                },
            },
            {
                encounterID = 3072,
                boss = "Seranel Sunlash",
                spells = {
                    { id=1224903, en="DODGE",            type="mechanic", first=17.0, cd=57.1,           cast="begincast" },
                    { id=1248689, en="TANK BUSTER",         type="tank",     first=26.7, cd=55.9,           cast="cast" },
                    { id=1225792, en="CLEAR STACK",       type="mechanic", first=7.3,  cd=29.2,           cast="begincast" },
                    { id=1225193, en="ENTER CIRCLE",       type="heal",     first=51.0, cd=57.1,           cast="begincast" },
                },
            },
            {
                encounterID = 3073,
                boss = "Gemellus",
                spells = {
                    { id=1253709, en="HIT CLONE",       type="mechanic", first=24.6, cd=41.3,           cast="begincast" },
                    { id=1224299, en="GRIP TARGET",          type="heal",     first=36.7, cd=41.3,           cast="begincast" },
                    { id=1284954, en="TARGET INCOMING",     type="tank",     first=13.6, cd=40.9,           cast="begincast" },
                    { id=1223847, en="ADDS SPAWN",          type="mechanic" },
                },
            },
            {
                encounterID = 3074,
                boss = "Degentrius",
                spells = {
                    { id=1215893, en="TARGET INCOMING",     type="tank",     first=8.0,  cd=23.1,           cast="cast" },
                    { id=1215087, en="ENTER CIRCLE",       type="heal",     first=15.9, cd=23.1,           cast="begincast" },
                    { id=1280113, en="TANK BUSTER",         type="tank",     first=3.8,  cd=23.1,           cast="begincast" },
                    { id=1215897, en="AOE INCOMING",       type="mechanic" },
                },
            },
        },
    },

    -- ════════════════════════════════════════════════════
    -- [DUNGEON] Maisara Caverns (Midnight)
    -- ════════════════════════════════════════════════════
    {
        zone = "Maisara Caverns",
        type = "dungeon",
        bosses = {
            {
                encounterID = 3212,
                boss = "Muro'jin and Nekraxx",
                spells = {
                    { id=1266480, en="TANK BUSTER",         type="tank",     first=5.9,  cd=44.4,           cast="begincast" },
                    { id=1243900, en="DODGE",            type="tank",     first=28.0, cd=45.0,           cast="begincast" },
                    { id=1260731, en="DODGE",            type="mechanic", first=20.0, cd=45.0,           cast="begincast" },
                    { id=1260643, en="FRONTAL ON YOU",     type="mechanic", first=35.0, cd=45.0,           cast="cast" },
                    { id=1246666, en="DISPEL",              type="tank",     first=12.0, cd=45.0,           cast="begincast" },
                    { id=1249479, en="STEP TRAP",               type="heal",     first=41.0, cd=45.0,           cast="begincast" },
                },
            },
            {
                encounterID = 3213,
                boss = "Vordaza",
                spells = {
                    { id=1251554, en="TANK BUSTER",         type="tank",     first=3.0,  cd=33.5,           cast="begincast" },
                    { id=1252054, en="DODGE FRONTAL",    type="tank",     first=25.4, cd=33.5,           cast="begincast" },
                    { id=1251204, en="KITE ADDS",          type="heal",     first=14.2, cd=33.5,           cast="cast" },
                    { id=1250708, en="PHASE CHANGE",    type="heal" },
                    { id=1252676, en="SPREAD OUT",              type="mechanic", first=19.2, cd=33.7,           cast="cast" },
                },
            },
            {
                encounterID = 3214,
                boss = "Rak'tul, Vessel of Souls",
                spells = {
                    { id=1251023, en="TANK BUSTER",         type="tank",     first=4.0,  cd=26.4,           cast="cast" },
                    { id=1252676, en="SPREAD OUT",              type="mechanic", first=17.2, cd=26.4,           cast="begincast" },
                    { id=1253788, en="PHASE CHANGE",    type="heal",     first=70.1, cd=120.1,          cast="begincast" },
                },
            },
        },
    },

}

-- ============================================================
-- INDEX PLAT
-- ============================================================
SM.SpellIndex  = {}
SM.DefaultSpells = {}

for _, zone in ipairs(SM.SpellDB) do
    for _, boss in ipairs(zone.bosses) do
        for _, sp in ipairs(boss.spells) do
            local entry = {
                id       = sp.id,
                en       = sp.en,
                fr       = sp.fr,
                type     = sp.type or "mechanic",
                first    = sp.first,
                cd       = sp.cd,
                cast     = sp.cast or "begincast",
                times    = sp.times,
                times_m  = sp.times_m,
                boss     = boss.boss,
                encID    = boss.encounterID,
                zone     = zone.zone,
                zoneType = zone.type,
            }
            SM.SpellIndex[sp.id] = entry
            table.insert(SM.DefaultSpells, entry)
        end
    end
end

SM.Print("SpellDB : " .. #SM.DefaultSpells .. " sorts chargés")

function SM.SeedSpells()
    local seeded = 0
    for _, entry in ipairs(SM.DefaultSpells) do
        if SolaryMDB.spells[entry.id] == nil then
            SolaryMDB.spells[entry.id] = (SM.LANG == "fr") and entry.fr or entry.en
            seeded = seeded + 1
        end
    end
end

function SM.GetSpellEntry(id)
    return SM.SpellIndex[id]
end

-- Injecte un sort personnalisé dans la SpellDB live (survit au /reload via LoadCustomSpells)
function SM.InjectCustomSpell(cs)
    local id = tonumber(cs.id)
    if not id then return end
    local zoneName = cs.zone or "Personnalisé"
    local bossName = cs.boss or "Personnalisé"

    local zoneEntry = nil
    for _, z in ipairs(SM.SpellDB) do
        if z.zone == zoneName then zoneEntry = z; break end
    end
    if not zoneEntry then
        zoneEntry = { zone = zoneName, type = "custom", _custom = true, bosses = {} }
        table.insert(SM.SpellDB, zoneEntry)
    end

    local bossEntry = nil
    for _, b in ipairs(zoneEntry.bosses) do
        if b.boss == bossName then bossEntry = b; break end
    end
    if not bossEntry then
        bossEntry = { boss = bossName, spells = {} }
        table.insert(zoneEntry.bosses, bossEntry)
    end

    for i = #bossEntry.spells, 1, -1 do
        if bossEntry.spells[i].id == id then table.remove(bossEntry.spells, i) end
    end
    local callout = cs.callout or ""
    table.insert(bossEntry.spells, { id = id, en = callout, fr = callout, type = "mechanic" })

    SM.SpellIndex[id] = {
        id = id, en = callout, fr = callout, type = "mechanic",
        boss = bossName, zone = zoneName, zoneType = "custom", _custom = true,
    }
end

function SM.LoadCustomSpells()
    if not SolaryMDB or not SolaryMDB.customSpells then return end
    for _, cs in ipairs(SolaryMDB.customSpells) do
        SM.InjectCustomSpell(cs)
    end
end

function SM.RemoveCustomSpell(id)
    SM.SpellIndex[id] = nil
    for _, zone in ipairs(SM.SpellDB) do
        for _, boss in ipairs(zone.bosses) do
            for i = #boss.spells, 1, -1 do
                if boss.spells[i].id == id then table.remove(boss.spells, i) end
            end
        end
    end
    for zi = #SM.SpellDB, 1, -1 do
        local zone = SM.SpellDB[zi]
        if zone._custom then
            for bi = #zone.bosses, 1, -1 do
                if #zone.bosses[bi].spells == 0 then table.remove(zone.bosses, bi) end
            end
            if #zone.bosses == 0 then table.remove(SM.SpellDB, zi) end
        end
    end
end

function SM.GetSpellByCallout(callout)
    if not callout then return nil end
    local low = callout:lower()
    for _, entry in ipairs(SM.DefaultSpells) do
        if (entry.en and entry.en:lower() == low) or (entry.fr and entry.fr:lower() == low) then
            return entry
        end
    end
    return nil
end

SM.NameToSpellId = {}
for _, entry in ipairs(SM.DefaultSpells) do
    if entry.en and entry.en ~= "" then
        SM.NameToSpellId[entry.en:lower()] = entry.id
    end
    if entry.fr and entry.fr ~= "" then
        SM.NameToSpellId[entry.fr:lower()] = entry.id
    end
end

function SM.GetBossSpells(encounterID)
    local out = {}
    for _, entry in ipairs(SM.DefaultSpells) do
        if entry.encID == encounterID then
            table.insert(out, entry)
        end
    end
    return out
end
