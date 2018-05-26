local is_chanjed = false
local defpath = props["scite.userhome"].."\\default.solution"
local CLR_ACTIVE = "30 180 30"
local _Plugins

local function SaveSolution()
    if not is_chanjed then return false end

    local tOut = {branchname = iup.GetAttributeId(tree_sol, "TITLE", 0)}
    local tStack = {tOut}
    for i = 1,  iup.GetAttribute(tree_sol, "TOTALCHILDCOUNT0") do
        local depth = tonumber(iup.GetAttributeId(tree_sol, "DEPTH", i))
        while depth < #tStack do table.remove(tStack, #tStack) end
        if iup.GetAttributeId(tree_sol, "KIND", i) == 'BRANCH' then
            local brn = {branchname = iup.GetAttributeId(tree_sol, "TITLE", i)}
            if iup.GetAttributeId(tree_sol, "STATE", i) == "COLLAPSED" then brn.state = "COLLAPSED" end
            if iup.GetAttributeId(tree_sol, "COLOR", i) == CLR_ACTIVE then brn.active = "YES" end
            table.insert(tStack[#tStack], brn)
            table.insert(tStack, brn)
        else
            local lf = {leafname = iup.GetAttributeId(tree_sol, "TITLE", i), userid = (iup.TreeGetUserId(tree_sol, i) or 'null')}
            table.insert(tStack[#tStack], lf)
        end
    end
    local str = ''
    local function tostr(t)
        str = str..'{branchname="'..t.branchname..'",\n'

        if t.active then str = str..'active="YES",\n' end
        if t.state then str = str..'state="COLLAPSED",\n' end
        for i = 1,  #t do
            if t[i].branchname then
                tostr(t[i], str)
                str = str..', '
            elseif t[i].leafname then
                str = str.."{leafname='"..t[i].leafname.."', "
                if t[i].userid then str = str.."userid='"..t[i].userid:gsub('\\', '\\\\').."'" end
                str = str..'},\n'
            end
        end
        str = str..'}'
    end

    tostr(tOut)
    assert(load('return '..str))
    if _G.iuprops['solution.current'] and not shell.fileexists(_G.iuprops['solution.current']) then _G.iuprops['solution.current'] = nil end
    local path = _G.iuprops['solution.current'] or defpath

    local f = io.open(path, "w")
    if f then
        f:write(str)
        f:flush()
        f:close()
    end
    is_chanjed = false
end

local function InsertProject()
    local title, ret = 'New'
    ret, title = iup.GetParam(_T'Новый Проект',
      function(h,i) if iup.GetParamParam(h,0).value:find('["\'\\]') then return 0 end return 1 end,
      _T"Имя%s\n", title)
    if ret then
        iup.SetAttributeId(tree_sol, "ADDBRANCH", tree_sol.value, title)
    end
    is_chanjed = true
    SaveSolution()
end

local function DeleteNode(i)
    local ret
    if i == 0 then
        ret = iup.Alarm(_T"Удаление проекта", _T"Вы действительно хотите удалить проект\nсо всем его содержимым?", _TH"Да", _TH"Нет")
    else
        ret = iup.Alarm(_T"Удаление элемента", _T"Исключить файл из проекта?", _TH"Да", _TH"Нет")
    end

    if ret == 1 then
        iup.SetAttributeId(tree_sol, "DELNODE", tree_sol.value, "SELECTED")
    end
    is_chanjed = true
    SaveSolution()
end

local function Add()
    local d = iup.filedlg{dialogtype='OPEN',  parentdialog='SCITE'}
    d:popup()
    local filename = d.value
    d:destroy()
    if filename then
       local val = tree_sol.value
       local _,_,fnExt = filename:find('([^\\]*)$')
       iup.SetAttributeId(tree_sol, "ADDLEAF", val, fnExt)
       iup.SetAttributeId(tree_sol, "IMAGE", val, GetExtImage(fnExt))
       iup.TreeSetUserId(tree_sol, val + 1, filename)
       is_chanjed = true
    end
end

local function AddCurentIn(val)
   if shell.fileexists(props["FilePath"]) then
       iup.SetAttributeId(tree_sol, "ADDLEAF", val, props['FileNameExt']:from_utf8())
       iup.SetAttributeId(tree_sol, "IMAGE", val + 1, GetExtImage(props['FileNameExt']))
       iup.TreeSetUserId(tree_sol, val + 1, props['FilePath']:from_utf8())
       is_chanjed = true
   else
       iup.Alarm(_T"Добавление файла в проект", _T"Файл еще не сохранен на диск", "OK"
       )
   end
end

local function AddCurent()
   AddCurentIn(tree_sol.value)
end

local function AddToActive()
    local nActive = 0
    for i = 0, iup.GetAttribute(tree_sol, "TOTALCHILDCOUNT0") do
        if iup.GetAttributeId(tree_sol, "KIND", i) == 'BRANCH' then
        if iup.GetAttributeId(tree_sol, "COLOR", i) == CLR_ACTIVE then nActive = i; break end
        end
    end
    AddCurentIn(nActive)
end

local function exec(filename)
    local ret, descr = shell.exec(filename)
    if not ret then
        print (">Exec: "..filename)
        print ("Error: "..descr)
    end
end

local function OpenFile(filename)
    local _,_,fnExt = filename:find('([^\\]*)$')
    local _,_,ext = filename:find('([^%.]*)$')
    local filename = iup.TreeGetUserId(tree_sol, tree_sol.value)
    if string.find(',exe,lnk,doc,xsl,pdf,chm,', ','..(ext or ''):lower()..',') then
        exec(filename)
    else
        scite.Open(filename:to_utf8())
    end
end

local function OpenAll()
    local val = tree_sol.value
    for i = 1,  iup.GetAttribute(tree_sol, "TOTALCHILDCOUNT0") do
        if iup.GetAttributeId(tree_sol, "KIND", i) ~= 'BRANCH' and iup.GetAttributeId(tree_sol, "PARENT", i) == val then
            local path = iup.TreeGetUserId(tree_sol, i)
            local _,_,ext = path:find('([^%.]*)$')
            if not string.find(',exe,lnk,doc,xsl,pdf,chm,', ','..(ext or ''):lower()..',') then
                scite.Open(path:to_utf8())
            end
        end
    end
end

local function ActivateProject()
    for i = 0, iup.GetAttribute(tree_sol, "TOTALCHILDCOUNT0") do
        if iup.GetAttributeId(tree_sol, 'KIND', i) == 'BRANCH' then iup.SetAttributeId(tree_sol, 'COLOR',i, '0 0 0') end
    end
    iup.SetAttributeId(tree_sol, 'COLOR',tree_sol.value, CLR_ACTIVE)
    is_chanjed = true
    SaveSolution()
end

local function SaveAsNew()
    local y,m,d,ch,mn,sec = shell.datetime()
    local title = 'New '..y..'-'..m..'-'..d..' '..ch..':'..mn
    iup.SetAttributeId(tree_sol, "ADDBRANCH", 0, title)
    AddAll(1)
    is_chanjed = true
    SaveSolution()
end

local started
local function Initialize()
    if started then return end
    started = true
    local path = _G.iuprops['solution.current'] or defpath
    local f =io.open(path)
    local str
    if f then
        str = f:read('*a')
        f:close()
    else
        str = '{branchname = "Solution"}'
    end
    local tree_nodes = assert(load('return '..str))()
    local bSetActive = false
    local function enrich(t)
        for i = 1,  #t do
            if t[i].branchname then
                if not bSetActive and t[i].active == 'YES' then t[i].color = CLR_ACTIVE; bSetActive = true end
                enrich(t[i])
                --str = str..', '
            elseif t[i].leafname then
                t[i].image = GetExtImage(t[i].userid)
            end
        end
        --str = str..'}'
    end
    enrich(tree_nodes)
    if not bSetActive then tree_nodes.color = CLR_ACTIVE end
    tree_nodes.imageexpanded = 'tree_µ'
    tree_sol.autoredraw = 'NO'
    iup.TreeAddNodes(tree_sol, tree_nodes)
    tree_sol.resetscroll = 1
    tree_sol.autoredraw = 'YES'
end

local function Open_Local(filename)
    _G.iuprops['solution.current'] = filename
    iup.SetAttributeId(tree_sol, "DELNODE", 0, "CHILDREN")
    started = false
    Initialize()
end

local function OpenSol()
    is_chanjed = true
    SaveSolution()
    local d = iup.filedlg{dialogtype='OPEN',  parentdialog='SCITE', extfilter='Solutions|*.solution;', directory=props["scite.userhome"].."\\" }
    d:popup()
    local filename = d.value
    d:destroy()
    if filename then
        Open_Local(filename)
    end
end

AddEventHandler("OnBeforeOpen", function(file, ext)
    if ext == "solution" then
        Open_Local(file)
        _Plugins.solution.Bar_obj.TabCtrl.value = tree_sol
        return true
    end
end)

local function SaveSolAs()
    is_chanjed = true
    SaveSolution()
    local d = iup.filedlg{dialogtype='SAVE',  parentdialog='SCITE', extfilter='Solutions|*.solution;', directory=props["scite.userhome"].."\\"}
    d:popup()
    local filename = d.value
    d:destroy()
    if filename then
        filename = filename:gsub('%.solution$', '')..'.solution'
        _G.iuprops['solution.current'] = filename
        is_chanjed = true
        SaveSolution()
    end
end

local function Solution_Init(h)
    _Plugins = h
    local prp = _G.iuprops['sidebar.functions.layout'] or ""
    local w
    -- for w in string.gmatch(prp, "[^|]+") do
    --    layout[w] = 'COLLAPSED'
    --end
    local line = nil --RGB(73, 163, 83)  RGB(30,180,30)
    tree_sol = iup.sc_tree{minsize = '0x5', size = _G.iuprops["sidebar.functions.tree_sol.size"],
    showdragdrop = 'YES', showrename = 'YES', dropfilestarget = 'YES',}
    --Обработку нажатий клавиш производим тут, чтобы вернуть фокус редактору
    tree_sol.size = nil

    tree_sol.button_cb = (function(h, but, pressed, x, y, status)

        if but == 51 and pressed == 0 then --right
            h.value = iup.ConvertXYToPos(h, x, y)
            menuhandler:PopUp('MainWindowMenu|_HIDDEN_|Solution_sidebar')

        elseif but == 49 and iup.isdouble(status) then --dbl left
            if h.kind ~= 'BRANCH' then
                OpenFile(iup.TreeGetUserId(h, h.value))
                iup.PassFocus()
            end
        end
        if pressed == 0 and line ~= nil then
            iup.PassFocus()
            line = nil
        end
    end)
    tree_sol.k_any = (function(h, number)
        if number == 13 then
            OpenFile(iup.TreeGetUserId(h, h.value))
            iup.PassFocus()
        elseif number == iup.K_ESC then
            iup.PassFocus()
        end
    end)
    tree_sol.branchclose_cb = function(h) if h.value == '0' then return - 1 end end
    tree_sol.rename_cb = function() is_chanjed = true return - 4 end
    tree_sol.dragdrop_cb = function(h, drag_id, drop_id, isshift, iscontrol)
        if iscontrol == 1 then return - 1 end
        is_chanjed = true return - 4
    end
    tree_sol.killfocus_cb = SaveSolution
    tree_sol.tips_cb = function(h, x, y, status)
        local n = iup.ConvertXYToPos(h, x, y)
        if n == 0 then
            h.tip = _G.iuprops['solution.current'] or defpath
        else
            h.tip = iup.TreeGetUserId(h, n)
        end
    end
    tree_sol.dropfiles_cb = function(h, filename, num, x, y)
        local val = iup.ConvertXYToPos(h, x, y)
        local _, _, fnExt = filename:find('([^\\]*)$')
        iup.SetAttributeId(tree_sol, "ADDLEAF", val, fnExt)
        iup.SetAttributeId(tree_sol, "IMAGE", val, GetExtImage(filename))
        iup.TreeSetUserId(tree_sol, val + 1, filename)
        is_chanjed = true
        SaveSolution()
    end

    menuhandler:InsertItem('MainWindowMenu', '_HIDDEN_|s1',   --TODO переместить в SideBar\FindRepl.lua вместе с функциями
        {'Solution_sidebar', plane = 1,{
            {'Solution', ru = _T'Рабочая область', {
                {'Save as', ru = _T'Сохранить как', action = SaveSolAs},
                {'Open', ru = _T'Открыть', action = OpenSol},
            }},
            {'Insert Project', ru = _T'Новый  проект', action = InsertProject},
            {'Delete Project', ru = _T'Удалить  проект', action = function() DeleteNode(0) end, visible = function() return iup.GetAttribute(tree_sol, "KIND") == "BRANCH" and tree_sol.value~='0' end},
            {'Open All Projects Files', ru = _T'Открыть все файлы проекта', action = OpenAll, visible = function() return iup.GetAttribute(tree_sol, "KIND") == "BRANCH" and tree_sol.value~='0' end},
            {'Set As Active Project', ru = _T'Установить активным', action = ActivateProject, visible = function() return iup.GetAttribute(tree_sol, "KIND") == "BRANCH" and iup.GetAttribute(tree_sol, "COLOR") ~= CLR_ACTIVE end},

            {'s_FindTextOnSel', separator = 1},
            {'Add...', ru = _T'Добавить...', action = Add},
            {'Add Curent File', ru = _T'Добавить текущий файл - '..props['FilePath'], action = AddCurent, visible = function() return shell.fileexists(props["FilePath"]) end },
            {'Add All Opened Files', ru = _T'Добавить все открытые файлы', action = function() AddAll(tree_sol.value) end},
            {'Remove File', ru = _T'Исключить файл из проекта', action = function() DeleteNode(1) end, visible = function() return iup.GetAttribute(tree_sol, "KIND")~="BRANCH" end},
            {'s1_FindTextOnSel', separator = 1},
            {'Go To Directory', ru = _T'Перейти в директорию', action = function() h.fileman.OpenDir(iup.TreeGetUserId(tree_sol, tree_sol.value):gsub('([^\\]*)$', '')) end, visible = function() return iup.GetAttribute(tree_sol, "KIND")~= "BRANCH" and (h.fileman ~= nil) end},
    }})

    menuhandler:InsertItem('TABBAR', 'slast', {'project', plane = 1, {
        {'Save As New Project', ru = _T'Сохранить все как новый проект', action=SaveAsNew},
        {'Add To Active Project', ru = _T'Добавить в активный проект', action=AddToActive},
    }})
    menuhandler:InsertItem('TABBAR', 's1',
        {'Save As New Project', ru = _T'Закрыть и добавить в активный проект', action = function() AddToActive(); scite.MenuCommand(IDM_CLOSE) end}

    )

    local function AddTbl(tbl)
        debug_prnArgs(tbl)
        local maxN = scite.buffers.GetCount() - 1
        for i = 0, maxN do
            if tbl[i] then
                local pth = scite.buffers.NameAt(i):from_utf8()
                if shell.fileexists(pth) then
                    local _, _, fnExt = pth:find('([^\\]*)$')

                    iup.SetAttributeId(tree_sol, "ADDLEAF", tree_sol.value, fnExt)
                    iup.SetAttributeId(tree_sol, "IMAGE", tree_sol.value, GetExtImage(fnExt))
                    iup.TreeSetUserId(tree_sol, tree_sol.value + 1, pth)
                end
            end
        end
        is_chanjed = true
    end
    menuhandler:PostponeInsert('MainWindowMenu', '_HIDDEN_|Window_bar|sxxx',
        {'solution', plane = 1, {
            {'s_comptemp', separator = 1},
            {"Add Checked To Project", ru = _T"Добавить отмеченные в солюшн", action = function() CORE.DoForFileSet('1', AddAll)() end,},
            {"Add Un Checked To Project", ru = _T"Добавить НЕотмеченные в солюшн", action = function() CORE.DoForFileSet('0', AddAll)() end,},
    }})
    return {   -- iup.vbox{   };
        handle = iup.flatscrollbox{tree_sol, border='NO'};
        OnSwitchFile = Initialize,
        OnOpen = Initialize,
        on_SelectMe = Initialize
    }

end

return {
    title = 'Solution',
    code = 'solution',
    sidebar = Solution_Init,
    tabhotkey = "Alt+Shift+S",
    description = [[Дерево проектов. Позволяет сохранять закладки
к файлам в виде дерева]]
}

