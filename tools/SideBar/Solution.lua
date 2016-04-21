local tree_func
local is_chanjed = false

local function SaveSolution()
    if not is_chanjed then return false end

    local tOut = {branchname = "Solution"}
    local tStack = {tOut}
    for i = 1,  iup.GetAttribute(tree_sol, "TOTALCHILDCOUNT0") do
        local depth = tonumber(iup.GetAttributeId(tree_sol, "DEPTH", i))
        while depth < #tStack do table.remove(tStack, #tStack) end
        if iup.GetAttributeId(tree_sol, "KIND", i) == 'BRANCH' then
            local brn = {branchname = iup.GetAttributeId(tree_sol, "TITLE", i)}
            if iup.GetAttributeId(tree_sol, "STATE", i) == "COLLAPSED" then brn.state = "COLLAPSED" end
            table.insert(tStack[#tStack], brn)
            table.insert(tStack, brn)
        else
            local lf = {leafname = iup.GetAttributeId(tree_sol, "TITLE", i), userid = (tree_sol:GetUserId(i) or 'null')}
            table.insert(tStack[#tStack], lf)
        end
    end
    local str = ''
    local function tostr(t)
        str = str..'{branchname="'..t.branchname..'",\n'

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
    assert(loadstring('return '..str))
    local path = props["SciteDefaultHome"].."\\data\\home\\default.solution"
    local f = io.open(path, "w")
    f:write(str)
    f:flush()
    f:close()
    is_chanjed = false
end

local function InsertProject()
    local title, ret = 'New'
    ret, title = iup.GetParam('Новый Проект',
      function(h,i) if iup.GetParamParam(h,0).value:find('["\'\\]') then return 0 end return 1 end,
      "Имя%s\n", title)
    if ret then
        iup.SetAttributeId(tree_sol, "ADDBRANCH", tree_sol.value, title)
    end
    is_chanjed = true
    SaveSolution()
end

local function DeleteNode(i)
    local ret
    if i == 0 then
        ret = iup.Alarm("Удаление проекта", "Вы действительно хотите удалить проект\nсо всем его содержимым?", "Да", "Нет")
    else
        ret = iup.Alarm("Удаление элемента", "Исключить файл из проекта?", "Да", "Нет")
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
       tree_sol:SetUserId(val + 1, filename)
       is_chanjed = true
    end
end

local function AddCurent()
   if shell.fileexists(props["FilePath"]) then
       local val = tree_sol.value
       iup.SetAttributeId(tree_sol, "ADDLEAF", val, props['FileName']:from_utf8(1251))
       iup.SetAttributeId(tree_sol, "IMAGE", val, GetExtImage(props['FileNameExt']))
       tree_sol:SetUserId(val + 1, props['FilePath']:from_utf8(1251))
       is_chanjed = true
   else
       iup.Alarm("Добавдение файла в проект", "Файл еще не сохранен на диск", "OK"
       )
   end
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
    local filename = tree_sol:GetUserId(tree_sol.value)
    if string.find('.exe.lnk.doc.xsl.pdf.chm.', '.'..ext..'.') then
        exec(filename)
    else
        scite.Open(filename:to_utf8(1251))
    end
end

local function OpenAll()
    local val = tree_sol.value
    for i = 1,  iup.GetAttribute(tree_sol, "TOTALCHILDCOUNT0") do
        if iup.GetAttributeId(tree_sol, "KIND", i) ~= 'BRANCH' and iup.GetAttributeId(tree_sol, "PARENT", i) == val then
            local path = tree_sol:GetUserId(i)
            local _,_,ext = path:find('([^%.]*)$')
            if not string.find('.exe.lnk.doc.xsl.pdf.chm.', '.'..ext..'.') then
                scite.Open(path:to_utf8(1251))
            end
        end
    end
end

local function AddAll(val)
    local maxN = scite.buffers.GetCount() - 1
    for i = 0,maxN do
        local pth = scite.buffers.NameAt(i):from_utf8(1251)
        if shell.fileexists(pth) then
            local _,_,fnExt = pth:find('([^\\]*)$')

            iup.SetAttributeId(tree_sol, "ADDLEAF", val, fnExt)
            iup.SetAttributeId(tree_sol, "IMAGE", val, GetExtImage(fnExt))
            tree_sol:SetUserId(val + 1, pth)
        end
    end
    is_chanjed = true
end

local function SaveAsNew()
    local y,m,d,ch,mn,sec = shell.datetime()
    local title = 'New '..y..'-'..m..'-'..d..' '..ch..' '..mn
    iup.SetAttributeId(tree_sol, "ADDBRANCH", 0, title)
    AddAll(1)
    is_chanjed = true
    SaveSolution()
end

local started
local function Initialize()
    if started then return end
    started = true
    local path = props["SciteDefaultHome"].."\\data\\home\\default.solution"
    local f =io.open(path)
    local str
    if f then
        str = f:read('*a')
        f:close()
    else
        str = '{branchname = "Solution"}'
    end
    local tree_nodes = assert(loadstring('return '..str))()

    local function enrich(t)
        for i = 1,  #t do
            if t[i].branchname then
                enrich(t[i], str)
                str = str..', '
            elseif t[i].leafname then
                t[i].image = GetExtImage(t[i].userid)
            end
        end
        str = str..'}'
    end
    enrich(tree_nodes)
    iup.TreeAddNodes(tree_sol, tree_nodes)

end

local function Solution_Init()
    local prp = _G.iuprops['sidebar.functions.layout'] or ""
    local w
   -- for w in string.gmatch(prp, "[^|]+") do
   --    layout[w] = 'COLLAPSED'
    --end
    local line = nil                                                                                              --RGB(73, 163, 83)  RGB(30,180,30)
    tree_sol = iup.tree{minsize = '0x5', size=_G.iuprops["sidebar.functions.tree_sol.size"],
        showdragdrop='YES', showrename='YES', dropfilestarget='YES',}
        --Обработку нажатий клавиш производим тут, чтобы вернуть фокус редактору
        tree_sol.size = nil

        tree_sol.button_cb = (function(h,but, pressed, x, y, status)

            if but == 51 and pressed == 0 then --right
                h.value = iup.ConvertXYToPos(h,x,y)
                menuhandler:PopUp('MainWindowMenu¦_HIDDEN_¦Solution_sidebar')

            elseif but == 49 and iup.isdouble(status) then --dbl left
                if h.kind ~= 'BRANCH' then
                    OpenFile(h:GetUserId(h.value))
                    iup.PassFocus()
                end
            end
            if pressed == 0 and line ~= nil then
                iup.PassFocus()
                line = nil
            end
        end)
        tree_sol.k_any = (function(h,number)
            if number == 13 then
                OpenFile(h:GetUserId(h.value))
                iup.PassFocus()
            elseif number == 65307 then
                iup.PassFocus()
            end
        end)
        tree_sol.rename_cb = function() is_chanjed = true return -4 end
        tree_sol.dragdrop_cb = function() is_chanjed = true return -4 end
        tree_sol.killfocus_cb = SaveSolution
        tree_sol.tips_cb = function(h, x, y, status)
            h.tip = h:GetUserId(iup.ConvertXYToPos(h,x,y))
        end
        tree_sol.dropfiles_cb = function(h, filename, num, x, y)
            local val = iup.ConvertXYToPos(h,x,y)
            local _,_,fnExt = filename:find('([^\\]*)$')
            iup.SetAttributeId(tree_sol, "ADDLEAF", val, fnExt)
            iup.SetAttributeId(tree_sol, "IMAGE", val, GetExtImage(filename))
            tree_sol:SetUserId(val + 1, filename)
            is_chanjed = true
            SaveSolution()
        end

    SideBar_Plugins.solution = {   -- iup.vbox{   };
        handle = tree_sol;
        OnSwitchFile = Initialize,
        OnOpen = Initialize,
        on_SelectMe =Initialize
        }

end

menuhandler:InsertItem('MainWindowMenu', '_HIDDEN_¦s1',   --TODO переместить в SideBar\FindRepl.lua вместе с функциями
{'Solution_sidebar',  plane=1,{
    {'Insert Project', ru='Новый  проект', action=InsertProject},
    {'Delete Project', ru='Удалить  проект', action=function() DeleteNode(0) end, visible = function() return iup.GetAttribute(tree_sol, "KIND")=="BRANCH" and tree_sol.value~='0' end},
    {'Open All Projects Files', ru='Открыть все файлы проекта', action=OpenAll, visible = function() return iup.GetAttribute(tree_sol, "KIND")=="BRANCH" and tree_sol.value~='0' end},

    {'s_FindTextOnSel', separator=1},
    {'Add...', ru='Добавить...', action=Add},
    {'Add Curent File', ru='Добавить текущтй файл', action=AddCurent, visible=function() return shell.fileexists(props["FilePath"]) end },
    {'Add All Opened Files', ru='Добавить все открытые файлы', action=function() AddAll(tree_sol.value) end},
    {'Remove File', ru='Исключить файл из проекта', action=function() DeleteNode(1) end, visible = function() return iup.GetAttribute(tree_sol, "KIND")~="BRANCH" end},
    {'s1_FindTextOnSel', separator=1},
    {'Go To Directory', ru='Перейти в директорию', action =function() SideBar_Plugins.fileman.OpenDir(tree_sol:GetUserId(tree_sol.value):gsub('([^\\]*)$','')) end, visible = function() return iup.GetAttribute(tree_sol, "KIND")~="BRANCH" and (SideBar_Plugins.fileman ~= nil) end},
}})

menuhandler:InsertItem('TABBAR', 'slast',
    {'Save As New Project', ru='Сохранить как новый проект', action=SaveAsNew}
)

Solution_Init()
