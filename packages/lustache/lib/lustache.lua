-- lustache: Lua mustache template parsing.
-- Copyright 2013 Olivine Labs, LLC <projects@olivinelabs.com>
-- MIT Licensed.
-- Edited by Senin Stanislav for NEF Framework 2015
do
    function string.split(str, sep)
        local out = {}
        for m in string.gmatch(str, "[^"..sep.."]+") do
            out[#out+1] = m
        end
        return out
    end

    local string_find, string_gsub, string_match, string_split, string_sub = 
    string.find, string.gsub, string.match, string.split, string.sub

    local error, ipairs, loadstring, pairs, setmetatable, tostring, type = 
    error, ipairs, loadstring, pairs, setmetatable, tostring, type

    local math_floor, math_max, table_concat, table_insert, table_remove = 
    math.floor, math.max, table.concat, table.insert, table.remove

    local html_escape_characters = {
        ["&"] = "&amp;",
        ["<"] = "&lt;",
        [">"] = "&gt;",
        ['"'] = "&quot;",
        ["'"] = "&#39;",
        ["/"] = "&#x2F;"
    }

    local patterns = {
        ['white'] = "%s*",
        ['space'] = "%s+",
        ['nonSpace'] = "%S",
        ['eq'] = "%s*=",
        ['curly'] = "%s*}",
        ['tag'] = "[#\\^/>{&=!]"
    }

    local scanner = {}
    local context = {}
    local renderer = {}
    lustache = {}

    local function is_array(array)
        if type(array) ~= "table" then return false end
        local max, n = 0, 0
        for k, _ in pairs(array) do
            if not (type(k) == "number" and k > 0 and math_floor(k) == k) then
                return false
            end
            max = math_max(max, k)
            n = n + 1
        end
        return n == max
    end

    -- Low-level function that compiles the given `tokens` into a
    -- function that accepts two arguments: a Context and a
    -- Renderer.

    local function compile_tokens(tokens, originalTemplate)
        local subs = {}
        local function subrender(i, tokens)
            if not subs[i] then
                local fn = compile_tokens(tokens, originalTemplate)
                subs[i] = function(ctx, rnd)
                    return fn(ctx, rnd)
                end
            end
            return subs[i]
        end
        local function render(ctx, rnd)
            local buf = {}
            local token, section
            for i, token in ipairs(tokens) do
                local t = token.type
                buf[#buf+1] = 
                t == "#" and rnd:_section(token, ctx, subrender(i, token.tokens), originalTemplate)
                or t == "^" and rnd:_inverted(token.value, ctx, subrender(i, token.tokens))
                or t == ">" and rnd:_partial(token.value, ctx, originalTemplate)
                or (t == "{" or t == "&") and rnd:_name(token.value, ctx, false)
                or t == "name" and rnd:_name(token.value, ctx, true)
                or t == "text" and token.value
                or ""
            end
            return table_concat(buf)
        end
        return render
    end

    local function escape_tags(tags)
        return {string_gsub(tags[1], "%%", "%%%%") .. "%s*", "%s*" .. string_gsub(tags[2], "%%", "%%%%")}
    end

    local function nest_tokens(tokens)
        local tree = {}
        local collector = tree
        local sections = {}
        local token, section
        for i,token in ipairs(tokens) do
            if token.type == "#" or token.type == "^" then
                token.tokens = {}
                sections[#sections+1] = token
                collector[#collector+1] = token
                collector = token.tokens
            elseif token.type == "/" then
                if #sections == 0 then
                    error("Unopened section: " .. token.value)
                end
                -- Make sure there are no open sections when we're done
                section = table_remove(sections, #sections)
                if not section.value == token.value then
                    error("Unclosed section: " .. section.value)
                end
                section.closingTagIndex = token.startIndex
                if #sections > 0 then
                    collector = sections[#sections].tokens
                else
                    collector = tree
                end
            else
                collector[#collector+1] = token
            end
        end
        section = table_remove(sections, #sections)
        if section then
            error("Unclosed section: " .. section.value)
        end
        return tree
    end

    -- Combines the values of consecutive text tokens in the given `tokens` array
    -- to a single token.
    local function squash_tokens(tokens)
        local out, txt = {}, {}
        local txtStartIndex, txtEndIndex
        for _, v in ipairs(tokens) do
            if v.type == "text" then
                if #txt == 0 then
                    txtStartIndex = v.startIndex
                end
                txt[#txt+1] = v.value
                txtEndIndex = v.endIndex
            else
                if #txt > 0 then
                    out[#out+1] = {type = "text", value = table_concat(txt), startIndex = txtStartIndex, endIndex = txtEndIndex}
                    txt = {}
                end
                out[#out+1] = v
            end
        end
        if #txt > 0 then
            out[#out+1] = {type = "text", value = table_concat(txt), startIndex = txtStartIndex, endIndex = txtEndIndex}
        end
        return out
    end

    -- Returns `true` if the tail is empty (end of string).
    function scanner:eos()
        return self.tail == ""
    end

    -- Tries to match the given regular expression at the current position.
    -- Returns the matched text if it can match, `null` otherwise.
    function scanner:scan(pattern)
        local match = string_match(self.tail, pattern)
        if match and string_find(self.tail, pattern) == 1 then
            self.tail = string_sub(self.tail, #match + 1)
            self.pos = self.pos + #match
            return match
        end
    end

    -- Skips all text until the given regular expression can be matched. Returns
    -- the skipped string, which is the entire tail of this scanner if no match
    -- can be made.
    function scanner:scan_until(pattern)
        local match
        local pos = string_find(self.tail, pattern)
        if pos == nil then
            match = self.tail
            self.pos = self.pos + #self.tail
            self.tail = ""
        elseif pos == 1 then
            match = nil
        else
            match = string_sub(self.tail, 1, pos - 1)
            self.tail = string_sub(self.tail, pos)
            self.pos = self.pos + #match
        end
        return match
    end

    function scanner:new(str)
        local out = {str  = str,
                     tail = str,
                     pos  = 1}
        return setmetatable(out, { __index = self })
    end

    function context:clear_cache()
        self.cache = {}
    end

    function context:push(view)
        return self:new(view, self)
    end

    function context:lookup(name)
        local value = self.cache[name]
        if not value then
            if name == "." then
                value = self.view
            else
                local context = self
                while context do
                    if string_find(name, ".") > 0 then
                        local names = string_split(name, ".")
                        local i = 0
                        value = context.view
                        if(type(value)) == "number" then
                            value = tostring(value)
                        end
                        while value and i < #names do
                            i = i + 1
                            value = value[names[i]]
                        end
                    else
                        value = context.view[name]
                    end
                    if value then break end
                    context = context.parent
                end
            end
            self.cache[name] = value
        end
        return value
    end

    function context:new(view, parent)
        local out = {view   = view,
                     parent = parent,
                     cache  = {},
                     magic  = "1235123123"}
        return setmetatable(out, {__index = self})
    end

    local function make_context(view)
        if not view then return view end
        return view.magic == "1235123123" and view or context:new(view)
    end

    function renderer:clear_cache()
        self.cache = {}
        self.partial_cache = {}
    end

    function renderer:compile(tokens, tags, originalTemplate)
        tags = tags or self.tags
        if type(tokens) == "string" then
            tokens = self:parse(tokens, tags)
        end
        local fn = compile_tokens(tokens, originalTemplate)
        return function(view) return fn(make_context(view), self) end
    end

    function renderer:render(template, view, partials)
        if type(self) == "string" then error("Call mustache:render, not mustache.render!") end
        if partials then
            -- remember partial table
            -- used for runtime lookup & compile later on
            self.partials = partials
        end
        if not template then
            return ""
        end
        local fn = self.cache[template]
        if not fn then
            fn = self:compile(template, self.tags, template)
            self.cache[template] = fn
        end
        return fn(view)
    end

    function renderer:_section(token, context, callback, originalTemplate)
        local value = context:lookup(token.value)
        if type(value) == "table" then
            if is_array(value) then
                local buffer = ""
                for i,v in ipairs(value) do
                    buffer = buffer .. callback(context:push(v), self)
                end
                return buffer
            end
            return callback(context:push(value), self)
        elseif type(value) == "function" then
            local section_text = string_sub(originalTemplate, token.endIndex+1, token.closingTagIndex - 1)
            local scoped_render = function(template) return self:render(template, context) end
            return value(section_text, scoped_render) or ""
        else
            if value then return callback(context, self) end
        end
        return ""
    end

    function renderer:_inverted(name, context, callback)
        local value = context:lookup(name)
        -- From the spec: inverted sections may render text once based on the
        -- inverse value of the key. That is, they will be rendered if the key
        -- doesn't exist, is false, or is an empty list.
        if value == nil or value == false or (is_array(value) and #value == 0) then
            return callback(context, self)
        end
        return ""
    end

    function renderer:_partial(name, context, originalTemplate)
        local fn = self.partial_cache[name]
        -- check if partial cache exists
        if (not fn and self.partials) then
            local partial = self.partials[name]
            if (not partial) then return "" end
            -- compile partial and store result in cache
            fn = self:compile(partial, nil, originalTemplate)
            self.partial_cache[name] = fn
        end
        return fn and fn(context, self) or ""
    end

    function renderer:_name(name, context, escape)
        local value = context:lookup(name)
        if type(value) == "function" then value = value(context.view) end
        local str = value == nil and "" or value
        str = tostring(str)
        if escape then
            return string_gsub(str, '[&<>"\'/]', function(s) return html_escape_characters[s] end)
        end
        return str
    end

    -- Breaks up the given `template` string into a tree of token objects. If
    -- `tags` is given here it must be an array with two string values: the
    -- opening and closing tags used in the template (e.g. ["<%", "%>"]). Of
    -- course, the default is to use mustaches (i.e. Mustache.tags).
    function renderer:parse(template, tags)
        tags = tags or self.tags
        local tag_patterns = escape_tags(tags)
        local scanner = scanner:new(template)
        local tokens = {} -- token buffer
        local spaces = {} -- indices of whitespace tokens on the current line
        local has_tag = false -- is there a {{tag} on the current line?
        local non_space = false -- is there a non-space char on the current line?
        -- Strips all whitespace tokens array for the current line if there was
        -- a {{#tag}} on it and otherwise only space
        local type, value, chr
        while not scanner:eos() do
            local start = scanner.pos
            value = scanner:scan_until(tag_patterns[1])
            if value then
                for i = 1, #value do
                    chr = string_sub(value,i,i)
                    if string_find(chr, "%s+") then
                        spaces[#spaces+1] = #tokens
                    else
                        non_space = true
                    end
                    tokens[#tokens+1] = {type = "text", value = chr, startIndex = start, endIndex = start}
                    start = start + 1
                end
            end
            if not scanner:scan(tag_patterns[1]) then
                break
            end
            has_tag = true
            type = scanner:scan(patterns.tag) or "name"
            scanner:scan(patterns.white)
            if type == "=" then
                value = scanner:scan_until(patterns.eq)
                scanner:scan(patterns.eq)
                scanner:scan_until(tag_patterns[2])
            elseif type == "{" then
                local close_pattern = "%s*}" .. tags[2]
                value = scanner:scan_until(close_pattern)
                scanner:scan(patterns.curly)
                scanner:scan_until(tag_patterns[2])
            else
                value = scanner:scan_until(tag_patterns[2])
            end
            if not scanner:scan(tag_patterns[2]) then
                error("Unclosed tag at " .. scanner.pos)
            end
            tokens[#tokens+1] = {type = type, value = value, startIndex = start, endIndex = scanner.pos - 1}
            if type == "name" or type == "{" or type == "&" then non_space = true end
            if type == "=" then
                tags = string_split(value, patterns.space)
                tag_patterns = escape_tags(tags)
            end
        end
        return nest_tokens(squash_tokens(tokens))
    end

    function renderer:new()
        local out = {
            ['cache'] = {},
            ['partial_cache'] = {},
            ['tags'] = {"{{", "}}"}
        }
        return setmetatable(out, { __index = self })
    end

    lustache = {
        ['name'] = "lustache",
        ['version']  = "1.3-1",
        ['renderer'] = renderer:new()
    }

    setmetatable(lustache, {
        __index = function(self, idx)
            if self.renderer[idx] then return self.renderer[idx] end
        end,
        __newindex = function(self, idx, val)
            if idx == "partials" then self.renderer.partials = val end
            if idx == "tags" then self.renderer.tags = val end
        end
    })
end

return lustache