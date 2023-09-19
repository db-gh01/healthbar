local DebuffManager = {
    msg_ids = {
        effect_on = S{160, 164, 166, 186, 194, 203, 205, 230, 236, 266, 267, 268, 269, 237, 271, 272, 277, 278, 279, 280, 319, 320, 375, 412, 645, 754, 755, 804},
        effect_off = S{206, 64, 159, 168, 204, 206, 321, 322, 341, 342, 343, 344, 350, 378, 531, 647, 805, 806},
        damaging_spell = S{2, 252, 264, 265},
        non_damaging_spell = S{75, 236, 237, 268, 270, 271},
        died = S{6, 20, 97, 113, 406, 605, 646},
    },
    same_effect = {
        [2] = {19}
    }
}

DebuffManager.tracked_debuffs = {}

function DebuffManager.clear(self)
    self.tracked_debuffs = {}
end

function DebuffManager.get_debuff_ids(self, target_id)
    local ids = S{}
    if self.tracked_debuffs[target_id] then
        for effect, tracked in pairs(self.tracked_debuffs[target_id]) do
            ids:add(effect)
        end
    end
    return ids
end

function DebuffManager.update_player_buffs(self)
    local player = windower.ffxi.get_player()
    self.tracked_debuffs[player.id] = {}
    for _, buff in ipairs(player.buffs) do
        self.tracked_debuffs[player.id][buff] = {
            target_id = player.id,
            effect = buff
        }
    end
end

function DebuffManager.track_party_buffs(self, data)
    for k = 0, 4 do
        local member_id = data:unpack('I', k * 48 + 5)
        if member_id ~= 0 then
            self.tracked_debuffs[member_id] = {}
            for i = 1, 32 do
                local effect = data:byte(k*48+5+16+i-1) + 256 * (math.floor(data:byte(k*48+5+8 + math.floor((i-1)/4)) / 4^((i-1)%4))%4)
                if effect ~= 0 and effect ~= 255 then
                    self.tracked_debuffs[member_id][effect] = {target_id=member_id, effect=effect,}
                end
            end
        end
    end
end

function DebuffManager.track_debuff_message(self, pdata)
    local msg_id = pdata:unpack('H',0x19) % 0x8000
    local target_id = pdata:unpack('I',0x09)
    local effect = pdata:unpack('I',0x0D)
    if self.msg_ids.died:contains(msg_id) then
        self.tracked_debuffs[target_id] = {}
        return
    elseif self.msg_ids.effect_off:contains(msg_id) then
        if self.tracked_debuffs[target_id] then
            self.tracked_debuffs[target_id][effect] = nil
            if self.same_effect[effect] then
                for _, v in ipairs(self.same_effect[effect]) do
                    self.tracked_debuffs[target_id][v] = nil
                end
            end
        end
    elseif self.msg_ids.effect_on:contains(msg_id) then
        self:apply_debuff(target_id, effect, nil)
    end

end

function DebuffManager.track_debuff_action(self, act)
    for _, target in ipairs(act.targets) do
        local target_is_npc = (target.id > 0x1000000 and target.id % 0x1000 < 0x700)
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
                if effect and effect > 0 then
                    self:apply_debuff(target.id, effect, spell)
                end
            elseif self.msg_ids.effect_on:contains(target.actions[1].message) then
                local spell = act.param
                local effect = target.actions[1].param
                if effetct and effect > 0 then
                    self:apply_debuff(target.id, effect, spell)
                end
            end
        end
    end
end

function DebuffManager.apply_debuff(self, target_id, effect, spell)
    if spell then
        local new_overwrites = res.spells[spell].overwrites or {}
        for effect, tracked in pairs(self.tracked_debuffs[target_id] or {}) do
            local tracked_overwrites = tracked.spell and res.spells[tracked.spell].overwrites or {}
            for _, v in ipairs(tracked_overwrites) do
                if v == spell then
                    return
                end
            end
            for _, v in ipairs(new_overwrites) do
                if v == tracked.spell then
                    self.tracked_debuffs[target_id][effect] = nil
                end
            end
        end
    end

    if not self.tracked_debuffs[target_id] then
        self.tracked_debuffs[target_id] = {}
    end
    self.tracked_debuffs[target_id][effect] = {
        target_id = target_id,
        spell = spell,
        effect = effect,
        time = os.time(),
    }
end

return DebuffManager
