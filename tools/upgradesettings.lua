
local function Convert(t)

    local function split(t, field, splitter)
        local s = t[field]
        if type(s) == 'table' then return end
        if s then
            local out = {}
            for w in s:gmatch('([^'..splitter..']+)') do
                table.insert(out, w)
            end
            t[field] = out
        end
    end

    local function converBar(t, field, bCapt)
        local s = t[field]
        if type(s) == 'table' then return end
        if s then
            local tBars = {}
            local tBar
            for w in s:gmatch('([^¦]+)') do
                if w:find('¬') then
                    tBar = {}
                    table.insert(tBars, tBar)
                    if bCapt then
                        tBar.title = w:gsub('¬', '')
                    else
                        tBar[1] = w:gsub('¬', '')
                    end
                else
                    table.insert(tBar, w)
                end
            end
            t[field] = tBars
        end
    end

    for n, v in pairs(t) do
        if type(v) == 'string' and v:find('¤') then
            local vt = {}
            for w in v:gmatch('([^¤]+)') do
                table.insert(vt, w)
            end
            t[n] = vt
        end
    end

    if t['settings.lexers'] then
        if type(t['settings.lexers']) == 'string' then
            local tl = {}
            for w in (t['settings.lexers'] or ''):gmatch('[^¦]+') do
                local tv = {}
                table.insert(tl, tv)
                _, _, tv.view, tv.ext, tv.name, tv.file = w:find('([^•]*)•([^•]*)•([^•]*)•([^•]*)')
            end
            t['settings.lexers'] = tl
        end
    end

    split(t, 'settings.status.layout', '¦')
    split(t, 'settings.hidden.plugins', '¦')
    split(t, 'settings.commands.plugins', '¦')
    if t['settings.user.toolbar'] then t['settings.user.toolbar'] = t['settings.user.toolbar']:gsub('¦', '|') end
    split(t, 'settings.user.toolbar', '‡')

    converBar(t, 'settings.toolbars.layout', false)
    converBar(t, 'settings.user.leftbar', true)
    converBar(t, 'settings.user.rightbar', true)


end

local function ConvertBuffers(tMsg)
    if type(tMsg['buffers'] or {}) == 'table' then return end
    local lst, pos, layouts = {}, {}, {}
    for f in (tMsg['buffers'] or ''):gmatch('[^•]+') do
        table.insert(lst, f)
    end
    for f in (tMsg['buffers.pos'] or ''):gmatch('[^•]+') do
        table.insert(pos, f)
    end
    for f in (tMsg['buffers.layouts'] or ''):gmatch('[^•]+') do
        local l = {}
        for fl in (f:gmatch('%d+')) do
            table.insert(l, fl)
        end
        table.insert(layouts, l)
    end
    tMsg['buffers.pos'] = nil
    tMsg['buffers.layouts'] = nil
    local buf = {}
    buf.lst = lst
    buf.pos = pos
    buf.layouts = layouts
    tMsg['buffers'] = buf
end

local function Run(a, b)

    local files = shell.findfiles(props["SciteDefaultHome"].."\\data\\home\\*.config")

    for i, filenameT in ipairs(files) do
        local f = io.open(props['SciteUserHome']..'\\'..filenameT.name)
        local s = f:read('*a')
        f:close()
        s = 'return {\n'..s:gsub('_G.iuprops([^\n]+)', '%1,'):gsub('] = {,','] = {' ):gsub('}\n','},\n' )..'\n}'

        local bsuc, fun = pcall(assert, load(s))
        if not bsuc then
            print(filenameT.name, fun)
            goto continue1
        end

        tMsg = fun()

        Convert(tMsg)

        tOut = {}
        for n, v in pairs(tMsg) do
            table.insert(tOut, '_G.iuprops["'..n..'"] = '..CORE.tbl2Out(v, ' ', true, true))
        end
        tOut['_VERSION'] = 2

        f = io.open(props['SciteUserHome']..'\\'..filenameT.name, "w")
        f:write(table.concat(tOut, '\n'):to_utf8(1251))
        f:close()
::continue1::
    end

    local files = shell.findfiles(props["SciteDefaultHome"].."\\data\\home\\*.fileset")

    for i, filenameT in ipairs(files) do
        local f = io.open(props['SciteUserHome']..'\\'..filenameT.name)
        local s = f:read('*a')
        f:close()
        s = 'return {\n'..s:gsub('_G.iuprops([^\n]+)', '%1,'):gsub('] = {,','] = {' ):gsub('}\n','},\n' )..'\n}'

        local bsuc, fun = pcall(assert, load(s))
        if not bsuc then
            print(filenameT.name, fun)
            goto continue
        end

        tMsg = fun()
        if tMsg['_VERSION'] == 2 then goto continue end
        ConvertBuffers(tMsg)

        tOut = {}
        for n, v in pairs(tMsg) do
            table.insert(tOut, '_G.iuprops["'..n..'"] = '..CORE.tbl2Out(v, ' ', true, true))
        end

        f = io.open(props['SciteUserHome']..'\\'..filenameT.name, "w")
        f:write(table.concat(tOut, '\n'):to_utf8(1251))
        f:close()
::continue::
    end

    local f = io.open(props['SciteUserHome']..'\\settings.lua')
    local s = f:read('*a')
    f:close()
    s = s:gsub('^_G.iuprops = ', 'return')

    tMsg = assert(load(s))()
    if tMsg['_VERSION'] == 2 then return end
    Convert(tMsg)
    ConvertBuffers(tMsg)
    tMsg['_VERSION'] = 2

    f = io.open(props['SciteUserHome']..'\\favorites.lst')
    local sf = f:read('*a')
    f:close()

    local tf = {}
    for ff in sf:gmatch('[^\n\r]+') do
        table.insert(tf, {ff, alias = ff:gsub('^.-([^\\]+)\\?$', '%1')})
    end

    tMsg['FileMan.Favorits'] = tf
    f = io.open(props['SciteUserHome']..'\\settings.lua', "w")
    s = CORE.tbl2Out(tMsg, ' ', false, true, true):gsub('^return ', '_G.iuprops = ')
    f:write(s:to_utf8(1251))
    f:close()

end

Run()
