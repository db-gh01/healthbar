_addon.name = 'healthbar'
_addon.author = 'DB'
_addon.version = '0.1'
_addon.language = 'Japanese'
_addon.commands = {'healthbar','bar'}

table = require('table')
set = require('sets')
bit = require('bit')
config = require('config')
images = require('images')
texts = require('texts')
packets = require('packets')

bar = require('Bar')
action_manager = require('ActionManager')
enmity_manager = require('EnmityManager')
debuff_manager = require('DebuffManager')
party_manager = require('PartyManager')
level_manager = require('LevelManager')

bars = {}
bar_groups = {}
target_bar = nil
subtarget_bar = nil
focustarget_bar = nil
aggro_bars = nil

layout = nil
settings = nil
ready = nil
last_cleanup_enmity_clock = os.clock()
last_execute_widescan = os.clock()
last_target_index = nil
last_subtarget_index = nil

setup_mode = false
dragged = nil

function initialize()
    if not windower.ffxi.get_info().logged_in then return end

    ready = false

    local layout_file = "layouts/" .. settings.layout .. ".xml"
    if not windower.file_exists(windower.addon_path .. layout_file) then
        error("layoutファイルが見つかりません")
        return
    end
    layout = T(config.load(layout_file))
    target_bar = bar.new(settings.target_bar.show, layout.target_bar, 'Target Bar')
    subtarget_bar = bar.new(settings.subtarget_bar.show, layout.subtarget_bar, 'Sub Target Bar')
    focustarget_bar = bar.new(settings.focustarget_bar.show, layout.focustarget_bar, 'Focus Target Bar')
    aggro_bars = {}
    for i = 1, layout.aggro_bar.count do
        aggro_bars[i] = bar.new(settings.aggro_bar.show, layout.aggro_bar, 'Aggro Bars' .. i)
    end
    bar_groups = {
        target_bar = {target_bar},
        subtarget_bar = {subtarget_bar},
        focustarget_bar = {focustarget_bar},
        aggro_bars = aggro_bars,
    }
    bars = table.pack(target_bar, subtarget_bar, focustarget_bar, table.unpack(aggro_bars))
    for _, bar in ipairs(bars) do
        if settings.auto_widescan then
            bar:enable_auto_widescan()
        else
            bar:disable_auto_widescan()
        end
    end
    for _, bar in ipairs(bars) do
        bar:predraw()
    end
    coroutine.sleep(1)
    for _, bar in ipairs(bars) do
        bar:store_extents()
        bar:postdraw()
    end

    target_bar:set_position(settings.target_bar.pos.x, settings.target_bar.pos.y)
    focustarget_bar:set_position(settings.focustarget_bar.pos.x, settings.focustarget_bar.pos.y)
    subtarget_bar:set_position(settings.subtarget_bar.pos.x, settings.subtarget_bar.pos.y)
    for i = 1, layout.aggro_bar.count do
        aggro_bars[i]:set_position(
            settings.aggro_bar.pos.x,
            settings.aggro_bar.pos.y + (i - 1) * layout.aggro_bar.itemheight * (layout.aggro_bar.bottomup and -1 or 1)
        )
    end

    if windower.ffxi.get_info().logged_in then
        Bar.set_player_id(windower.ffxi.get_player().id)
        party_manager:update_party_members()
        Bar.set_party_member_ids(party_manager:get_party_member_ids())
    end

    debuff_manager:update_player_buffs()
    level_manager:widescan_log(settings.widescan_log)

    ready = true
end

function set_target_and_subtarget()
    local t = windower.ffxi.get_mob_by_target('t')
    if t and t.index ~= last_target_index then
        last_target_index = t.index
        target_bar:set_mob(t.id)
        target_bar:show()
    elseif not t and last_target_index then
        last_target_index = nil
        target_bar:set_mob(nil)
        target_bar:hide()
    end

    local st = windower.ffxi.get_mob_by_target('st')
    if st and st.index ~= last_subtarget_index then
        last_subtarget_index = st.index
        subtarget_bar:set_mob(st.id)
        subtarget_bar:show()
    elseif not st and last_subtarget_index then
        last_subtarget_index = nil
        subtarget_bar:set_mob(nil)
        subtarget_bar:hide()
    end
end

function update_aggro_bars()
    local index = 1
    for _, mob_id in ipairs(enmity_manager:get_enmity_list()) do
        aggro_bars[index]:set_mob(mob_id)
        aggro_bars[index]:show()
        index = index + 1
        if index > layout.aggro_bar.count then break end
    end
    for i = index, layout.aggro_bar.count do
        aggro_bars[i]:hide()
    end
end

function set_focus(t)
    local mob = nil
    if T{'clear', 'off'}:contains(t:lower()) then
        focustarget_bar:set_mob(nil)
        focustarget_bar:hide()
        return
    end
    if not t or #t == 0 then
        mob = windower.ffxi.get_mob_by_target('t')
    elseif T{'t', 'st', 'lastst', 'bt', 'ht'}:contains(t:lower()) then
        mob = windower.ffxi.get_mob_by_target(t)
    else
        mob = windower.ffxi.get_mob_by_name(t)
    end
    if mob then
        focustarget_bar:set_mob(mob.id)
        focustarget_bar:update_all()
        focustarget_bar:show()
    end
end

windower.register_event('prerender', function()
    if not ready then return end
    if setup_mode then return end

    set_target_and_subtarget()
    for _, bar in ipairs(bars) do
        if bar:is_visible() then
            bar:update_frequent()
            bar:update_action(action_manager)
            bar:update_target(enmity_manager)
            bar:update_debuff(debuff_manager)
            bar:update_level(level_manager)
        end
    end

    local c = os.clock()
    if c - last_cleanup_enmity_clock > 0.5 then
        if enmity_manager:cleanup_enmity() then
            update_aggro_bars()
        end
        last_cleanup_enmity_clock = c
    end
    if settings.auto_widescan then
        local c = os.clock()
        if c - last_execute_widescan > 0.5 then
            level_manager:execute_widescan(true)
            last_execute_widescan = c
        end
    end
end)

function delayed_update_party_members()
    party_manager:update_party_members()
    Bar.set_party_member_ids(party_manager:get_party_member_ids())
end

function setup()
    if not ready then return end
    if setup_mode then
        setup_mode = false
        last_subtarget_index = -1
        last_target_index = -1
        set_target_and_subtarget()
        set_focus('clear')
        update_aggro_bars()
        settings:save()
    else
        setup_mode = true
        for _, bar in ipairs(bars) do
            bar:setup_dummy()
            bar:show()
        end
    end
end

windower.register_event('mouse', function(type, x, y, delta, blocked)
    if blocked or not setup_mode then
        return
    end
    if type == 1 then
        for _, group in pairs(bar_groups) do
            for _, b in ipairs(group) do
                if b:hover(x, y) then
                    dragged = {bars = group, x = x, y = y}
                    return true
                end
            end
        end
    elseif type == 0 then
        if dragged then
            local dx = x - dragged.x
            local dy = y - dragged.y
            for _, b in ipairs(dragged.bars) do
                b:set_position(b:pos_x() + dx, b:pos_y() + dy)
            end
            dragged.x = x
            dragged.y = y
            return true
        end
    elseif type == 2 then
        if dragged then
            settings.target_bar.pos = {
                x = target_bar:pos_x(),
                y = target_bar:pos_y()
            }
            settings.subtarget_bar.pos = {
                x = subtarget_bar:pos_x(),
                y = subtarget_bar:pos_y()
            }
            settings.focustarget_bar.pos = {
                x = focustarget_bar:pos_x(),
                y = focustarget_bar:pos_y()
            }
            settings.aggro_bar.pos = {
                x = aggro_bars[1]:pos_x(),
                y = aggro_bars[1]:pos_y()
            }
            dragged = nil
            return true
        end
    end
    return false
end)

windower.register_event('outgoing chunk', function(id, data, modified, injected, blocked)
    -- Widescan
    if id == 0x0F4 then
        level_manager:handle_outgoing_widescan(data)
    end
end)

windower.register_event('incoming chunk', function(id, data, modified, injected, blocked)
    -- Party Member Update
    if id == 0x0DD then
        coroutine.schedule(delayed_update_party_members, 1)
    -- Pet Info
    elseif id == 0x067 then
        local p =  packets.parse('incoming', data)
        if p['Owner Index'] > 0 then
            local owner = windower.ffxi.get_mob_by_index(p['Owner Index'])
            if owner then
                party_manager:handle_pet_info(p['Pet ID'], owner.id)
                Bar.set_party_member_ids(party_manager:get_party_member_ids())
            end
        end
    -- Action
    elseif id == 0x028 then
        local act = windower.packets.parse_action(data)
        enmity_manager:track_enmity(act, party_manager, update_aggro_bars)
        enmity_manager:get_enmity_list()
        action_manager:track_action(act)
        debuff_manager:track_debuff_action(act)
    -- Action Message
    elseif id == 0x029 then
        debuff_manager:track_debuff_message(data)
    -- Party Buffs
    elseif id == 0x076 then
        debuff_manager:track_party_buffs(data)
    -- Widescan
    elseif id == 0x0F4 then
        level_manager:handle_incoming_widescan(data)
    -- Zone In
    elseif id == 0x00A then
        level_manager:handle_zone_in()
    -- Zone Out
    elseif id == 0x00B then
        level_manager:handle_zone_out()
        debuff_manager:clear()
        enmity_manager:clear()
        action_manager:clear()
        last_subtarget_index = -1
        last_target_index = -1
        set_target_and_subtarget()
        update_aggro_bars()
        set_focus('clear')
    end
end)

windower.register_event('gain buff', function(buff_id) debuff_manager:update_player_buffs() end)

windower.register_event('lose buff', function(buff_id) debuff_manager:update_player_buffs() end)

windower.register_event('addon command', function(cmd, ...)
    local args = T{...}
    if not cmd then return end
    if T{'f', 'ft', 'focus'}:contains(cmd:lower()) then
        set_focus(args:concat(" "))
    elseif T{'setup', 's'}:contains(cmd:lower()) then
        setup()
    end
end)

default = {
    layout = 'layout',
    auto_widescan = false,
    widescan_log = true,
    target_bar = {
        show = true,
        pos = {
            x = 500,
            y = 150,
        },
    },
    subtarget_bar = {
        show = true,
        pos = {
            x = 800,
            y = 250,
        },
    },
    focustarget_bar = {
        show = true,
        pos = {
            x = 350,
            y = 400,
        },
    },
    aggro_bar = {
        show = true,
        pos = {
            x = 200,
            y = 100,
        },
    },
}
settings = config.load(default)
config.register(settings, initialize)

