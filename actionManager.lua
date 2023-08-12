res = require('resources')

local ActionManager = {}

ActionManager.tracked_actions = {}

ActionManager.msg_ids = {}
ActionManager.msg_ids.ability = S{}
ActionManager.msg_ids.tp_move = S{}
for id, m in pairs(res.action_messages) do
    if m.en:match("\${ability}") then
        ActionManager.msg_ids.ability:add(id)
    end
    if m.en:match("\${weapon_skill}") then
        ActionManager.msg_ids.tp_move:add(id)
    end
end

function ActionManager.clear(self)
    self.tracked_actions = {}
end

function ActionManager.get_mob_action(self, id, clock)
    local clock = clock or os.clock()
    if self.tracked_actions[id] then
        if self.tracked_actions[id].immediately then
            if clock - self.tracked_actions[id].begin < 4 then
                return self.tracked_actions[id].action.name
            else
                self.tracked_actions[id] = nil
                return nil
            end
        else
            if self.tracked_actions[id].finish then
                if clock - self.tracked_actions[id].finish < 4 then
                    return self.tracked_actions[id].action.name
                else
                    self.tracked_actions[id] = nil
                    return nil
                end
            else
                return self.tracked_actions[id].action.name
            end
        end
    else
        return nil
    end
end

function ActionManager.track_action(self, act)

    local actor_is_pc = (act.actor_id < 0x1000000)
    local actor_is_pet = (act.actor_id > 0x1000000 and act.actor_id % 0x1000 > 0x700)

    local action = nil
    local action_id = nil
    local msg_id = nil
    local immediately = false
    local interrupted = false
    local begin = nil
    local finish = nil

    -- 06: Use job ability
    if act.category == 6 then
        action_id = act.param
        action = res.job_abilities[act.param]
        immediately = true
        begin = os.clock()
    -- 14: Unblinkable job ability
    elseif act.category == 14 then
        action_id = act.param
        action = res.job_abilities[act.param]
        immediately = true
        begin = os.clock()
    -- 07: Begin weapon skill or TP move
    elseif act.category == 7 then
        action_id = act.targets[1].actions[1].param
        msg_id = act.targets[1].actions[1].message
        if actor_is_pc then
            action = res.weapon_skills[action_id]
        elseif self.msg_ids.ability:contains(msg_id) then
            action = res.job_abilities[action_id]
        else
            action = res.monster_abilities[action_id]
        end
        begin = os.clock()
        if act.param == 28787 then
            interrupted = true
        end
    -- 08: Begin spell casting or interrupt casting
    elseif act.category == 8 then
        action_id = act.targets[1].actions[1].param
        action = res.spells[action_id]
        begin = os.clock()
        if act.param == 28787 then
            interrupted = true
        end
    -- 09: Begin item use or interrupt usage
    elseif act.category == 9 then
        action_id = act.targets[1].actions[1].param
        action = res.items[action_id]
        begin = os.clock()
        if act.param == 28787 then
            interrupted = true
        end
    -- 12: Begin ranged attack
    elseif act.category == 12 then
        action_id = 272
        action = res.monster_abilities[action_id]
        begin = os.clock()
    -- 02: Finish ranged attack
    elseif act.category == 2 then
        action_id = 272
        action = res.monster_abilities[action_id]
        finish = os.clock()
    -- 03: Finish weapon skill
    elseif act.category == 3 then
        action_id = act.param
        if actor_is_pc then
            action = res.weapon_skills[action_id]
        else
            action = res.monster_abilities[action_id]
        end
        finish = os.clock()
    -- 04: Finish spell casting
    elseif act.category == 4 then
        action_id = act.param
        action = res.spells[action_id]
        finish = os.clock()
    -- 05: Finish item use
    elseif act.category == 5 then
        action_id = act.param
        action = res.items[action_id]
        finish = os.clock()
    -- 11: Finish TP move
    elseif act.category == 11 then
        action_id = act.param
        if actor_is_pc then
            action = res.job_abilities[action_id]
        else
            action = res.monster_abilities[action_id]
        end
        finish = os.clock()
    -- 13: Pet completes ability/WS
    elseif act.category == 13 then
        action_id = act.param
        msg_id = act.targets[1].actions[1].message
        if self.msg_ids.ability:contains(msg_id) then
            action = res.job_abilities[action_id]
        else
            action = res.monster_abilities[action_id]
        end
        finish = os.clock()
    end

    --print(act.category, act.param, action_id, action and action.name, interrupted)

    if interrupted then
        self.tracked_actions[act.actor_id] = nil
    elseif action_id and action and finish then
        if
            self.tracked_actions[act.actor_id] and
            self.tracked_actions[act.actor_id].action_id == action_id
        then
            self.tracked_actions[act.actor_id].finish = finish
        else
            self.tracked_actions[act.actor_id] = {
                target_id = act.targets[1].id,
                action_id = action_id,
                action = action,
                finish = finish,
                immediately = immediately,
            }
        end
    elseif action_id and action and begin then
        self.tracked_actions[act.actor_id] = {
            target_id = act.targets[1].id,
            action_id = action_id,
            action = action,
            begin = begin,
            immediately = immediately,
        }
    end

end

return ActionManager
