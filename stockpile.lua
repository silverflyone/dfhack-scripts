-- Combines food and plant items across stockpiles.
local argparse = require('argparse')
local utils = require('utils')

local opts, args = {
    help = false,
    all = nil,
    here = nil,
    dry_run = false,
    verbose = 0
  }, {...}

  -- list of types that use race and caste
local typesThatUseCreatures={REMAINS=true,FISH=true,FISH_RAW=true,VERMIN=true,PET=true,EGG=true,CORPSE=true,CORPSEPIECE=true}

-- CList class
-- generic list class used for key value pairs.
local CList = { }

function CList:new(o)
    -- key, value pair table structure. __len allows # to be used for table count.
    o = o or { }
    setmetatable(o, self)
    self.__index = self
    self.__len = function (t) local n = 0 for _, __ in pairs(t) do n = n + 1 end return n end
    return o
end

function log(level, ...)
    -- if verbose is specified, then print the arguments, or don't.
    if opts.verbose >= level then dfhack.print(string.format(...)) end
end

local function isRestrictedItem(item)
    -- is the item restricted from merging?
    local flags = item.flags
    return flags.rotten or flags.trader or flags.hostile or flags.forbid
        or flags.dump or flags.on_fire or flags.garbage_collect or flags.owned
        or flags.removed or flags.encased or flags.spider_web or flags.melt 
        or flags.hidden or #item.specific_refs > 0
end

function print_stockpile_items(items, stockpile, contents, container, ind)
    if not ind then ind = '' end

    for _, item in pairs(contents) do
        local x, y, z = dfhack.items.getPosition(item)
        local type_id = item:getType()
        local subtype_id = item:getSubtype()

        if dfhack.items.getGeneralRef(item, df.general_ref_type.CONTAINS_ITEM) then
            local contained_items = dfhack.items.getContainedItems(item)
            log(2, ('      %sContainer:%s <%6d> #items:%5d\n'):format(ind, utils.getItemDescription(item), item.id, #contained_items))
            print_stockpile_items(items, stockpile, contained_items, item, ind .. '   ')
        else
            -- item.material_amount.Leather > 0 or item.material_amount.Bone > 0 or item.material_amount.Shell > 0 or item.material_amount.Tooth > 0 or item.material_amount.Horn > 0 or item.material_amount.HairWool > 0 or item.material_amount.Yarn
--            if type_id == df.item_type.CORPSEPIECE and not isRestrictedItem(item) and item.material_amount.Tooth > 0 then -- and not item.corpse_flags.unbutchered then
            if not isRestrictedItem(item) and (item:getMaterial() < 0 and item.material_amount.Yarn > 0 and not item.corpse_flags.unbutchered) then

                local race = ''
                local caste = ''
                if item:getMaterial() < 0 then
                    race = df.global.world.raws.creatures.all[item.race].creature_id
                    caste = df.global.world.raws.creatures.all[item.race].caste[item.caste].caste_id
                end
                local mat_info = dfhack.matinfo.decode(item:getActualMaterial(), item:getActualMaterialIndex())
                dfhack.print(item.material_amount.Bone .. item.material_amount.Shell .. item.material_amount.Tooth .. item.material_amount.Horn .. item.material_amount.Pearl .. item.material_amount.HairWool .. item.material_amount.Yarn)
                log(0, ('      %13s %63s<%6d> size:%6d wear:%1d wear timer:%6d mat:%3d ind:%3d act mat:%3d ind:%3d mat info:%6s race:%16s caste:%10s quality:%d, maker:%d stockpile:%s\n'):format(df.item_type[item:getType()], utils.getItemDescription(item, 2), item.id, item.stack_size, item.wear, item.wear_timer, item:getMaterial(), item:getMaterialIndex(), item:getActualMaterial(), item:getActualMaterialIndex(), mat_info, race, caste, item:getQuality(), item:getMaker(), items[item.id].stockpile_id or 'nil'))
--                printall_recurse(item.corpse_flags)
            else
                -- restricted; such as marked for action or dump.
                log(2, ('      %sitem:%40s <%6d> is restricted\n'):format(ind, utils.getItemDescription(item), item.id))
            end
        end
    end
end

local function print_stockpiles(items, stockpiles)

    log(1, ('print_stockpiles\n'))
    for _, stockpile in pairs(stockpiles) do

        local contents = dfhack.buildings.getStockpileContents(stockpile.stockpile)
        log(1, ('   stockpile:%30s <%6d> pos:(%3d,%3d,%3d) #items:%5d\n'):format(stockpile.stockpile.name, stockpile.stockpile.id, stockpile.stockpile.centerx, stockpile.stockpile.centery, stockpile.stockpile.z,  #contents))

        if #contents > 0 then
            print_stockpile_items(items, stockpile, contents)
        end
    end
end

function pop_stockpile_contents(items, stockpile, contents)
    log(3, 'pop_stockpile_contents\n')
    for _, item in pairs(contents) do
        items[item.id] = {}
        items[item.id].item = item
        items[item.id].stockpile_id = stockpile.id
        if dfhack.items.getGeneralRef(item, df.general_ref_type.CONTAINS_ITEM) then
            pop_stockpile_contents(items, stockpile, dfhack.items.getContainedItems(item))
        end
    end
end

local function pop_stockpiles(items, stockpiles, stockpile_filter)
    log(0, 'pop_stockpiles\n')
    for _, stockpile in pairs(stockpile_filter) do
        stockpiles[stockpile.id] = {}
        stockpiles[stockpile.id].stockpile = stockpile
        local contents = dfhack.buildings.getStockpileContents(stockpile)
        if #contents > 0 then
            pop_stockpile_contents(items, stockpile, contents)
        end
    end
end

local function get_stockpile_all()
    -- attempt to get all the stockpiles for the fort, or exit with error
    -- return the stockpiles as a table
    log(3, 'get_stockpile_all\n')
    local stockpiles = {}
    for _, building in pairs(df.global.world.buildings.all) do
        if building:getType() == df.building_type.Stockpile then
            table.insert(stockpiles, building)
        end
    end
    dfhack.print(('Stockpile(all): %d found\n'):format(#stockpiles))
    return stockpiles
end

local function get_stockpile_here()
    -- attempt to get the stockpile located at the game cursor, or exit with error
    -- return the stockpile as a table
    log(3, 'get_stockpile_here\n')
    local stockpiles = {}
    local pos = argparse.coords('here', 'here')
    local building = dfhack.buildings.findAtTile(pos)
    if not building or building:getType() ~= df.building_type.Stockpile then qerror('Stockpile not found at game cursor position.') end
    table.insert(stockpiles, building)
    local items = dfhack.buildings.getStockpileContents(building)
    log(0, ('Stockpile(here): %s <%d> #items:%d\n'):format(building.name, building.id, #items))
    return stockpiles
end

local function parse_commandline(opts, args)
    -- check the command line/exit on error, and set the defaults
    log(3, 'parse_commandline\n')
    local positionals = argparse.processArgsGetopt(args, {
            {'h', 'help', handler=function() opts.help = true end},
            {'d', 'dry-run', handler=function(optarg) opts.dry_run = true end},
            {'v', 'verbose', hasArg=true, handler=function(optarg) opts.verbose = math.tointeger(optarg) or 0 end},
    })

    -- if stockpile option is not specificed, then default to all
    if args[1] == 'all' then
        opts.all=get_stockpile_all()
    elseif args[1] == 'here' then
        opts.here=get_stockpile_here()
    else
        opts.help = true
    end

end

-- main program starts here
local function main()

    if df.global.gamemode ~= df.game_mode.DWARF or not dfhack.isMapLoaded() then
        qerror('combine needs a loaded fortress map to work\n')
    end

    parse_commandline(opts, args)

    items = CList:new(nil)
    stockpiles = CList:new(nil)

    pop_stockpiles(items, stockpiles, opts.all or opts.here)
--    if opts.help then
--        print(dfhack.script_help())
--        return
--    end

    print_stockpiles(items, stockpiles)
    
end

if not dfhack_flags.module then
    main()
end
