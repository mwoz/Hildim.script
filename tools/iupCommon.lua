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

_G.iuprops['pariedtag.on'] = _G.iuprops['pariedtag.on'] or 1
props['autoformat.line'] = _G.iuprops['autoformat.line']
props['spell.autospell'] = _G.iuprops['spell.autospell']
props['formenjine.old.ext'] = _G.iuprops['formenjine.old.ext']
props['pariedtag.on'] = _G.iuprops['pariedtag.on']

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

local function SaveLayOut()
    local res = ''
    for l=0, editor.LineCount do
        if shell.bit_and(editor.FoldLevel[l],SC_FOLDLEVELHEADERFLAG) ~=0 and not editor.FoldExpanded[l] then res = res..','..l end
    end
    return res
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
        local nf,spathes = false,'',''
        local sposes
        local slayout = ''
        if cmd == IDM_QUIT then sposes = '' end
        local curBuf = scite.buffers.GetCurrent()
        DoForBuffers(function(i)
            if i and i ~= cur and (cmd ~= 9134 or ((props['FilePath']:from_utf8(1251):find('Безымянный') or props['FileNameExt']:find('^%^')) and editor.Modify)) then
                scite.SendEditor(SCI_SETSAVEPOINT)
                if not props['FileNameExt']:from_utf8(1251):find('Безымянный') and not props['FileNameExt']:find('^%^') then
                    spathes = spathes..'•'..props['FilePath']:from_utf8(1251)
                    local ml,bk = 0,''
                    while true do
                        ml = editor:MarkerNext(ml, 2)
                        if (ml == -1) then break end
                        bk = bk..'¦'..ml
                        ml = ml + 1
                    end
                    if sposes then
                        sposes = sposes..'•'..editor.FirstVisibleLine..bk
                        slayout = slayout..'•'..SaveLayOut()
                    end
                    nf = true
                else
                    if i <= curBuf then curBuf = curBuf - 1 end
                end
                scite.MenuCommand(IDM_CLOSE)
            end
        end)
        if curBuf >= 0 then _G.iuprops['buffers.current'] = curBuf end
        if nf and cmd == IDM_QUIT then
            _G.iuprops['buffers'] = spathes;
            _G.iuprops['buffers.pos'] = sposes
            _G.iuprops['buffers.layouts'] = slayout
        end
        if cmd == IDM_QUIT then iup.DestroyDialogs();SaveIup();
        else return true end
    elseif cmd == 9117 then  --перезагрузка скрипта
        iup.DestroyDialogs();SaveIup()
        scite.PostCommand(1,0)
        return true
    elseif cmd == IDM_TOGGLEOUTPUT then
        if _G.iuprops['bottombar.win']~='1' then
            local hMainLayout = iup.GetLayout()
            if iup.GetDialogChild(hMainLayout, "BottomBarSplit").barsize == '0' then
               iup.GetDialogChild(hMainLayout, "BottomBarSplit").barsize = '3'
               iup.GetDialogChild(hMainLayout, "BottomExpander").state = 'OPEN'
               iup.GetDialogChild(hMainLayout, "BottomBarSplit").value = _G.iuprops["sidebarctrl.BottomBarSplit.value"] or '900'
            else
               iup.GetDialogChild(hMainLayout, "BottomBarSplit").barsize = '0'
               iup.GetDialogChild(hMainLayout, "BottomExpander").state = 'CLOSE'
               _G.iuprops["sidebarctrl.BottomBarSplit.value"] = iup.GetDialogChild(hMainLayout, "BottomBarSplit").value
                iup.GetDialogChild(hMainLayout, "BottomBarSplit").value = '1000'
            end
        end
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

local old_matrix = iup.matrix
iup.matrix = function(t)
    t.hlcolor="255 255 255"
    t.hlcoloralpha="255"
    local mtr = old_matrix(t)
    function mtr:SetCommonCB(act_act,act_resel, act_esc, act_right)
        local function a_cb(h, key, lin, col, edition, value)
            if key == 65364 then  --down
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
            elseif key == 65362 then  --up
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
            elseif key == 65307 then --escape
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
    return mtr
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

iup.scitedetachbox = function(t)
    local dtb = t.HANDLE or iup.detachbox(t)
    dtb.sciteid = t.sciteid
    dtb.Dlg_Close_Cb = t.Dlg_Close_Cb
    dtb.Dlg_Show_Cb = t.Dlg_Show_Cb
    dtb.Split_h = t.Split_h
    dtb.Split_Title = t.Split_Title
    dtb.Split_CloseVal = t.Split_CloseVal
    dtb.Dlg_Resize_Cb = t.Dlg_Resize_Cb
    dtb.On_Detach = t.On_Detach

    dtb.detachPos = (function()
        local oldPos = iup.GetGlobal('CURSORPOS')
        iup.SetGlobal('CURSORPOS', (_G.iuprops['dialogs.'..dtb.sciteid..'.x'] or '100')..'x'..(_G.iuprops['dialogs.'..dtb.sciteid..'.y'] or '100'));
        dtb.DetachRestore = true
        dtb.detach = 1
        iup.SetGlobal('CURSORPOS', oldPos)
    end)

    dtb.detached_cb=(function(h, hNew, x, y)

        if h.On_Detach then h.On_Detach(h, hNew, x, y) end
        hNew.resize ="YES"
        hNew.shrink ="YES"
        hNew.minsize="100x100"
        hNew.maxbox="NO"
        hNew.minbox="NO"
        hNew.toolbox="YES"
        hNew.title= t.Dlg_Title or "dialog"
        hNew.x=10
        hNew.y=10
        x=10;y=10
        local firstShow = true
        hNew.rastersize = _G.iuprops['dialogs.'..h.sciteid..'.rastersize']
        _G.iuprops[h.sciteid..'.win']='1'
        if h.Split_h then  _G.iuprops['dialogs.'..h.sciteid..'.splitvalue'] = h.Split_h.value end
        hNew.close_cb =(function(h)
            if _G.dialogs[dtb.sciteid] ~= nil then

                if dtb.Dlg_Close_Cb then dtb.Dlg_Close_Cb(h) end

                _G.iuprops[dtb.sciteid..'.win']='0'
                dtb.restore = 1
                _G.dialogs[dtb.sciteid] = nil
                return -1
            end
        end)
        hNew.show_cb=(function(h,state)
            if state == 0 then
                if dtb.DetachRestore then
                    dtb.DetachRestore = false
                    firstShow = false
                    h.rastersize = _G.iuprops['dialogs.'..dtb.sciteid..'.rastersize']
                    iup.ShowXY(h, _G.iuprops['dialogs.'..dtb.sciteid..'.x'],_G.iuprops['dialogs.'..dtb.sciteid..'.y'])
                    return
                elseif firstShow then
                    firstShow = false
                    h.rastersize = _G.iuprops['dialogs.'..dtb.sciteid..'.rastersize']
                    iup.ShowXY(h, h.x,h.y)
                end
                if dtb.Split_h then
                    if dtb.Split_h.barsize ~= "0" then _G.iuprops['dialogs.'..dtb.sciteid..'.splitvalue'] = dtb.Split_h.value end
                    dtb.Split_h.value = dtb.Split_CloseVal
                    dtb.Split_h.barsize = "0"
                end
                _G.dialogs[dtb.sciteid] = dtb
            elseif state == 4 then
                _G.iuprops['dialogs.'..dtb.sciteid..'.x']= h.x
                _G.iuprops['dialogs.'..dtb.sciteid..'.y']= h.y
                dtb.visible = 'YES'
                _G.iuprops['dialogs.'..dtb.sciteid..'.rastersize'] = h.rastersize
                if dtb.Split_h then
                    dtb.Split_h.value = _G.iuprops['dialogs.'..dtb.sciteid..'.splitvalue']
                    dtb.Split_h.barsize = "3"
                end
            end
            if state == 0 then dtb.visible='YES' end
            if dtb.Dlg_Show_Cb then dtb.Dlg_Show_Cb(h, state) end
        end)
        if h.Dlg_Resize_Cb then
            hNew.resize_cb = h.Dlg_Resize_Cb
        end
        if tonumber(_G.iuprops['dialogs.'..h.sciteid..'.x'])== nil or tonumber(_G.iuprops['dialogs.'..h.sciteid..'.y']) == nil then _G.iuprops['dialogs.'..h.sciteid..'.x']=0;_G.iuprops['dialogs.'..h.sciteid..'.y']=0 end
    end)
    return dtb
end

local old_iup_ShowXY = iup.ShowXY
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
        elseif t.sciteid == "splash" then
            local _,_,x2,y2 = iup.GetGlobal('SCREENSIZE'):find('(%d*)x(%d*)')
            dlg:showxy(tonumber(x2)/2 - 100,tonumber(y2)/2 - 100)
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
            --вызывать destroy из обработчиков событий в диалоге нельзя - развязываемся через пост
            if _G.deletedDialogs == nil then _G.deletedDialogs = {} end
            table.insert(_G.deletedDialogs, t.sciteid)
            scite.PostCommand(2,0)
        end
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
                    if _G.iuprops['sidebar.win'] == '0' then
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
    if SideBar_obj.handle then SideBar_obj.handle.SaveValues() end
    if LeftBar_obj.handle then LeftBar_obj.handle.SaveValues() end

    if _G.dialogs == nil then return end
    if _G.dialogs['findrepl'] ~= nil then
        _G.dialogs['findrepl'].restore = 1
        _G.dialogs['findrepl'] = nul
    end
    iup.Detach(iup.GetDialogChild(hMainLayout, "FindReplDetach"))
    iup.Destroy(iup.GetDialogChild(hMainLayout, "FindReplDetach"))
    if _G.dialogs['sidebar'] ~= nil then
        _G.dialogs['sidebar'].restore = 1
        _G.dialogs['sidebar'] = nil
    end
    if _G.dialogs['leftbar'] ~= nil then
        _G.dialogs['leftbar'].restore = 1
        _G.dialogs['leftbar'] = nil
    end
    if _G.dialogs['concolebar'] ~= nil then
        iup.GetDialogChild(hMainLayout, "BottomSplit").value = _G.iuprops['dialogs.concolebar.splitvalue']
        iup.GetDialogChild(hMainLayout, "ConsoleExpander").state = "OPEN"
        _G.dialogs['concolebar'].restore = 1
        _G.dialogs['concolebar'] = nil
    end
    if _G.dialogs['bottombar'] ~= nil then
        iup.GetDialogChild(hMainLayout, "BottomBarSplit").value = _G.iuprops['dialogs.bottombar.splitvalue']
        iup.GetDialogChild(hMainLayout, "BottomExpander").state = "OPEN"
        _G.dialogs['bottombar'].restore = 1
        _G.dialogs['bottombar'] = nil
    end
    if SideBar_obj.handle then
        iup.Detach(SideBar_obj.handle)
        iup.Destroy(SideBar_obj.handle)
        SideBar_obj.handle = nil
    end
    if LeftBar_obj.handle then
        iup.Detach(LeftBar_obj.handle)
        iup.Destroy(LeftBar_obj.handle)
        LeftBar_obj.handle = nil
    end
    for sciteid, dlg in pairs(_G.dialogs) do
        if dlg ~= nil then
            if _G.iuprops['sidebar.win'] == '0' then
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
    --iup.ShowSideBar(-1)
end

function Splash_Screen()

    dlg_SPLASH = iup.scitedialog{iup.hbox{
    iup.label{
      padding = "30x30",
      title = "!!!WAIT!!!",
      font = "Arial, 33", background= "IMAGE_search";
    }, background= "IMAGE_search";
  }; maxbox="NO",minbox ="NO",resize ="NO", menubox = "NO", border = "NO",opacity= "123",
    sciteparent="SCITE", sciteid="splash", resize ="NO"}
    dlg_SPLASH.show_cb=(function(h,state)
        if state == 4 then dlg_SPLASH:postdestroy() end
    end)

end
