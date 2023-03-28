local error_wrapper = require('lib.tools.error_wrapper')
local json = require('cjson')

local pkg_acl_filter = {
    __name = 'pkg_acl_filter'
}

pkg_acl_filter.types = {
    ['sources'] = {
        ['module'] = 'm',
        ['service'] = 's',
        ['constant'] = 'c'
    },
    ['targets'] = {
        ['module'] = 'm',
        ['service'] = 's',
        ['signal'] = 'sig',
        ['event'] = 'e',
        ['constant'] = 'c'
    }
}

pkg_acl_filter.constants = {
    ['sources'] = {
        ['MODULES'] = 'M',
        ['SERVICES'] = 'S',
        ['ANY'] = 'MS'
    },
    ['targets'] = {
        ['MODULES'] = 'M',
        ['SERVICES'] = 'S',
        ['SIGNALS'] = 'SIG',
        ['EVENTS'] = 'E',
        ['ANY'] = 'MS'
    }
}

pkg_acl_filter.masks = {
    -- modules
    ['cMcM'] = true, -- 2
    ['cMcSIG'] = true, -- 6
    -- services
    ['cScM'] = true, -- 12
    ['cScS'] = true, -- 14
    ['cScE'] = true, -- 18
    ['cScMS'] = true, -- 20
    -- constants
    ['cMScM'] = true, -- 22
}

pkg_acl_filter.res = {}

function pkg_acl_filter:set_by_list(list, val, key)
    if list[val] then
        self.res[key] = list[val]

        return true
    end

    return false
end

function pkg_acl_filter:filter(acl_list, modules, services, signals, events)
    if (type(acl_list) ~= 'table') then
        return false, error_wrapper:new(self, 'acl_list must be a table!')
    end

    if (type(modules) ~= 'table') then
        return false, error_wrapper:new(self, 'modules must be a table!')
    end

    if (type(services) ~= 'table') then
        return false, error_wrapper:new(self, 'services must be a table!')
    end

    if (type(signals) ~= 'table') then
        return false, error_wrapper:new(self, 'signals must be a table!')
    end

    if (type(events) ~= 'table') then
        return false, error_wrapper:new(self, 'events must be a table!')
    end

    local filtered_list = {}
    local subs_by_types = {
        ['module'] = modules,
        ['service'] = services,
        ['signal'] = signals,
        ['event'] = event
    }

    for i=1, #acl_list do
        self.res = {}

        local source_type = acl_list[i][1]
        local source = acl_list[i][2]
        local target_type = acl_list[i][3]
        local target = acl_list[i][4]

        -- source type
        if (not self:set_by_list(self.types.sources, source_type, 'st')) then
            goto continue
        end

        -- source
        if (self.res.st == self.types.sources.constant and not self:set_by_list(self.constants.sources, source, 's')) then
            goto continue
        elseif (not self.res.s and not self:set_by_list(subs_by_types[source_type], source, 's')) then
            goto continue
        end

        -- target type
        if (not self:set_by_list(self.types.targets, target_type, 'tt')) then
            goto continue
        end

        -- закоментил т.к. невозможно добавить правило, где target из другого пакета, соотв. target_path вида: package.service1
        -- невозможно проверить. Теперь target не проверяется.
        -- target
        -- if (self.res.tt == self.types.targets.constant and not self:set_by_list(self.constants.targets, target, 't')) then
        --     goto continue
        -- elseif (not self.res.t and not self:set_by_list(subs_by_types[target_type], target, 't')) then
        --     goto continue
        -- end

        if (self.res.tt == self.types.targets.constant and not self:set_by_list(self.constants.targets, target, 't')) then
            goto continue
        end

        -- mask
        if (self.res.st ~= self.types.sources.constant) then
            self.res.s = string.upper(self.res.st)
            self.res.st = self.types.sources.constant
        end

        if (self.res.tt ~= self.types.targets.constant) then
            self.res.t = string.upper(self.res.tt)
            self.res.tt = self.types.targets.constant
        end

        self.res.mask = self.res.st .. self.res.s .. self.res.tt .. self.res.t

        if self.masks[self.res.mask] then
            table.insert(filtered_list, {source_type, source, target_type, target})
        end

        ::continue::
    end

    return filtered_list
end

function pkg_acl_filter:diff_lists(acl_list, filtered_list)
    acl_list = json.encode(acl_list)

    for i=1, #filtered_list do
        local rule = json.encode(filtered_list[i])
        local s, e = string.find(acl_list, rule, 1, true)

        if (not s) then
            goto continue
        end

        e = e + 1

        if (string.sub(acl_list, e, e) == ',') then
            rule = rule .. ','
        end

        acl_list = string.gsub(acl_list, '%' .. rule, '', 1)

        ::continue::
    end

    -- затираем хвост массива
    acl_list = string.gsub(acl_list, '%],]', ']]', 1)

    return json.decode(acl_list)
end

return pkg_acl_filter