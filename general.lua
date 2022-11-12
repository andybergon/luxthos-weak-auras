local local_env = aura_env
local CLASS = local_env.id:gsub("General Options %- LWA %- ", "")
local_env.CLASS = CLASS

LWA = LWA or {}
LWA[CLASS] = LWA[CLASS] or {}

local LWA = LWA[CLASS]

local config = nil
LWA.configs = LWA.configs or {}
LWA.configs["general"] = local_env.config


local CLASS_GROUP = "Luxthos - " .. CLASS
local DYNAMIC_EFFECTS_GROUP = "Dynamic Effects - LWA - " .. CLASS
local CORE_GROUP = "Core - LWA - " .. CLASS
local LEFT_SIDE_GROUP = "Left Side - LWA - " .. CLASS
local RIGHT_SIDE_GROUP = "Right Side - LWA - " .. CLASS
local UTILITIES_GROUP = "Utilities - LWA - " .. CLASS
local MAINTENANCE_GROUP = "Maintenance - LWA - " .. CLASS
local RESOURCES_GROUP = "Resources - LWA - " .. CLASS
local CAST_BAR = "Cast Bar - LWA - " .. CLASS

local_env.parent = CLASS_GROUP

local MAX_WIDTH = 405
local RESOURCES_HEIGHT = 0
local NB_CORE = 8
local resources

local function tclone(t1)
    local t = {}
    
    if t1 then
        for k, v in pairs(t1) do
            if "table" == type(v) then
                v = tclone(v)
            end
            
            if "string" == type(k) then
                t[k] = v
            else
                tinsert(t, v)
            end
        end
    end
    
    return t
end

local function tmerge(...)
    local ts = {...}
    local t = tclone(ts[1])
    local t2
    
    for i = 2, #ts do
        t2 = ts[i] or {}
        
        for k, v in pairs(t2) do
            if "table" == type(v) then
                v = tclone(v)
                
                if t[k] and #t[k] == 0 then
                    t[k] = tmerge(t[k], v)
                else
                    t[k] = v
                end
            else
                t[k] = v
            end
        end
    end
    
    return t
end

local function SetRegionSize(r, w, h)
    r:SetRegionWidth(w)
    r:SetRegionHeight(h)
end

local function ResizeAnchorFrame(skipCore)
    local config = LWA.GetConfig()
    local h = max(1, config.core.height + config.core.spacing + config.core.margin + RESOURCES_HEIGHT)
    
    if 1 == h % 2 then
        h = h + 1
    end
    
    SetRegionSize(local_env.region, MAX_WIDTH, h)
    
    local function RepositionGroups()
        local configs = { config.core, config.utility, config.maintenance }
        
        for i, g in ipairs({ CORE_GROUP, UTILITIES_GROUP, MAINTENANCE_GROUP }) do
            if not (skipCore and CORE_GROUP == g) then
                g = WeakAuras.GetRegion(g)
                
                if g then
                    g:PositionChildren()
                    
                    if 0 == #g.sortedChildren then
                        g:SetHeight(configs[i].height)
                        g.currentHeight = configs[i].height
                    end
                end
            end
        end
    end
    
    if skipCore then
        C_Timer.After(0.05, RepositionGroups)
    else
        RepositionGroups()
    end
end

function LWA.GetConfig(grp, force)
    local default = {
        style = {
            border_size = 0,
            border_icons = true,
            border_resources = true,
            border_color = { [1] = 0, [2] = 0, [3] = 0, [4] = 1 },
            zoom = 30,
        },
        core = {
            nb_min = 5,
            nb_max = 8,
            width = 48,
            height = 48,
            spacing = 3,
            margin = 0,
            resources_position = 2, -- Below
        },
        utility = {
            width = 38,
            height = 38,
            spacing = 3,
            margin = 10,
            behavior = 2, -- Always Show
        },
        top = {
            width = 38,
            height = 38,
            spacing = 3,
            margin = 10,
        },
        side = {
            width = 38,
            height = 38,
            spacing = 3,
            margin = 3,
            grow_direction = 1,
        },
        maintenance = {
            width = 36,
            height = 36,
            spacing = 0,
            margin = 10,
        },
        alpha = {
            global = 100,
            ooc = 100,
            ignore_enemy = true,
            ignore_friendly = true,
        },
        resources = {
            health_bar = {
                format = 1
            },
            mana_bar = {
                format = 1
            }
        },
    }
    
    if force or not config or WeakAuras.IsOptionsOpen() then
        config = tmerge(
            default,
            LWA.configs["general"],
            LWA.configs["class"] or {}
        )
    end
    
    if grp then
        return config[grp] or {}
    end
    
    return config
end

local function UpdateBorder(region, apply)
    if #region.subRegions > 0 then
        local config, size, r, g, b, a = LWA.GetConfig(), 0
        
        if apply then
            size = config.style.border_size
            r, g, b, a = unpack(config.style.border_color)
        end
        
        for _, border in ipairs(region.subRegions) do
            if "subborder" == border.type then
                border:SetVisible(size > 0)
                
                if size > 0 then
                    local bd = border:GetBackdrop()
                    bd.edgeSize = size
                    border:SetBackdrop(bd)
                    border:SetBorderColor(r, g, b, a)
                end
            end
        end
    end
end

local throttledInitHandler = nil
local initLastRun = 0

function LWA.ThrottledInit()
    if throttledInitHandler then return end
    
    local currentTime = time()
    
    if WeakAuras.IsImporting() then
        throttledInitHandler = C_Timer.NewTimer(2, LWA.ThrottledInit)
        
    elseif initLastRun <= currentTime - 0.2 then
        throttledInitHandler = C_Timer.NewTimer(0.05, LWA.Init)
    else
        throttledInitHandler = C_Timer.NewTimer(max(0.05, currentTime - initLastRun), LWA.Init)
    end
end

function LWA.Init()
    if WeakAuras.IsImporting() then return end
    
    initLastRun = time()
    
    local config = LWA.GetConfig(nil, true)
    local isOptionsOpen = WeakAuras.IsOptionsOpen()
    local zoom = config.style.zoom / 100
    
    if throttledInitHandler then
        throttledInitHandler:Cancel()
        throttledInitHandler = nil
    end
    
    if not local_env.parentFrame then
        local_env.parentFrame = WeakAuras.GetRegion(CLASS_GROUP)
    end
    
    if local_env.parentFrame and not local_env.parentFrame.SetRealScale then
        local_env.parentFrame.SetRealScale = local_env.parentFrame.SetScale
        
        local_env.parentFrame.SetScale = function(self, scale)
            local_env.parentFrame:SetRealScale(scale)
            local castBar = WeakAuras.GetRegion(CAST_BAR)
            
            if castBar then
                castBar:SetScale(scale)
            end
        end
    end
    
    if isOptionsOpen then
        NB_CORE = config.core.nb_max
    else
        NB_CORE = max(4, config.core.nb_min, min(NB_CORE, config.core.nb_max))
    end
    
    MAX_WIDTH = NB_CORE * (config.core.width + config.core.spacing) - config.core.spacing
    
    local function InitIcons(group, c, selfPoint)
        local grpRegion = WeakAuras.GetRegion(group)
        
        if not grpRegion then return end
        
        local i, isAbilities = 0, CORE_GROUP == group
        
        for childId, regions in pairs(grpRegion.controlledChildren) do
            local region = regions[""] and regions[""].regionData.region
            
            i = i + 1
            
            if region then
                region:SetAnchor(selfPoint, region.relativeTo, region.relativePoint)
                
                if region.SetZoom then
                    region:SetZoom(min(1, zoom + (region.extraZoom or 0)))
                else
                    print("LWA Issue: " .. CLASS .. " > " .. group .. " > " .. childId)
                end
                
                if isAbilities and i > NB_CORE then
                    SetRegionSize(region, config.top.width, config.top.height)
                else
                    SetRegionSize(region, c.width, c.height)
                end
                
                UpdateBorder(region, config.style.border_icons)
            end
        end
        
        if isAbilities then
            grpRegion:PositionChildren()
            
            if not isOptionsOpen then
                NB_CORE = max(4, config.core.nb_min, min(#grpRegion.sortedChildren, config.core.nb_max))
                
                MAX_WIDTH = NB_CORE * (config.core.width + config.core.spacing) - config.core.spacing
            end
            
            local_env.region:SetRegionWidth(MAX_WIDTH)
        end
    end
    
    InitIcons(CORE_GROUP, config.core, "BOTTOM")
    InitIcons(UTILITIES_GROUP, config.utility, "TOP")
    InitIcons(MAINTENANCE_GROUP, config.maintenance, "TOP")
    InitIcons(DYNAMIC_EFFECTS_GROUP, config.top, "BOTTOMRIGHT")
    InitIcons(LEFT_SIDE_GROUP, config.side, "TOPRIGHT")
    InitIcons(RIGHT_SIDE_GROUP, config.side, "TOPLEFT")
    
    local_env.UpdateResources()
    
    for _, g in ipairs({ DYNAMIC_EFFECTS_GROUP, LEFT_SIDE_GROUP, RIGHT_SIDE_GROUP }) do
        g = WeakAuras.GetRegion(g)
        
        if g then
            g:PositionChildren()
        end
    end
end

function local_env.UpdateResources()
    if WeakAuras.IsImporting() then return end
    
    local config = LWA.GetConfig()
    
    local totalHeight, nb = 0, 0
    local h1 = config.core.height
    local s1 = config.core.spacing
    local m1 = config.core.margin
    local y = 0
    
    local grpRegion = WeakAuras.GetRegion(RESOURCES_GROUP)
    
    if not resources or WeakAuras.IsOptionsOpen() then
        local grpData = WeakAuras.GetData(RESOURCES_GROUP)
        
        resources = grpData and grpData.controlledChildren
    end
    
    if grpRegion and resources and #resources > 0 then
        if config.core.resources_position == 2 then -- Below
            y = h1 + s1 + m1
        end
        
        grpRegion:SetOffset(0, -y)
        
        local isOptionsOpen = WeakAuras.IsOptionsOpen()
        local resRegion, isVisible, regionType
        local w, h = 0, 0
        
        local function InitResource(region, index, nb)
            if not region then return end
            
            index = max(1, index or 1)
            nb = max(1, nb or 1)
            
            w, h = MAX_WIDTH, 20
            
            if nb > 1 then
                local s = config.core.spacing
                
                w = (w + s) / nb - s
            end
            
            local cg = region.configGroup
            
            if cg and config.resources[cg] then
                h = config.resources[cg].height or 20
            end
            
            SetRegionSize(region, w, h)
            region.bar:Update()
            UpdateBorder(region, config.style.border_resources)
            local_env.UpdateBar({ region = region }, index, nb)
            
            if region.bar.spark then
                region.bar.spark:SetHeight(max(15, Round(h * 2)))
            end
        end
        
        y = 0
        
        for _, resId in ipairs(resources) do
            resRegion = WeakAuras.GetRegion(resId)
            
            if resRegion then
                isVisible = isOptionsOpen
                regionType = resRegion.regionType
                h = 0
                
                if "aurabar" == regionType then
                    isVisible = isVisible or resRegion:IsVisible()
                    InitResource(resRegion)
                    
                elseif "dynamicgroup" == regionType then
                    local nbChild = 0
                    local childRegions = {}
                    
                    for _, region in pairs(resRegion.controlledChildren) do
                        if region and region[""] then
                            nbChild = nbChild + 1
                            
                            childRegions[region[""].regionData.dataIndex] = region[""].regionData.region
                            
                            isVisible = isVisible or region[""].regionData.region:IsVisible()
                        end
                    end
                    
                    for i, region in ipairs(childRegions) do
                        InitResource(region, i, nbChild)
                        
                        region:SetYOffset(-y)
                    end
                end
                
                if isVisible then
                    nb = nb + 1
                    
                    if isVisible then
                        if "dynamicgroup" == regionType then
                            resRegion:PositionChildren()
                        else
                            resRegion:SetOffset(0, -y)
                        end
                    end
                    
                    totalHeight = totalHeight + h
                    y = y + h + s1
                end
            end
        end
        
        RESOURCES_HEIGHT = totalHeight + max(nb - 1, 0) * config.core.spacing
    end
    
    ResizeAnchorFrame()
    
    local castBar = WeakAuras.GetRegion(CAST_BAR)
    
    if castBar then
        castBar:SetParent(UIParent)
        
        if local_env.parentFrame then
            castBar:SetScale(local_env.parentFrame:GetScale())
        end
    end
end

function LWA.GrowCore(newPositions, activeRegions)
    local nb = #activeRegions
    
    if nb <= 0 then return end
    
    local config = LWA.GetConfig()
    
    local w1 = config.core.width
    local h1 = config.core.height
    local s1 = config.core.spacing
    local m1 = config.core.margin
    
    local maxCore = min(nb, config.core.nb_max)
    local x, y
    local xOffset = ((maxCore - 1) * (w1 + s1) / 2)
    local yOffset = h1 + 1
    local region
    
    if not WeakAuras.IsOptionsOpen() then
        NB_CORE = max(4, config.core.nb_min, maxCore)
        
        MAX_WIDTH = NB_CORE * (w1 + s1) - s1
        
        ResizeAnchorFrame(true)
    end
    
    if config.core.resources_position == 1 then  -- Above
        yOffset = h1 + RESOURCES_HEIGHT + s1 + m1
    end
    
    for i, regionData in ipairs(activeRegions) do
        region = regionData.region
        
        x = (i - 1) * (w1 + s1) - xOffset
        y = -yOffset
        
        SetRegionSize(region, w1, h1)
        
        newPositions[i] = { x, y }
        
        if i == maxCore then break end
    end
    
    local maxOverflow = nb - maxCore
    
    if maxOverflow > 0 then
        local w2 = config.top.width
        local h2 = config.top.height
        local s2 = config.top.spacing
        local m2 = config.top.margin
        
        local nbPerRow = math.floor(((MAX_WIDTH / 2) + s2) / (w2 + s2)) or 1
        local i2, j
        
        xOffset = -((MAX_WIDTH - w2) / 2)
        yOffset = m2 + yOffset - h1 - h2 + max(s1, s2) - s2 - 2
        
        if config.core.resources_position == 1 then -- Above
            yOffset = yOffset - RESOURCES_HEIGHT - s1 - m1
        end
        
        for i, regionData in ipairs(activeRegions) do
            if i > maxCore then
                region = regionData.region
                
                i2 = i - maxCore
                j = (i2 % nbPerRow)
                
                if j == 1 then
                    yOffset = yOffset + h2 + s2
                end
                
                if j == 0 then
                    j = nbPerRow
                end
                
                x = (j - 1) * (w2 + s2) + xOffset
                y = yOffset
                
                SetRegionSize(region, w2, h2)
                
                newPositions[i] = { x, y }
            end
        end
    end
end

function LWA.GrowDynamicEffects(newPositions, activeRegions)
    local nb = #activeRegions
    
    if nb <= 0 then return end
    
    local config = LWA.GetConfig()
    
    local w = config.top.width
    local h = config.top.height
    local s1 = config.core.spacing
    local s2 = config.top.spacing
    
    local xOffset = 0
    local yOffset = config.top.margin + max(s1, s2) - s2 - h
    local nbPerRow, m = math.floor(((MAX_WIDTH / 2) + s2) / (w + s2)) or 1
    
    for i, _ in ipairs(activeRegions) do
        m = (i % nbPerRow)
        
        if m == 1 then
            xOffset = 0
            yOffset = yOffset + h + s2
        end
        
        newPositions[i] = { -xOffset, yOffset }
        
        xOffset = xOffset + w + s2
    end
end

function LWA.GrowLeftSide(newPositions, activeRegions)
    local nb = #activeRegions
    
    if nb <= 0 then return end
    
    local config = LWA.GetConfig()
    
    local s1 = config.core.spacing
    
    local w2 = config.side.width
    local h2 = config.side.height
    local s2 = config.side.spacing
    
    local x, y
    local xOffset = config.side.margin + max(s1, s2)
    local yOffset = 0
    
    if config.side.grow_direction == 2 then -- Upward
        yOffset = -(h2 + s2 + config.top.margin)
    end
    
    for i, _ in ipairs(activeRegions) do
        x = -xOffset
        y = -yOffset
        
        newPositions[i] = { x, y }
        
        if config.side.grow_direction == 3 then -- Horizontal
            xOffset = xOffset + w2 + s2
            
        elseif config.side.grow_direction == 2 then -- Upward
            yOffset = -(-yOffset + h2 + s2)
        else
            yOffset = yOffset + h2 + s2
        end
    end
end

function LWA.GrowRightSide(newPositions, activeRegions)
    local nb = #activeRegions
    
    if nb <= 0 then return end
    
    local config = LWA.GetConfig()
    
    local s1 = config.core.spacing
    
    local w2 = config.side.width
    local h2 = config.side.height
    local s2 = config.side.spacing
    
    local x, y
    local xOffset = config.side.margin + max(s1, s2)
    local yOffset = 0
    
    if config.side.grow_direction == 2 then -- Upward
        yOffset = -(h2 + s2 + config.top.margin)
    end
    
    for i, _ in ipairs(activeRegions) do
        x = xOffset
        y = -yOffset
        
        newPositions[i] = { x, y }
        
        if config.side.grow_direction == 3 then -- Horizontal
            xOffset = xOffset + w2 + s2
            
        elseif config.side.grow_direction == 2 then -- Upward
            yOffset = -(-yOffset + h2 + s2)
        else
            yOffset = yOffset + h2 + s2
        end
    end
end

function LWA.GrowUtilities(newPositions, activeRegions)
    local nb = #activeRegions
    
    if nb <= 0 then return end
    
    local config = LWA.GetConfig()
    
    local maxCore = min(nb, NB_CORE)
    
    local w1 = config.core.width
    local s1 = config.core.spacing
    
    local w2 = config.utility.width
    local h2 = config.utility.height
    local s2 = config.utility.spacing
    
    local x, y
    local xOffset = (maxCore - 1) * (w1 + s1) / 2
    local yOffset = config.utility.margin + max(s1, s2) - s2 - h2
    
    local nbPerRow = math.floor((MAX_WIDTH + s2) / (w2 + s2)) or 1
    local m
    
    for i, _ in ipairs(activeRegions) do
        m = (i % nbPerRow)
        
        if m == 1 then
            xOffset = (min(nb - i, nbPerRow - 1)) * (w2 + s2) / 2
            yOffset = yOffset + h2 + s2
        end
        
        if m == 0 then
            m = nbPerRow
        end
        
        x = (m - 1) * (w2 + s2) - xOffset
        y = -yOffset
        
        newPositions[i] = { x, y }
    end
end

function LWA.GrowMaintenance(newPositions, activeRegions)
    local nb = #activeRegions
    
    if nb <= 0 then return end
    
    local config = LWA.GetConfig()
    
    local maxCore = min(nb, NB_CORE)
    
    local w1 = config.core.width
    local s1 = config.core.spacing
    
    local w2 = config.maintenance.width
    local h2 = config.maintenance.height
    local s2 = config.maintenance.spacing
    
    local x, y
    local xOffset = (maxCore - 1) * (w1 + s1) / 2
    local yOffset = config.maintenance.margin + config.utility.margin + max(config.utility.spacing, s2) - s2 - h2
    
    local nbPerRow = math.floor((MAX_WIDTH + s2) / (w2 + s2)) or 1
    local m
    
    for i, _ in ipairs(activeRegions) do
        m = (i % nbPerRow)
        
        if m == 1 then
            xOffset = (min(nb - i, nbPerRow - 1)) * (w2 + s2) / 2
            yOffset = yOffset + h2 + s2
        end
        
        if m == 0 then
            m = nbPerRow
        end
        
        x = (m - 1) * (w2 + s2) - xOffset
        y = -yOffset
        
        newPositions[i] = { x, y }
    end
end

local function MixRGB(c1, c2, pos)
    pos = 1 - (pos or 0.5)
    
    return {
        (c1[1] * pos) + (c2[1] * (1 - pos)),
        (c1[2] * pos) + (c2[2] * (1 - pos)),
        (c1[3] * pos) + (c2[3] * (1 - pos)),
        (c1[4] * pos) + (c2[4] * (1 - pos))
    }
end

function local_env.UpdateBar(aura, i, nb)
    local config = LWA.GetConfig("resources")
    local e = aura or aura_env
    local region = e.region
    local cg = region.configGroup
    
    if not (region and cg and config[cg]) then return end
    
    cg = config[cg]
    
    local cs = region.colorState or ""
    
    if cs ~= "" then
        cs = cs .. "_"
    end
    
    i = max(1, region.index or i or 1)
    nb = max(1, region.indexMax or nb or 1)
    
    local c1, c2 = cg[cs .. "color1"], cg[cs .. "color2"]
    local bar = region.bar
    
    if cg[cs .. "gradient"] and cg[cs .. "gradient"] < 3 then
        if nb > 1 and 1 == cg[cs .. "gradient"] then
            local cc1, cc2 = c1, c2
            
            if i > 1 then
                c1 = MixRGB(cc1, cc2, (i - 1) / nb)
            end
            
            c2 = MixRGB(cc1, cc2, i / nb)
        end
        
        local orientation = "HORIZONTAL"
        
        if 2 == cg[cs .. "gradient"] then
            orientation = "VERTICAL"
            
            local tmp = c1
            c1 = c2
            c2 = tmp
        end
        
        bar.fg:SetGradient(orientation, CreateColor(unpack(c1)), CreateColor(unpack(c2)))
    else
        bar:SetForegroundColor(unpack(c1))
    end
    
    if region.ot then
        region.ot:SetColorTexture(unpack(c2))
    end
end

function LWA.GrowDynamicResource(newPositions, activeRegions)
    local nb = #activeRegions
    
    if nb <= 0 then return end
    
    local config = LWA.GetConfig()
    
    local s = config.core.spacing
    local w = (MAX_WIDTH + s) / nb
    local xOffset, x = (MAX_WIDTH - w + s) / 2
    
    for i, regionData in ipairs(activeRegions) do
        x = (i - 1) * w - xOffset
        
        regionData.region:SetRegionWidth(w - s)
        local_env.UpdateBar({ region = regionData.region }, i, nb)
        regionData.region.bar:Update()
        
        newPositions[i] = { x, 0 }
    end
end

local function round(num, decimals)
    local mult = 10^(decimals or 0)
    
    return Round(num * mult) / mult
end

local barFormats = {
    "value",
    "kvalue",
    "value (percent%)",
    "kvalue (percent%)",
    "percent%",
}

function LWA.UpdateBarText(value, percent, format)
    local text = barFormats[format] or "value"
    
    text = text:gsub("percent", round(percent, 0))
    
    if 2 == format or 4 == format then
        local rem = math.fmod(value, 1000) or 0
        
        if rem >= 950 then
            rem = 0
        end
        
        text = text:gsub("kvalue", FormatLargeNumber(Round((value - rem) / 1000)) .. "." .. Round(rem / 100) .. "K"):gsub("%.0K", "K"):gsub("%.", DECIMAL_SEPERATOR)
    else
        text = text:gsub("value", value)
    end
    
    return text
end