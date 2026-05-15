require 'tables'

Bar = {}

Bar.player_id = nil
Bar.party_member_ids = T{}

local TEXT_KEYS_ALL = {'name', 'hpp', 'level', 'action', 'target', 'distance'}
local TEXT_KEYS_MAIN = {'name', 'hpp', 'level', 'action'}
local TEXT_KEYS_VISIBLE_ON_SHOW = {'name', 'hpp', 'distance'}

local NAME_COLORS = {
    dead = {red = 155, green = 155, blue = 155},
    player = {red = 255, green = 255, blue = 255},
    party = {red = 102, green = 255, blue = 255},
    npc = {red = 150, green = 225, blue = 150},
    claimed_by_party = {red = 255, green = 130, blue = 130},
    unclaimed = {red = 230, green = 230, blue = 138},
    claimed_other = {red = 153, green = 102, blue = 255},
}

function Bar.set_player_id(id)
    Bar.player_id = id
end

function Bar.set_party_member_ids(members)
    Bar.party_member_ids = T(members)
end

function Bar.new(settings_show, bar_layout, bar_name)

    local o = {}

    o.texts = {}
    o.images = {}
    o.auto_widescan_enabled = false
    o.pos = {x = 0, y = 0}

    if not settings_show then
        o.enabled = false
        return setmetatable(o, {__index = Bar})
    end

    o.enabled = true
    o.layout = {}
    o.mob_id = nil
    o.mob_index = nil
    o.bar_name = bar_name
    o.visible = false
    o.debuff_ids = S{}
    o.debuff_version = -1
    o.last_hpp = nil
    o.last_distance_text = nil
    o.last_name_color_key = nil
    o.last_target_name = nil
    o.last_target_color_key = nil
    o.target_visible = false
    o.last_action = nil
    o.action_visible = false
    o.last_level = nil
    o.level_visible = false

    o.layout.width = bar_layout.width
    o.layout.height = bar_layout.height
    o.layout.texts = {}
    o.layout.texts.name = table.amend(bar_layout.texts.name, bar_layout.texts.base, true)
	o.layout.texts.hpp = table.amend(bar_layout.texts.hpp, bar_layout.texts.base, true)
	o.layout.texts.level = table.amend(bar_layout.texts.level, bar_layout.texts.base, true)
	o.layout.texts.target = table.amend(bar_layout.texts.target, bar_layout.texts.base, true)
	o.layout.texts.distance = table.amend(bar_layout.texts.distance, bar_layout.texts.base, true)
	o.layout.texts.action = table.amend(bar_layout.texts.action, bar_layout.texts.base, true)
    o.layout.images = {}
    o.layout.images.frame = bar_layout.images.frame
    o.layout.images.bg = bar_layout.images.bg
    o.layout.images.body = bar_layout.images.body
    o.layout.images.arrow = bar_layout.images.arrow
    o.layout.debuff = bar_layout.debuff

    o.images.bg_left = images.new({
        pos = {x = 0, y = 0}, visible = true, draggable = false, repeatable = {x = 1, y = 1},
        color = o.layout.images.bg.color,
        size = {width = o.layout.images.bg.image_left.width, height = o.layout.height},
        texture = {path = windower.addon_path .. o.layout.images.bg.image_left.texture, fit = false},
    })
    o.images.bg_center = images.new({
        pos = {x = 0, y = 0}, visible = true, draggable = false, repeatable = {x = 1, y = 1},
        color = o.layout.images.bg.color,
        size = {width = o.layout.width, height = o.layout.height},
        texture = {path = windower.addon_path .. o.layout.images.bg.image_center.texture, fit = false},
    })
    o.images.bg_right = images.new({
        pos = {x = 0, y = 0}, visible = true, draggable = false, repeatable = {x = 1, y = 1},
        color = o.layout.images.bg.color,
        size = {width = o.layout.images.bg.image_right.width, height = o.layout.height},
        texture = {path = windower.addon_path .. o.layout.images.bg.image_right.texture, fit = false},
    })
    o.images.frame_left = images.new({
        pos = {x = 0, y = 0}, visible = true, draggable = false, repeatable = {x = 1, y = 1},
        color = o.layout.images.frame.color,
        size = {width = o.layout.images.frame.image_left.width, height = o.layout.height},
        texture = {path = windower.addon_path .. o.layout.images.frame.image_left.texture, fit = false},
    })
    o.images.frame_center = images.new({
        pos = {x = 0, y = 0}, visible = true, draggable = false, repeatable = {x = 1, y = 1},
        color = o.layout.images.frame.color,
        size = {width = o.layout.width, height = o.layout.height},
        texture = {path = windower.addon_path .. o.layout.images.frame.image_center.texture, fit = false},
    })
    o.images.frame_right = images.new({
        pos = {x = 0, y = 0}, visible = true, draggable = false, repeatable = {x = 1, y = 1},
        color = o.layout.images.frame.color,
        size = {width = o.layout.images.frame.image_right.width, height = o.layout.height},
        texture = {path = windower.addon_path .. o.layout.images.frame.image_right.texture, fit = false},
    })
    o.images.body = images.new({
        pos = { x = 0, y = 0 }, visible = true, draggable = false, repeatable = {x = 1, y = 1},
        color = o.layout.images.body.color,
        size = {width = o.layout.width, height = o.layout.height},
        texture = {path = windower.addon_path .. o.layout.images.body.image.texture, fit = false},
    })
    o.images.arrow = images.new({
        pos = { x = 0, y = 0 }, visible = true, draggable = false, repeatable = {x = 1, y = 1},
        color = o.layout.images.arrow.color,
        size = {width = o.layout.images.arrow.image.width, height = o.layout.images.arrow.image.height},
        texture = {path = windower.addon_path .. o.layout.images.arrow.image.texture, fit = false},
    })

	o.debuff_icons = {}
	for i = 1, o.layout.debuff.count do
		o.debuff_icons[i] = images.new({
			pos = {x = 0, y = 0}, visible = true, draggable = false, repeatable = {x = 1, y = 1},
            color = {alpha = 255, red = 255, green = 255, blue = 255},
            size = {width = o.layout.debuff.icon_size, height = o.layout.debuff.icon_size},
            texture = {fit = false},
		})
	end

    for k, v in pairs({
        name = '${name|(TargetName)}',
        hpp = '${hpp|(100)}%',
        level = 'Lv${level|(???)}',
        action = '${action|(ActionText)}',
        target = '${target|(Target)}',
        distance = '${distance|(0.0)}\'',
    }) do
        o.texts[k] = texts.new(v, {
            pos = {x = 100, y = 100},
            text = table.copy(o.layout.texts[k].text),
            flags = o.layout.texts[k].flags,
            bg = table.copy(o.layout.texts[k].bg),
        })
    end

	return setmetatable(o, {__index = Bar})
end

function Bar.destroy(self)
    setmetatable(self, {__index = nil})
    for _, image in ipairs(self.images) do
        image:destroy()
    end
    for _, text in ipairs(self.texts) do
        text:destroy()
    end
end

function Bar.enable_auto_widescan(self)
    if not self.enabled then return end
    self.auto_widescan_enabled = true
end

function Bar.disable_auto_widescan(self)
    if not self.enabled then return end
    self.auto_widescan_enabled = false
end

function Bar.predraw(self)
    if not self.enabled then return end
    self.images.bg_left:hide()
    self.images.bg_center:hide()
    self.images.bg_right:hide()
    self.images.frame_left:hide()
    self.images.frame_center:hide()
    self.images.frame_right:hide()
    self.images.body:hide()
    self.images.arrow:hide()
    for _, k in ipairs(TEXT_KEYS_ALL) do
        if self.layout.texts[k].show then
            self.texts[k]:bg_transparency(1)
            self.texts[k]:transparency(1)
            self.texts[k]:stroke_transparency(1)
            self.texts[k]:show()
        end
    end
end

function Bar.store_extents(self)
    if not self.enabled then return end
    for _, k in ipairs(TEXT_KEYS_ALL) do
        if self.layout.texts[k].show then
            self.layout.texts[k].extents = {}
            self.layout.texts[k].extents.x, self.layout.texts[k].extents.y = self.texts[k]:extents()
        end
    end
end

function Bar.postdraw(self)
    if not self.enabled then return end
    for _, k in ipairs(TEXT_KEYS_ALL) do
        if self.layout.texts[k].show then
            self.texts[k]:hide()
            self.texts[k]:bg_alpha(self.layout.texts[k].bg.alpha)
            self.texts[k]:alpha(self.layout.texts[k].text.alpha)
            self.texts[k]:stroke_alpha(self.layout.texts[k].text.stroke.alpha)
        end
    end
end

function Bar.pos_x(self)
    return self.pos.x
end
function Bar.pos_y(self)
    return self.pos.y
end

function Bar.set_position(self, x, y)
    self.pos.x = x
    self.pos.y = y
    if not self.enabled then return end
    local windower_settings = windower.get_windower_settings()
    for _, k in ipairs(TEXT_KEYS_MAIN) do
        if self.layout.texts[k].show then
            local tx, ty
            if self.layout.texts[k].flags.right then
                tx = -(windower_settings.ui_x_res - self.pos.x) + self.layout.width + self.layout.texts[k].offset.x
            else
                tx = self.pos.x + self.layout.texts[k].offset.x
            end
            if self.layout.texts[k].flags.bottom then
                ty = -(windower_settings.ui_y_res - self.pos.y) - self.layout.texts[k].extents.y + self.layout.texts[k].offset.y
            else
                ty = self.pos.y + self.layout.height + self.layout.texts[k].offset.y
            end
            self.texts[k]:pos(tx, ty)
        end
    end
    if self.layout.texts.distance.show then
        self.texts.distance:pos(
            -(windower_settings.ui_x_res - self.pos.x) + self.layout.texts.distance.offset.x,
            self.pos.y + self.layout.height/2 - self.layout.texts.distance.extents.y/2 + self.layout.texts.distance.offset.y
        )
    end
    if self.layout.texts.target.show then
        self.texts.target:pos(
            self.pos.x + self.layout.width + self.layout.texts.target.offset.x,
            self.pos.y + self.layout.height/2 - self.layout.texts.target.extents.y/2 + self.layout.texts.target.offset.y
        )
    end

    self.images.bg_left:pos(x - self.layout.images.bg.image_left.width, y)
    self.images.bg_center:pos(x, y)
    self.images.bg_right:pos(x + self.layout.width, y)
    self.images.frame_left:pos(x - self.layout.images.frame.image_left.width, y)
    self.images.frame_center:pos(x, y)
    self.images.frame_right:pos(x + self.layout.width, y)
    self.images.body:pos(x, y)
    if self.layout.texts.target.show then
        self.images.arrow:pos(
            self.pos.x + self.layout.width + self.layout.images.arrow.offset.x,
            self.pos.y + self.layout.height/2 - self.layout.images.arrow.image.height/2 + self.layout.images.arrow.offset.y
        )
    end
    if self.layout.debuff.show then
        for i = 1, self.layout.debuff.count do
            local x = 0
            if self.layout.debuff.right_to_left then
                x = self.pos.x + self.layout.width + self.layout.debuff.offset.x - (i-1) * (self.layout.debuff.icon_size + self.layout.debuff.padding)
            else
                x = self.pos.x + self.layout.debuff.offset.x + (i-1) * (self.layout.debuff.icon_size + self.layout.debuff.padding)
            end
            self.debuff_icons[i]:pos(x, self.pos.y + self.layout.height + self.layout.debuff.offset.y)
        end
    end
end

function Bar.show(self)
    if not self.enabled then return end
    self.images.bg_left:show()
    self.images.bg_center:show()
    self.images.bg_right:show()
    self.images.frame_left:show()
    self.images.frame_center:show()
    self.images.frame_right:show()
    self.images.body:show()
    for _, k in ipairs(TEXT_KEYS_VISIBLE_ON_SHOW) do
        if self.layout.texts[k].show then
            self.texts[k]:show()
        end
    end
    if self.layout.debuff.show then
        self:show_debuff_icons(self.debuff_ids)
    end
    self.visible = true
end

function Bar.hide(self)
    if not self.enabled then return end
    self.images.bg_left:hide()
    self.images.bg_center:hide()
    self.images.bg_right:hide()
    self.images.frame_left:hide()
    self.images.frame_center:hide()
    self.images.frame_right:hide()
    self.images.body:hide()
    self.images.arrow:hide()
    for _, k in ipairs(TEXT_KEYS_ALL) do
        if self.layout.texts[k].show then
            self.texts[k]:hide()
        end
    end
    self:hide_debuff_icons()
    self.target_visible = false
    self.action_visible = false
    self.level_visible = false
    self.visible = false
end

function Bar.hide_debuff_icons(self)
    if not self.enabled then return end
    for i = 1, self.layout.debuff.count do
        self.debuff_icons[i]:hide()
    end
end

function Bar.show_debuff_icons(self, debuff_ids)
    if not self.enabled then return end
    local i = 1
    for k, id in ipairs(debuff_ids:sort()) do
        if i > self.layout.debuff.count then break end
        self.debuff_icons[i]:path(windower.addon_path .. 'assets/icons/' .. tostring(id) .. '.png')
        self.debuff_icons[i]:show()
        i = i + 1
    end
    for j = i, self.layout.debuff.count do
        self.debuff_icons[j]:hide()
    end
end

function Bar.set_text_color(self, color)
    if not self.enabled then return end
    for _, k in ipairs(TEXT_KEYS_MAIN) do
        if self.layout.texts[k].show then
            self.texts[k]:color(color.red, color.green, color.blue)
        end
    end
end

function Bar.setup_dummy(self)
    if not self.enabled then return end
    self.texts.name.name = self.bar_name
    if self.layout.texts.hpp.show then
        local hpp = math.random(1, 100)
        self.texts.hpp.hpp = hpp
        self.texts.hpp:show()
        self.images.body:width(self.layout.width * (hpp / 100))
    end
    if self.layout.texts.level.show then
        self.texts.level.level = math.random(50, 150)
        self.texts.level:show()
    end
    if self.layout.texts.action.show then
        self.texts.action.action = "Action"
        self.texts.action:show()
    end
    if self.layout.texts.distance.show then
        self.texts.distance.distance = string.format('%.1f', math.random(1, 50))
        self.texts.distance:show()
    end
    if self.layout.texts.target.show then
        self.texts.target.target = "Target"
        self.texts.target:show()
        self.images.arrow:show()
    end
    self.debuff_ids = S{2, 4, 6, 7, 10, 13, 21, 148, 404}
end

function Bar.update_all(self)
    if not self.enabled then return end
    if not self.mob_id then return end
    local mob = windower.ffxi.get_mob_by_id(self.mob_id)
    if not mob then return end
    self.texts.name.name = mob.name
    self:update_frequent()
end

function Bar.update_frequent(self)
    if not self.enabled then return end
    if not self.mob_id then return end
    local mob = windower.ffxi.get_mob_by_id(self.mob_id)
    if not mob then return end
    if self.last_hpp ~= mob.hpp then
        self.last_hpp = mob.hpp
        self.texts.hpp.hpp = mob.hpp
        self.images.body:width(self.layout.width * (mob.hpp / 100))
    end

    local distance_text = string.format('%.1f', math.sqrt(mob.distance))
    if self.last_distance_text ~= distance_text then
        self.last_distance_text = distance_text
        self.texts.distance.distance = distance_text
    end

    local color_key = self:get_name_color_key_by_type(mob)
    if self.last_name_color_key ~= color_key then
        self.last_name_color_key = color_key
        self:set_text_color(NAME_COLORS[color_key])
    end
end

function Bar.update_target(self, enmity_manager)
    if not self.enabled then return end
    if not self.layout.texts.target.show then return end
    if not self.mob_id then return end

    local target_name = nil
    local target_color = nil
    local target_color_key = nil
    local target_mob = nil
    local enmity_target = enmity_manager:get_enmity(self.mob_id)
    if enmity_target and enmity_target.target_id then
        target_mob = windower.ffxi.get_mob_by_id(enmity_target.target_id)
        if target_mob then
            target_name = target_mob.name
            target_color_key = self:get_name_color_key_by_type(target_mob)
            target_color = NAME_COLORS[target_color_key]
        end
    else
        local mob = windower.ffxi.get_mob_by_id(self.mob_id)
        if mob then
            local target_index = mob.target_index
            if target_index and target_index ~= 0 then
                target_mob = windower.ffxi.get_mob_by_index(target_index)
                if target_mob then
                    target_name = target_mob.name
                    target_color_key = self:get_name_color_key_by_type(target_mob)
                    target_color = NAME_COLORS[target_color_key]
                end
            end
        end
    end

    if target_name then
        if self.last_target_name ~= target_name then
            self.last_target_name = target_name
            self.texts.target.target = target_name
        end
        if self.last_target_color_key ~= target_color_key then
            self.last_target_color_key = target_color_key
            self.texts.target:color(target_color.red, target_color.green, target_color.blue)
        end
        if not self.target_visible then
            self.texts.target:show()
            self.images.arrow:show()
            self.target_visible = true
        end
    else
        if self.target_visible then
            self.texts.target:hide()
            self.images.arrow:hide()
            self.target_visible = false
        end
        self.last_target_name = nil
        self.last_target_color_key = nil
    end
end

function Bar.update_debuff(self, debuff_manager)
    if not self.enabled then return end
    if not self.layout.debuff.show then return end
    local version = debuff_manager:get_debuff_version(self.mob_id)
    if self.debuff_version == version then
        return
    end
    self.debuff_version = version
    local debuff_ids = debuff_manager:get_debuff_ids(self.mob_id)
    if self.debuff_ids:equals(debuff_ids) then return end
    self.debuff_ids = debuff_ids
    self:show_debuff_icons(self.debuff_ids)
end

function Bar.update_action(self, action_manager, clock)
    if not self.enabled then return end
    if not self.layout.texts.action.show then return end
    local action = action_manager:get_mob_action(self.mob_id, clock)
    if action then
        if self.last_action ~= action then
            self.last_action = action
            self.texts.action.action = action
        end
        if not self.action_visible then
            self.texts.action:show()
            self.action_visible = true
        end
    else
        if self.action_visible then
            self.last_action = nil
            self.texts.action.action = ""
            self.texts.action:hide()
            self.action_visible = false
        end
    end
end

function Bar.update_level(self, level_manager)
    if not self.enabled then return end
    if not self.layout.texts.level.show then return end
    if not self.mob_id then return end
    -- local index = self.mob_id % 0x1000

    local level = nil
    if self.mob_is_monster then
        level = level_manager:get_mob_level(self.mob_index)
        if not level and self.auto_widescan_enabled then
            level_manager:execute_widescan()
        end
    end

    if level and level > 0 then
        if self.last_level ~= level then
            self.last_level = level
            self.texts.level.level = level
        end
        if not self.level_visible then
            self.texts.level:show()
            self.level_visible = true
        end
    else
        if self.level_visible then
            self.texts.level:hide()
            self.level_visible = false
        end
        self.last_level = nil
    end
end

function Bar.set_mob(self, mob_id)
    if not self.enabled then return end
    self.mob_id = mob_id
    if mob_id then
        local mob = windower.ffxi.get_mob_by_id(mob_id)
        self.mob_index = mob and mob.index or nil
        self.mob_is_monster = (mob and (bit.band(mob.spawn_type, 0x0010) == 0x0010))
    else
        self.mob_index = nil
        self.mob_is_monster = false
    end
    self.debuff_ids = S{}
    self.debuff_version = -1
    self.last_hpp = nil
    self.last_distance_text = nil
    self.last_name_color_key = nil

    if self.layout.texts.target.show then
        self.texts.target.target = ""
        self.texts.target:hide()
        self.images.arrow:hide()
    end
    if self.layout.texts.action.show then
        self.texts.action.action = ""
        self.texts.action:hide()
    end
    if self.layout.texts.level.show then
        self.texts.level.level = ""
        self.texts.level:hide()
    end
    if self.layout.debuff.show then
        self:hide_debuff_icons()
    end

    self.last_target_name = nil
    self.last_target_color_key = nil
    self.target_visible = false
    self.last_action = nil
    self.action_visible = false
    self.last_level = nil
    self.level_visible = false
    self:update_all()
end

function Bar.is_visible(self)
    return self.visible
end


--[[
spawn_type:
bit 1    PC
bit 2    NPC
bit 3    Party
bit 4    Alliance
bit 5    Monster
bit 6    No Nameplate (interactables like Doors, ???, etc)
]]
function Bar.get_name_color_by_type(self, mob)
    return NAME_COLORS[self:get_name_color_key_by_type(mob)]
end

function Bar.get_name_color_key_by_type(self, mob)
    if mob.hpp == 0 then
        return 'dead'
    elseif mob.id == Bar.player_id then
        return 'player'
    elseif Bar.party_member_ids:contains(mob.id) then
        return 'party'
    elseif not mob.is_npc then
        return 'player'
    elseif bit.band(mob.spawn_type, 0x0002) == 2 then
        return 'npc'
    elseif Bar.party_member_ids:contains(mob.claim_id) then
        return 'claimed_by_party'
    elseif mob.claim_id == 0 then
        return 'unclaimed'
    else
        return 'claimed_other'
    end
end

function Bar.hover(self, x, y)
    if not self.enabled then return false end
    for k, obj in pairs(self.texts) do
        if obj:hover(x, y) then return true end
    end
    for k, obj in pairs(self.images) do
        if obj:hover(x, y) then return true end
    end
    return false
end

return Bar
