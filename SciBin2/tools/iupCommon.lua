_G.iuprops = {}
local iuprops_read_ok = false
local file = props["scite.userhome"]..'\\settings.lua'
local text = ''
if pcall(io.input, file) then
    text = io.read('*a')
end
io.close()

local bSuc, tMsg = pcall(dostring,text)
if not bSuc then
    print('Ошибка в файле settings.lua:', tMsg..'\nсохраним текущий settings.lua в settings.lua.bak')
    io.output(props["scite.userhome"]..'\\settings.lua.bak')
    io.write(text)
    io.close()
end
iuprops_read_ok = true


props['autoformat.line'] = _G.iuprops['autoformat.line']
props['spell.autospell'] = _G.iuprops['spell.autospell']
props['formenjine.old.ext'] = _G.iuprops['formenjine.old.ext']

function CheckFMExt()
	local cur_prop = ifnil(tonumber(props['formenjine.old.ext']), 0)
	props['formenjine.old.ext'] = 1 - cur_prop
    _G.iuprops['formenjine.old.ext'] = props['formenjine.old.ext']
    ResetFormEnjineExt()
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

end
AddEventHandler("OnMenuCommand", function(cmd, source)

    if cmd == 9132 or cmd == 9134 or cmd == IDM_CLOSEALL or cmd == IDM_QUIT then
        local cur = -1   --9132 - закрыть все, кроме текущего, поэтому запомним текущий
        if cmd ==  9132 then cur = scite.buffers.GetCurrent() end

        local msg = ''
        local notSaved = {}
        DoForBuffers(function(i)
            if i then
                if editor.Modify and i ~= cur and (cmd ~= 9134 or props['FilePath']:from_utf8(1251):find('Безымянный')) and not props['FileNameExt']:find('^%^') then
                    msg = msg..'  '..props['FilePath']:from_utf8(1251)..'\n'
                    table.insert(notSaved, i)
                end
            else
                return msg
            end
        end)
        local result = 7
        if msg ~= '' then
            msg = 'Некоторые файлы не сохранены:\n'..msg..'Сохранить все?'
            result = shell.msgbox(msg, "Close", 3) --YESNOCANCEL Yes - 6, NO - 7 CANCEL - 2
            if result == 2 then return true end
            if result == 6 then
                for _,j in ipairs(notSaved) do
                    scite.buffers.SetDocumentAt(j)
                    scite.MenuCommand(IDM_SAVE)
                end
                if cmd == 9134 then return end
            end
        end
        if cmd == IDM_QUIT then ClearAllEventHandler() end
        local nf,spathes = false,''
        DoForBuffers(function(i)
            if i and i ~= cur and (cmd ~= 9134 or ((props['FilePath']:from_utf8(1251):find('Безымянный') or props['FileNameExt']:find('^%^')) and editor.Modify)) then
                scite.SendEditor(SCI_SETSAVEPOINT)
                if props['FilePath'] ~= '' and not props['FileNameExt']:find('^%^') then
                    spathes = spathes..'•'..props['FilePath']:from_utf8(1251)
                    nf = true
                end
                scite.MenuCommand(IDM_CLOSE)
            end
        end)
        if nf and cmd == IDM_QUIT then _G.iuprops['buffers'] = spathes end
        if cmd == IDM_QUIT then iup.DestroyDialogs();SaveIup();
        else return true end
    elseif cmd == 9117 then  --перезагрузка скрипта
        iup.DestroyDialogs();SaveIup()
        scite.PostCommand(1,0)
        return true
    end
end)
AddEventHandler("OnSave", function(cmd, source)
    if props["ext.lua.startup.script"] == props["FilePath"] then
        scite.PostCommand(4,0)
    end
end)

--Расширение iup.TreeAddNodes - позволяет в табличном представлении дерева задавать свойство userdata
local old_TreeSetNodeAttrib = iup.TreeSetNodeAttrib
iup.TreeSetNodeAttrib = function (handle, tnode, id)
  old_TreeSetNodeAttrib(handle, tnode, id)
  if tnode.userdata then iup.SetAttribute(handle, "USERDATA"..id, tnode.userdata) end
  if tnode.imageid then iup.SetAttribute(handle, "IMAGE"..(id), tnode.imageid) end

end
--Переопределяем iup сообщение об ошибке - чтобы не было их всплывающего окна, печатаем все к нам в output
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

local old_iup_list = iup.list
iup.list = function(t)
    local cmb = old_iup_list(t)
    function cmb:FillByDir(pathmask, strSel)
        local current_path = props["sys.calcsybase.dir"]..pathmask

        local files = shell.findfiles(current_path)
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
        sHist = props[sHist]:gsub('||', '‡')..'‡'
        i = 1
        for elem in sHist:gmatch('([^|]+)|') do
            iup.SetAttribute(self, i, elem:gsub('‡', '|'))
            i = i + 1
        end
        if sLast then self.value = props[sLast] end
    end
    function cmb:SaveHist()
        local s = self.value
        self.insertitem1 = s

        local i = tonumber(self.count)
        local mn = tonumber(self.visible_items)
        while(i > 1) do
            if i> mn + 1 or (iup.GetAttribute(self,i) == s) then
                self.removeitem = i
            end
            i = i - 1
        end
        self.value = s
    end
    return cmb
end

---Расширение iup
_G.dialogs = {}
iup.scitedialog = function(t)
    local dlg = _G.dialogs[t.sciteid]
    if dlg == nil then
        dlg = iup.dialog(t)
        iup.SetNativeparent(dlg, t.sciteparent)
        _G.dialogs[t.sciteid] = dlg
        if dlg.resize == 'YES' then dlg.rastersize = props['dialogs.'..t.sciteid..'.rastersize'] end
        if t.sciteparent == "IUPTOOLBAR" then
            dlg:showxy(0,0)
        elseif t.sciteparent == "IUPSTATUSBAR" then
            dlg:showxy(0,0)
        elseif t.sciteparent == "SCITE" then
            dlg:showxy(tonumber(_G.iuprops['dialogs.'..t.sciteid..'.x']),tonumber(_G.iuprops['dialogs.'..t.sciteid..'.y']))
        else
            local w = (_G.iuprops['dialogs.'..t.sciteid..'.rastersize'] or ''):gsub('x%d*', '')
            if w=='' then w='300' end
            if tonumber(w) < 10 then w = '300' end
            dlg:showxy(0,0)
            iup.ShowSideBar(tonumber(w))
        end
        function dlg:postdestroy()
            --вызывать destroy из обработчиков событий в диалоге нельзя - развязываемся через пост
            if _G.deletedDialogs == nil then _G.deletedDialogs = {} end
            table.insert(_G.deletedDialogs, t.sciteid)
            scite.PostCommand(2,0)
        end
        --dlg.rastersize = "NULL"
    else
        dlg:show()
    end
    return dlg
end

AddEventHandler("OnSendEditor", function(id_msg, wp, lp)
    if id_msg == SCN_NOTYFY_ONPOST then
        if wp == 2 then --закрытие диалога (отложенное)
            while table.maxn(_G.deletedDialogs) > 0 do
                sciteid = table.remove(_G.deletedDialogs)
                local dlg = _G.dialogs[sciteid]
                if dlg ~= nil then
                    if sciteid ~= 'sidebarp' or _G.iuprops['sidebar.win'] == '0' then
                        _G.iuprops['dialogs.'..sciteid..'.rastersize'] = dlg.rastersize
                        _G.iuprops['dialogs.'..sciteid..'.x'] = dlg.x
                        _G.iuprops['dialogs.'..sciteid..'.y'] = dlg.y
                    end
                    _G.dialogs[sciteid] = nil
                    dlg:hide()
                    dlg:destroy()
                end
            end
        elseif wp == 1 then   --перезагрузка скрипта
            print("Reload...")
            scite.ReloadStartupScript()
            OnSwitchFile("")
            print("...Ok")
        elseif wp == 4 then   --перезагрузка скрипта
            scite.MenuCommand(9117)
        end
    end
end)

--Уничтожение диалогов при выключении или перезагрузке
iup.DestroyDialogs = function()
    local hMainLayout = iup.GetLayout()

    if _G.dialogs == nil then return end
    if _G.dialogs['findrepl'] ~= nil then
        _G.dialogs['findrepl'].restore = 1
        _G.dialogs['findrepl'] = nul
    end
    if _G.dialogs['sidebar'] ~= nil then
        _G.dialogs['sidebar'].restore = 1
        _G.dialogs['sidebar'] = nul
    end
    if _G.dialogs['concolebar'] ~= nil then
        iup.GetDialogChild(hMainLayout, "BottomSplit").value = _G.iuprops['dialogs.concolebar.splitvalue']
        iup.GetDialogChild(hMainLayout, "ConsoleExpander").state = "OPEN"
        _G.dialogs['concolebar'].restore = 1
        _G.dialogs['concolebar'] = nul
    end
    if _G.dialogs['bottombar'] ~= nil then
        iup.GetDialogChild(hMainLayout, "BottomBarSplit").value = _G.iuprops['dialogs.bottombar.splitvalue']
        iup.GetDialogChild(hMainLayout, "BottomExpander").state = "OPEN"
        _G.dialogs['bottombar'].restore = 1
        _G.dialogs['bottombar'] = nul
    end
    if _G.dialogs['sidebarp'] then _G.dialogs['sidebarp'].SaveValues() end
    for sciteid, dlg in pairs(_G.dialogs) do
        if dlg ~= nil then
            if sciteid ~= 'sidebarp' or _G.iuprops['sidebar.win'] == '0' then
                _G.iuprops['dialogs.'..sciteid..'.rastersize'] = dlg.rastersize
                _G.iuprops['dialogs.'..sciteid..'.x'] = dlg.x
                _G.iuprops['dialogs.'..sciteid..'.y'] = dlg.y
            end
            _G.dialogs[sciteid] = nil
            dlg:hide()
            dlg:destroy()
        end
    end
    h = iup.GetDialogChild(hMainLayout, "ToolBar")
    tTlb.show_cb(h,4)
    iup.Detach(h)
    iup.Destroy(h)

    local h = iup.GetDialogChild(hMainLayout, "StatusBar")
    iup.Detach(h)
    iup.Destroy(h)

    _G.dialogs = nil
    iup.ShowSideBar(-1)
end
