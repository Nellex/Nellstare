local error_wrapper = require('lib.tools.error_wrapper')
local json = require('cjson')
local lib_auth = require('lib.tools.lib_auth')
local wpgsql = require('lib.db.wpgsql')

local lib_menu = {
    __name = 'lib_menu'
}

function lib_menu:chk_category(db, parent, category)
    local category_chk = db:execparams(
        [[SELECT id FROM hub.menu_categories WHERE (category_name -> 'parent' ->> 'en') = $1 AND (category_name -> 'category' ->> 'en') = $2]],
        parent,
        category
    )

    if (category_chk ~= db.select_ok) then
        return false, error_wrapper:new(self, 'SQL exec error: ' .. tostring(category_chk))
    end

    local category = db:to_obj()

    if (category and #category == 1) then
        return tonumber(category[1]['id'])
    end

    return false, error_wrapper:new(self, 'category not found')
end

function lib_menu:add_category(db, menu_item)
    if (type(menu_item) ~= 'table') then
        return false, error_wrapper:new(self, 'menu_item must be a table')
    end

    if (menu_item.parent.en == menu_item.category.en) then
        return false, error_wrapper:new(self, 'Parent category can\'t be named as menu item category')
    end

    local category_id, category_id_err = self:chk_category(db, menu_item.parent.en, menu_item.category.en)

    if category_id then
        return category_id
    end

    local category_add = db:execparams(
        'INSERT INTO hub.menu_categories (category_name) VALUES ($1)',
        json.encode({
            ['parent'] = menu_item.parent,
            ['category'] = menu_item.category,
        })
    )

    if (category_add ~= db.insert_ok) then
        return false, error_wrapper:new(self, 'SQL exec error: ' .. tostring(category_add))
    end

    return self:chk_category(db, menu_item.parent.en, menu_item.category.en)
end

function lib_menu:del_category(db, parent, category)
    local category_id, category_id_err = self:chk_category(db, parent, category)

    if (not category_id) then
        return false, error_wrapper:chain(self, category_id_err)
    end

    db:bind('hub', 'menu_categories')
    db:where('=', 'id', category_id)
    local category_del = db:delete()

    if (category_del ~= db.insert_ok) then
        return false, error_wrapper:new(self, 'SQL exec error: ' .. tostring(category_del))
    end

    return true
end

function lib_menu:iusd_category(db, parent, category)
    local category_id, category_id_err = self:chk_category(db, parent, category)

    if (not category_id) then
        return false, error_wrapper:chain(self, category_id_err)
    end

    local category_iusd = db:execparams(
        'SELECT id FROM hub.menu WHERE category_id = $1',
        category_id
    )

    if (category_iusd ~= db.select_ok) then
        return false, error_wrapper:new(self, 'SQL exec error: ' .. tostring(category_iusd))
    end
    
    if db:to_obj() then
        return true
    end

    return false, false
end

function lib_menu:chk_item(db, item_name, unit_id)
    local menu_item_chk = db:execparams(
        [[SELECT id FROM hub.menu WHERE (item_name ->> 'en') = $1 AND unit_id = $2]],
        item_name,
        unit_id
    )

    if (menu_item_chk ~= db.select_ok) then
        return false, error_wrapper:new(self, 'SQL exec error: ' .. tostring(menu_item_chk))
    end

    local item = db:to_obj()

    if (item and #item == 1) then
        return tonumber(item[1]['id'])
    end

    return false, error_wrapper:new(self, 'Menu item "' .. item_name .. '" not found')
end

function lib_menu:add_item(db, menu_item, unit_name)
    local unit_id = lib_auth:chk_unit(db, unit_name)

    if (not unit_id) then
        return false, error_wrapper:new(self, 'Unit \"' .. unit_name .. '\" not found')
    end

    local menu_item_id, menu_item_id_err = self:chk_item(db, menu_item.item.en, unit_id)

    if menu_item_id then
        return menu_item_id
    end

    local category_id, category_id_err = self:chk_category(db, menu_item.parent.en, menu_item.category.en)
    
    if (not category_id) then
        return false, error_wrapper:chain(self, category_id_err)
    end

    local menu_item_add = db:execparams(
        'INSERT INTO hub.menu (category_id, unit_id, item_name) VALUES ($1, $2, $3)',
        category_id,
        unit_id,
        json.encode(menu_item.item)
    )

    if (menu_item_add ~= db.insert_ok) then
        return false
    end

    return self:chk_item(db, menu_item.item.en, unit_id)
end

function lib_menu:del_item(db, item_name, unit_name)
    local unit_id = lib_auth:chk_unit(db, unit_name)

    if (not unit_id) then
        return false, error_wrapper:new(self, 'Unit \"' .. unit_name .. '\" not found')
    end

    local menu_item_del = db:execparams(
        [[DELETE FROM hub.menu WHERE (item_name ->> 'en') = $1 AND unit_id = $2]],
        item_name,
        unit_id
    )

    if (menu_item_del ~= db.insert_ok) then
        return false, error_wrapper:new(self, 'SQL exec error: ' .. tostring(menu_item_del))
    end

    return true
end

return lib_menu