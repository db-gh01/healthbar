local EnmityManager = {}

EnmityManager.tracked_enmities = {}

function EnmityManager.clear(self)
    self.tracked_enmities = {}
end

function EnmityManager.get_enmity_list(self, id, clock)
    local ids = {}
    for k, v in pairs(self.tracked_enmities) do
        table.insert(ids, k)
    end
    return ids
end

function EnmityManager.get_enmity(self, id)
    return self.tracked_enmities[id]
end

function EnmityManager.track_enmity(self, act, party, callback)

    local now = os.clock()
    if self.tracked_enmities[act.actor_id] then
        self.tracked_enmities[act.actor_id].last_update = now
        return
    end

    local added = false
    local actor_is_npc = (act.actor_id > 0x1000000 and act.actor_id % 0x1000 < 0x700)
    for _, target in ipairs(act.targets) do
        if not self.tracked_enmities[target.id] then
            local target_is_npc = (target.id > 0x1000000 and target.id % 0x1000 < 0x700)
            if party:get_party_member(act.actor_id) and target_is_npc then
                if self.tracked_enmities[target.id] then
                    self.tracked_enmities[target.id].last_update = now
                else
                    self.tracked_enmities[target.id] = {target_id = act.actor_id, added = now, last_update = now}
                    added = true
                end
            end
            if actor_is_npc and party:get_party_member(target.id) then
                self.tracked_enmities[act.actor_id] = {target_id = target.id, added = now, last_update = now}
                added = true
            end
        end
    end
    if added then
        callback()
    end
end

function EnmityManager.cleanup_enmity(self)
    local deleted = false
    for id, enmity in pairs(self.tracked_enmities) do
        local mob = windower.ffxi.get_mob_by_id(id)
        if
            (not mob or mob.hpp == 0 or mob.status == 0 or mob.status == 2 or mob.distance > 2500 or not mob.valid_target) and
            os.clock() - enmity.last_update > 3
        then
            self.tracked_enmities[id] = nil
            deleted = true
        end
    end
    return deleted
end

return EnmityManager
