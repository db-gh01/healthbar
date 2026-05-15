local DebuffManager = {
    msg_ids = {
        effect_on = S{160, 164, 166, 186, 194, 203, 205, 230, 236, 266, 267, 268, 269, 237, 271, 272, 277, 278, 279, 280, 319, 320, 375, 412, 645, 754, 755, 804},
        effect_off = S{206, 64, 159, 168, 204, 206, 321, 322, 341, 342, 343, 344, 350, 378, 531, 647, 805, 806},
        damaging_spell = S{2, 252, 264, 265},
        non_damaging_spell = S{75, 236, 237, 268, 270, 271},
        died = S{6, 20, 97, 113, 406, 605, 646},
        no_effect = S{75, 156, 323}
    },
    same_effect = {
        [2] = {19, 193},
    }
}

DebuffManager.tracked_debuffs = {}
DebuffManager.debuff_versions = {}
local POW4 = {1, 4, 16, 64}

local function bump_version(self, target_id)
    self.debuff_versions[target_id] = (self.debuff_versions[target_id] or 0) + 1
end

function DebuffManager.clear(self)
    self.tracked_debuffs = {}
    self.debuff_versions = {}
end

function DebuffManager.get_debuff_version(self, target_id)
    return self.debuff_versions[target_id] or 0
end

function DebuffManager.get_debuff_ids(self, target_id)
    local ids = T{}
    if self.tracked_debuffs[target_id] then
        for _, tracked in ipairs(self.tracked_debuffs[target_id]) do
            ids:append(tracked.buff_id)
        end
    end
    return ids
end

function DebuffManager.update_player_buffs(self)
    local player = windower.ffxi.get_player()
    if not player then return end
    self.tracked_debuffs[player.id] = {}
    local c = 1
    for _, buff in ipairs(player.buffs) do
        self.tracked_debuffs[player.id][c] = {target_id=player.id, buff_id=buff}
        c = c + 1
    end
    bump_version(self, player.id)
end

function DebuffManager.track_party_buffs(self, data)
    local floor = math.floor
    for k = 0, 4 do
        local base = k * 48 + 5
        local member_id = data:unpack('I', base)
        if member_id ~= 0 then
            self.tracked_debuffs[member_id] = {}
            local c = 1
            for i = 0, 31 do
                local low = data:byte(base + 16 + i)
                local high = floor(data:byte(base + 8 + floor(i / 4)) / POW4[(i % 4) + 1]) % 4
                local effect = low + 256 * high
                if effect ~= 0 and effect ~= 255 then
                    self.tracked_debuffs[member_id][c] = {target_id=member_id, buff_id=effect,}
                    c = c + 1
                end
            end
            bump_version(self, member_id)
        end
    end
end

function DebuffManager.track_debuff_message(self, pdata)
    local msg_id = pdata:unpack('H',0x19) % 0x8000
    local target_id = pdata:unpack('I',0x09)
    local effect = pdata:unpack('I',0x0D)
    if self.msg_ids.died:contains(msg_id) then
        if self.tracked_debuffs[target_id] then
            bump_version(self, target_id)
        end
        self.tracked_debuffs[target_id] = nil
        return
    elseif self.msg_ids.effect_off:contains(msg_id) then
        if self.tracked_debuffs[target_id] then
            local removed = false
            for i = 1, #self.tracked_debuffs[target_id] do
                if self.tracked_debuffs[target_id][i].buff_id == effect then
                    table.remove(self.tracked_debuffs[target_id], i)
                    removed = true
                    break
                end
                if self.same_effect[effect] then
                    local remove = nil
                    for _, v in ipairs(self.same_effect[effect]) do
                        if self.tracked_debuffs[target_id][i].buff_id == v then
                            remove = i
                        end
                    end
                    if remove then
                        table.remove(self.tracked_debuffs[target_id], remove)
                        removed = true
                        break
                    end
                end
            end
            if removed then
                bump_version(self, target_id)
            end
        end
    elseif self.msg_ids.effect_on:contains(msg_id) then
        self:apply_debuff(target_id, effect, nil)
    end

end

function DebuffManager.track_debuff_action(self, act)
    local spell = act.param
    for _, target in ipairs(act.targets) do
        local target_is_npc = (target.id > 0x1000000 and (target.id % 0x1000 < 0x700 or target.id %  0x1000 >= 2048))
        if target_is_npc then
            if self.msg_ids.damaging_spell:contains(target.actions[1].message) then
                local spell = act.param
                local effect = res.spells[spell] and res.spells[spell].status or nil
                if effect then
                    self:apply_debuff(target.id, effect, spell)
                end
            elseif self.msg_ids.non_damaging_spell:contains(target.actions[1].message) then
                local spell = act.param
                local effect = target.actions[1].param
                if self.msg_ids.no_effect:contains(target.actions[1].message) then
                    return
                end
                if effect and effect > 0 then
                    self:apply_debuff(target.id, effect, spell)
                end
            elseif self.msg_ids.effect_on:contains(target.actions[1].message) then
                local spell = act.param
                local effect = target.actions[1].param
                if effect and effect > 0 then
                    self:apply_debuff(target.id, effect, spell)
                end
            end
        end
    end
end

function DebuffManager.apply_debuff(self, target_id, effect, spell)
    local tracked = self.tracked_debuffs[target_id]
    if not tracked then
        tracked = {}
        self.tracked_debuffs[target_id] = tracked
    end

    if spell then
        local spell_res = res.spells[spell]
        local new_overwrites = spell_res and spell_res.overwrites or {}
        for i = #tracked, 1, -1 do
            local tracked_debuff = tracked[i]
            if tracked_debuff.buff_id == effect then
                return
            end
            local tracked_spell = tracked_debuff.spell
            local tracked_overwrites = tracked_spell and res.spells[tracked_spell] and res.spells[tracked_spell].overwrites or {}
            for _, v in ipairs(tracked_overwrites) do
                if v == spell then
                    return
                end
            end
            for _, v in ipairs(new_overwrites) do
                if v == tracked_spell then
                    table.remove(tracked, i)
                    break
                end
            end
        end
    else
        for _, tracked_debuff in ipairs(tracked) do
            if tracked_debuff.buff_id == effect then
                return
            end
        end
    end

    table.insert(tracked, {
        target_id = target_id,
        spell = spell,
        buff_id = effect,
        time = os.time(),
    })
    bump_version(self, target_id)
end

return DebuffManager
