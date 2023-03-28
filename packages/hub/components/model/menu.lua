do
    local packages_list_st, packages_list_st_err = load_module('hub.packages_list')

    if (not packages_list_st) then
        error(packages_list_st_err, 0)
    end

    wpgsql = require('lib.db.wpgsql')
    hub_db = wpgsql:new()
    
    local conn_ok, conn_err = hub_db:connect(
        config.db_host,
        config.db_port,
        config.db_user,
        config.db_password,
        config.db_name
    )

    if (not conn_ok) then
        error(conn_err, 1)
    end

    local res = {}
    local db_objects = {}
    menu = {}

    function menu:get_units()
        local usr_id = tonumber(id())

        if (not usr_id) then
            return false
        end

        res.units = hub_db:execparams(
                string.format([[SELECT * 
                FROM auth.units
                WHERE id IN (
                    SELECT unit_id
                    FROM auth.groups_policies
                    WHERE grp_id IN (SELECT grp_id FROM auth.users_groups WHERE usr_id = $1) AND (r_p = true OR w_p = true)
                ) AND unit_name IN (%s);]],
                hub_db:list_arr(packages_list)
            ),
            usr_id
        )

        if (res.units == hub_db.select_ok) then
            return hub_db:to_obj()
        end

        return false
    end

    function menu:get_items(units)
        hub_db:add_param(config.lang)
        local units_list = hub_db:list_obj_params(units, 'id')

        if (not units_list) then return false end

        res.menu = hub_db:execparams(
            "SELECT id, category_id, unit_id, (item_name ->> $1) AS title,  (item_name ->> 'icon') AS icon FROM hub.menu WHERE unit_id IN" .. units_list,
            table.unpack(hub_db.params)
        )

        if (res.menu == hub_db.select_ok) then
            return hub_db:to_obj()
        end

        return false
    end

    function menu:get_categories(items)
        hub_db:add_param(config.lang)
        local categories_list = hub_db:list_obj_params(items, 'category_id')

        if (not categories_list) then
            return false
        end

        res.categories = hub_db:execparams(
            [[WITH RECURSIVE r AS (
                SELECT id, (category_name -> 'parent' ->> $1) AS parent, (category_name -> 'category' ->> $1) AS category, (category_name -> 'category' ->> 'icon') AS icon
                FROM hub.menu_categories
                WHERE id IN ]] .. categories_list .. [[
            
                UNION
            
                SELECT menu_categories.id, (menu_categories.category_name -> 'parent' ->> $1) AS parent, (menu_categories.category_name -> 'category' ->> $1) AS category, (menu_categories.category_name -> 'category' ->> 'icon') AS icon
                FROM hub.menu_categories
                JOIN r ON (menu_categories.category_name -> 'category' ->> $1) IN (r.parent)
            )
            
            SELECT * FROM r ORDER BY id, parent, category;]],
            table.unpack(hub_db.params)
        )

        if (res.categories == hub_db.select_ok) then
            return hub_db:to_obj()
        end

        return false
    end

    function menu:get_data()
        local units = self:get_units()

        if (not units) then
            return false, 'get units err'
        end

        local items = self:get_items(units)

        if (not items) then
            return false, 'get items err'
        end

        local categories = self:get_categories(items)

        if(not categories) then
            return false, 'get categories err'
        end

        hub_db:disconnect()

        return {categories, items, units}
    end
end