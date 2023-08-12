local PartyManager = {}

PartyManager.party_members = {}

function PartyManager.update_party_members(self)
    local party = windower.ffxi.get_party()
    if not party then return end
    self.party_members = {}
    for _, t in ipairs({'p', 'a1', 'a2'}) do
        for i = 0, 5 do
            local member = party[t .. i]
            if member and member.mob then
                self.party_members[member.mob.id] = {
                    is_pc = true,
                    is_pet = false,
                    owner = nil
                }
                if member.mob.pet_index then
                    local pet = windower.ffxi.get_mob_by_index(member.mob.pet_index)
                    self.party_members[pet.id] = {
                        is_pc = false,
                        is_pet = true,
                        owner = member.id
                    }
                end
            end
        end
    end
end

function PartyManager.handle_pet_info(self, pet_id, owner_id)
    if owner_id and self.party_members[owner_id] then
        self.party_members[pet_id] = {
            is_pc = false,
            is_pet = true,
            owner = owner_id
        }
    end
end

function PartyManager.get_party_member(self, id)
    return self.party_members[id]
end

function PartyManager.get_party_member_ids(self)
    local ids = {}
    for k, v in pairs(self.party_members) do
        table.insert(ids, k)
    end
    return ids
end

return PartyManager
