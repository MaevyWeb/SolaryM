-- SolaryM.lua

local FLASH_THRESHOLD = 5    -- Flash quand il reste X secondes sur la barre
local FLASH_STAY      = 4    -- Durée d'affichage du flash

local currentBoss  = nil
local bwHandle     = {}
local activeTimers = {}

-- ============================================================
-- FLASH D'ALERTE à -8s
-- ============================================================
local flashFrame, flashTitle, flashSub, flashTimer

local function CreateFlash()
    if flashFrame then return end

    flashFrame = CreateFrame("Frame", "SolaryMFlash", UIParent)
    flashFrame:SetSize(320, 56)
    flashFrame:SetPoint("TOP", UIParent, "TOP", 0, -160)
    flashFrame:SetFrameStrata("HIGH")
    flashFrame:SetMovable(true); flashFrame:EnableMouse(true)
    flashFrame:RegisterForDrag("LeftButton")
    flashFrame:SetScript("OnDragStart", flashFrame.StartMoving)
    flashFrame:SetScript("OnDragStop",  flashFrame.StopMovingOrSizing)
    flashFrame:Hide()

    local bg = flashFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0.04, 0.04, 0.06, 0.95)

    local accent = flashFrame:CreateTexture(nil, "ARTWORK")
    accent:SetSize(5, 56); accent:SetPoint("LEFT")
    accent:SetColorTexture(1, 0.3, 0.1, 1)

    local icon = flashFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    icon:SetPoint("LEFT", flashFrame, "LEFT", 12, 0)
    icon:SetTextColor(1, 0.3, 0.1, 1); icon:SetText("!")

    flashTitle = flashFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    flashTitle:SetPoint("TOPLEFT", flashFrame, "TOPLEFT", 38, -8)
    flashTitle:SetPoint("RIGHT", flashFrame, "RIGHT", -8, 0)
    flashTitle:SetJustifyH("LEFT"); flashTitle:SetTextColor(1, 0.9, 0.2, 1)

    flashSub = flashFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    flashSub:SetPoint("BOTTOMLEFT", flashFrame, "BOTTOMLEFT", 38, 8)
    flashSub:SetPoint("RIGHT", flashFrame, "RIGHT", -8, 0)
    flashSub:SetJustifyH("LEFT"); flashSub:SetTextColor(0.6, 0.6, 0.6, 1)
end

local function ShowFlash(customName, bwName)
    if not flashFrame then return end
    flashTitle:SetText("⚠  " .. customName)
    flashSub:SetText(customName ~= bwName and bwName or "")
    flashFrame:SetAlpha(0); flashFrame:Show()
    UIFrameFadeIn(flashFrame, 0.2, 0, 1)
    if flashTimer and not flashTimer:IsCancelled() then flashTimer:Cancel() end
    flashTimer = C_Timer.NewTimer(FLASH_STAY, function()
        UIFrameFadeOut(flashFrame, 0.4, 1, 0)
        C_Timer.NewTimer(0.4, function() flashFrame:Hide() end)
    end)
end

local function CancelAllTimers()
    for _, t in ipairs(activeTimers) do
        if t and not t:IsCancelled() then t:Cancel() end
    end
    activeTimers = {}
    if flashFrame then flashFrame:Hide() end
    if flashTimer and not flashTimer:IsCancelled() then flashTimer:Cancel() end
end

-- ============================================================
-- HOOK BIGWIGS
-- ============================================================
local injectedBars = {}  -- garde trace des barres qu'on a nous-mêmes injectées

local function OnBWBar(_, module, _, barText, barTime, icon)
    if not currentBoss or not barText or not module then return end

    -- Ignore les barres qu'on a injectées nous-mêmes pour éviter la boucle
    if injectedBars[barText] then
        injectedBars[barText] = nil
        -- Planifie quand même le flash à -8s sur cette barre
        if barTime <= FLASH_THRESHOLD then
            ShowFlash(barText, barText)
        else
            local t = C_Timer.NewTimer(barTime - FLASH_THRESHOLD, function()
                ShowFlash(barText, barText)
            end)
            table.insert(activeTimers, t)
        end
        return
    end

    SolaryMDB.bosses[currentBoss] = SolaryMDB.bosses[currentBoss] or {}

    -- Cherche le nom custom dans la DB (clés au format "NomBW|diff")
    local customName = nil
    local mechTable = SolaryMDB.bosses[currentBoss]
    for key, val in pairs(mechTable) do
        local bwName = key:match("^(.+)|") or key
        if bwName == barText then
            customName = (val ~= "" and val ~= bwName) and val or nil
            break
        end
    end

    -- Si mécanique inconnue, l'enregistre
    if customName == nil then
        local found = false
        for key in pairs(mechTable) do
            local bwName = key:match("^(.+)|") or key
            if bwName == barText then found = true; break end
        end
        if not found then
            mechTable[barText] = barText
            if SolaryM_RefreshPanel then SolaryM_RefreshPanel() end
        end
        customName = barText
    end

    -- Si nom custom différent : stoppe la barre BW et recrée avec le nom custom
    if customName ~= barText then
        injectedBars[customName] = true  -- marque pour ignorer au prochain tour
        BigWigsLoader.SendMessage(bwHandle, "BigWigs_StopBar", module, barText)
        BigWigsLoader.SendMessage(bwHandle, "BigWigs_StartBar", module, nil, customName, barTime, icon)
    end

    -- Flash à -5s
    if barTime <= FLASH_THRESHOLD then
        ShowFlash(customName, barText)
    else
        local t = C_Timer.NewTimer(barTime - FLASH_THRESHOLD, function()
            ShowFlash(customName, barText)
        end)
        table.insert(activeTimers, t)
    end
end

local function OnBWEngage(_, module)
    CancelAllTimers()
    if module and module.displayName then
        currentBoss = module.displayName
        SolaryMDB.bosses[currentBoss] = SolaryMDB.bosses[currentBoss] or {}
        if SolaryM_RefreshPanel then SolaryM_RefreshPanel() end
    end
end

local function OnBWEnd()
    CancelAllTimers()
    currentBoss = nil
end

-- ============================================================
-- DB MIDNIGHT SEASON 1
-- Clé unique = name .. "|" .. diff
-- ============================================================
SolaryM_RaidData = {
    {
        name = "The Voidspire",
        bosses = {
            { name = "Imperator Averzian", mechs = {
                { name="Shadow's Advance",    fr="Avancée des Ombres",      diff="N",   desc="3 Voidshapers → 3 cases. Immunisés à 99% sauf Umbral Collapse. 2 stoppables max par vague." },
                { name="Umbral Collapse",     fr="Effondrement Sombre",      diff="N",   desc="Soak de groupe sur un Voidshaper → retire son immunité. 2 fois par vague." },
                { name="Void Rupture",        fr="Rupture du Vide",          diff="N",   desc="Case revendiquée → explosion 12yd + beams. Esquiver." },
                { name="Void Fall",           fr="Chute du Vide",            diff="N",   desc="Knockback + cercles AoE. Esquiver." },
                { name="Oblivion's Wrath",    fr="Courroux de l'Oubli",      diff="N",   desc="Faisceaux en demi-cercle depuis le boss. Positionner le boss face au raid." },
                { name="Shadow Phalanx",      fr="Phalange des Ombres",      diff="N",   desc="Soldats intargetables traversent l'arène. Létaux si traversés. Trouver la brèche." },
                { name="Dark Upheaval",       fr="Soulèvement Sombre",       diff="N",   desc="Burst raid puis DoT continu. CDs healeurs." },
                { name="Blackening Wounds",   fr="Blessures Noircies",       diff="N",   desc="Stack -4% HP max sur le tank. Adds fixate le tank avec le plus de stacks. Swap aux spawns." },
                { name="Imperator's Glory",   fr="Gloire de l'Impérateur",   diff="N",   desc="Boss dans une case → +75% dégâts et -99% dégâts reçus. Garder le boss loin des cases." },
                { name="Imperator's Glory",   fr="Gloire de l'Impérateur",   diff="HM",  desc="HM : zone élargie à 10yd. Le boss ne peut pas approcher les cases ni les adds." },
                { name="March of the Endless",fr="Marche des Infinis",       diff="N",   desc="WIPE si 3 cases adjacentes revendiquées. Condition de défaite centrale." },
                { name="Gathering Darkness",  fr="Obscurité Croissante",     diff="HM",  desc="HM : Voidshapers non tués se transforment en Endwalkers plus dangereux." },
                { name="Dark Resilience",     fr="Résilience des Ténèbres",  diff="HM",  desc="HM : Voidmaws à 35% HP rejoignent une case pour se soigner à plein. Stun/slow avant." },
                { name="Cosmic Shell",        fr="Coque Cosmique",           diff="MM",  desc="MM : Voidshapers castent Cosmic Shell → immunisés à Umbral Collapse. À contrer." },
            }},
            { name = "Vorasius", mechs = {
                { name="Primordial Roar",     fr="Rugissement Primordial",   diff="N",   desc="Pull tout le raid. Courir à l'opposé. Fin : burst + knockback. Ne pas tomber." },
                { name="Shadowclaw Slam",     fr="Frappe Griffe Sombre",     diff="N",   desc="Cercle au sol → TANK soake sinon WIPE. Les 2 premiers créent Crystal Walls + Smash. Même tank prend les 2 puis swap." },
                { name="Aftershock",          fr="Réplique",                 diff="N",   desc="Anneaux depuis le cercle de Slam. Laisser le 1er exploser puis esquiver les suivants." },
                { name="Blisterburst",        fr="Explosion Vésiculeuse",    diff="N",   desc="Adds fixate → kiter contre un Crystal Wall et tuer là. 1 add suffit pour détruire un mur." },
                { name="Blisterburst",        fr="Explosion Vésiculeuse",    diff="HM",  desc="HM : 2 adds nécessaires par mur. Coordonner 2 joueurs par mur avant Void Breath." },
                { name="Blisterburst",        fr="Explosion Vésiculeuse",    diff="MM",  desc="MM : encore plus d'adds. Pré-assigner des équipes fixes par mur dès le pull." },
                { name="Void Breath",         fr="Souffle du Vide",          diff="N",   desc="Beam balayant l'arène. Commence du côté de la main tenant l'orbe. Murs DOIVENT être détruits sinon WIPE." },
                { name="Overpowering Pulse",  fr="Pulsion Dévastatrice",     diff="N",   desc="WIPE si aucun joueur en mêlée. Le tank reste toujours au corps à corps." },
                { name="Primordial Power",    fr="Pouvoir Primordial",        diff="N",   desc="Soft enrage : stack après chaque Roar, augmente les dégâts raid." },
                { name="Primordial Power",    fr="Pouvoir Primordial",        diff="HM",  desc="HM : stacks montent plus vite. Ne pas traîner." },
            }},
            { name = "Fallen-King Salhadaar", mechs = {
                { name="Void Convergence",    fr="Convergence du Vide",      diff="N",   desc="2 orbes dérivent vers le boss. Si l'un l'atteint → WIPE. Kiter le boss vers un portail." },
                { name="Dark Radiation",      fr="Radiation des Ténèbres",   diff="N",   desc="DoT raid 8s à la mort de chaque orbe. Attendre qu'il disparaisse avant de tuer le 2e." },
                { name="Void Infusion",       fr="Infusion du Vide",         diff="N",   desc="WIPE si orbe touche le boss. Condition de défaite principale." },
                { name="Shattering Twilight", fr="Crépuscule Fracassant",    diff="N",   desc="Tankbuster + spikes. Le tank s'écarte du raid avant l'impact." },
                { name="Shattering Twilight", fr="Crépuscule Fracassant",    diff="HM",  desc="HM : rebondit sur plusieurs joueurs aléatoires. Tout le raid surveille sa position." },
                { name="Instability",         fr="Instabilité",              diff="N",   desc="Stack DoT tank. Swap quand Salhadaar cast — il est immobile, attention aux orbes." },
                { name="Despotic Command",    fr="Commandement Despotique",  diff="N",   desc="DoT sur joueurs → bords + dispel. Après dispel : healing absorb immédiat." },
                { name="Twisting Obscurity",  fr="Obscurité Tordue",         diff="N",   desc="DoT 23s raid-wide simultané avec les healing absorbs. Coordination healeurs." },
                { name="Fractured Projection",fr="Projection Fracturée",     diff="N",   desc="Images castent Shadow Fracture → flaques permanentes. Interrupt/CC toutes." },
                { name="Fractured Projection",fr="Projection Fracturée",     diff="MM",  desc="MM : images protégées par Nexus Shield. Seule celle avec la barre verte est kickable." },
                { name="Entropic Unraveling", fr="Démembrement Entropique",  diff="N",   desc="100 énergie : +25% dégâts subis 20s + beams rotatifs. Boss immobile. BL ici." },
                { name="Enduring Void",       fr="Vide Persistant",          diff="MM",  desc="MM : orbes détruits se réactivent et continuent vers le boss. Double gestion." },
            }},
            { name = "Vaelgor & Ezzorak", mechs = {
                { name="Twilight Bond",       fr="Lien du Crépuscule",       diff="N",   desc="Enrage si dragons à moins de 15yd OU HP diffère de +10%. Équilibrer." },
                { name="Dread Breath",        fr="Souffle Redoutable",        diff="N",   desc="Cône sur joueur aléatoire : dégâts + DoT + fear 15s. S'écarter du raid. Dispel." },
                { name="Void Howl",           fr="Hurlement du Vide",         diff="N",   desc="Spawn Voidorbs. Stack avant spawn. Tuer vite." },
                { name="Nullbeam",            fr="Rayon Nul",                diff="N",   desc="Channel tank → Nullzone tether tout le monde. Tout le monde brise son tether AVANT le tank." },
                { name="Nullzone Implosion",  fr="Implosion de Zone Nulle",   diff="HM",  desc="HM : implosion au snap final du tank. CD healer." },
                { name="Gloom",               fr="Lugubre",                   diff="N",   desc="Orbe en mouvement. 5 joueurs soakent. Violet → bleu = bien soaké." },
                { name="Gloom",               fr="Lugubre",                   diff="HM",  desc="HM : 2 groupes de 5 en rotation (debuff Diminish 1min). Assigner les groupes." },
                { name="Gloom Resonance",     fr="Résonance Lugubre",         diff="MM",  desc="MM : Gloomfields proches amplifient leurs dégâts. Diriger vers des zones isolées." },
                { name="Midnight Flames",     fr="Flammes de Minuit",         diff="N",   desc="Intermission à 100 énergie. Tuer Manifestation of Midnight vite." },
                { name="Shadowmark",          fr="Marque des Ombres",         diff="N",   desc="Intermission : joueur explose après 4s en 8yd. S'éloigner immédiatement." },
                { name="Veilwing",            fr="Aile du Voile",             diff="N",   desc="Tankbuster Vaelgor qui rampe. Swap après chaque Gloom." },
                { name="Rackfang",            fr="Croc-Torture",              diff="N",   desc="Tankbuster Ezzorak + healing absorb + Impale (bleed + stun 3s). Swap après Gloom." },
            }},
            { name = "Lightblinded Vanguard", mechs = {
                { name="Judgment",            fr="Jugement",                  diff="N",   desc="Tankbuster Venel/Bellamy avec vulnérabilité empowered. Swap immédiatement après." },
                { name="Aura of Devotion",    fr="Aura de Dévotion",          diff="N",   desc="Bellamy 100e : -75% dégâts pour alliés 25s. Sortir les 2 autres boss." },
                { name="Divine Toll",         fr="Péage Divin",               diff="N",   desc="Salves de boucliers toutes les 2s : dégâts + silence 4s. CDs." },
                { name="Avenger's Shield",    fr="Bouclier du Vengeur",       diff="N",   desc="Cercles de dégâts. Spread." },
                { name="Aura of Wrath",       fr="Aura de Courroux",          diff="N",   desc="Venel 100e : +100% dégâts sacrés 15s. Sortir les 2 autres boss. Window DPS." },
                { name="Execution Sentence",  fr="Sentence d'Exécution",      diff="N",   desc="4 cercles de soak. Diviser le raid. Ne pas se chevaucher." },
                { name="Execution Sentence",  fr="Sentence d'Exécution",      diff="HM",  desc="HM : cercles ne peuvent pas se chevaucher — debuff si overlap, prochain soak létal." },
                { name="Aura of Peace",       fr="Aura de Paix",              diff="N",   desc="Sen 100e : stop dégâts → sortir les boss → charge → Sacred Shield. Burst avant Blinding Light." },
                { name="Blinding Light",      fr="Lumière Aveuglante",         diff="N",   desc="WIPE si Sacred Shield non brisé. Priorité absolue." },
                { name="Blinding Light",      fr="Lumière Aveuglante",         diff="MM",  desc="MM : 2 autres capacités lancées simultanément. Tous les CDs." },
                { name="Tyr's Wrath",         fr="Courroux de Tyr",           diff="N",   desc="Healing absorb sur les 3 joueurs les plus proches de Sen." },
                { name="Light Infused",       fr="Infusé de Lumière",         diff="N",   desc="DoT saints permanent sur tout le raid." },
                { name="Divine Shield",       fr="Bouclier Divin",            diff="N",   desc="Bellamy et Senn bubble 8s au BL. Mass Dispel immédiat." },
                { name="Retribution Aura",    fr="Aura de Rétribution",       diff="N",   desc="+5% dégâts par boss mort trop tôt. Les 3 boss doivent mourir ensemble." },
            }},
            { name = "Crown of the Cosmos", mechs = {
                { name="Echoing Darkness",    fr="Obscurité en Écho",         diff="N",   desc="Stack si tanks quittent le corps à corps des Sentinels phase 1. WIPE." },
                { name="Silverstrike Arrow",  fr="Flèche Argentée",           diff="N",   desc="Ligne depuis le joueur ciblé. Nettoie les effets Void. Bien viser." },
                { name="Void Expulsion",      fr="Expulsion du Vide",         diff="N",   desc="Déplacement forcé sur 1 joueur." },
                { name="Void Expulsion",      fr="Expulsion du Vide",         diff="HM",  desc="HM : cible plusieurs joueurs simultanément." },
                { name="Grasp of Emptiness",  fr="Emprise du Néant",          diff="N",   desc="Obelisques enracinent + dégâts. Ralentissement 20% à la libération." },
                { name="Grasp of Emptiness",  fr="Emprise du Néant",          diff="HM",  desc="HM : ralentissement 35%." },
                { name="Grasp of Emptiness",  fr="Emprise du Néant",          diff="MM",  desc="MM : ralentissement 60%. Anticipation obligatoire." },
                { name="Null Corona",         fr="Couronne Nulle",            diff="N",   desc="Healing absorb. Si dispel → saute sur un autre joueur. Heal through d'abord." },
                { name="Stellar Emission",    fr="Émission Stellaire",        diff="N",   desc="Dégâts shadow toutes les 2s + amplifie les déplacements de +25%." },
                { name="Stellar Emission",    fr="Émission Stellaire",        diff="MM",  desc="MM : amplification à +35%." },
                { name="Singularity Eruption",fr="Éruption de Singularité",  diff="N",   desc="Poches de gravité → dégâts + knockback 6yd. Esquiver." },
                { name="Orbiting Matter",     fr="Matière Orbitale",          diff="N",   desc="Masse orbitale tire les joueurs vers Alleria. Se déplacer hors de la trajectoire." },
                { name="Crushing Singularity",fr="Singularité Écrasante",     diff="N",   desc="Intermission : Silverstrike Barrage + pulls + éruptions. CDs coordonnés." },
                { name="Gravity Collapse",    fr="Effondrement Gravitationnel",diff="N",  desc="Tankbuster phase 2 qui rampe. Rotation de CDs tanks." },
                { name="Rift Simulacrum",     fr="Simulacre de Faille",       diff="N",   desc="+10% dégâts et réduction à Alleria tant qu'il est vivant. Tuer vite." },
                { name="Voidstalker Sting",   fr="Dard du Traqueur du Vide",  diff="N",   desc="DoT 10s sur plusieurs joueurs." },
                { name="Voidstalker Sting",   fr="Dard du Traqueur du Vide",  diff="HM",  desc="HM : DoT 25s. Pression de soin plus élevée." },
                { name="Empowering Darkness", fr="Obscurité Amplifiante",     diff="HM",  desc="HM : Rift Simulacrum buff Alleria de 5%/s dans les 30yd. Tuer encore plus vite." },
                { name="Green Bar Kicks",     fr="Interruptions Séquentielles",diff="MM", desc="MM : seule la cible avec la barre verte est kickable. Assignments fixes." },
            }},
        },
    },
    {
        name = "The Dreamrift",
        bosses = {
            { name = "Chimaerus the Undreamt God", mechs = {
                { name="Alndust Upheaval",    fr="Soulèvement d'Alndust",    diff="N",   desc="Soak ciblant le tank → soakers envoyés dans le Rift. Raid divisé en 2 groupes." },
                { name="Rift Emergence",      fr="Émergence du Rift",        diff="N",   desc="Dégâts raid pulse nature. Spawne des Manifestation adds dans le Rift. Tuer en priorité." },
                { name="Alnshroud",           fr="Voile d'Aln",              diff="N",   desc="Adds spawent avec bouclier. Quand brisé → add en Reality + flaque. Se faire dispel sur la flaque." },
                { name="Rending Tear",        fr="Déchirure Lacérante",      diff="N",   desc="Tankbuster cône frontal massif + bleed + knockback. Orienter loin du raid." },
                { name="Caustic Phlegm",      fr="Flegme Caustique",         diff="N",   desc="DoT nature raid-wide 12s." },
                { name="Rift Sickness",       fr="Maladie du Rift",          diff="N",   desc="Chaque add qui spawn = healing absorb raid-wide." },
                { name="Fearsome Cry",        fr="Cri Terrifiable",          diff="N",   desc="Cast des Haunting Essence adds : fear + dégâts nature. INTERRUPT prioritaire." },
                { name="Essence Bolt",        fr="Éclair d'Essence",         diff="N",   desc="Cast des Haunting Essence adds : cible aléatoire. Interrupt si possible." },
                { name="Discordant Roar",     fr="Rugissement Discordant",   diff="N",   desc="Colossal Horror adds : dégâts raid au spawn. +10% dégâts par stack. Tuer vite." },
                { name="Colossal Strikes",    fr="Frappes Colossales",       diff="N",   desc="Tankbuster des Colossal Horror adds : 3 hits physiques + nature. CDs tank." },
                { name="Consume",             fr="Dévorer",                  diff="N",   desc="100 énergie : channel 10s puis knockback. Adds Eaten → phase 2. Tuer tous les adds AVANT." },
                { name="Corrupted Devastation",fr="Dévastation Corrompue",   diff="N",   desc="Ligne marquée → Chimaerus plonge dessus, stun + dégâts. Spawne adds + flaques. Esquiver." },
                { name="Consuming Miasma",    fr="Miasme Dévorant",          diff="HM",  desc="HM uniquement : debuff dispellable → explosion 10yd qui détruit les flaques." },
                { name="Ravenous Dive",       fr="Plongeon Vorace",          diff="N",   desc="Dégâts raid + knock-up. Mange les adds restants. Retour phase 1. Tuer tous les adds avant." },
            }},
        },
    },
    {
        name = "March on Quel'Danas",
        bosses = {
            { name = "Belo'ren, Child of Al'ar", mechs = {
                { name="Rebirth Cycle",       fr="Cycle de Renaissance",     diff="N",   desc="Le boss revient à la vie si des adds atteignent son corps mort. Tuer les adds en priorité." },
                { name="Rebirth Cycle",       fr="Cycle de Renaissance",     diff="HM",  desc="HM : adds se déplacent plus vite. Timing serré." },
                { name="Void Irradiation",    fr="Irradiation du Vide",      diff="N",   desc="Cercle grandissant sur un joueur. S'éloigner du raid et attendre l'explosion." },
                { name="Void Irradiation",    fr="Irradiation du Vide",      diff="HM",  desc="HM : plusieurs joueurs marqués simultanément. Spread immédiat." },
                { name="Flame Surge",         fr="Déferlante de Flammes",    diff="N",   desc="Vague de feu frontale. S'écarter du devant du boss." },
                { name="Flame Nova",          fr="Nova de Feu",              diff="HM",  desc="HM : explosion de zone au décollage. Se préparer à bouger." },
                { name="Void Corruption",     fr="Corruption du Vide",       diff="MM",  desc="MM : stack +5% dégâts reçus sur les joueurs trop proches du boss." },
            }},
            { name = "Midnight Falls", mechs = {
                { name="Dark Naaru",          fr="Naaru des Ténèbres",       diff="N",   desc="Phase d'adds. Tuer les Naaru corrompus avant qu'ils rejoignent Midnight." },
                { name="Dark Naaru",          fr="Naaru des Ténèbres",       diff="HM",  desc="HM : spawent plus fréquemment. CDs DPS à garder." },
                { name="Void Tendrils",       fr="Tentacules du Vide",       diff="N",   desc="Tentacules enracinent des joueurs. Les autres brisent les enracinements." },
                { name="Void Tendrils",       fr="Tentacules du Vide",       diff="HM",  desc="HM : affecte plus de joueurs simultanément. Coordination des breaks." },
                { name="Entropic Cascade",    fr="Cascade Entropique",       diff="N",   desc="Dégâts en chaîne entre joueurs proches. Se spread." },
                { name="Entropic Cascade",    fr="Cascade Entropique",       diff="HM",  desc="HM : chaîne rebondit plus de fois. Distance de spread augmentée." },
                { name="Sunwell Corruption",  fr="Corruption du Puits",      diff="N",   desc="Purifier les zones corrompues du Puits Solaire." },
                { name="Void Surge",          fr="Déferlante du Vide",       diff="HM",  desc="HM : vague supplémentaire entre les phases. CDs healeurs anticipés." },
                { name="Absolute Void",       fr="Vide Absolu",              diff="MM",  desc="MM uniquement : phase finale, dégâts raid massifs. Tous les CDs défensifs." },
            }},
        },
    },
}

-- ============================================================
-- SEED DB + MIGRATION
-- ============================================================
local function BuildKnownIndex()
    local idx = {}
    for _, raid in ipairs(SolaryM_RaidData) do
        for _, boss in ipairs(raid.bosses) do
            idx[boss.name] = {}
            for _, mech in ipairs(boss.mechs) do
                idx[boss.name][mech.name .. "|" .. mech.diff] = true
            end
        end
    end
    return idx
end

local function SeedDefaults()
    SolaryMDB.bosses = SolaryMDB.bosses or {}
    local known = BuildKnownIndex()
    local purged = 0
    for bossName, mechTable in pairs(SolaryMDB.bosses) do
        if known[bossName] then
            for key, customVal in pairs(mechTable) do
                if not known[bossName][key] then
                    local bwName = key:match("^(.+)|") or key
                    if customVal == bwName or customVal == key then
                        mechTable[key] = nil; purged = purged + 1
                    end
                end
            end
        end
    end
    for _, raid in ipairs(SolaryM_RaidData) do
        for _, boss in ipairs(raid.bosses) do
            SolaryMDB.bosses[boss.name] = SolaryMDB.bosses[boss.name] or {}
            for _, mech in ipairs(boss.mechs) do
                local key = mech.name .. "|" .. mech.diff
                if SolaryMDB.bosses[boss.name][key] == nil then
                    SolaryMDB.bosses[boss.name][key] = mech.name
                end
            end
        end
    end
    if purged > 0 then
        print("|cFFFFAA00SolaryM:|r Migration — |cFFFFD700" .. purged .. "|r entrée(s) supprimée(s).")
    end
end

-- ============================================================
-- CHARGEMENT
-- ============================================================
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event)
    if event ~= "PLAYER_LOGIN" then return end
    SolaryMDB = SolaryMDB or { bosses = {} }
    SeedDefaults()
    if not BigWigsLoader then
        print("|cFFFF6600SolaryM:|r BigWigs introuvable — addon désactivé.")
        return
    end
    CreateFlash()
    BigWigsLoader.RegisterMessage(bwHandle, "BigWigs_StartBar",     OnBWBar)
    BigWigsLoader.RegisterMessage(bwHandle, "BigWigs_OnBossEngage", OnBWEngage)
    BigWigsLoader.RegisterMessage(bwHandle, "BigWigs_OnBossWipe",   OnBWEnd)
    BigWigsLoader.RegisterMessage(bwHandle, "BigWigs_OnBossWin",    OnBWEnd)
    print("|cFFFFAA00SolaryM|r chargé — /solarym pour ouvrir le panneau.")
end)

-- ============================================================
-- GLOBALS
-- ============================================================
function SolaryM_GetCurrentBoss() return currentBoss end
function SolaryM_TestAlert(custom, original)
    ShowFlash(custom or "Soak", original or "Umbral Despair")
end

-- ============================================================
-- SLASH
-- ============================================================
SLASH_SOLARYM1 = "/solarym"
SlashCmdList["SOLARYM"] = function(msg)
    msg = (msg or ""):lower():trim()
    if msg == "" or msg == "panel" then
        if SolaryM_TogglePanel then SolaryM_TogglePanel()
        else print("|cFFFFAA00SolaryM:|r Panneau non chargé.") end
    elseif msg == "move" then
        if flashFrame then
            flashTitle:SetText("Flash d'alerte")
            flashSub:SetText("Déplace ici")
            flashFrame:Show()
            print("|cFFFFAA00SolaryM:|r Déplace le flash, puis /solarym move pour figer.")
        end
    elseif msg == "test" then
        ShowFlash("Soak", "Umbral Despair")
    else
        print("|cFFFFAA00SolaryM:|r  /solarym panneau  |  /solarym test test flash  |  /solarym move déplacer")
    end
end
