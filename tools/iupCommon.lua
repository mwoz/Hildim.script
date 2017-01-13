--Constants
require 'shell'

local old_iup_ShowXY = iup.ShowXY

_G.iuprops = {}
local iuprops_read_ok = false
local file = props["scite.userhome"]..'\\settings.lua'

if shell.fileexists(file) then
    local text = ''
    if pcall(io.input, file) then
        text = io.read('*a')
        io.close()
    end
    local bSuc, tMsg = pcall(dostring,text)
    if not bSuc then
        print('ќшибка в файле settings.lua:', tMsg..'\nсохраним текущий settings.lua в settings.lua.bak')
        io.output(props["scite.userhome"]..'\\settings.lua.bak')
        io.write(text)
        io.close()
    end
elseif shell.fileexists(props["SciteDefaultHome"]..'\\data\\home\\default.config') then
    props['config.restore'] = props["SciteDefaultHome"]..'\\data\\home\\default.config'
else
    props['config.restore'] = props["SciteDefaultHome"]..'\\tools\\default.config'
end


if props['config.restore'] ~= '' then
    if pcall(io.input, props['config.restore']) then
        local l = (_G.iuprops['settings.lexers'] or '')
        text = io.read('*a')
        io.close()
        local bSuc, tMsg = pcall(dostring, text)
        if not bSuc then
            print('ќшибка в файле '..props['config.restore'], tMsg)
        elseif l ~= _G.iuprops['settings.lexers'] or '' then
            local t = {}
            for w in _G.iuprops['settings.lexers']:gmatch('[^¶]+') do
                local _,_, p4 = w:find('[^Х]*Х[^Х]*Х[^Х]*Х([^Х]*)')
                t[p4] = true
            end
            local str = ''
            for n,_ in pairs(t) do
                str = str..'import $(SciteDefaultHome)\\languages\\'..n..'\n'
                n = n:gsub('%.properties$', '.styles')
                if shell.fileexists(props["SciteUserHome"]..'\\'..n) then
                    str = str..'import $(scite.userhome)\\'..n..'\n'
                end
            end
            f = io.open(props['SciteUserHome']..'\\Languages.properties',"w")
            f:write(str)
            f:close()
            _G.iuprops['command.reloadprops'] = true
        end
    end
end
props['config.restore'] = ''
props['script.started'] = 'Y'

iuprops_read_ok = true

local function RestoreLayOut(strLay)
    strLay = strLay:gsub('^Х', '')
    for n in strLay:gmatch('%d+') do
        n = tonumber(n)
        if shell.bit_and(editor.FoldLevel[n],SC_FOLDLEVELHEADERFLAG) ~=0 then
            local lineMaxSubord = editor:GetLastChild(n,- 1)
            if n < lineMaxSubord then
                editor.FoldExpanded[n] = false
                editor:HideLines(n + 1, lineMaxSubord)
            end
        end
    end

end

rfl = oStack{50, _G.iuprops['resent.files.list']}
function rfl:GetMenu()
    local t = {}
    local function OpenMenu(i)
        return function()
            scite.Open(self.data.lst[i])
        end
    end

    local maxN = scite.buffers.GetCount() - 1
    local k = 1
    local ts = self.data.lst
    local cnt = #ts
    if cnt > (_G.iuprops['resent.files.list.length'] or 10) then cnt = (_G.iuprops['resent.files.list.length'] or 10) end
    for i = 1, cnt do
        local bSet = true
        for j = 0,maxN do
            if ts[i] == scite.buffers.NameAt(j):from_utf8(1251) then
                bSet = false
                break
            end
        end
        if bSet then
            local l = {}
            local s = ''
            if k < 11 then s = '&'..k..'.' end
            l[1] = s..ts[i]
            if ((_G.iuprops['resent.files.list.pathafter'] or 1) == 1) then
                l[1] = l[1]:gsub('(.+)[\\]([^\\]*)$', '%2\t%1')
            end
            l.action = OpenMenu(i)
            table.insert(t,l)
            k = k + 1
        end
    end
    table.insert(t,{'s0', separator = 1})
    table.insert(t,{'List Settings', ru = "—войства списка", action = function()
        local res, loc, len, pathAfter, bClear = iup.GetParam('Recent List Settings',
            nil,
            "Location in File menu: %o|Submenu|Bottom|\n"..
            "Length: %i[5,30,1]\n"..
            "Path After Name: %b\n"..
            "Clear Now: %b\n",
            _G.iuprops['resent.files.list.location'] or 0,
            _G.iuprops['resent.files.list.length'] or 10,
            _G.iuprops['resent.files.list.pathafter'] or 10,
            0
        )
        if res then
            _G.iuprops['resent.files.list.location'] = loc
            _G.iuprops['resent.files.list.length'] = len
            _G.iuprops['resent.files.list.pathafter'] = pathAfter
            if bClear == 1 then
                self.data.lst = {}
                self.data.pos = {}
                self.data.layout = {}
                self.data.bmk = {}
            end
        end
    end})
    return t
end

function rfl:check(fname)
    local str = fname:upper()
    local res = '{lst={'
    for i = 1,  #self.data.lst do
        if self.data.lst[i]:upper() == str then
            if editor.LineCount < (self.data.pos[i] or 0) then
                print("So match!", self.data.lst[i], self.data.pos[i], self.data.layout[i], self.data.bmk[i])
            end
            editor.FirstVisibleLine = (self.data.pos[i] or 0)
            RestoreLayOut(self.data.layout[i] or '')
            editor.FirstVisibleLine = (self.data.pos[i] or 0)
            local bk = self.data.bmk[i] or ''
            for g in bk:gmatch('[^¶]+') do
                editor:MarkerAdd(tonumber(g), 1)
                if BOOKMARK then BOOKMARK.Add(tonumber(g)) end
            end
            table.remove(self.data.lst, i)
            table.remove(self.data.pos, i)
            table.remove(self.data.layout, i)
            table.remove(self.data.bmk, i)
            return
        end
    end
end

iuprops['resent.files.list'] = rfl

_G.iuprops['pariedtag.on'] = _G.iuprops['pariedtag.on'] or 1

function iup.SaveChProps(bReset)
    local t = {
'buffers',
'buffers.new.position',
'buffers.zorder.switching',
'findres.magnification',
'findres.width',
'findres.wrap',
'iup.defaultfontsize',
'iuptoolbar.visible',
'line.margin.visible',
'magnification',
'output.magnification',
'output.vertical.size',
'output.wrap',
'position.height',
'position.left',
'position.maximize',
'position.top',
'position.width',
'print.magnification',
'tabbar.multiline',
'tabbar.tab.close.on.doubleclick',
'tabbar.title.maxlength',
'view.eol',
'view.indentation.guides',
'view.whitespace',
'wrap',
'wrap.aware.home.end.keys',
'wrap.indent.mode',
'wrap.style',
'wrap.visual.flags',
'wrap.visual.flags.location',
'wrap.visual.startindent',
    }
    for i = 1, #t do
        t[i] = t[i]..'='..props[t[i]]
    end
    local file = props["scite.userhome"]..'\\SciTE.session'
 	if pcall(io.output, file) then
		io.write(table.concat(t,'\n'))
 	end
	io.close()
    if bReset then scite.RunAsync(function() scite.Perform("reloadproperties:") end) end
end

local function SaveIup()
    if not iuprops_read_ok then return end
    local t = {}
    for n,v in pairs(_G.iuprops) do

        local tp = type(v)
        if tp == 'nil' then v = 'nil'
        elseif tp == 'boolean' or tp == 'number' then v = tostring(v)
        elseif tp == 'string' then
            v = "'"..v:gsub('\\', '\\\\'):gsub("'", "\\039").."'"
        elseif tp == 'table' and v.tostr then
            v = v:tostr()
        else
            iup.Message('Error', "Type "..tp.." can't be saved")
        end
        table.insert(t, '["'..n..'"] = '..v..",")
    end
    local file = props["scite.userhome"]..'\\settings.lua'
 	if pcall(io.output, file) then
		io.write('_G.iuprops = {\n'..table.concat(t,'\n')..'\n}')
 	end
	io.close()
    iup.SaveChProps()
end

local function SaveLayOut()
    local res = ''
    for l=0, editor.LineCount do
        if shell.bit_and(editor.FoldLevel[l],SC_FOLDLEVELHEADERFLAG) ~=0 and not editor.FoldExpanded[l] then res = res..','..l end
    end
    return res
end

iup.GetBookmarkLst = function()
    local ml, bk = 0, ''
    while true do
        ml = editor:MarkerNext(ml, 2)
        if (ml == -1) then break end
        bk = bk..'¶'..ml
        ml = ml + 1
    end
    return bk
end

iup.CloseFilesSet = function(cmd)
    local cur = -1   --9132 - закрыть все, кроме текущего, поэтому запомним текущий
    if cmd ==  9132 then cur = scite.buffers.GetCurrent() end

    local msg = ''
    local notSaved = {}

    local maxN = scite.buffers.GetCount() - 1
    for i = 0,maxN do
        local pth = scite.buffers.NameAt(i):from_utf8(1251)
        local _,_,fnExt = pth:find('([^\\]*)$')
        if not scite.buffers.SavedAt(i) and i ~= cur and (cmd ~= 9134 or pth:find('Ѕезым€нный')) and not fnExt:find('^%^') then
            msg = msg..pth:gsub('(.+)[\\]([^\\]*)$', '%2(%1)')..'\n'
            table.insert(notSaved, i)
        end
    end

    local result = 2
    if msg ~= '' then
        msg = msg..'—охранить все?'
        result = tonumber(iup.Alarm('Ќекоторые файлы не сохранены:', msg, 'ƒа', 'Ќет', 'ќтмена'))
        --result = shell.msgbox(msg, "Close", 3) --YESNOCANCEL Yes - 6, NO - 7 CANCEL - 2
        if result == 3 then return true end
        if result == 1 then
            for _,j in ipairs(notSaved) do
                scite.buffers.SetDocumentAt(j)
                scite.MenuCommand(IDM_SAVE)
            end
            if cmd == 9134 then return end
        end
    end
    if cmd == IDM_QUIT then
        props['are.you.sure.close'] = 0
        props['check.if.already.open'] = 0
        scite.HideForeReolad();
        ClearAllEventHandler();
    end
    local nf,spathes = false,'',''
    local sposes
    local slayout = ''
    if cmd == IDM_QUIT or cmd == 0 then sposes = '' end
    local curBuf = scite.buffers.GetCurrent()
    local tmpFlag = props['load.on.activate']
    props['load.on.activate'] = 0
    DoForBuffers(function(i)
        if i and i ~= cur and (cmd ~= 9134 or ((props['FilePath']:from_utf8(1251):find('Ѕезым€нный') or props['FileNameExt']:find('^%^')) and editor.Modify)) then
            editor:SetSavePoint()
            if not props['FileNameExt']:from_utf8(1251):find('Ѕезым€нный') and not props['FileNameExt']:find('^%^') then
                spathes = spathes..'Х'..props['FilePath']:from_utf8(1251)
                local bk = iup.GetBookmarkLst()
                if sposes then
                    sposes = sposes..'Х'..editor.FirstVisibleLine..bk
                    slayout = slayout..'Х'..SaveLayOut()
                end
                nf = true
            else
                if i <= curBuf then curBuf = curBuf - 1 end
            end
            if cmd ~= 0 then scite.MenuCommand(IDM_CLOSE) end
        end
    end)
    props['load.on.activate'] = tmpFlag
    if curBuf >= 0 then _G.iuprops['buffers.current'] = curBuf end
    if nf and ((cmd == IDM_QUIT  ) or cmd == 0) then    --если  buffers не сброшен в нул, значит была ошибка при загрузке
        _G.iuprops['buffers'] = spathes;
        _G.iuprops['buffers.pos'] = sposes
        _G.iuprops['buffers.layouts'] = slayout
    end
    if cmd == IDM_QUIT then iup.DestroyDialogs();SaveIup();
    else return true end
end

iup.RestoreFiles = function(bForce)
    if (props['session.started'] ~= '1' and _G.iuprops['session.reload'] == '1') or bForce then
        local bNew = (props['FileName'] ~= '')
        local t,p,bk,l = {},{},{},{}
        for f in (_G.iuprops['buffers'] or ''):gmatch('[^Х]+') do
            table.insert(t, f:to_utf8(1251))
        end
        local bki
        if _G.iuprops['buffers.pos'] then
            for f in _G.iuprops['buffers.pos']:gmatch('[^Х]+') do
                local i = 0
                for g in f:gmatch('[^¶]+') do
                    if i==0 then
                        table.insert(p, g)
                        bki = {}
                        table.insert(bk, bki)
                    else table.insert(bki, g) end
                    i = 1
                end
            end
        end
        if _G.iuprops['buffers.layouts'] then
            for f in _G.iuprops['buffers.layouts']:gmatch('Х[^Х]*') do
                table.insert(l, f)
            end
        end
        for i = #t,1,-1 do
            scite.Open(t[i])
            if p[i] then editor.FirstVisibleLine = tonumber(p[i]) end
            if bk and bk[i] then
                for j = 1, #(bk[i]) do
                    editor:MarkerAdd(tonumber(bk[i][j]), 1)
                    if BOOKMARK then BOOKMARK.Add(tonumber(bk[i][j])) end
                end
            end
            if l and l[i] then
                RestoreLayOut(l[i])
            end
        end
        --scite.EnsureV visible()
        if bNew then
            scite.buffers.SetDocumentAt(0)
        else
            local b = tonumber(_G.iuprops['buffers.current'] or -1)
            if b >= 0 then scite.buffers.SetDocumentAt(b) end
        end
    end
end

local function LoadSession_local(filename)
    if pcall(io.input, filename) then
        text = io.read('*a')
        io.close()
        local bSuc, tMsg = pcall(dostring,text)
        if not bSuc then
            print('ќшибка в файле '..filename, tMsg)
            return false
        end
        iup.RestoreFiles(true)
        _G.iuprops['buffers'] = nil
        return true
    end
end

iup.LoadSession = function()
    local d = iup.filedlg{dialogtype='OPEN', parentdialog='SCITE', extfilter='Session|*.fileset;', directory=props["SciteDefaultHome"].."\\data\\home\\" }
    d:popup()
    local filename = d.value
    d:destroy()
    if not filename then return end
    LoadSession_local(filename)
end

iup.SaveSession = function()
    local d = iup.filedlg{dialogtype='SAVE', parentdialog='SCITE', extfilter='Session|*.fileset;', directory=props["SciteDefaultHome"].."\\data\\home\\" }
    d:popup()
    local filename = d.value
    d:destroy()

    if not filename then return end
    if not filename:lower():find('%.fileset$') then filename = filename..'.fileset' end
    if iup.CloseFilesSet(0) then

        local t = {}
        for n,v in pairs(_G.iuprops) do
            local _,_,prefix = n:find('([^%.]*)')
            if prefix == 'buffers' then
                local tp = type(v)
                if tp == 'nil' then v = 'nil'
                elseif tp == 'boolean' or tp == 'number' then v = tostring(v)
                elseif tp == 'string' then
                    v = "'"..v:gsub('\\', '\\\\'):gsub("'", "\\039").."'"
                elseif tp == 'table' and v.tostr then
                    v = v:tostr()
                else
                    iup.Message('Error', "Type "..tp.." can't be saved")
                end
                table.insert(t, '_G.iuprops["'..n..'"] = '..v)
            end
        end


        if pcall(io.output, filename) then
            io.write(table.concat(t,'\n'))
            io.close()
        end
    end
end

function CORE.HelpUI(helpid, anchor)
    local dv, fl = 'Hildim', helpid
    local _, _, d, f = helpid:find('(.*)::(.*)')
    if d then dv, fl = d, f end

    if shell.fileexists(props['SciteDefaultHome']..'/help/'..dv..'.chm') then
        local strCmd = props['SciteDefaultHome']..'/help/'..dv..'.chm::ui/'..fl..'.html'
        if anchor then strCmd = strCmd..'#'..anchor end
        --print(strCmd)
        scite.ExecuteHelp(strCmd, 0)
    elseif shell.fileexists(props['SciteDefaultHome']..'/help/'..dv..'/ui/'..fl..'.html') then
        local url = 'file:///'..props['SciteDefaultHome']..'/help/'..dv..'/ui/'..fl..'.html'
        if anchor then url = url..'#'..anchor; print(anchor) end
        shell.exec(url)
    else print(dv..'/ui/'..fl..'.html'..' - file not found') end
end

function CORE.SwitchPane(bForward)
    if bForward then
        if editor.Focus then
            iup.SetFocus(iup.GetDialogChild(iup.GetLayout(), "FindRes"))
        elseif findres.Focus then
            iup.SetFocus(iup.GetDialogChild(iup.GetLayout(), "Run"))
        else
            iup.PassFocus()
        end
    else
        if editor.Focus then
            iup.SetFocus(iup.GetDialogChild(iup.GetLayout(), "Run"))
        elseif output.Focus then
            iup.SetFocus(iup.GetDialogChild(iup.GetLayout(), "FindRes"))
        else
            iup.PassFocus()
        end
    end
end

AddEventHandler("OnMenuCommand", function(cmd, source)

    if cmd == 9132 or cmd == 9134 or cmd == IDM_CLOSEALL or cmd == IDM_QUIT then
        return iup.CloseFilesSet(cmd)
    elseif cmd == 9117 or cmd == IDM_REBOOT then  --перезагрузка скрипта
        iup.DestroyDialogs();
        SaveIup()
        scite.RunAsync(function()
                print("Reload IDM...")
                scite.ReloadStartupScript()
                OnSwitchFile("")
                print("...Ok")
            end)
        return true
    elseif cmd == IDM_TOGGLEOUTPUT then
        local hMainLayout = iup.GetLayout()
        local bHidden = (tonumber(iup.GetDialogChild(hMainLayout, "BottomBarSplit").barsize) == 0)
        if bHidden then
            local l =  (_G.iuprops['bottombar.layout'] or 700500)
            local v2 = l % 10000
            if SideBar_Plugins.findrepl.Bar_obj then v2 = 0 end
            local v = math.floor(l / 10000)
            iup.GetDialogChild(hMainLayout, "BottomBarSplit").barsize = '3'
            iup.GetDialogChild(hMainLayout, "BottomExpander").state = 'OPEN'
            if v > 0 then iup.GetDialogChild(hMainLayout, "ConsoleDetach").Attach() end
            if v < 1000 then iup.GetDialogChild(hMainLayout, "FindResDetach").Attach() end
            if v2 < 1000 and v2 ~= 0 then iup.GetDialogChild(hMainLayout, "FindReplDetach").Attach() end
            iup.GetDialogChild(hMainLayout, "BottomBarSplit").value = _G.iuprops["sidebarctrl.BottomBarSplit.value"] or '900'
            if v2 < 1000 and v2 ~= 0 then iup.GetDialogChild(hMainLayout, "BottomSplit2").value = v2 end
            iup.GetDialogChild(hMainLayout, "BottomSplit").value = v
        else
            _G.iuprops['bottombar.layout'] = iup.GetDialogChild(hMainLayout, "BottomSplit").value * 10000 + iup.GetDialogChild(hMainLayout, "BottomSplit2").value

            iup.GetDialogChild(hMainLayout, "BottomBarSplit").barsize = '0'
            if (_G.iuprops['concolebar.win'] or '0') == '0' then iup.GetDialogChild(hMainLayout, "ConsoleDetach").cmdHide() end
            if (_G.iuprops['findresbar.win'] or '0') == '0' then iup.GetDialogChild(hMainLayout, "FindResDetach").cmdHide() end
            iup.GetDialogChild(hMainLayout, "BottomExpander").state = 'CLOSE'
            local v = tonumber(iup.GetDialogChild(hMainLayout, "BottomBarSplit").value)
            if v > 950 then v = 950
            elseif v < 100 then v = 100 end
            _G.iuprops["sidebarctrl.BottomBarSplit.value"] = ''..v
            iup.GetDialogChild(hMainLayout, "BottomBarSplit").value = '1000'
        end
    elseif cmd == IDM_CLOSE then
        local source = props["FilePath"]
        if source:find('^%^') then return end
        if not source:find('^\\\\') then
            if not shell.fileexists(source:from_utf8(1251)) then return end
        end
    elseif cmd == IDM_HELP then
        local h = iup.GetFocus()
        local hlp
        while h do
            if h.helpid then hlp = h end
            if h.name or not h.helpid then break end
            h = iup.GetParent(h)
        end
        if hlp then
            CORE.HelpUI(hlp.helpid, hlp.name)
            return true
        end
        if output.Focus then CORE.HelpUI("outputpane", nil); return true end
        if findres.Focus then CORE.HelpUI("findrespane", nil); return true end
    end
end)

AddEventHandler("OnSave", function(cmd, source)
    if props["ext.lua.startup.script"] == props["FilePath"] then
        scite.RunAsync(iup.ReloadScript)
    elseif editor.Lexer == SCLEX_LUA then
        local lp = output.TextLength
        scite.RunAsync(function()
            if lp ~= output.TextLength then
                s, e = output:findtext('\\w.+?\]:', SCFIND_REGEXP, lp)
                if s then
                    output.TargetStart = s
                    output.TargetEnd = e
                    output:ReplaceTarget(props["FilePath"]..':')
                end
            end
        end)
        assert(loadstring(editor:GetText()))
        return
    end
end)

AddEventHandler("OnClose", function(source)
    if source:find('^%^') then return end
    if not source:find('^\\\\') then
        if not shell.fileexists(source:from_utf8(1251)) then return end
    end
    iuprops['resent.files.list']:ins(source:from_utf8(1251), editor.FirstVisibleLine, SaveLayOut(), iup.GetBookmarkLst())
    if scite.buffers.GetCount() == 1 and editor.ReadOnly then scite.MenuCommand(IDM_READONLY) end
end)

AddEventHandler("OnOpen", function(source)
    if source:find('^%^') then return end
    if not source:find('^\\\\') then
        if not shell.fileexists(source:from_utf8(1251)) then return end
    end
    iuprops['resent.files.list']:check(source:from_utf8(1251))
    if props['session.started'] ~= '1' and props['session.reload'] ~= '1' then print('') end --??почему-то этот вывод ликвидирует по€вление звездочки в названии при открытии из оболочки
end)

--–асширение iup.TreeAddNodes - позвол€ет в табличном представлении дерева задавать свойство userdata
local old_TreeSetNodeAttrib = iup.TreeSetNodeAttrib
iup.TreeSetNodeAttrib = function (handle, tnode, id)
  old_TreeSetNodeAttrib(handle, tnode, id)
  if tnode.userdata then iup.SetAttribute(handle, "USERDATA"..id, tnode.userdata) end
  if tnode.imageid then iup.SetAttribute(handle, "IMAGE"..(id), tnode.imageid) end

end
--ѕереопредел€ем iup сообщение об ошибке - чтобы не было их всплывающего окна, печатаем все к нам в output
iup._ERRORMESSAGE = function(msg,traceback)
    print(msg..(traceback or ""))
end
function list_getvaluenum(h)
    local l = h.focus_cell:gsub(':.*','')
    return tonumber(l)
end

function Iif(b,a,c)
    if b then return a end
    return c
end

function Min(a,b)
    if a < b then return a end
    return b
end
function Max(a,b)
    if a > b then return a end
    return b
end

local old_matrix = iup.matrix
iup.matrix = function(t)
    t.hlcolor="255 255 255"
    t.hlcoloralpha="255"
    local mtr = old_matrix(t)
    function mtr:SetCommonCB(act_act,act_resel, act_esc, act_right)
        local function a_cb(h, key, lin, col, edition, value)
            if key == iup.K_DOWN then  --down
                local sel = 1
                if h.marked then sel = h.marked:find('1') end
                sel = sel - 1
                if sel < h.count - 1 then
                    iup.SetAttribute(h, 'MARK'..(sel)..':0', 0)
                    iup.SetAttribute(h, 'MARK'..(sel+1)..':0', 1)
                    h.focus_cell = (sel+1)..":1"
                    h.redraw = "ALL"
                    if act_resel then act_resel(sel) end
                end
                return -1
            elseif key == iup.K_UP then  --up
                local sel = h.marked:find('1')
                if sel == nil then sel = h.count + 2 end
                sel = sel - 1
                if sel > 1 then
                    iup.SetAttribute(h, 'MARK'..(sel)..':0', 0)
                    iup.SetAttribute(h, 'MARK'..(sel-1)..':0', 1)
                    h.focus_cell = (sel-1)..":1"
                    h.redraw = "ALL"
                    if act_resel then act_resel(sel) end
                end
                return -1
            elseif key == 13 then
                if act_act then act_act(lin) end
            elseif key == iup.K_ESC then --escape
                if act_esc then act_esc() end
            end
        end
        local function c_cb(h, lin, col, status)
            local sel = 0
            if h.marked then sel = h.marked:find('1') - 1 end
            iup.SetAttribute(h,  'MARK'..sel..':0', 0)
            iup.SetAttribute(h, 'MARK'..lin..':0', 1)
            h.redraw = lin..'*'
            if iup.isdouble(status) and iup.isbutton1(status) then
                if act_act then act_act(lin) end
                return -1
            elseif iup.isbutton3(status) then
                h.focus_cell = lin..':'..col
                if act_right then act_right(lin) end
            end
            if lin ~= sel and act_resel then act_resel(sel) end
        end
        self.action_cb = a_cb
        self.click_cb = c_cb
    end
    function mtr.FitColumns(n, block, s)
        return function(h, col)
            local h = mtr
            if not block or n == col then col = (s or 0) end
            local w = h.rastersize:gsub('x.*', '') - (16 + 8*n)
            local w0 = w
            for i = 1, col do
                w = w - h["rasterwidth"..i]
            end
            local wp = 0
            for i = col + 1, n do
                wp = wp + h["rasterwidth"..i]
            end
            local l = w / wp

            local iMax, lMax = 0, 0
            w = 0
            for i = 1, n do
                if i > col then
                    h["rasterwidth"..i] = math.floor(h["rasterwidth"..i] * l)
                    if tonumber(h["rasterwidth"..i]) < 2 then
                        h["rasterwidth"..i] = 5
                    elseif lMax < tonumber(h["rasterwidth"..i]) then
                        lMax = tonumber(h["rasterwidth"..i])
                        iMax = i
                    end
                end
                w = w + h["rasterwidth"..i]

                if h.name and block then _G.iuprops[h.name..'.rw'..i] = h["rasterwidth"..i] end
            end
            w = w - w0
            if w > 0 and lMax - 5 > w then
                h["rasterwidth"..iMax] = h["rasterwidth"..iMax] - w
            end
        end
    end
    return mtr
end

local old_iup_expander = iup.expander
iup.expander = function(t)
    local expand = old_iup_expander(t)

    function expand:switch()
        if expand.state == 'OPEN' then expand.state = 'CLOSE'
        else expand.state = 'OPEN' end
    end

    function expand:isOpen() return expand.state == 'OPEN' end

    return expand
end

local old_iup_list = iup.list
iup.list = function(t)
    local cmb = old_iup_list(t)
    function cmb:FillByDir(pathmask, strSel)
        local current_path = props["sys.calcsybase.dir"]..pathmask

        local files = shell.findfiles(current_path)
        if not files then return end
        table.sort(files, function(a, b) return a.name:lower() < b.name:lower() end)
        if files then
            local i, filename
            local j = 1
            for i, filename in ipairs(files) do
                if not filename.isdirectory then
                    iup.SetAttribute(self, j, filename.name)
                    if filename.name == strSel then self.value = j end
                    j = j + 1
                end
            end
        end
    end
    function cmb:FillByHist(sHist,sLast)
        sHist = props[sHist]:gsub('||', 'З')..'З'
        i = 1
        for elem in sHist:gmatch('([^|]+)|') do
            iup.SetAttribute(self, i, elem:gsub('З', '|'))
            i = i + 1
        end
        if sLast then self.value = props[sLast] end
    end
    function cmb:SaveHist()
        local s = self.value
        self.insertitem1 = s

        local i = tonumber(self.count)
        local mn = tonumber(self.visibleitems)
        while(i > 1) do
            if i> mn-1 or (iup.GetAttribute(self,i) == s) then
                self.removeitem = i
            end
            i = i - 1
        end
        self.value = s
    end
    return cmb
end

iup.scitedeatach = function(dtb)
    dtb.detachhidden = 1
    iup.ShowXY(dtb.Dialog, _G.iuprops['dialogs.'..dtb.sciteid..'.x'] or '100', _G.iuprops['dialogs.'..dtb.sciteid..'.y'] or '100')
end

iup.scitedetachbox = function(t)
    local dtb, statusBtn, cmd_Hide, cmd_Attach
    local bMoved = 0, sX, sY, bRecurs

    local function button_cb(h, button, pressed, x, y, status)
        h.value = 0
        if not dtb.Dialog then return end
        if button == 49  then
            bMoved = pressed; sX = x; sY = y
            if bMoved == 0 then
                _G.iuprops['dialogs.'..dtb.sciteid..'.x']= dtb.Dialog.x
                _G.iuprops['dialogs.'..dtb.sciteid..'.y']= dtb.Dialog.y
            end
        end
    end

    local function motion_cb(h, x, y, status)
    h.value=1
        if not dtb.Dialog then return end
        if bMoved == 1 and sX and sY and not bRecurs then
            local _,_,wx,wy = dtb.Dialog.screenposition:find('(%-?%d*),(%-?%d*)')
            local nX, nY = tonumber(wx) + (x - sX), tonumber(wy) + (y - sY)
            bRecurs = true
            if nX ~= wx or nY ~= wy then old_iup_ShowXY(dtb.Dialog, nX, nY) end
            bRecurs = false
        end
    end

    local function get_scId()
        return _G.iuprops[dtb.sciteid..'.win'] or '0'
    end
    local btn_attach = iup.flatbutton{image = 'ui_toolbar__arrow_µ', canfocus='NO', name = t.sciteid..'_title_btnattach', tip='Attach', flat_action = function() cmd_Attach() end}

    btn_attach.image.bgcolor = iup.GetGlobal('DLGBGCOLOR')
    local hbTitle = iup.expander{iup.hbox{ alignment='ACENTER',bgcolor=iup.GetGlobal('DLGBGCOLOR'), name = t.sciteid..'_title_hbox', fontsize=iup.GetGlobal("DEFAULTFONTSIZE"), gap = 5,

        iup.flatbutton{title = ' '..t.Dlg_Title, image=t.buttonImage, maxsize = 'x20', fontsize='9',flat='YES',border='NO',padding='3x', alignment='ALEFT',
        canfocus='NO', expand = 'HORIZONTAL', size = '100x20', button_cb = button_cb, motion_cb = motion_cb, enterwindow_cb=function() end,
        leavewindow_cb=function() end,},
        btn_attach,
        iup.flatbutton{image = 'cross_button_µ', tip='Hide', canfocus='NO', flat_action = function() cmd_Hide() end},
    }, barsize = 1, state='CLOSE', name = t.sciteid..'_expander'}
    if t[1] then
        local vb = t[1]
        table.remove(t)
        table.insert(t, iup.vbox{hbTitle, vb, fontsize=iup.GetGlobal("DEFAULTFONTSIZE"),})
    else
        local pVbx = iup.GetDialogChild(t.HANDLE, t.sciteid..'_vbox')
        local exOld = iup.GetDialogChild(pVbx, t.sciteid..'_expander')
        if exOld then
            iup.Detach(exOld)
            iup.Destroy(exOld)
        end
        local hTmp = iup.dialog{hbTitle}
        local hBT = iup.GetDialogChild(hTmp, t.sciteid..'_expander')
        iup.Detach(hBT)
        iup.Destroy(hTmp);hTmp = nil
        iup.Insert(pVbx, nil, hBT)

        iup.Map(hBT)
    end
    dtb = t.HANDLE or iup.sc_detachbox(t)
    dtb.sciteid = t.sciteid
    dtb.Dlg_Close_Cb = t.Dlg_Close_Cb
    dtb.Dlg_Show_Cb = t.Dlg_Show_Cb
    dtb.Split_h = t.Split_h
    dtb.Split_Title = t.Split_Title
    dtb.Split_CloseVal = t.Split_CloseVal
    dtb.On_Detach = t.On_Detach
    dtb.barsize = 0

    dtb.detachPos = (function(bShow)
        dtb.detachhidden = 1
        _G.iuprops[dtb.sciteid..'.win']= Iif(bShow,'1', '2')
        hbTitle.state = 'OPEN'
        dtb.Dialog.rastersize = _G.iuprops['dialogs.'..dtb.sciteid..'.rastersize']

        if t.Split_h then
            if dtb.Split_h.barsize ~= "0" then _G.iuprops['dialogs.'..dtb.sciteid..'.splitvalue'] = dtb.Split_h.value; _G.iuprops['sidebarctrl.'..dtb.Split_h.name..'.value'] = dtb.Split_h.value; end
            dtb.Split_h.value = dtb.Split_CloseVal
            dtb.Split_h.barsize = "0"
        end
        _G.dialogs[dtb.sciteid] = dtb
        dtb.Dialog.rastersize = _G.iuprops['dialogs.'..dtb.sciteid..'.rastersize']
        if bShow then
            iup.ShowXY(dtb.Dialog, _G.iuprops['dialogs.'..dtb.sciteid..'.x'] or '100', _G.iuprops['dialogs.'..dtb.sciteid..'.y'] or '100')
        else
            if statusBtn then statusBtn.visible = 'YES' end
        end
        if not bShow and dtb.Dlg_Show_Cb then dtb.Dlg_Show_Cb(dtb.Dialog, 0) end
    end)

    dtb.detached_cb=(function(h, hNew, x, y)
        dtb.Dialog = hNew
        if h.On_Detach then h.On_Detach(h, hNew, x, y) end
        hNew.resize ="YES"
        hNew.shrink ="YES"
        hNew.minsize="100x100"
        hNew.maxbox="NO"
        hNew.minbox="NO"
        hNew.menubox="NO"
        hNew.toolbox="YES"
  --[[      hNew.title= t.Dlg_Title or "dialog"]]
        hNew.x=10
        hNew.y=10
        x=10;y=10
        local firstShow = true
        hNew.rastersize = _G.iuprops['dialogs.'..h.sciteid..'.rastersize']
        _G.iuprops[h.sciteid..'.win']='1'
        if h.Split_h then  _G.iuprops['dialogs.'..h.sciteid..'.splitvalue'] = h.Split_h.value end
        hNew.close_cb =(function(h)
            if _G.dialogs[dtb.sciteid] ~= nil then
                dtb.HideDialog()
                return -1
            end
        end)
        hNew.show_cb=(function(h,state)
            if bMoved == 1 then return end
            if state == 0 then
                dtb.visible = 'YES'
                if OnResizeSideBar then OnResizeSideBar(t.sciteid) end
            end
            if dtb.Dlg_Show_Cb then dtb.Dlg_Show_Cb(h, state) end
        end)

        if tonumber(_G.iuprops['dialogs.'..h.sciteid..'.x'])== nil or tonumber(_G.iuprops['dialogs.'..h.sciteid..'.y']) == nil then _G.iuprops['dialogs.'..h.sciteid..'.x']=0;_G.iuprops['dialogs.'..h.sciteid..'.y']=0 end
        hNew.button_cb = function(h, button, pressed, x, y, status) end
        hNew.move_cb = function(h, x, y)
            _G.iuprops['dialogs.'..dtb.sciteid..'.y']= y
            _G.iuprops['dialogs.'..dtb.sciteid..'.x']= x
        end
        hNew.resize_cb = function(h, x, y)
            _G.iuprops['dialogs.'..dtb.sciteid..'.rastersize'] = h.rastersize
            if OnResizeSideBar then OnResizeSideBar(t.sciteid) end
        end
    end)
    dtb.HideDialog = function()
        if dtb.Dialog then
            dtb.Dialog:hide()
            _G.iuprops[dtb.sciteid..'.win'] = '2'
            iup.PassFocus()
            if statusBtn then statusBtn.visible = 'YES' end
        end
    end
    dtb.ShowDialog = function()
        if dtb.Dialog and (_G.iuprops[dtb.sciteid..'.win'] or '0') == '2' then
            _G.iuprops[dtb.sciteid..'.win'] = '1'
            iup.ShowXY(dtb.Dialog, _G.iuprops['dialogs.'..dtb.sciteid..'.x'] or '100', _G.iuprops['dialogs.'..dtb.sciteid..'.y'] or '100')
            if statusBtn then statusBtn.visible = 'NO' end
        end
    end

    dtb.onSetStaticControls = function()
        --btn_attach.active = Iif(FindReplButCondition(),'YES', 'NO')
    end
    dtb.Attach = function()
        if t.Dlg_BeforeAttach then t.Dlg_BeforeAttach() end
        if _G.dialogs[dtb.sciteid] ~= nil then
            if dtb.Dlg_Close_Cb then dtb.Dlg_Close_Cb(h) end

            _G.iuprops[dtb.sciteid..'.win'] = '0'
            local canvasbar
            if dtb.sciteid == 'concolebar' or dtb.sciteid == 'findresbar' then
                canvasbar = iup.GetChild(iup.GetChild(_G.dialogs[dtb.sciteid], 1), 1)
                canvasbar.visible = 'NO'
            end

            hbTitle.state = 'CLOSE'
            dtb.visible = 'YES'

            dtb.restore = nil
            _G.dialogs[dtb.sciteid] = nil
            if t.Split_h then
                local l = tonumber(_G.iuprops['dialogs.'..dtb.sciteid..'.splitvalue'] or 500)
                if l < 15 and dtb.sciteid == 'concolebar' then l = 200
                elseif l > 985 and dtb.sciteid == 'findresbar'  then l = 800 end
                dtb.Split_h.value = l
                dtb.Split_h.barsize = "3"
            end
            dtb.Dialog = nil
            if statusBtn then statusBtn.visible = 'NO' end
            if OnResizeSideBar then OnResizeSideBar(t.sciteid) end
            if canvasbar then canvasbar.visible = 'YES' end
        end
    end

    cmd_Attach = function ()
        if get_scId() == "0" then return end
        if tonumber(iup.GetDialogChild(iup.GetLayout(), "BottomBarSplit").barsize) == 0 then
            scite.MenuCommand(IDM_TOGGLEOUTPUT)
            if get_scId() == "0" then return end
        end
        dtb.Attach()
    end

    local function cmd_PopUp()
        if get_scId()=="0" then
            dtb.detachPos(true)
        elseif get_scId()=="2" then
            dtb.ShowDialog()
        end
        if statusBtn then statusBtn.visible = 'NO' end
    end

    cmd_Hide = function ()
        if get_scId()=="2" then return end
        if statusBtn then _G.iuprops[t.sciteid..'.visible.state'] = get_scId() end
        if get_scId()=="0" then
            dtb.detachPos(false)
        elseif get_scId()=="1" then
            dtb.HideDialog()
        end
        if statusBtn then statusBtn.visible = 'YES' end
    end
    dtb.cmdHide = function() cmd_Hide() end

    local function cmd_Switch()
        if (_G.iuprops[t.sciteid..'.win'] or "0") ~= "2" then
            cmd_Hide()
        elseif (_G.iuprops[t.sciteid..'.visible.state'] or "1") == "1" then
            cmd_PopUp()
        elseif (_G.iuprops[t.sciteid..'.visible.state'] or "1") == "0" then
            cmd_Attach()
        end
        if t.onFormSetStaticControls then t.onFormSetStaticControls() end
    end

    dtb.Switch = cmd_Switch

    if t.buttonImage then
        if not _tmpSidebarButtons then _tmpSidebarButtons = {} end
        statusBtn = iup.flatbutton{image = t.buttonImage, visible = "NO", canfocus  = "NO", flat_action=cmd_Switch,
                                   tip=t.Dlg_Title,}
        function statusBtn:flat_button_cb(button, pressed, x, y, status) if button==51 and pressed == 1 then menuhandler:PopUp('MainWindowMenu¶View¶'..t.sciteid) end end
        table.insert(_tmpSidebarButtons, statusBtn)
    end

    local tSub = {radio = 1,
        {'Attached', ru='«акреплено', action=cmd_Attach, check = function() return get_scId()=="0" end,},
        {'Pop Up', ru='¬сплывающее окно', action=cmd_PopUp, check = function() return get_scId()=="1" end, },
        {'Hidden', ru='—крыто', action=cmd_Hide, check = function() return get_scId()=="2" end },
        {'Show/Hide', ru='—крыть/ѕоказать (√ор€ча€ клавиша)', action=cmd_Switch, visible = false },
    }

    menuhandler:InsertItem('MainWindowMenu', 'View¶slast',  {dtb.sciteid, ru = t.Dlg_Title, tSub})

    if t.MenuEx then menuhandler:InsertItem(t.MenuEx, 'xxxxxx', {'View', ru = '¬ид', tSub}) end

    return dtb
end

iup.ShowXY = function(h,x,y)
    x = tonumber(x)
    y = tonumber(y)
    local _,_,_,_,x2,y2 = iup.GetGlobal('VIRTUALSCREEN'):find('(%-?%d*) (%-?%d*) (%-?%d*) (%-?%d*)')
    x2 = tonumber(x2)
    y2 = tonumber(y2)
    if x > x2 - 10 then x = 100 end
    if y > y2 - 10 then y = 100 end
    return old_iup_ShowXY(h,x,y)
end

iup.ShowInMouse = function(dlg)
    local cPos = editor.SelectionEnd
    local _, _, xC, yC, dY
    if editor.FirstVisibleLine <= editor:LineFromPosition(cPos) and
        editor:LineFromPosition(cPos) <= editor.FirstVisibleLine + editor.LinesOnScreen then
        dY = editor:TextHeight(editor:LineFromPosition(cPos))
        _, _, xC, yC = iup.GetDialogChild(iup.GetLayout(), "Source").Screenposition:find('(%d+),(%d+)')
        xC = tonumber(xC) + editor:PointXFromPosition(cPos) + editor:TextWidth(editor.StyleAt[cPos], ' ') * editor.SelectionNCaretVirtualSpace[0]
        yC = tonumber(yC) + editor:PointYFromPosition(cPos) + dY
    else
        _, _, xC, yC = iup.GetGlobal('CURSORPOS'):find('(%d+)x(%d+)')
        dY = 0
    end
    local _, _, xD, yD = dlg.RASTERSIZE:find('(%d+)x(%d+)')
    xC = tonumber(xC)
    xD = tonumber(xD)
    yC = tonumber(yC)
    yD = tonumber(yD)

    for x0S, y0S, xS, yS in iup.GetGlobal('MONITORSINFO'):gmatch('(%d+) (%d+) (%d+) (%d+)') do
        x0S = tonumber(x0S)
        y0S = tonumber(y0S)
        xS = tonumber(xS) + x0S
        yS = tonumber(yS) + y0S
        if x0S <= xC and xC <= xS and y0S <= yC and yC <= yS then
            if xC + xD > xS then xC = xC - xD if xC < x0S then xC = x0S end end
            if yC + yD > yS then yC = yC - yD - dY if yC < y0S then yC = y0S end end
            dlg:showxy(xC, yC)
            return
        end
    end
    dlg:showxy(10, 10)
end
---–асширение iup

_G.dialogs = {}
iup.scitedialog = function(t)
    local dlg = _G.dialogs[t.sciteid]
    if dlg == nil then
        dlg = iup.dialog(t)
        iup.SetNativeparent(dlg, t.sciteparent)
        _G.dialogs[t.sciteid] = dlg
        if dlg.resize == 'YES' then dlg.rastersize = _G.iuprops['dialogs.'..t.sciteid..'.rastersize'] end
        if t.sciteparent == "IUPTOOLBAR" then
            dlg:showxy(0,0)
        elseif t.sciteparent == "IUPSTATUSBAR" then
            dlg:showxy(0,0)
        elseif t.sciteid == "splash" then
            local _,_,x2,y2 = iup.GetGlobal('SCREENSIZE'):find('(%d*)x(%d*)')
            dlg:showxy(tonumber(x2)/2 - 100,tonumber(y2)/2 - 100)
        elseif t.dropdown then
            dlg:showxy(-2000, -2000)
            dlg:hide()
            function dlg:k_any(k)
                if k == iup.K_ESC then iup.PassFocus() end
            end
        elseif t.sciteparent == "SCITE" then
            dlg:showxy((tonumber(_G.iuprops['dialogs.'..t.sciteid..'.x']) or 400),(tonumber(_G.iuprops['dialogs.'..t.sciteid..'.y'])) or 300)
        else
            local w = (_G.iuprops['dialogs.'..t.sciteid..'.rastersize'] or ''):gsub('x%d*', '')
            if w=='' then w='300' end
            if tonumber(w) < 10 then w = '300' end
            dlg:showxy(0,0)
            iup.ShowSideBar(tonumber(w))
        end
        function dlg:postdestroy()
            scite.RunAsync(function()
                if _G.dialogs[t.sciteid] then
                    _G.iuprops['dialogs.'..t.sciteid..'.rastersize'] = dlg.rastersize
                    _G.iuprops['dialogs.'..t.sciteid..'.x'] = dlg.x
                    _G.iuprops['dialogs.'..t.sciteid..'.y'] = dlg.y

                    _G.dialogs[t.sciteid] = nil
                    dlg:hide()
                    dlg:destroy()
                elseif t.sciteid == 'splash' then
                    dlg:hide()
                    dlg:destroy()
                end
            end)
        end
        local id = t.sciteid
        if t.hlpdevice then id = t.hlpdevice..'::'..id end
        iup.SetAttribute(dlg, "HELPID", t.sciteid)
    else
        dlg:show()
    end
    return dlg
end

iup.drop_cb_to_list = function(list, action)
    local mousemove_cb_old =list.mousemove_cb
    list.mousemove_cb = function(h, lin, col)
        if lin == 0 then return end
        if iup.GetAttributeId2(list, 'MARK', lin, 0) ~= '1' then

            list.marked = nil
            iup.SetAttributeId2(list, 'MARK', lin, 0, 1)
            list.FOCUSCELL = lin..':1'
            list.SHOW = lin..':1'
            list.redraw = 'ALL'
        end
        if mousemove_cb_old then mousemove_cb_old(h, lin, col) end

    end

    if not list.leavewindow_cb then
        function list:leavewindow_cb()
            -- if blockReselect then return end
            list.marked = nil
            list.redraw = 'ALL'
        end
    end

	list.click_cb = function(_, lin, col, status)
        if (iup.isdouble(status) or bToolBar) and iup.isbutton1(status) then
            action(lin)
        end
    end

    local keypress_cb_old = list.keypress_cb
	list.keypress_cb = function(h, k, press)
        if press == 0 then return end
        if k == iup.K_ESC then
            iup.PassFocus()
        elseif k == iup.K_CR then
            local l = 0
            if list.marked then l = tonumber(list.marked:find('1') or 1) - 1 end
            if l >= 1 then
                action(l)
            end
        elseif k == iup.K_DOWN then
            local l = 1
            if list.marked then l = tonumber(list.marked:find('1') or '1') end
            if l <= tonumber(list.numlin) then
                list.marked = nil
                iup.SetAttributeId2(list, 'MARK', l, 0, 1)
                list.FOCUSCELL = l..':1'
                list.SHOW = l..':1'
                list.redraw = 'ALL'
                return iup.IGNORE
            end
        elseif k == iup.K_UP then
            local l = tonumber(list.numlin)
            if list.marked then l = tonumber(list.marked:find('1') or list.numlin) - 2 end
            if l >= 1 then
                list.marked = nil
                iup.SetAttributeId2(list, 'MARK', l, 0, 1)
                list.FOCUSCELL = l..':1'
                list.SHOW = l..':1'
                list.redraw = 'ALL'
                return iup.IGNORE
            end
        elseif keypress_cb_old then
            return keypress_cb_old(h, k, press)
        end
	end
end

function iup.ReloadScript()
    print("Reload...")
    scite.HideForeReolad()
    local bd
    local tblDat
    if OnScriptReload then tblDat = {}; OnScriptReload(true, tblDat) end
    iup.DestroyDialogs();
    SaveIup()
    scite.ReloadStartupScript()
    if OnScriptReload then OnScriptReload(false, tblDat) end
    OnSwitchFile("")
    scite.EnsureVisible()
    iup.GetLayout().resize_cb()
    print("...Ok")
    if _G.iuprops['command.reloadprops'] then _G.iuprops['command.reloadprops'] = false; scite.RunAsync(function() scite.Perform("reloadproperties:") end) end
end

AddEventHandler("OnContextMenu", function(lp, wp, source)
    menuhandler:ContextMenu(lp, wp, source)
    return ""
end)

local function LoadIuprops_Local(filename)
    props['config.restore'] = filename
    _G.iuprops['current.config.restore'] = filename
    scite.RunAsync(iup.ReloadScript)
end

iup.LoadIuprops = function()
    local d = iup.filedlg{dialogtype='OPEN', parentdialog='SCITE', extfilter='Config|*.config;', directory=props["SciteDefaultHome"].."\\data\\home\\" }
    d:popup()
    local filename = d.value
    d:destroy()
    if not filename then return end
    LoadIuprops_Local(filename)
end


AddEventHandler("OnBeforeOpen", function(file, ext)
    if ext == "fileset" then
        return LoadSession_local(file)
    elseif ext == "config" then
        LoadIuprops_Local(file)
        return true
    end
end)

local function SaveIuprops_local(filename)
    local hMainLayout = iup.GetLayout()
    if not hMainLayout or not filename then return end
    if not filename:lower():find('%.config$') then filename = filename..'.config' end

    if SideBar_obj and SideBar_obj.handle then SideBar_obj.handle.SaveValues() end
    if LeftBar_obj and LeftBar_obj.handle then LeftBar_obj.handle.SaveValues() end

    for sciteid, dlg in pairs(_G.dialogs) do
        if dlg ~= nil and not _G.iuprops[sciteid..'.win'] then
            _G.iuprops['dialogs.'..sciteid..'.rastersize'] = dlg.rastersize
            _G.iuprops['dialogs.'..sciteid..'.x'] = dlg.x
            _G.iuprops['dialogs.'..sciteid..'.y'] = dlg.y
        end
    end
    local h = iup.GetDialogChild(hMainLayout, "toolbar_expander")
    _G.iuprops["layout.toolbar_expander"] = h.state

    h = iup.GetDialogChild(hMainLayout, "statusbar_expander")
    _G.iuprops["layout.statusbar_expander"] = h.state

    local hFind
    if _G.dialogs['findrepl'] then
        hFind = _G.dialogs['findrepl']
    else
        hFind = iup.GetDialogChild(iup.GetLayout(), "FindReplDetach")
    end
    local t = {}
    for n,v in pairs(_G.iuprops) do
        local _, _, prefix, ctrl = n:find('([^%.]*)%.([^%.]*)')
        if prefix == 'sidebarctrl' or prefix == 'concolebar' or prefix == 'dialogs' or prefix == 'findrepl' or prefix == 'findres' or prefix == 'layout' or
           prefix == 'session' or prefix == 'settings' or prefix == 'sidebar' then
            local process = true

            if prefix == 'sidebarctrl' then
                process = (iup.GetDialogChild(hFind, ctrl) == nil)
            end
            if process then
                local tp = type(v)
                if tp == 'nil' then v = 'nil'
                elseif tp == 'boolean' or tp == 'number' then v = tostring(v)
                elseif tp == 'string' then
                    v = "'"..v:gsub('\\', '\\\\'):gsub("'", "\\039").."'"
                elseif tp == 'table' and v.tostr then
                    v = v:tostr()
                else
                    iup.Message('Error', "Type "..tp.." can't be saved")
                end
                table.insert(t, '_G.iuprops["'..n..'"] = '..v)
            end
        end
    end


 	if pcall(io.output, filename) then
		io.write(table.concat(t,'\n'))
        io.close()
 	end
end

iup.SaveIuprops = function()

    local d = iup.filedlg{dialogtype='SAVE', parentdialog='SCITE', extfilter='Config|*.config;', directory=props["SciteDefaultHome"].."\\data\\home\\" }
    d:popup()
    local filename = d.value
    d:destroy()
    SaveIuprops_local(filename)

    _G.iuprops['current.config.restore'] = filename
end

iup.SaveCurIuprops = function()
    if _G.iuprops['current.config.restore']..'' ~= '' then SaveIuprops_local(_G.iuprops['current.config.restore']) end
end

--”ничтожение диалогов при выключении или перезагрузке
iup.DestroyDialogs = function()
    local hMainLayout = iup.GetLayout()
    if not hMainLayout then return end
    hMainLayout.resize_cb = nil
    if SideBar_obj and SideBar_obj.handle then SideBar_obj.handle.SaveValues() end
    if LeftBar_obj and LeftBar_obj.handle then LeftBar_obj.handle.SaveValues() end

    if iup.GetDialogChild(hMainLayout, "BottomBarSplit").barsize == '0' then
        iup.GetDialogChild(hMainLayout, "BottomBarSplit").barsize = '3'
        iup.GetDialogChild(hMainLayout, "BottomExpander").state = 'OPEN'
        if (_G.iuprops['concolebar.win'] or '0') == '0' then iup.GetDialogChild(hMainLayout, "ConsoleExpander").state = 'OPEN' end
        if (_G.iuprops['findresbar.win'] or '0') == '0' then iup.GetDialogChild(hMainLayout, "FindResExpander").state = 'OPEN' end
        iup.GetDialogChild(hMainLayout, "BottomBarSplit").value = _G.iuprops["sidebarctrl.BottomBarSplit.value"] or '900'
    end

    if _G.dialogs == nil then return end
    if _G.dialogs['findrepl'] ~= nil then
        iup.SaveNamedValues(_G.dialogs['findrepl'], 'sidebarctrl')
        _G.dialogs['findrepl'].restore = nil
        _G.dialogs['findrepl'] = nul
    end
    local hFind = iup.GetDialogChild(hMainLayout, "FindReplDetach")
    if hFind then
        iup.Detach(hFind)
        iup.Destroy(hFind)
    end
    if _G.dialogs['sidebar'] ~= nil then
        _G.dialogs['sidebar'].restore = nil
        _G.dialogs['sidebar'] = nil
    end
    if _G.dialogs['leftbar'] ~= nil then
        _G.dialogs['leftbar'].restore = nil
        _G.dialogs['leftbar'] = nil
    end

    if _G.dialogs['concolebar'] ~= nil then
        iup.GetDialogChild(hMainLayout, "BottomSplit").value = _G.iuprops['dialogs.concolebar.splitvalue']
        iup.GetDialogChild(hMainLayout, "ConsoleExpander").state = "OPEN"
        _G.dialogs['concolebar'].restore = nil
        _G.dialogs['concolebar'] = nil
    end
    if _G.dialogs['findresbar'] ~= nil then
        iup.GetDialogChild(hMainLayout, "BottomSplit").value = _G.iuprops['dialogs.findresbar.splitvalue']
        iup.GetDialogChild(hMainLayout, "FindResExpander").state = "OPEN"
        _G.dialogs['findresbar'].restore = nil
        _G.dialogs['findresbar'] = nil
    end

    local h = iup.GetDialogChild(hMainLayout, "MenuBar")
    if h then iup.Detach(h); iup.Destroy(h) end

    if SideBar_obj.handle then
        SideBar_obj.handle.OnMyDestroy()
        iup.Detach(SideBar_obj.handle)
        iup.Destroy(SideBar_obj.handle)
        iup.GetDialogChild(hMainLayout, "RightBarExpander").state = "OPEN"
        SideBar_obj.handle = nil
    end
    if LeftBar_obj.handle then
        LeftBar_obj.handle.OnMyDestroy()
        iup.Detach(LeftBar_obj.handle)
        iup.Destroy(LeftBar_obj.handle)
        iup.GetDialogChild(hMainLayout, "LeftBarExpander").state = "OPEN"
        LeftBar_obj.handle = nil
    end
    for sciteid, dlg in pairs(_G.dialogs) do
        if dlg ~= nil then
            _G.iuprops['dialogs.'..sciteid..'.rastersize'] = dlg.rastersize
            _G.iuprops['dialogs.'..sciteid..'.x'] = dlg.x
            _G.iuprops['dialogs.'..sciteid..'.y'] = dlg.y
            _G.dialogs[sciteid] = nil
            dlg:hide()
            dlg:destroy()
        end
    end
    h = iup.GetDialogChild(hMainLayout, "toolbar_expander")
    if h then
        _G.iuprops["layout.toolbar_expander"] = h.state
        tTlb.show_cb(h, 4) iup.Detach(h); iup.Destroy(h)
    end

    h = iup.GetDialogChild(hMainLayout, "statusbar_expander")
    if h then
        _G.iuprops["layout.statusbar_expander"] = h.state
        iup.Detach(h); iup.Destroy(h)
    end

    _G.dialogs = nil
    --iup.ShowSideBar(-1)
    for i = 1,  #onDestroy_event do
        onDestroy_event[i]()
    end
    collectgarbage('collect')
end

function Splash_Screen()
    dlg_SPLASH = iup.dialog{iup.hbox{
    iup.label{
      padding = "5x5",
      image = props["SciteDefaultHome"].."\\tools\\HildiM.bmp",
      font = "Arial, 33",
    },
  }; maxbox="NO",minbox ="NO",resize ="NO", menubox = "NO", border = "NO",opacity= "123",
    sciteparent = "SCITE", sciteid = "splash", resize = "NO"}

    local _, _, x2, y2 = iup.GetGlobal('SCREENSIZE'):find('(%d*)x(%d*)')
    dlg_SPLASH:showxy(tonumber(x2)/2 - 100,tonumber(y2)/2 - 100)
end

AddEventHandler("OnMarginClick", function(margin, modif, line)
    if margin == 2 and editor.Focus then
        local curLevel = editor.FoldLevel[line]
        if shell.bit_and(curLevel, SC_FOLDLEVELHEADERFLAG) == 0 then
            if modif == 0 then return end
            line = editor.FoldParent[line]
            curLevel = editor.FoldLevel[line]
        end
        if modif > 3 then line = editor.FoldParent[line]; modif = modif - 4 end
        if modif == 0 then
            if line == -1 then scite.MenuCommand(IDM_TOGGLE_FOLDALL)
            else editor:ToggleFold(line) end
        elseif modif == 1 then
            CORE.ToggleSubfolders(false, line + 1)
            return "Y"
        elseif modif == 2 then
            editor:FoldChildren(line, 2)
        elseif modif == 3 then
            scite.MenuCommand(IDM_TOGGLE_FOLDALL)
        end
        CORE.ShowCaretAfterFold()
        return "Y"
    end
end)

--–асширени€, загружаемые в любом случае
require "menuhandler"
_G.g_session = {}
dofile (props["SciteDefaultHome"].."\\tools\\xComment.lua")
dofile (props["SciteDefaultHome"].."\\tools\\new_file.lua")
dofile (props["SciteDefaultHome"].."\\tools\\AutocompleteObject.lua")
dofile (props["SciteDefaultHome"].."\\tools\\defAutoformat.lua")
dofile (props["SciteDefaultHome"].."\\tools\\FindTextOnSel.lua")
