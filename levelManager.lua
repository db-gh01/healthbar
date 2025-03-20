require('table')
require('logger')
require('sets')
packets = require('packets')

levelManager = {}

levelManager.mob_level_table = T{}
levelManager.widescan_log_enabled = true

levelManager.state = {
    last_scan_pos_x = nil,
    last_scan_pos_y = nil,
    last_scan_time = nil,
    cutscene = false,
    zoning = false,
    scanning = false,
}

levelManager.city_ids = S{
    230,231,232,233,234,235,236,237,238,239,
    240,241,242,243,244,245,246,247,248,249,
    250,251,252,
    256,257,
    280,281,283,284,285,
}

function levelManager.widescan_log(self, enabled)
    if enabled then
        self.widescan_log_enabled = true
    else
        self.widescan_log_enabled = false
    end
end

function levelManager.get_mob_level(self, index)
    if self.mob_level_table[index] then
        return self.mob_level_table[index]
    else
        self.mob_level_table[index] = -1
        return nil
    end
end

function levelManager.set_mob_level(self, index, level)
    self.mob_level_table[index] = level
end

function levelManager.remove_mob_level(self, index)
    self.mob_level_table[index] = nil
end

function levelManager.clear(self)
    self.mob_level_table:clear()
end

function levelManager.handle_outgoing_widescan(self, p)
    if self.widescan_log_enabled then
        log("広域スキャンが実行されました")
    end
    local player = windower.ffxi.get_mob_by_target('me')
    if player then
        self.state.last_scan_pos_x = player.x
        self.state.last_scan_pos_y = player.y
        self.state.last_scan_time = os.clock()
    end
end

function levelManager.handle_incoming_widescan(self, data)
    local p = packets.parse('incoming', data)
    if p['Index'] and p['Level'] then
        self:set_mob_level(p['Index'], p['Level'])
    end
end

function levelManager.handle_mob_despawn(self, data)
    local p = packets.parse('incoming', data)
    if p['Type'] and p['Type'] == "kesu" and p['Mob Index'] and self.mob_level_table[p['Mob Index']] then
        self:remove_mob_level(p['Mob Index'])
    end
end

function levelManager.handle_zone_in(self)
    coroutine.schedule(function()
        self.state.last_scan_time = nil
        self.state.last_scan_pos_x = nil
        self.state.last_scan_pos_y = nil
        self.state.scanning = false
        self.state.zoning = false
    end, 10)
end

function levelManager.handle_zone_out(self)
    self.state.last_scan_time = os.clock()
    self.state.zoning = true
    self:clear()
end

function levelManager.execute_widescan(self, periodical)
    local info = windower.ffxi.get_info()
    if not info or not info.zone then return end
    if
        self.state.scanning or
        self.state.zoning or
        self.state.cutscene or
        info.mog_house or
        self.city_ids:contains(info.zone)
    then
        return
    end

    self.state.scanning = true

    if self.state.last_scan_time and os.clock() - self.state.last_scan_time < 5 then
        self.state.scanning = false
        return
    end
    if self.state.last_scan_time and periodical and os.clock() - self.state.last_scan_time < 30 then
        self.state.scanning = false
        return
    end
    local player = windower.ffxi.get_mob_by_target('me')
    if not player then
        self.state.scanning = false
        return
    end
    if
        periodical and
        self.state.last_scan_pos_x and
        self.state.last_scan_pos_y and
        (player.x - self.state.last_scan_pos_x)^2 + (player.y - self.state.last_scan_pos_y)^2 < 10000
    then
        self.state.scanning = false
        return
    end

    self.state.last_scan_pos_x = player.x
    self.state.last_scan_pos_y = player.y
    self.state.last_scan_time = os.clock()

    if self.widescan_log_enabled then
        log("Lv取得広域スキャンを実行")
    end
    packets.inject(packets.new('outgoing', 0x0F4, {
        [ 'Flags' ]		= 1,
        [ '_unknown1' ]	= 0,
        [ '_unknown2' ]	= 0,
    }))

    self.state.scanning = false
end
return levelManager
