--Constants
require 'shell'
local RestoreIup
local old_iup_ShowXY = iup.ShowXY
CORE.old_iup_ShowXY = old_iup_ShowXY

if not lanes then
    lanes = require("lanes").configure()
end
local linda = lanes.linda()

local function runAsync(cmd, key, dir)
    local ierr, strerr
    local proc, err, errdesc = shell.startProc(cmd, dir)
    if proc then
        while true do
            local c, msg, exitcode = proc:Continue()
            if c == "C" then
                linda:send( "CORE_CMD_"..key.."_C", msg)
            elseif c == "S" then
                linda:send( "CORE_CMD_"..key.."_S", msg..' '..math.tointeger(exitcode))
                return
            else
                linda:send( "CORE_CMD_"..key.."_E", msg..' '..math.tointeger(exitcode))
                return
            end
        end
    else
        print("Error: Command "..cmd, err, errdesc)
        linda:send( "CORE_CMD_"..key.."_E","Error: Command "..cmd..' '..err..' '..(errdesc or ''))
        return - 1
    end
end

local lanesgen = lanes.gen("package,io,string,math", {required = {"shell"}}, runAsync)

_G.iuprops = {}
local iuprops_read_ok = false
local file = props["scite.userhome"]..'\\settings.lua'
if shell.fileexists(file) then
    local bRepit = true
::repit::
    local text = ''
    local bSuc, pF = pcall(io.input, file)
    if bSuc then
        text = pF:read('*a')
        pF:close()
    end
    local bSuc, tMsg = pcall(dostring, text)

    if bRepit and (_G.iuprops['_VERSION'] or 1) ~= 3 then
        bRepit = false

        local sucs, msg = pcall(dofile, props["SciteDefaultHome"].."\\tools\\upgradesettings.lua")
        if sucs then
            --print("Convert settings - 3.0")
            goto repit
        else
            print("Convert settings failed:", msg)
        end
   -- else
   --     text = text:from_utf8()
    end

    if not bSuc then
        print('Error in settings.lua:', tMsg..'\nsave current settings.lua to settings.lua.bak')
        io.output(props["scite.userhome"]..'\\settings.lua.bak')
        io.write(text:to_utf8())
        io.close()
    end
elseif shell.fileexists(props["scite.userhome"]..'\\_default.config') then
    props['config.restore'] = props["scite.userhome"]..'\\_default.config'
    _G.iuprops['current.config.restore'] = props["scite.userhome"]..'\\default.config'
else
    props['config.restore'] = props["SciteDefaultHome"]..'\\tools\\_default.config'
    _G.iuprops['current.config.restore'] = props["scite.userhome"]..'\\default.config'
end


if props['config.restore'] ~= '' then
    local bSuc, pF = pcall(io.input, props['config.restore'])
    if bSuc then
        local l = (_G.iuprops['settings.lexers'] or '')
        text = pF:read('*a'):from_utf8()
        pF:close()
        local bSuc, tMsg = pcall(dostring, text)
        if not bSuc then
            print('Ошибка в файле '..props['config.restore'], tMsg)
        elseif not _G.g_session['scip.save.session'] and (l ~= _G.iuprops['settings.lexers'] or '') then
            local t = _G.iuprops['settings.lexers']
            local str = ''

            for i = 1, #t do
                str = str..'import $(SciteDefaultHome)\\languages\\'..t[i].file..'\n'
                local n = t[i].file:gsub('%.properties$', '.styles')
                if shell.fileexists(props["SciteUserHome"]..'\\'..n) then
                    str = str..'import $(scite.userhome)\\'..n..'\n'
                end
            end

            f = io.open(props['SciteUserHome']..'\\Languages.properties',"w")
            f:write(str)
            f:close()
            _G.iuprops['command.reloadprops'] = true
        end
        if not _G.iuprops['buffers'] then
    _G.iuprops['buffers'] = { lst = {'',}, pos = {0,}, enc = {0,}, bmk = {'',}, layouts = {'',},}
    _G.iuprops['menus.show.icons'] = 1
    _G.iuprops['autoformat.indent'] = 1
    _G.iuprops['autoformat.line'] = 1
    _G.iuprops['autoformat.indent.force'] = 1
    _G.iuprops['changes.mark.line'] = 1
        end
    end
end
props['config.restore'] = ''
props['script.started'] = 'Y'

iuprops_read_ok = true

local function RestoreLayOut(strLay)
    if not strLay or not strLay.gmatch then return end
    for n in strLay:gmatch('%d+') do
        n = math.tointeger(n)
        if (editor.FoldLevel[n] & SC_FOLDLEVELHEADERFLAG) ==0 then
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
            if ts[i] == scite.buffers.NameAt(j) then
                bSet = false
                break
            end
        end
        if bSet then
            local l = {}
            local s = ''
            if k < 11 then s = '&'..k..'.' end
            l[1] = s..ts[i] --:to_utf8()
            --print(ts[i])
            if ((_G.iuprops['resent.files.list.pathafter'] or 1) == 1) then
                l[1] = l[1]:gsub('(.+)[\\]([^\\]*)$', '%2\t%1')
            end
            l.action = OpenMenu(i)
            table.insert(t,l)
            k = k + 1
        end
    end
    table.insert(t,{'s0', separator = 1})
    table.insert(t,{_TH'List Settings', action = function()
        local res, loc, len, pathAfter, bClear = iup.GetParam(_TH'Recent List Settings',
            nil,
            _TH"Location in File menu: %o|Submenu|Bottom|\n"..
            _TH"Length: %i[5,30,1]".."\n"..
            _TH"Path After Name: ".."%b\n"..
            _TH"Clear Now: ".."%b\n",
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
                self.data.enc = {}
            end
        end
    end})
    return t
end

function OnCommandLine(line)
    local cmdLine
    _G.g_session['scip.restore.files'] = false
    local _, l1, lk, l2
    if line:find('[-/]cmd ') then
        _, _, l1, lk, l2 = line:find('([^-]*)([-/])cmd (.+)')
        if not l2 then
            print('Command line error: "'..line..'"')
            return
        end
        cmdLine = l2
        line = l1
    end
    if line ~= '' then
        line = line:gsub('^ +', ''):gsub(' +$', '')
        if line ~= '' then
            line = line:gsub('^"', ''):gsub('"$', '')
            scite.Open(line)
        end
    end
    if cmdLine then
        if lk == '/' then cmdLine = cmdLine:gsub('\\', '\\\\') end
        assert(load(cmdLine))()
    end
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
            for g in bk:gmatch('%d+') do
                editor:MarkerAdd(tonumber(g), MARKER_BOOKMARK)
                if BOOKMARK then BOOKMARK.Add(tonumber(g)) end
            end
            local rez = self.data.enc[i]
            table.remove(self.data.lst, i)
            table.remove(self.data.pos, i)
            table.remove(self.data.layout, i)
            table.remove(self.data.bmk, i)
            table.remove(self.data.enc, i)
            return rez
        end
    end
end

iuprops['resent.files.list'] = rfl

_G.iuprops['pariedtag.on'] = _G.iuprops['pariedtag.on'] or 1

function iup.SaveChProps(bReset)
    if _G.g_session['scip.save.session'] then return end
    local t = {
'autocompleteword.automatic',
'ext.lua.debug.traceback',
'buffers',
'buffers.new.position',
'buffers.zorder.switching',
'caret.additional.blinks',
'caret.fore',
'caret.line.back',
'caret.line.back.alpha',
'caret.overstrike.block',
'caret.period',
'caret.policy.lines',
'caret.policy.width',
'caret.policy.xeven',
'caret.policy.xjumps',
'caret.policy.xslop',
'caret.policy.xstrict',
'caret.policy.yeven',
'caret.policy.yjumps',
'caret.policy.yslop',
'caret.policy.ystrict',
'caret.sticky',
'caret.width',
'clear.before.execute',
'end.at.last.lin',
'findres.caret.line.back',
'findres.caret.line.back.alpha',
'findres.magnification',
'findres.width',
'findres.wrap',
'iup.defaultfontsize',
'iuptoolbar.visible',
'line.margin.visible',
'magnification',
'output.caret.line.back',
'output.caret.line.back.alpha',
'output.code.page.oem2ansi',
'output.magnification',
'output.vertical.size',
'output.wrap',
'position.height',
'position.left',
'position.maximize',
'position.top',
'position.width',
'print.magnification',
'selection.additional.alpha',
'selection.additional.back',
'selection.alpha',
'selection.back',
'tabbar.tab.close.on.doubleclick',
'tabctrl.active.bakcolor',
'tabctrl.active.forecolor',
'tabctrl.active.readonly.forecolor',
'tabctrl.alwayssavepos',
'tabctrl.colorized',
'tabctrl.cut.ext',
'tabctrl.cut.illumination',
'tabctrl.cut.prefix',
'tabctrl.cut.saturation',
'tabctrl.forecolor',
'tabctrl.moved.color',
'tabctrl.readonly.color',
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
'layout.hlcolor',
'layout.borderhlcolor',
'layout.bordercolor',
'layout.bgcolor',
'layout.txtbgcolor',
'layout.fgcolor',
'layout.txtfgcolor',
'layout.txthlcolor',
'layout.txtinactivcolor',
'layout.bordercolor',
'layout.splittercolor',
'layout.scroll.forecolor',
'layout.scroll.presscolor',
'layout.scroll.highcolor',
'layout.scroll.backcolor',
'layout.standard.decoration',
'iup.scrollbarsize',
'locale',
    }
    for i = 1, #t do
        t[i] = t[i]..'='..props[t[i]]
    end
    local file = props["scite.userhome"]..'\\SciTE.session'
 	if pcall(io.output, file) then
		io.write(table.concat(t,'\n'))
 	end
	io.close()
    if bReset then scite.RunAsync(function() scite.ReloadProperties() end) end
end

local function SaveIup()
    if not _G.g_session['LOADED'] then return end
    if not _G.g_session['scip.save.settings'] then
        local file = props["scite.userhome"]..'\\settings.lua'
        if pcall(io.output, file) then
            _G.iuprops['_VERSION'] = 3
            local s = CORE.tbl2Out(_G.iuprops, ' ', false, true, true):gsub('^return ', '_G.iuprops = ')
            io.write(s)
        else
            iup.Alarm("HidlM", _TH"Unable to save settings to file Settings.lua!", "Ok")
        end
        io.close()
    end
    iup.SaveChProps()
end

local function SaveLayOut()
    local res = ''
    for l=0, editor.LineCount do
        if (editor.FoldLevel[l] & SC_FOLDLEVELHEADERFLAG) ~= 0 and not editor.FoldExpanded[l] then res = res..','..l end
    end
    return res
end

iup.GetBookmarkLst = function()
    local ml, bk = 0, ''
    while true do
        ml = editor:MarkerNext(ml, 1 << MARKER_BOOKMARK)
        if (ml == -1) then break end
        bk = bk..','..ml
        ml = ml + 1
    end
    return bk
end

iup.CloseFilesSet = function(cmd, tForClose, bAddToRecent)
    local cur = -1   --9132 - закрыть все, кроме текущего, поэтому запомним текущий
    if cmd == 9132 then cur = scite.buffers.GetCurrent() end
    if cmd == IDM_CLOSEALL then bAddToRecent = true end

    local function MastClose(i)
        if tForClose then return tForClose[i] end
        return i ~= cur
    end

    local msg = ''
    local notSaved = {}

    local maxN = scite.buffers.GetCount() - 1
    for i = 0,maxN do
        local pth = scite.buffers.NameAt(i)
        local _,_,fnExt = pth:find('([^\\]*)$')
        if not scite.buffers.SavedAt(i) and MastClose(i) and (cmd ~= 9134 or pth:find(_TH'Untitled')) and not fnExt:find('^%^') then
            msg = msg..pth:gsub('(.+)[\\]([^\\]*)$', '%2(%1)')..'\n'
            table.insert(notSaved, i)
        end
    end

    local result = 2
    if msg ~= '' then
        msg = msg.._TH'Save all?'
        result = tonumber(iup.Alarm(_TH'Some files are not saved:', msg, _TH'Yes', _TH'No', _TH'Cancel'))
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
        scite.HideForeReolad(1);--!!-с принудительной установкой таймера на закрытие
        ClearAllEventHandler();
    end
    local nf,spathes = false,'',''
    local sposes
    local slayout = ''
    if cmd == IDM_QUIT or cmd == 0 then sposes = '' end
    local curBuf = scite.buffers.GetCurrent()
    local curCoBuf = scite.buffers.BufferByName(scite.buffers.CoName())
    local tmpFlag = props['load.on.activate']
    props['load.on.activate'] = 0
    scite.BlockUpdate(UPDATE_BLOCK)
    local cloned = {}
    local tblBuff = {lst = {}, pos = {}, layouts = {}, bmk = {}, enc = {}}
    local cloused = {}
    DoForBuffers(function(i)
        if i and MastClose(i) and (cmd ~= 9134 or ((props['FilePath']:find(_TH'Untitled') or props['FileNameExt']:find('^%^')) and editor.Modify)) then
            editor:SetSavePoint()
            if not props['FileNameExt']:find(_TH'Untitled') and not props['FileNameExt']:find('^%^') then
                if not cloned[props['FilePath']] then
                    local pref = ''
                    if scite.buffers.IsCloned(scite.buffers.GetCurrent()) == 1 then
                        cloned[props['FilePath']] = true
                        pref = pref..'<'
                    end
                    if scite.ActiveEditor() == 1 then
                        pref = pref..'>'
                    end
                    table.insert(tblBuff.lst, pref..props['FilePath'])
                    table.insert(tblBuff.pos, editor.FirstVisibleLine)
                    table.insert(tblBuff.layouts, SaveLayOut())
                    table.insert(tblBuff.bmk, pref..iup.GetBookmarkLst())
                    table.insert(tblBuff.enc, scite.buffers.EncodingAt(scite.buffers.GetCurrent()))
                    nf = true
                    table.insert(cloused, pref..props['FilePath'])
                    if bAddToRecent then
                        iuprops['resent.files.list']:ins(props['FilePath'], editor.FirstVisibleLine, SaveLayOut(), iup.GetBookmarkLst(), scite.buffers.EncodingAt(scite.buffers.GetCurrent()))
                    end
                end
            else
                if i <= curBuf then curBuf = curBuf - 1 end
                if i <= curCoBuf then curCoBuf = curCoBuf - 1 end
            end
            if cmd ~= 0 then scite.Close() end
        end
    end)
    --debug_prnArgs(tblBuff)
    --print(debug.traceback())
    --iup.Alarm("345", "qwe", "ddd")
    scite.BlockUpdate(UPDATE_FORCE)
    if OnCloseFileset then OnCloseFileset(cloused) end
    if scite.buffers.SecondEditorActive() == 0 then iup.GetDialogChild(iup.GetLayout(), 'barBtncoeditor').visible = 'NO' end

    props['load.on.activate'] = tmpFlag
    if curBuf >= 0 then _G.iuprops['buffers.current'] = curBuf end
    _G.iuprops['buffers.cocurrent'] = curCoBuf
    if nf then    --если  buffers не сброшен в нул, значит была ошибка при загрузке
        _G.iuprops['buffers'] = tblBuff;
    end
    if cmd == IDM_QUIT then iup.DestroyDialogs();SaveIup();
    else return true end
end

function CORE.fixMarks(bReset)
    local mrk = editor:MarkerNext(-1, 1 << MARKER_NOTSAVED)
    while mrk > -1 do
        editor:MarkerDelete(mrk, MARKER_NOTSAVED)
        if bReset then editor:MarkerAdd(mrk, MARKER_SAVED) end
        mrk = editor:MarkerNext(mrk, 1 << MARKER_NOTSAVED)
    end
end

local function onOpen_local(source)
    if source:find('^%^') then return end
    if not source:find('^\\\\') then
        if not shell.fileexists(source:from_utf8()) then return end
    end
    iuprops['resent.files.list']:check(source:from_utf8())
    CORE.fixMarks(false)
end

local function onNavigate_local(item)
    if item == '_openSet' then
        scite.BlockUpdate(UPDATE_BLOCK)
        editor.VScrollBar = false
        BlockEventHandler"OnTextChanged"
        BlockEventHandler"OnBeforeOpen"
        BlockEventHandler("OnOpen", onOpen_local)
        BlockEventHandler("OnNavigation", onNavigate_local)
        BlockEventHandler"OnUpdateUI"
    elseif item == '_openSetLast' then
        UnBlockEventHandler"OnOpen"
        UnBlockEventHandler"OnNavigation"
        UnBlockEventHandler"OnUpdateUI"
        UnBlockEventHandler"OnBeforeOpen"
        UnBlockEventHandler"OnTextChanged"
        editor.VScrollBar = true
    elseif item == '_-openSet' then
        scite.BlockUpdate(UPDATE_FORCE)
    end
end

iup.RestoreFiles = function(bForce)
    local fPrevOnOpen
    if _G.iuprops['session.reload'] ~= '1' or _G.g_session['scip.restore.files'] then _G.iuprops['buffers'] = { lst = {'',}, pos = {0,}, enc = {0,}, bmk = {'',}, layouts = {'',},} end
    if props['session.started'] ~= '1' or bForce then
        local bNew = (props['FileName'] ~= '')
        local buf = (_G.iuprops['buffers'] or {})
        local t, p, bk, l, enc = buf.lst or {}, buf.pos or {}, buf.bmk or {}, buf.layouts or {}, buf.enc or {}

        scite.BlockUpdate(UPDATE_BLOCK)
        --local fvl = editor.FirstVisibleLine
        --editor.VScrollBar = false
        if #t > 0 then
            BlockEventHandler"OnTextChanged"
            BlockEventHandler"OnBeforeOpen"
            BlockEventHandler"OnRightEditorVisibility"
            BlockEventHandler"OnOpen"
            BlockEventHandler"OnNavigation"
            BlockEventHandler"OnUpdateUI"
            fPrevOnOpen = OnOpen
            OnOpen = onOpen_local
        end
        local bRight, bRightPrev, bCloned, bIsRight = false, false, false, false
        local curPos = tonumber(_G.iuprops['buffers.current'] or - 1)
        local curCoPos = tonumber(_G.iuprops['buffers.cocurrent'] or - 1)
        for i = #t, 1,- 1 do
            if i == 1 then
                OnOpen = fPrevOnOpen
                UnBlockEventHandler"OnUpdateUI"
                UnBlockEventHandler"OnNavigation"
                UnBlockEventHandler"OnOpen"
                UnBlockEventHandler"OnRightEditorVisibility"
                UnBlockEventHandler"OnBeforeOpen"
                UnBlockEventHandler"OnTextChanged"
            end
            local sNm = t[i]
            bCloned = false
            if sNm:find('^<') then
                sNm = sNm:gsub('^<', '')
                bCloned = true
            end

            bRight = false
            if sNm:find('^>') then
                sNm = sNm:gsub('^>', '')
                bRight = true
            end

            _ENCODINGCOOKIE = enc[i] or 0
            scite.Open(sNm)
            _ENCODINGCOOKIE = nil

            if bRight ~= bRightPrev then
                CORE.ChangeTab()
            end
            if bCloned then scite.MenuCommand(IDM_CLONETAB) bRight = not bRight end

            if bRight or bCloned then bIsRight = true end

            bRightPrev = bRight
            if p[i] then
                editor.FirstVisibleLine = (math.tointeger(p[i]) or 0)
                editor.SelectionStart = editor:PositionFromLine(editor:DocLineFromVisible(editor.FirstVisibleLine + 5))
                editor.SelectionEnd = editor.SelectionStart
            end

            for bki in (bk[i] or ''):gmatch('%d+') do
                editor:MarkerAdd(math.tointeger(bki), MARKER_BOOKMARK)
                if BOOKMARK then BOOKMARK.Add(math.tointeger(bki)) end
            end
            if l and l[i] then
                RestoreLayOut(l[i])
            end
        end
        UnBlockEventHandler"OnRightEditorVisibility"

        scite.BlockUpdate(UPDATE_FORCE)
        --editor.VScrollBar = true
        --editor.FirstVisibleLine = fvl
        if bNew then
            scite.buffers.SetDocumentAt(0)
        else
            if curCoPos >= 0 then scite.buffers.SetDocumentAt(curCoPos) end
            if curPos >= 0 then scite.buffers.SetDocumentAt(curPos) end
        end

        if not bIsRight then
            _G.iuprops['coeditor.win'] = '2';
            if _G.g_session['coeditor'] then _G.g_session['coeditor'].HideDialog(); end
        else
            coeditor.Zoom = editor.Zoom
            editor:GrabFocus()
            editor.Focus = true
        end
    end
end

local function LoadSession_local(filename)
    local bSucs, f = pcall(io.input, filename)
    if bSucs then
        text = f:read('*a'):from_utf8()
        f:close()
        local bSuc, tMsg = pcall(dostring,text)
        if not bSuc then
            print('Ошибка в файле '..filename, tMsg)
            return false
        end
        iup.RestoreFiles(true)
        _G.iuprops['buffers'] = nil
        return true
    else
        print('Ошибка при открытии файла: '..f)
    end
end

iup.LoadSession = function()
    local d = iup.filedlg{dialogtype='OPEN', parentdialog='SCITE', extfilter='Session|*.fileset;', directory=props["scite.userhome"].."\\" }
    d:popup()
    local filename = d.value
    d:destroy()
    if not filename then return end
    LoadSession_local(filename)
end

iup.SaveSession = function()
    local d = iup.filedlg{dialogtype='SAVE', parentdialog='SCITE', extfilter='Session|*.fileset;', directory=props["scite.userhome"].."\\" }
    d:popup()
    local filename = d.value
    d:destroy()

    if not filename then return end
    if not filename:lower():find('%.fileset$') then filename = filename..'.fileset' end
    if iup.CloseFilesSet(0) then
        if pcall(io.output, filename) then
            local s = CORE.tbl2Out(_G.iuprops["buffers"], ' ', false, true, true):gsub('^return ', '_G.iuprops["buffers"] = ')
            io.write(s:to_utf8())
            io.close()
        end
    end
end

function CORE.HelpUI(helpid, anchor)
    local dv, fl = 'Hildim', helpid
    local _, _, d, f = helpid:find('(.*)::(.*)')
    if d then dv, fl = d, f end
    if(anchor) then anchor = anchor:gsub("&", "") end
    if shell.fileexists(props['SciteDefaultHome']..'/help/'..dv..'.chm') then
        local strCmd = props['SciteDefaultHome']..'/help/'..dv..'.chm::ui/'..fl..'.html'
        if anchor then strCmd = strCmd..'#'..anchor end
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

function CORE.SetText(t)
    BlockEventHandler"OnTextChanged"
    editor:SetText(t)
    UnBlockEventHandler"OnTextChanged"
end

function CORE.SetRO(fname)
    if shell.fileexists(fname) then
        local attr = shell.getfileattr(fname)
        if (attr & 1) == 1 then
            shell.setfileattr(fname, attr - 1)
        end
    end
end

function CORE.OpenRO(fname)
    CORE.SetRO(fname)
    return io.open(fname, "w")
end

function CORE.AskReWriteFile(fname)
    if shell.fileexists(fname) then
        local attr = shell.getfileattr(fname)
        local msg, ro
        msg = _TH"The file \n'%1'\n already exists%2. Overwrite?"
        ro = ''
        if (attr & 1) == 1 then ro = _TH" and is read-only" end
        return 1 == iup.Alarm('HildiM', _FMT(msg, fname, ro), _TH"OK", _TH"Cancel")
    else
        return true
    end
end

function CORE.AskCreatePath(fname)
    local p = fname:gsub('[^\\]*$', '')
    if not shell.fileexists(p) then
        local msg = _TH"The directory \n'%1'\n is not exists. Create?"

        if 1 == iup.Alarm('HildiM', _FMT(msg, p), _TH"OK", _TH"Cancel") then
            local pNew = ''
            for pNext in p:gmatch('[^\\]+') do
                pNew = pNew..pNext
                if not shell.fileexists(pNew..'\\') then
                    if not shell.greateDirectory(pNew) then
                        iup.Alarm('HildiM', _TH"The directory \n'%1'\n can't be created.", _TH"OK", _TH"Cancel")
                        return false
                    end
                end
                pNew = pNew..'\\'
            end
            return true
        else
            return false
        end
    else
        return true
    end
end

function CORE.CloseListSet(sel, lst, column, capt, iCapt)
    for i = lst.numlin, 1,- 1 do
        if (iup.GetAttributeId2(lst, 'TOGGLEVALUE', i, column) or '0') == sel then
            lst.dellinhidden = i
        else
            iup.SetAttributeId2(lst, 'TOGGLEVALUE', i, column, '0')
        end
    end
    if capt then lst:setcell(0, iCapt, capt.."("..lst.numlin..")") end
    lst.redraw = 'ALL'
end

local cmdCounter = 0
local cmdMap = {}

function CORE.AsyncProc(cmd, fCallBack, dir)
    local function prn(k, v)
        if k == 'S' then v = 'Exit: '..v
        elseif k == 'E' then  v = 'Error: '..v end
        output:SetSel(output.TextLength, output.TextLength)
        output:ReplaceSel(v)
    end
    cmdCounter = #cmdMap
    cmdMap[''..cmdCounter] = fCallBack or prn
    lanesgen(cmd, ''..cmdCounter, dir)
   -- return
    --cmdCounter = cmdCounter + 1
end

AddEventHandler("OnLindaNotify", function(key)
    if key:find("^CORE_CMD_") then
        local _, _, id, k = key:find('(%d+)_(.)')
        if id and cmdMap[id] then
            local key, val = linda:receive( 1.0, key)
            cmdMap[id](k, val)
            if k ~= 'C' then table.remove(cmdMap, id) end
        end
    end
end)

AddEventHandler("OnMenuCommand", function(cmd, source)
    if cmd == 9132 or cmd == 9134 or cmd == IDM_CLOSEALL or (cmd == IDM_QUIT and not _G.g_session['scip.plugins']) then
        if cmd == IDM_QUIT then
            if MACRO and MACRO.Record then MACRO.StopRecord() return true end
            scite.SavePosition()
        end
        return iup.CloseFilesSet(cmd)
    elseif cmd == 9117 or cmd == IDM_REBOOT then  --перезагрузка скрипта
        if dlg_SPLASH then dlg_SPLASH:hide(); dlg_SPLASH:destroy(); dlg_SPLASH = nil; end
        iup.DestroyDialogs();
        SaveIup()
        ClearAllEventHandler()
        RestoreIup()
        scite.RunAsync(function()
                print("Reload IDM...")
                CORE.ResetConcoleTimer(true)
                scite.ReloadStartupScript()
                OnSwitchFile("")
                print("...Ok")
            end)
        return true
    elseif cmd == IDM_TOGGLEOUTPUT then
        local hMainLayout = iup.GetLayout()
        local split = iup.GetDialogChild(hMainLayout, "BottomBarSplit")
        local bHidden = (tonumber(split.barsize) == 0)
        if split.popupside ~= '0' then
            if split.hidden == 'YES' then
                CORE.BottomBarSwitch('NO')
            else
                CORE.BottomBarSwitch('YES')
            end
        elseif bHidden then
            local l =  (_G.iuprops['bottombar.layout'] or 700500)
            local v2 = l % 10000
            if SideBar_Plugins.findrepl.Bar_obj then v2 = 0 end
            local v = math.floor(l / 10000)
            iup.GetDialogChild(hMainLayout, "BottomBarSplit").barsize = '5'
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
            if not shell.fileexists(source:from_utf8()) then return end
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
    elseif cmd == IDM_GO or cmd == IDM_BUILD or cmd == IDM_COMPILE then
        local strcmd
        if cmd == IDM_GO then strcmd = 'go'
        elseif cmd == IDM_BUILD then strcmd = 'build'
        else strcmd = 'compile' end
        if props['command.'..strcmd..'.subsystem$'] == '10' then
            if props["clear.before.execute"] == '1' then output:SetText('') end
            assert(load(props['command.'..strcmd..'$']))()
            return true
        end
    end
end)

function CORE.CoToChange(dif)
    local f = Iif(dif > 0, editor.MarkerNext, editor.MarkerPrevious)
    local l = editor:LineFromPosition(editor.CurrentPos)
    local lP = l
    OnNavigation("Change")
    local rotate = true
::rotated::
    repeat
        l = f(editor, l + dif, (1 << MARKER_NOTSAVED) | (1 << MARKER_SAVED))
        if lP + dif ~= l and l > 0 then
            editor.SelectionStart = editor:PositionFromLine(l)
            editor.SelectionEnd = editor.SelectionStart
            editor:EnsureVisible(l)
            editor:EnsureVisibleEnforcePolicy(l)
            OnNavigation("Change-")
            return
        end
        lP = l
    until l == -1
    if rotate then
        rotate = false
        l = Iif(dif > 0, 0, editor:LineFromPosition(editor.Length - 1))
        goto rotated
    end
    OnNavigation("Change-")
    print(Iif(dif > 0, 'Next', 'Previous')..' change not found')
end

AddEventHandler("OnTextChanged", function(position, flag, linesAdded, leg)
    if (_G.iuprops['changes.mark.line'] or 0) == 1 and not _G.g_session['OPENING'] then
        local e = Iif(leg == scite.buffers.GetBufferSide(scite.buffers.GetCurrent()), editor, coeditor)
        if (flag & (SC_PERFORMED_UNDO | SC_PERFORMED_REDO)) ~= 0 then
            scite.RunAsync(function()
                if scite.buffers.SavedAt(scite.buffers.GetCurrent()) then CORE.fixMarks(); return end
            end)
        end
        local bOk, lstart = pcall(function() return e:LineFromPosition(position) end)
        if not bOk then return end
        if lstart ~= 0 or linesAdded ~= e:LineFromPosition(e.Length) then
            for i = lstart, lstart + Iif(linesAdded > 0, linesAdded, 0) do
                 if (e:MarkerGet(i) & (1 << MARKER_NOTSAVED)) == 0 then e:MarkerAdd(i, MARKER_NOTSAVED) end
            end
        end
    elseif type(_G.g_session['OPENING']) == 'number' and _G.g_session['OPENING'] > 1 then
        _G.g_session['OPENING'] = _G.g_session['OPENING'] - 1
    else
        _G.g_session['OPENING'] = nil
    end
end)

AddEventHandler("OnSave", function(cmd, source)
    CORE.fixMarks(true)

    while editor:EndUndoAction() > 0 do
        print'!!!Warning!!! EndUndoAction from OnSave'
    end
    if editor.Lexer == SCLEX_LUA then
        local lp = output.TextLength
        scite.RunAsync(function()
            if lp ~= output.TextLength then
                s, e = output:findtext('\\w.+?\\]:', SCFIND_REGEXP, lp)
                if s then
                    output.TargetStart = s
                    output.TargetEnd = e
                    output:ReplaceTarget(props["FilePath"]..':')
                end
            end
        end)
        assert(load(editor:GetText()))
        return
    end
end)

AddEventHandler("OnClose", function(source)
    _G.g_session['OPENING'] = true
    if source:find('^%^') or source:find('\\%^^') then return end
    if not source:find('^\\\\') then
        if not shell.fileexists(source) then return end
    end
    iuprops['resent.files.list']:ins(source, editor.FirstVisibleLine, SaveLayOut(), iup.GetBookmarkLst(), scite.buffers.EncodingAt(scite.buffers.GetCurrent()))
    if scite.buffers.GetCount() == 1 and editor.ReadOnly then scite.MenuCommand(IDM_READONLY) end
end)

AddEventHandler("OnOpen", onOpen_local)
AddEventHandler("OnNavigation", onNavigate_local)

--Расширение iup.TreeAddNodes - позволяет в табличном представлении дерева задавать свойство userdata
local old_TreeSetNodeAttrib = iup.TreeSetNodeAttrib
iup.TreeSetNodeAttrib = function (handle, tnode, id)
  old_TreeSetNodeAttrib(handle, tnode, id)
  if tnode.userdata then iup.SetAttributeId(handle, "USERDATA", id, tnode.userdata) end
end
--Переопределяем iup сообщение об ошибке - чтобы не было их всплывающего окна, печатаем все к нам в output
iup._ERRORMESSAGE = function(msg,traceback)
    print(msg..(traceback or ""))
end
function list_getvaluenum(h)
    local l = h.focus_cell:gsub(':.*','')
    return tonumber(l)
end

function Min(a,b)
    if a < b then return a end
    return b
end
function Max(a,b)
    if a > b then return a end
    return b
end

local old_flatscrollbox = iup.flatscrollbox
iup.flatscrollbox = function(t)
    t.sb_forecolor = props['layout.scroll.forecolor']
    t.sb_highcolor = props['layout.scroll.highcolor']
    t.sb_presscolor = props['layout.scroll.presscolor']
    t.sb_backcolor = props['layout.scroll.backcolor']
    return old_flatscrollbox(t)
end

local old_iup_flatbutton = iup.flatbutton
iup.flatbutton = function(t)
    t.borderhlcolor = props["layout.borderhlcolor"]
    t.hlcolor = props["layout.hlcolor"]
    return old_iup_flatbutton(t)
end

iup.hi_toggle = function(t)
    t.toggle = 'YES'
    local fg, bg
    t.image = "uncheck_t_µ"
    t.imagepress = "check_t_µ"
    t.spacing = 5
    if t.ctrl then
        t.imageinactive = "uncheck_µ"
        fg = props['layout.txtfgcolor']
        bg = props['layout.txtbgcolor']
    else
        t.imageinactive = "uncheck_µ"
        fg = props['layout.fgcolor']
        bg = props['layout.bgcolor']
    end

    t.borderwidth = '0'

    t.pscolor = bg
    t.fgcolor = fg
    local map_cb_old = t.map_cb
    t.map_cb = function(h)
        h.bgcolor = bg
        if map_cb_old then map_cb_old(h) end
    end
    return iup.flatbutton(t)
end

local old_matrix = iup.matrix
iup.matrix = function(t)
    t.hlcolor="255 255 255"
    t.hlcoloralpha = "255"
    t.sb_forecolor = props['layout.scroll.forecolor'];
    t.sb_highcolor = props['layout.scroll.highcolor'];
    t.sb_presscolor = props['layout.scroll.presscolor'];
    t.sb_backcolor = props['layout.scroll.backcolor']
    t['bgcolor0:*'] = props['layout.scroll.backcolor']
    t['bgcolor*:0'] = props['layout.scroll.backcolor']
    t.bgcolor = props['layout.txtbgcolor'];
    t.fgcolor = props['layout.txtfgcolor']

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
                local sel
                if h.marked then sel = h.marked:find('1') end
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
            local w = h.rastersize:gsub('x.*', '') - (16 + 8 * n)
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
    -- if not t.staterefresh then t.staterefresh = "NO" end
    local expand = old_iup_expander(t)

    function expand:switch()
        if expand.state == 'OPEN' then expand.state = 'CLOSE'
        else expand.state = 'OPEN' end
    end

    function expand:isOpen() return expand.state == 'OPEN' end

    return expand
end

local old_iup_GetParam = iup.GetParam
local indGetParam
iup.GetParam = function(...)
    local tParams = table.pack(...)
    local _, _, capt, fName = (tParams[1]):find('([^^]*)^(.*)')
    indGetParam = fName
    if fName then
        tParams[1] = capt
        iup.SetGlobal('INPUTCALLBACKS', 'YES')
    end
    local t = table.pack(old_iup_GetParam(table.unpack(tParams)))
    iup.SetGlobal('INPUTCALLBACKS', 'NO')
    indGetParam = nil
    return table.unpack(t)
end

function OnParamKeyPress()
    if editor.Focus or findres.Focus or output.Focus or not indGetParam then
        iup.SetGlobal('INPUTCALLBACKS', 'NO')
    else
        CORE.HelpUI(indGetParam, nil)
    end
end

local old_iup_text = iup.text
iup.text = function(t)
    if not t.bgcolor then t.bgcolor = props['layout.txtbgcolor'] end
    if not t.fgcolor and not (t.readonly or t.readonly == 'NO') then t.fgcolor = props['layout.txtfgcolor'] end
    return old_iup_text(t)
end

local old_iup_list = iup.list
iup.list = function(t)
    if not t.flat then t.flat = 'YES' end
    if not t.bgcolor then t.bgcolor = props['layout.txtbgcolor'] end
    if not t.fgcolor then t.fgcolor = props['layout.txtfgcolor'] end
    local cmb = old_iup_list(t)
    function cmb:FillByDir(pathmask, strSel)
        local current_path = props["sys.calcsybase.dir"]..pathmask

        local files = scite.findfiles(current_path)
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
    cmb.staticfgcolor = props['layout.fgcolor']
    return cmb
end

iup.scitedeatach = function(dtb)
    dtb.detachhidden = 1
    iup.ShowXY(dtb.Dialog, _G.iuprops['dialogs.'..dtb.sciteid..'.x'] or '100', _G.iuprops['dialogs.'..dtb.sciteid..'.y'] or '100')
end

function CORE.BottomBarSwitch(cmd)
    if cmd== 'NO' then CORE.curTopSplitter = 'BottomBar' end
    local hMainLayout = iup.GetLayout()
    local bottomsplit = iup.GetDialogChild(hMainLayout, "BottomBarSplit")
    bottomsplit.hidden = cmd
    if (_G.iuprops['findresbar.win'] or '0') == '0' then
        iup.GetDialogChild(hMainLayout, "barBtnfindresbar").visible = cmd
    end
    if (_G.iuprops['concolebar.win'] or '0') == '0' then
        iup.GetDialogChild(hMainLayout, "barBtnconcolebar").visible = cmd
    end
    if (_G.iuprops['findrepl.win'] or '0') == '0' then
        iup.GetDialogChild(hMainLayout, "barBtnfindrepl").visible = cmd
    end
end

CORE.paneldraw_cb = function(h)
    local _, _, xD, yD = h.RASTERSIZE:find('(%d+)x(%d+)')
    iup.DrawBegin(h)
    iup.DrawSetClipRect(h, 0, 0, xD, yD)
    h.drawcolor = props['layout.bgcolor']
    h.drawstyle = "FILL"
    iup.DrawRectangle(h, 0, 0, xD - 1, yD - 1)
    local w = tonumber(props['layout.wndframesize']) + 2
    h.drawcolor = props['layout.splittercolor']
    h.drawstyle = "STROKE"
    h.drawlinewidth = w
    w = w / 2
    iup.DrawRectangle(h, w, w, xD - w, yD - w)
    if h.drawactive == '1' then
        h.drawcolor = props['layout.bordercolor']
        h.drawlinewidth = 2
        iup.DrawRectangle(h, 1, 1, xD - 1, yD - 1)

    end
    iup.DrawEnd(h)
end

CORE.panelactivate_cb = function(flat_title)
    return function(h, active)
        h.drawactive = active
        if(flat_title) then
            flat_title.fgcolor = Iif(active == 1, props['layout.fgcolor'], props['layout.txtinactivcolor'])
            iup.Redraw(flat_title, 1)
        end
        h.customframedraw_cb(h)
    end
end

function CORE.panelCaption(ts)
    local pDlg, sX, sY, bMoved, hbTitle, flat_title
    local function fDlg()
        if not pDlg then
            pDlg = iup.GetParent(hbTitle)
            while iup.GetParent(pDlg) do pDlg = iup.GetParent(pDlg ) end
            pDlg.customframeactivate_cb = CORE.panelactivate_cb(flat_title)
        end
        return pDlg
    end
    local function button_cb(h, button, pressed, x, y, status)
        h.value = 0
        if not fDlg() then return end
        if button == 49  then
            bMoved = pressed; sX = x; sY = y
            if bMoved == 0 then
                _G.iuprops['dialogs.'..ts.sciteid..'.x'] = fDlg().x
                _G.iuprops['dialogs.'..ts.sciteid..'.y'] = fDlg().y
            end
        end
    end

    local function motion_cb(h, x, y, status)
    h.value=1
        if not fDlg() then return end
        if bMoved == 1 and sX and sY and not bRecurs then
            local _,_,wx,wy = fDlg().screenposition:find('(%-?%d*),(%-?%d*)')
            local nX, nY = tonumber(wx) + (x - sX), tonumber(wy) + (y - sY)
            bRecurs = true
            if nX ~= wx or nY ~= wy then old_iup_ShowXY(fDlg(), nX, nY) end
            bRecurs = false
        end
    end

    local btn_attach
    if ts.attach_action then
        btn_attach = iup.flatbutton{image = 'ui_toolbar__arrow_µ', canfocus = 'NO', name = ts.sciteid..'_title_btnattach', tip = 'Attach', flat_action = ts.attach_action}
        btn_attach.image.bgcolor = iup.GetLayout().bgcolor
    end

    flat_title = iup.flatbutton{title = ' '..ts.title, name = 'Title', fgcolor = props['layout.fgcolor'], image = ts.buttonImage, maxsize = 'x20', fontsize = '9', flat = 'YES', border = 'NO', padding = '3x', alignment = 'ALEFT',
        canfocus = 'NO', expand = 'HORIZONTAL', size = '100x20', button_cb = button_cb, motion_cb = motion_cb, enterwindow_cb = function() end,
    leavewindow_cb = function() end,}

    hbTitle = iup.expander{iup.hbox{ alignment = 'ACENTER', bgcolor = iup.GetLayout().bgcolor, name = ts.sciteid..'_title_hbox', fontsize = iup.GetGlobal("DEFAULTFONTSIZE"), gap = 5,
        flat_title,
        btn_attach,
        iup.flatbutton{image = 'cross_button_µ', tip = 'Hide', canfocus = 'NO', flat_action = ts.action},
    }, barsize = 0, state = ts.state, name = ts.sciteid..'_expander'}
    return hbTitle
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

     btn_attach.image.bgcolor = iup.GetLayout().bgcolor
     local flat_title = iup.flatbutton{title = ' '..t.Dlg_Title,name='Title',fgcolor=props['layout.fgcolor'], image=t.buttonImage, maxsize = 'x20', fontsize='9',flat='YES',border='NO',padding='3x', alignment='ALEFT',
         canfocus='NO', expand = 'HORIZONTAL', size = '100x20', button_cb = button_cb, motion_cb = motion_cb, enterwindow_cb=function() end,
         leavewindow_cb = function() end,}

     local hbTitle = iup.expander{iup.hbox{ alignment='ACENTER',bgcolor=iup.GetLayout().bgcolor, name = t.sciteid..'_title_hbox', fontsize=iup.GetGlobal("DEFAULTFONTSIZE"), gap = 5,
         flat_title,
         btn_attach,
         iup.flatbutton{image = 'cross_button_µ', tip='Hide', canfocus='NO', flat_action = function() cmd_Hide() end},
     }, barsize = 0, state='CLOSE', name = t.sciteid..'_expander'}
    --local hbTitle = iup.dialog{CORE.panelCaption{title = ' '..t.Dlg_Title, sciteid = t.sciteid, attach_action = function() cmd_Attach() end, state = 'CLOSE', action = function() cmd_Hide() end}}

    if t[1] then
        local vb = t[1]
        table.remove(t)
        --table.insert(t, iup.vbox{hbTitle, vb, fontsize=iup.GetGlobal("DEFAULTFONTSIZE"),})

        table.insert(t, iup.backgroundbox{iup.vbox{iup.scrollbox{hbTitle, scrollbar = 'NO', state = 'CLOSE', expand = "HORIZONTAL", visible = 'NO'}, vb, fontsize = iup.GetGlobal("DEFAULTFONTSIZE"),}, focus_cb = t.focus_cb})
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

    if t.focus_cb then
        local function Sropagatefocus(h)
            for i = 0, iup.GetChildCount(h) - 1 do
                local h1 = iup.GetChild(h, i)
                Sropagatefocus(h1)
                if h1.propagatefocus == 'NO' and not h1.setfocus_cb and not h1.getfocus_cb then h1.propagatefocus = 'YES' end
            end
        end
        Sropagatefocus(dtb)
    end

    dtb.sciteid = t.sciteid
    dtb.Dlg_Close_Cb = t.Dlg_Close_Cb
    dtb.Dlg_Show_Cb = t.Dlg_Show_Cb
    dtb.Split_h = nil
    if t.Split_h then
        if type(t.Split_h) == 'function' then
            dtb.Split_h = t.Split_h
        else
            dtb.Split_h = (function() return t.Split_h end)
        end
    end
    dtb.Split_Title = t.Split_Title
    dtb.Split_CloseVal = t.Split_CloseVal
    dtb.On_Detach = t.On_Detach
    dtb.barsize = 0

    local function ShowStatusBtn()
        if t.MenuVisible then
            scite.RunAsync(function()
                statusBtn.visible = Iif(t.MenuVisible(), 'YES', 'NO')
            end)
        else
            statusBtn.visible = 'YES'
        end
    end

    dtb.detachPos = (function(bShow)
        dtb.detached = 1
        dtb.detachhidden = 1
        dtb.detached = nil
local hbTitle = iup.GetDialogChild(iup.GetLayout(), dtb.sciteid..'_expander')
        _G.iuprops[dtb.sciteid..'.win'] = Iif(bShow, '1', '2')
        hbTitle.state = 'OPEN'
        iup.GetParent(hbTitle).visible = "YES"
        iup.GetParent(hbTitle).size = hbTitle.size
        dtb.Dialog.rastersize = _G.iuprops['dialogs.'..dtb.sciteid..'.rastersize']

        if t.Split_h then
            local s = dtb.Split_h()

            if s.barsize ~= "0" then _G.iuprops['dialogs.'..dtb.sciteid..'.splitvalue'] = s.value; _G.iuprops['sidebarctrl.'..s.name..'.value'] = s.value; end
            s.value = dtb.Split_CloseVal
            s.barsize = "0"
        end
        _G.dialogs[dtb.sciteid] = dtb
        dtb.Dialog.rastersize = _G.iuprops['dialogs.'..dtb.sciteid..'.rastersize']

        if bShow then
            iup.ShowXY(dtb.Dialog, _G.iuprops['dialogs.'..dtb.sciteid..'.x'] or '100', _G.iuprops['dialogs.'..dtb.sciteid..'.y'] or '100')
        else
            if statusBtn then ShowStatusBtn() end
        end
        if not bShow and dtb.Dlg_Show_Cb then dtb.Dlg_Show_Cb(dtb.Dialog, 0) end
    end)

    dtb.detached_cb =(function(h, hNew, x, y)
        dtb.Dialog = hNew
        if h.On_Detach then h.On_Detach(h, hNew, x, y) end
        hNew.resize ="YES"
        hNew.shrink ="YES"
        hNew.minsize="100x100"
        hNew.maxbox="NO"
        hNew.minbox="NO"
        hNew.menubox="NO"
        hNew.toolbox="YES"
        hNew.bgcolor = iup.GetLayout().bgcolor
        hNew.txtbgcolor = iup.GetLayout().txtbgcolor
        hNew.txtfgcolor = iup.GetLayout().txtfgcolor
        hNew.borderhlcolor = iup.GetLayout().borderhlcolor
        hNew.hlcolor = iup.GetLayout().hlcolor
        hNew.bordercolor = iup.GetLayout().bordercolor
        hNew.flat = 'YES'
        hNew.customframedraw = Iif(props['layout.standard.decoration'] == '1', 'NO', 'YES')
        hNew.customframecaptionheight = -1

        hNew.x=10
        hNew.y=10
        x=10;y=10
        local firstShow = true
        hNew.rastersize = _G.iuprops['dialogs.'..h.sciteid..'.rastersize']
        _G.iuprops[h.sciteid..'.win']='1'
        if h.Split_h then _G.iuprops['dialogs.'..h.sciteid..'.splitvalue'] = h.Split_h().value end

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
            if not dtb.detached then
                _G.iuprops['dialogs.'..dtb.sciteid..'.y'] = y
                _G.iuprops['dialogs.'..dtb.sciteid..'.x'] = x
            end
        end
        hNew.resize_cb = function(h, x, y)
            _G.iuprops['dialogs.'..dtb.sciteid..'.rastersize'] = h.rastersize
            if OnResizeSideBar then OnResizeSideBar(t.sciteid) end
        end

        hNew.customframedraw_cb = CORE.paneldraw_cb

        hNew.customframeactivate_cb = CORE.panelactivate_cb(flat_title)

        scite.RunAsync(function() iup.Refresh(hNew) end)

    end)
    dtb.HideDialog = function()
        if dtb.Dialog then
            dtb.Dialog:hide()
            _G.iuprops[dtb.sciteid..'.win'] = '2'
            iup.PassFocus()
            if statusBtn then ShowStatusBtn() end
        end
    end
    dtb.ShowDialog = function()
        if dtb.Dialog and (_G.iuprops[dtb.sciteid..'.win'] or '0') == '2' then
            _G.iuprops[dtb.sciteid..'.win'] = '1'
            iup.ShowXY(dtb.Dialog, _G.iuprops['dialogs.'..dtb.sciteid..'.x'] or '100', _G.iuprops['dialogs.'..dtb.sciteid..'.y'] or '100')
            if statusBtn then statusBtn.visible = 'NO' end
        end
        scite.RunAsync(function() iup.Refresh(dtb.Dialog) end)

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
            if dtb.sciteid == 'concolebar' or dtb.sciteid == 'findresbar' or dtb.sciteid == 'coeditor' then
                canvasbar = iup.GetChild(iup.GetChild(_G.dialogs[dtb.sciteid], 1), 1)
                canvasbar.visible = 'NO'
            end
 local hbTitle = iup.GetDialogChild(iup.GetLayout(), dtb.sciteid..'_expander')

            hbTitle.state = 'CLOSE'
            iup.GetParent(hbTitle).size = "x0"
            iup.GetParent(hbTitle).visible = "NO"
            dtb.visible = 'YES'

            dtb.restore = nil
            _G.dialogs[dtb.sciteid] = nil
            if t.Split_h then
                local s = dtb.Split_h()

                local l = tonumber(_G.iuprops['dialogs.'..dtb.sciteid..'.splitvalue'] or 500)
                if l < 15 and dtb.sciteid == 'concolebar' then l = 200
                elseif l > 985 and dtb.sciteid == 'findresbar'  then l = 800 end
                s.value = l
                s.barsize = '5'
            end
            dtb.Dialog = nil
            if statusBtn then statusBtn.visible = 'NO' end
            if OnResizeSideBar then OnResizeSideBar(t.sciteid) end
            if canvasbar then canvasbar.visible = 'YES' end
        end
    end

    dtb.AutoHide = function()
        local right = (dtb.sciteid == 'sidebar')
        local split = t.Split_h
        local tab = iup.GetDialogChild(iup.GetLayout(), 'sidebartab_'..dtb.sciteid)
        tab.tabtype = Iif(right, 'RIGHT', 'LEFT')
        tab.taborientation = 'VERTICAL'
        tab.tabstextorientation = Iif(right, -90, 90)
        tab.tabspadding = '3x10'
        local _, _, w1 = tab.rastersize:find('x(%d+)')
        local _, _, w2 = iup.GetChild(tab, 0).rastersize:find('x(%d+)')
        split.hiddengap = w1 - w2
        split.popupside = Iif(right, '2', '1')
        split.hidden = 'YES'
        local bottomsplit = iup.GetDialogChild(iup.GetLayout(), "BottomBarSplit")
        if bottomsplit then bottomsplit.hidden = "YES" end
    end

    dtb.UnAutoHide = function()
        local s = t.Split_h
        local tab = iup.GetDialogChild(iup.GetLayout(), 'sidebartab_'..dtb.sciteid)
        tab.tabtype = 'TOP'
        tab.taborientation = 'HORIZONTAL'
        tab.tabstextorientation = 0
        tab.tabspadding = '10x3'

        s.popupside = '0'
        s.hidden = 'NO'
    end

    cmd_Attach = function ()
        local s = get_scId()
        if s ~= "0" and s ~= "3" then
            local sId = dtb.sciteid
            local bIsBotom = (sId == 'findrepl' or sId == 'concolebar' or sId == 'findresbar')
            if tonumber(iup.GetDialogChild(iup.GetLayout(), "BottomBarSplit").barsize) == 0 and bIsBotom  then
                scite.MenuCommand(IDM_TOGGLEOUTPUT)
                if get_scId() == "0" then return end
            end
            dtb.Attach()
            if bIsBotom and iup.GetDialogChild(iup.GetLayout(), 'BottomBarSplit').popupside ~= '0' then
                CORE.BottomBarSwitch('NO')
            end
        end
        if s == '3' then
            dtb.UnAutoHide()
            _G.iuprops[dtb.sciteid..'.win'] = '0'
        end
    end

    local function cmd_PopUp()
        local s =  get_scId()
        if s == "0" or s == '3' then
            if s == '3' then dtb.UnAutoHide() end
            if dtb.sciteid == 'concolebar' then
                iup.GetDialogChild(iup.GetLayout(), "Run").visible = "YES"
            elseif dtb.sciteid == 'findresbar' then
                iup.GetDialogChild(iup.GetLayout(), "FindRes").visible = "YES"
            end
            dtb.detachPos(true)
        elseif s == "2" then

            dtb.ShowDialog()
        end
        if statusBtn then statusBtn.visible = 'NO' end
    end

    local function cmd_AutoHide()
        local s = get_scId()
        if s == '3' then return end
        if s ~= "0" and s ~= "3" then dtb.Attach() end
        dtb.AutoHide()
        _G.iuprops[dtb.sciteid..'.win'] = '3'
    end

    cmd_Hide = function ()
        local s = get_scId()
        if s == "2" then return end
        if statusBtn then _G.iuprops[t.sciteid..'.visible.state'] = get_scId() end
        if s == "0" or s == '3' then
            if s == '3' then dtb.UnAutoHide() end
            dtb.detachPos(false)
        elseif s == "1" then
            dtb.HideDialog()
        end
        if statusBtn then statusBtn.visible = 'YES' end
    end
    dtb.cmdHide = function() cmd_Hide() end

    local function cmd_AttachPane()
        if (_G.iuprops[t.sciteid..'.win'] or "0") == "3" then
            cmd_Attach()
        else
            cmd_AutoHide()
        end
    end

    local function cmd_Switch()
        if (_G.iuprops[t.sciteid..'.win'] or "0") == "0" and (t.sciteid == 'findrepl' or t.sciteid == 'concolebar' or t.sciteid == 'findresbar') and iup.GetLayout("BottomBarSplit").popupside ~= '0' then
            if t.sciteid == 'findrepl' and _Plugins.findrepl.Bar_obj then
                local s = _Plugins.findrepl.Bar_obj.handle.Split_h()
                if s then s.hidden = "NO" end
            else
                CORE.BottomBarSwitch('NO')
            end
        elseif (_G.iuprops[t.sciteid..'.win'] or "0") ~= "2" and (_G.iuprops[t.sciteid..'.win'] or "0") ~= "3" then
            cmd_Hide()
        elseif (_G.iuprops[t.sciteid..'.win'] or "1") == "3" then
            --cmd_AutoHide()
            local right = (dtb.sciteid == 'sidebar')
            local split = t.Split_h
            split.hidden = Iif(split.hidden == 'YES', 'NO', 'YES')
        elseif (_G.iuprops[t.sciteid..'.visible.state'] or "1") == "1" then
            cmd_PopUp()
        elseif (_G.iuprops[t.sciteid..'.visible.state'] or "1") == "0" then
            cmd_Attach()
        end
        if t.onFormSetStaticControls then t.onFormSetStaticControls() end
    end

    dtb.Switch = cmd_Switch
    dtb.AttachPane = cmd_AttachPane

    if t.buttonImage then
        if not _tmpSidebarButtons then _tmpSidebarButtons = {} end
        statusBtn = iup.flatbutton{name = 'barBtn'..t.sciteid, image = t.buttonImage, visible = "NO", canfocus = "NO", flat_action = function()
                if t.sciteid == 'findrepl' then CORE.ActivateFindDialog('', -1) else cmd_Switch() end
            end,
            tip = t.Dlg_Title,}
        function statusBtn:flat_button_cb(button, pressed, x, y, status)
            if button == 51 and pressed == 1 and (t.sciteid ~= 'findrepl' or not SideBar_Plugins.findrepl.Bar_obj) then
                menuhandler:PopUp('MainWindowMenu|View|'..t.sciteid)
            end
        end
        table.insert(_tmpSidebarButtons, statusBtn)
    end

    local tSub = {radio = 1,
        {'Attached', action = cmd_Attach, check = function() return get_scId() == "0" end,},
        {'Pop Up', action = cmd_PopUp, check = function() return get_scId() == "1" end, },
        {'Hidden', action = cmd_Hide, check = function() return get_scId() == "2" end },
        {'Autohide panel', action = cmd_AutoHide,visible = function() return dtb.sciteid == 'sidebar' or dtb.sciteid == 'leftbar' end, check = function() return get_scId() == "3" end },
		{'Main Window split', visible = "(_G.iuprops['coeditor.win'] or '')=='0' and '"..dtb.sciteid.."'=='coeditor'",{radio = 1,
            {'Horizontal',  action = function() CORE.RemapCoeditor() end, check = "iup.GetChild(iup.GetDialogChild(iup.GetLayout(), 'CoSourceExpanderBtm'),1)", },
            {'Vertical',  action = function() CORE.RemapCoeditor() end, check = "not iup.GetChild(iup.GetDialogChild(iup.GetLayout(), 'CoSourceExpanderBtm'),1)", },
		},},
        {'s1', separator = 1},
        {'Show/Hide', action = cmd_Switch, key = Iif(dtb.sciteid == 'leftbar', 'F8', Iif(dtb.sciteid == 'sidebar', 'F9', nil)) },
        {'Attached/Autohide panel', action = cmd_AttachPane, visible= function() return dtb.sciteid == 'leftbar' or dtb.sciteid == 'sidebar' end, key = Iif(dtb.sciteid == 'leftbar', 'Ctrl+ F8', Iif(dtb.sciteid == 'sidebar', 'Ctrl+F9', nil)) },
    }

    if dtb.Split_h then
        dtb.Split_h().flat_button_cb = function(h, button, pressed, x, y, status)
            if button == iup.BUTTON1 and iup.isdouble(status) then cmd_Switch()
            elseif button == iup.BUTTON3 then
                menuhandler:PopUp('MainWindowMenu|View|'..t.sciteid)
            end
        end
    end

    menuhandler:InsertItem('MainWindowMenu', 'View|slast',  {dtb.sciteid, image = t.buttonImage, cpt = t.Dlg_Title,
    visible = t.MenuVisible or function() return  t.sciteid ~= 'findrepl' or not SideBar_Plugins.findrepl.Bar_obj end,
    tSub})

    if t.MenuEx then menuhandler:InsertItem(t.MenuEx, 'xxxxxx', {'&View', visible = t.MenuVisibleEx, tSub}) end

    return dtb
end

iup.ShowXY = function(h, x, y, bOrig)
    local xNew, yNew
    if bOrig then goto ok end
    x = math.floor(tonumber(x))
    y = math.floor(tonumber(y))
    if x == -2000 and y == -2000 then goto ok end
    for x11, y11, x12, y12 in iup.GetGlobal('MONITORSINFO'):gmatch('(%-?%d*) (%-?%d*) (%-?%d*) (%-?%d*)') do
        x11 = tonumber(x11)
        x12 = tonumber(x12)
        y11 = tonumber(y11)
        y12 = tonumber(y12)
        if x11 - 5 < x and x < (x12 + x11 - 10) and y11 - 5 < y and y < (y12 + y11 - 10) then goto ok end
        if not xNew then
            xNew = x11 + 10
            yNew = y11 + 10
        end
    end
    x = xNew
    y = yNew
::ok::
    return old_iup_ShowXY(h, x, y)
end

iup.ShowInMouse = function(dlg, bIupCtrl)
    local cPos = editor.SelectionEnd
    local hCtrl
    if bIupCtrl then hCtrl = iup.GetFocus() end
    local _, _, xC, yC, dY
    if hCtrl then
        _, _, _, dY = hCtrl.RASTERSIZE:find('(%-?%d+)x(%-?%d+)')
        _, _, xC, yC = hCtrl.Screenposition:find('(%-?%d+),(%-?%d+)')
        yC = yC + dY
    elseif editor.FirstVisibleLine <= editor:LineFromPosition(cPos) and
        editor:LineFromPosition(cPos) <= editor.FirstVisibleLine + editor.LinesOnScreen then
        dY = editor:TextHeight(editor:LineFromPosition(cPos))
        _, _, xC, yC = iup.GetDialogChild(iup.GetLayout(), "Source").Screenposition:find('(%-?%d+),(%-?%d+)')
        xC = tonumber(xC) + editor:PointXFromPosition(cPos) + editor:TextWidth(editor.StyleAt[cPos], ' ') * editor.SelectionNCaretVirtualSpace[0]
        yC = tonumber(yC) + editor:PointYFromPosition(cPos) + dY
    else
        _, _, xC, yC = iup.GetGlobal('CURSORPOS'):find('(%-?%d+)x(%-?%d+)')
        dY = 0
    end
    local _, _, xD, yD = dlg.RASTERSIZE:find('(%-?%d+)x(%-?%d+)')
    xC = tonumber(xC)
    xD = tonumber(xD)
    yC = tonumber(yC)
    yD = tonumber(yD)

    for x0S, y0S, xS, yS in iup.GetGlobal('MONITORSINFO'):gmatch('(%-?%d+) (%-?%d+) (%-?%d+) (%-?%d+)') do

        x0S = tonumber(x0S)
        y0S = tonumber(y0S)
        xS = tonumber(xS) + x0S
        yS = tonumber(yS) + y0S
        if x0S <= xC and xC <= xS and y0S <= yC and yC <= yS then
            if xC + xD > xS then xC = xC - xD if xC < x0S then xC = x0S end end
            if yC + yD > yS then yC = yC - yD - dY if yC < y0S then yC = y0S end end
            dlg:showxy(xC, yC)
            return hCtrl
        end
    end
    dlg:showxy(10, 10)
    return hCtrl
end
---Расширение iup

_G.dialogs = {}
iup.scitedialog = function(t)
    local dlg = _G.dialogs[t.sciteid]
    t.txtbgcolor = props['layout.txtbgcolor']
    t.txtinactivcolor = props['layout.txtinactivcolor']
    t.txtfgcolor = props['layout.txtfgcolor']
    t.bordercolor = props['layout.bordercolor']
    t.borderhlcolor = props['layout.borderhlcolor']
    t.icon = 'SCITE'
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
        -- else
        --     local w = (_G.iuprops['dialogs.'..t.sciteid..'.rastersize'] or ''):gsub('x%d*', '')
        --     if w=='' then w='300' end
        --     if tonumber(w) < 10 then w = '300' end
        --     dlg:showxy(0,0)
        --     iup.ShowSideBar(tonumber(w))
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
        iup.SetAttribute(dlg, "HELPID", id)
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
    local tblDat
    if OnScriptReload then tblDat = {}; OnScriptReload(true, tblDat) end
    ClearAllEventHandler();
    print("Reload...")
    scite.HideForeReolad()
    local bd

    iup.DestroyDialogs();
    SaveIup()
    RestoreIup()
    CORE.ResetConcoleTimer(true)
    scite.ReloadStartupScript()
    scite.RunAsync(function()
    if OnScriptReload then OnScriptReload(false, tblDat) end
    OnSwitchFile("")
    scite.EnsureVisible()
    iup.GetLayout().resize_cb()
    print("...Ok")
    if _G.iuprops['command.reloadprops'] then _G.iuprops['command.reloadprops'] = false; scite.RunAsync(function() scite.ReloadProperties() end) end
    end)
end

AddEventHandler("OnContextMenu", function(lp, wp, source)
    menuhandler:ContextMenu(lp, wp, source)
    return ""
end)

local function LoadIuprops_Local(filename)
    props['config.restore'] = filename
    _G.iuprops['current.config.restore'] = filename:gsub('^(.-)_?([^\\]-%.[^\\.]+)$', '%1%2')
    scite.RunAsync(iup.ReloadScript)
end

local function LoadIuprops()
    local d = iup.filedlg{dialogtype='OPEN', parentdialog='SCITE', extfilter='Config|*.config;', directory=props["scite.userhome"].."\\" }
    d:popup()
    local filename = d.value
    d:destroy()
    if not filename then return end
    LoadIuprops_Local(filename)
    mnu_configs = nil
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

    local t = {}
    for n,v in pairs(_G.iuprops) do
        local _, _, prefix, ctrl = n:find('([^%.]*)%.([^%.]*)')
        if prefix == 'sidebarctrl' or prefix == 'concolebar' or prefix == 'dialogs' or prefix == 'findrepl' or prefix == 'findres' or prefix == 'layout' or
           prefix == 'session' or prefix == 'settings' or prefix == 'sidebar' then
            if not n:find'%.hist$' then
                v = CORE.tbl2Out(v, ' ', true, true)
                if v then table.insert(t, '_G.iuprops["'..n..'"] = '..v) end
            end
        end
    end
    table.insert(t, '_G.iuprops["_VERSION"] = 3')


 	if pcall(io.output, filename) then
		io.write(table.concat(t,'\n'):to_utf8())
        io.close()
 	end
end

local mnu_configs

iup.SaveIuprops = function()

    local d = iup.filedlg{dialogtype='SAVE', parentdialog='SCITE', extfilter='Config|*.config;', directory=props["scite.userhome"].."\\" }
    d:popup()
    local filename = d.value
    d:destroy()
    SaveIuprops_local(filename)
    if filename then
        _G.iuprops['current.config.restore'] = filename:gsub('^(.-)_?([^\\]-%.[^\\.]+)$', '%1%2')
    end
    mnu_configs = nil
end

iup.ConfigList = function()
    if not mnu_configs then
        local t = (scite.findfiles(props["scite.userhome"].."\\*.config") or {})
        mnu_configs = {}
        local mnu_i
        for i = 1,  #t do
            mnu_i = {t[i].name, action = function() LoadIuprops_Local(props["scite.userhome"]..'\\'..t[i].name) end}
            table.insert(mnu_configs, mnu_i)
        end
        mnu_i = {'s1', separator = 1}
        table.insert(mnu_configs, mnu_i)
        mnu_i = {'Load...', action = LoadIuprops, image = 'folder_open_document_µ'}
        table.insert(mnu_configs, mnu_i)
    end
    return mnu_configs
end

iup.SaveCurIuprops = function()
    if _G.iuprops['current.config.restore']..'' ~= '' then SaveIuprops_local(_G.iuprops['current.config.restore']) end
end

--Уничтожение диалогов при выключении или перезагрузке
iup.DestroyDialogs = function()
    local hMainLayout = iup.GetLayout()
    if not hMainLayout then return end
    hMainLayout.resize_cb = nil
    if SideBar_obj and SideBar_obj.handle then SideBar_obj.handle.SaveValues() end
    if LeftBar_obj and LeftBar_obj.handle then LeftBar_obj.handle.SaveValues() end

    if iup.GetDialogChild(hMainLayout, "BottomBarSplit").barsize == '0' then
        iup.GetDialogChild(hMainLayout, "BottomBarSplit").barsize = '5'
        iup.GetDialogChild(hMainLayout, "BottomExpander").state = 'OPEN'
        if (_G.iuprops['concolebar.win'] or '0') == '0' then iup.GetDialogChild(hMainLayout, "ConsoleExpander").state = 'OPEN' end
        if (_G.iuprops['findresbar.win'] or '0') == '0' then iup.GetDialogChild(hMainLayout, "FindResExpander").state = 'OPEN' end
        iup.GetDialogChild(hMainLayout, "BottomBarSplit").value = _G.iuprops["sidebarctrl.BottomBarSplit.value"] or '900'
    end
    if (_G.iuprops['coeditor.win'] or '0') == '0' then iup.GetDialogChild(hMainLayout, "SourceExDetach").state = 'OPEN' end

    if _G.dialogs == nil then return end
    if _G.dialogs['findrepl'] ~= nil then
        iup.SaveNamedValues(_G.dialogs['findrepl'], 'findreplace')
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
    local split = iup.GetDialogChild(hMainLayout, 'SourceSplitRight')
    if split.popupside ~= '0' then split.popupside = '0' end
    split = iup.GetDialogChild(hMainLayout, 'SourceSplitLeft')
    if split.popupside ~= '0' then split.popupside = '0' end
    split = iup.GetDialogChild(hMainLayout, 'BottomBarSplit')
    if split.popupside ~= '0' then split.popupside = '0' end

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

    if _G.dialogs['coeditor'] ~= nil then
        iup.GetDialogChild(hMainLayout, "CoSourceExpander").state = "OPEN"
        _G.dialogs['coeditor'].restore = nil
        _G.dialogs['coeditor'] = nil
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

    h = iup.GetDialogChild(hMainLayout, "toolbar_expander_upper")
    if h then
        iup.Detach(h); iup.Destroy(h)
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
    for i = 1,  #CORE.onDestroy_event do
        try{
            CORE.onDestroy_event[i],
            catch{
                print
            }
        }
    end
    collectgarbage('collect')
end

function Splash_Screen()
    dlg_SPLASH = iup.dialog{iup.hbox{
    iup.label{
      padding = "5x5",
      image = "HildiM_µ",
      font = "Arial, 33",
    },
  }; maxbox="NO",minbox ="NO",resize ="NO", menubox = "NO", border = "NO",opacity= "123",
    sciteparent = "SCITE", sciteid = "splash", resize = "NO"}

    local _, _, x2, y2 = iup.GetGlobal('SCREENSIZE'):find('(%d*)x(%d*)')
    dlg_SPLASH:showxy(tonumber(x2)/2 - 100,tonumber(y2)/2 - 100)
end
function CORE.WinFromId(wid)
    if wid == IDM_SRCWIN then return editor
    elseif wid == IDM_COSRCWIN then return coeditor
    elseif wid == IDM_RUNWIN then return output
    elseif wid == IDM_FINDRESWIN then return findres end
    print("CORE.WinFromId: '"..wid.."' not found")
end

AddEventHandler("OnMarginClick", function(margin, modif, line, wid)
    local e = CORE.WinFromId(wid)
    if margin == 2 and e.Focus then
        if modif > 3 then line = e.FoldParent[line]; modif = modif - 4 end
        local curLevel = e.FoldLevel[line]
        if (curLevel & SC_FOLDLEVELHEADERFLAG) ~= 0 then
            if modif == 0 then
                if line == -1 then CORE.ToggleSubfolders(nil, -1, e, nil, nil, true)
                else e:ToggleFold(line) end
            elseif modif == 1 then
                CORE.ToggleSubfolders(false, line, e, nil, nil, true)
            elseif modif == 2 then
                e:ToggleFold(line)
                CORE.ToggleSubfolders(false, line, e, 100, Iif( e.FoldExpanded[line], 1, 0), true)
            elseif modif == 3 then
                CORE.ToggleSubfolders(nil, -1, e, nil, nil, true)
            end
            CORE.ShowCaretAfterFold()
            return "Y"
        end
    end
end)

RestoreIup = function()
    iup.ShowXY              = old_iup_ShowXY
    iup.TreeSetNodeAttrib   = old_TreeSetNodeAttrib
    iup.matrix              = old_matrix
    iup.expander            = old_iup_expander
    iup.GetParam            = old_iup_GetParam
    iup.list                = old_iup_list
end
