require "seacher"
local containers
local oDeattFnd
local firstMark = tonumber(props["findtext.first.mark"])
local popUpFind
--local _Plugins

local function fb_find(t)
  t.map_cb = function(h)h.bgcolor = props["layout.txtbgcolor"] end
  return iup.flatbutton(t)
end

local function bgb_find(t)
    t.map_cb = function(h) h.bgcolor = props["layout.txtbgcolor"] end
    t.fgcolor = props["layout.txtfgcolor"]
    return iup.backgroundbox(t)
end

local fmark = _T'Search Mark'
local tMarks = {
    CORE.InidcFactory('Find.Mark.1', fmark..' 1', INDIC_ROUNDBOX, 16711884, 50),
    CORE.InidcFactory('Find.Mark.2', fmark..' 2', INDIC_ROUNDBOX, 16711680, 50),
    CORE.InidcFactory('Find.Mark.3', fmark..' 3', INDIC_ROUNDBOX, 65280, 50),
    CORE.InidcFactory('Find.Mark.4', fmark..' 4', INDIC_ROUNDBOX, 65535, 100),
    CORE.InidcFactory('Find.Mark.5', fmark..' 5', INDIC_ROUNDBOX, 16768273, 50),
    CORE.InidcFactory('Find.Mark.6', fmark..' 6', INDIC_ROUNDBOX, 494591, 50),
}

function CORE.SetFindMarkers()
    local function SetFMTo(e)
        e:MarkerDefine(5, SC_MARK_BOOKMARK)
        e.MarkerBack[5] = 16711884
        e:MarkerDefine(6, SC_MARK_BOOKMARK)
        e.MarkerBack[6] = 16711680
        e:MarkerDefine(7, SC_MARK_BOOKMARK)
        e.MarkerBack[7] = 65280
        e:MarkerDefine(8, SC_MARK_BOOKMARK)
        e.MarkerBack[8] = 65535
        e:MarkerDefine(9, SC_MARK_BOOKMARK)
        e.MarkerBack[9] = 16768273
        e:MarkerDefine(10, SC_MARK_EMPTY)
        e.MarkerBack[10] = CORE.Str2Rgb('255 127 0')
    end
    local function addSBColors(sb, side)
        iup.SetAttributeId2(sb, "COLORID", 2, -1, "")
        iup.SetAttributeId2(sb, "COLORID", 2, 5, CORE.Rgb2Str(16711884))
        iup.SetAttributeId2(sb, "COLORID", 2, 6, CORE.Rgb2Str(16711680))
        iup.SetAttributeId2(sb, "COLORID", 2, 7, CORE.Rgb2Str(65280))
        iup.SetAttributeId2(sb, "COLORID", 2, 8, CORE.Rgb2Str(65535))
        iup.SetAttributeId2(sb, "COLORID", 2, 9, CORE.Rgb2Str(16768273))
        iup.SetAttributeId2(sb, "COLORID", 2, 10, CORE.Rgb2Str(494591))

    end

    if props['findreplmarkers.set'] ~= '1' then
        props['findreplmarkers.set'] = '1'
        SetFMTo(editor)
        SetFMTo(coeditor)
    end
    addSBColors(iup.GetDialogChild(iup.GetLayout(), 'Source'), 1)
    addSBColors(iup.GetDialogChild(iup.GetLayout(), 'CoSource'), 2)
end

local findSettings = seacher{}

local function Ctrl(s)
    return iup.GetDialogChild(containers[2],s)
end

local function PrepareFindText(s)
    s = (s or ''):gsub('[\n\r]+$', '')
    if s:find('[\n\r]') then
        return ''
    elseif (Ctrl("chkRegExp").value == "ON" and Ctrl("chkRegExp").active == "YES") or (Ctrl("chkBackslash").value == "ON" and Ctrl("chkBackslash").active == "YES") then
        return s:gsub('\\', '\\\\'):gsub('\t', '\\t')
    else
        return s
    end
end

local function SetInfo(msg, chColor)
    local strColor
    if chColor == 'E' then strColor = "255 0 0"
    elseif chColor == 'W' then strColor = "255 0 0"
    else strColor = "0 0 255" end
    Ctrl('lblInfo').title = msg
    Ctrl('lblInfo').fgcolor = strColor
end

local cv = (function(s) return iup.GetDialogChild(containers[2],s).value end)

local function ReadSettings(bScipCheckRegEx)
    if cv("cmbReplaceWhat"):find('[\r\n]') then
        iup.GetDialogChild(containers[2], "cmbReplaceWhat").value = select(3, cv("cmbReplaceWhat"):find('^([^\r\n]*)'))
    end
    findSettings:Reset{
        wholeWord = (cv("chkWholeWord") == "ON")
        ,matchCase = (cv("chkMatchCase") == "ON")
        ,wrapFind = (cv("chkWrapFind") == "ON")
        ,backslash = (cv("chkBackslash") == "ON")
        ,regExp = (cv("chkRegExp") == "ON")
        ,style = Iif(cv("chkInStyle") == "ON",math.tointeger(cv("numStyle")),nil)
        ,searchUp = (containers["zUpDown"].valuepos == "0")
        ,findWhat = self:encode(cv("cmbFindWhat"))
        ,replaceWhat = self:encode(cv("cmbReplaceWhat"))
    }
    if Ctrl("chkRegExp").value == 'ON' then
        local err = scite.CheckRegexp(Ctrl("cmbFindWhat").value)
        if err then
            if not bScipCheckRegEx then
                print(err)
                SetInfo('regex_error', 'E')
            end
            return true
        end
    end
    if cv("chkInStyle") == "ON" and Ctrl("chkInStyle") == 'YES' then
        local prLine = editor:LineFromPosition(editor.CurrentPos)
        local fLine = editor.FirstVisibleLine
        editor:DocumentEnd()
        editor:LineScroll(1, fLine)
        editor:GotoLine(prLine)
    end
end


local prev_KF = nil
local function live_killFocus(h)
    local a = findres:findtext('^</\\', SCFIND_REGEXP, 0)
    if a then
        findres.TargetStart = a
        findres.TargetEnd = a + 3
        findres:ReplaceTarget('<')
    end
    if prev_KF then prev_KF(h) end
    h.killfocus_cb = prev_KF
    prev_KF = nil
end
local function Find_onTimer(h)
    h.run = "NO"
    local a = findres:findtext('^</\\', SCFIND_REGEXP, 0)
    if a then
        findres.TargetStart = 0
        findres.TargetEnd = findres.LineEndPosition[findres:LineFromPosition(a)]+1
        findres:ReplaceTarget('')
    end
    findSettings:FindAll(50, true)
    if not prev_KF then
        prev_KF = Ctrl('cmbFindWhat').killfocus_cb
        Ctrl('cmbFindWhat').killfocus_cb = live_killFocus
    end
end
local tm = iup.timer{time = 300, run = 'NO', action_cb = Find_onTimer}

local tmr

function CORE.ClearLiveFindMrk()
    EditorClearMarks(tMarks[6])
    editor:MarkerDeleteAll(10);
end

function CORE.FindMarkAll(fnd, maxlines, bLive, bMark)
    CORE.ClearLiveFindMrk()
    bMark = bMark and Ctrl("chkMarkSearch").value == 'ON'
    fnd:FindAll(maxlines, bLive, false, Iif(bMark, 10, nil), Iif(bMark , tMarks[6], nil))
end

local function FindMark_onTimer()
    CORE.ClearLiveFindMrk()
    tmr.run="NO"
    if Ctrl("chkMarkSearch").value ~= 'ON' then return end
    if ReadSettings(true) then return end
    findSettings:MarkAll(false, tMarks[6], 10)
end

tmr = iup.timer{time = 300, run = 'NO', action_cb = FindMark_onTimer}

local function onFindEdit(h, c, new_value)

    local res = nil
    if new_value:find('[\n\r]') then
        h.value = PrepareFindText(new_value)
        res = iup.IGNORE
    end
    findSettings.findWhat = new_value
    if Ctrl('byInput').value == 'ON' and Ctrl("tabFindRepl").valuepos == '0' and not ReadSettings() then
        if Ctrl('byInputAll').value == 'ON' then
            tm.run = "NO"
            tm.run = "YES"
        else
            OnNavigation("Find")
            local pos = findSettings:FindNext(true)
            OnNavigation("Find-")
            if pos < 0 then SetInfo(_T'Nothing Found', 'E')
            else SetInfo('', '') end
        end
    end
    tmr.run = "NO"
    tmr.run = "YES"

    return res
end

--Хендлеры контролов диалога
local function PostAction(bForce)
    if (_G.dialogs['findrepl'] and Ctrl("zPin").valuepos == '1' and Ctrl("chkPassFocus").value == 'ON') or bForce then
        popUpFind.show_cb(popUpFind,4)
        popUpFind.close_cb(popUpFind)
    end
end

local function PassFocus_local(scp)
    -- if Ctrl("chkPassFocus").value == 'ON' or (_G.dialogs['findrepl'] and Ctrl("zPin").valuepos == '1') then
    if Ctrl("chkPassFocus").value == 'ON' then
        if _G.iuprops['findrepl.win'] == '0' then CORE.ScipHidePannel(1 + (scp or 0)) end
        iup.PassFocus()
    end
end

local function CloseFind()
    if _G.dialogs['findrepl'] then
        popUpFind.close_cb(popUpFind)
    end
end

local function ReplaceAll(h)
    if ReadSettings() then return end
    local count = findSettings:ReplaceAll(false)
    SetInfo(_T'Replacements: '..count, Iif(count == 0, 'E', ''))
    Ctrl("cmbFindWhat"):SaveHist()
    Ctrl("cmbReplaceWhat"):SaveHist()
    PassFocus_local()
    PostAction()
end


local function ReplaceSel(h)
    if ReadSettings() then return end
    local count = findSettings:ReplaceAll(true)
    SetInfo(_T'Replacements: '..count, Iif(count == 0, 'E', ''))
    Ctrl("cmbFindWhat"):SaveHist()
    Ctrl("cmbReplaceWhat"):SaveHist()
    PassFocus_local()
    PostAction()
end

local function FindSel(h)
    if ReadSettings() then return end
    local count = findSettings:FindAll(nil, false, true)
    SetInfo(_T'Found: '..count, Iif(count == 0, 'E', ''))
    Ctrl("cmbFindWhat"):SaveHist()
    PassFocus_local()
    PostAction()
end

local function CheckBottomBar()
    if _G.iuprops['findrepl.win'] ~= '0' or _Plugins.findrepl.Bar_obj then CORE.BottomBarSwitch('NO') end
end

local function FindAll(h)
    if ReadSettings() then return end
    local count = findSettings:FindAll(nil, false)
    SetInfo(_T'Found: '..count, Iif(count == 0, 'E', ''))
    Ctrl("cmbFindWhat"):SaveHist()
    PassFocus_local(1)
    PostAction()
    CheckBottomBar()
end

local function GetCount(h)
    if ReadSettings() then return end
    local count = findSettings:Count()
    SetInfo(_T'Found: '..count, Iif(count == 0, 'E', ''))
    Ctrl("cmbFindWhat"):SaveHist()
    PassFocus_local()
end

local function FindNext(h)
    if ReadSettings() then return end
    OnNavigation("Find")
    local pos = findSettings:FindNext(true)
    OnNavigation("Find-")
    if pos < 0 then SetInfo(_T'Nothing Found', 'E')
    else SetInfo('', '') end
    Ctrl("cmbFindWhat"):SaveHist()
    PassFocus_local()
    if Ctrl('tabFindRepl').valuepos == '0' then PostAction() end
end

function CORE.ReplaceNext(h)
    if ReadSettings() then return end
    SetInfo('', '')
    OnNavigation("Repl")
    local pos = findSettings:ReplaceOnce()
    OnNavigation("Repl-")
    if not pos then SetInfo(_T'Found an entry "'..Ctrl("cmbFindWhat").value..'"', '') return end

    if pos < 0 then SetInfo(_T'Nothing Found', 'E')
    else SetInfo(_T'Replacement done', 'E') end

    Ctrl("cmbFindWhat"):SaveHist()
    Ctrl("cmbReplaceWhat"):SaveHist()
    PassFocus_local()
    PostAction()
end

local function MarkAll(h)
    if ReadSettings() then return end
    local clrStr = math.tointeger(Ctrl("matrixlistColor").focusitem)
    local count = findSettings:MarkAll(Ctrl("chkMarkInSelection").value == "ON", tMarks[clrStr], clrStr + 4)
    SetInfo(_T'Marked: '..count, Iif(count == 0, 'E', ''))
    Ctrl("cmbFindWhat"):SaveHist()
    PassFocus_local()
end

local function ClearMark(h)
    editor:MarkerDeleteAll(math.tointeger(Ctrl("matrixlistColor").focusitem) + 4)
    EditorClearMarks(tMarks[math.tointeger(Ctrl("matrixlistColor").focusitem)])
end

local function ClearMarkAll(h)
    for i = 1, 5 do
        editor:MarkerDeleteAll(i + 4)
        EditorClearMarks(tMarks[i])
    end
end

local function BookmarkAll(h)
    if ReadSettings() then return end
    local count = findSettings:BookmarkAll(Ctrl("chkMarkInSelection").value == "ON")
    SetInfo(_T'Marked: '..count, Iif(count == 0, 'E', ''))
    Ctrl("cmbFindWhat"):SaveHist()
    PassFocus_local()
    PostAction()
end

local function FindInFiles()
    if ReadSettings() then return end

    if Ctrl("cmbFindWhat").value == '' then return end

    if Ctrl("cmbFilter").value == '' then Ctrl("cmbFilter").value = '*.*' end
    if Ctrl("cmbFolders").value == '' then Ctrl("cmbFolders").value = props['FileDir'] end
    local fWhat = Ctrl("cmbFindWhat").value
    local fFilter = Ctrl("cmbFilter").value
    local fDir = Ctrl("cmbFolders").value
    local params = Iif(Ctrl("chkWholeWord").value=='ON', 'w','~')..
                   Iif(Ctrl("chkMatchCase").value=='ON', 'c','~')..'~'..
                   Iif(Ctrl("chkRegExp").value=='ON', 'r','~')..
                   Iif(Ctrl("chkSubFolders").value=='ON', 's','~')..
                   Iif(_G.iuprops['findres.groupbyfile'], 'g', '~')..
                   Iif(Ctrl("chkFindProgress").value=='ON', 'p', '~')
    SetInfo('', '')
    scite.PerformGrepEx(params, fWhat, fDir, fFilter)

    Ctrl("cmbFindWhat"):SaveHist()
    Ctrl("cmbFolders"):SaveHist()
    Ctrl("cmbFilter"):SaveHist()
    Ctrl("btnFindInFiles").image = "cross_script_µ"
    iup.Update(Ctrl("btnFindInFiles"))
    PassFocus_local(1)
    PostAction()
    if Ctrl("chkFindProgress").value == 'ON' then
        Ctrl("progress").max = 100
        Ctrl("progress").value = 0
        Ctrl("progress").text = _T'Count...'
        Ctrl("zbProgress").valuepos = 1
    end
    CheckBottomBar()
end

local function ReplaceInBuffers()
    if ReadSettings() then return end
    local count = DoForBuffers_Stack(findSettings:ReplaceInBufer())
    SetInfo(_T'Replacements: '..count, Iif(count == 0, 'E', ''))
    Ctrl("cmbReplaceWhat"):SaveHist()
    Ctrl("cmbFindWhat"):SaveHist()
    PassFocus_local()
    PostAction()
end

local function FindInBuffers()
    if ReadSettings() then return end
    findSettings:CollapseFindRez()
    local count = DoForBuffers_Stack(findSettings:FindInBufer(), 100)
    SetInfo(_T'Found: '..count, Iif(count == 0, 'E', ''))
    Ctrl("cmbFindWhat"):SaveHist()
    PassFocus_local()
    PostAction()
    CheckBottomBar()
end

local function GoToMarkDown()
    local iPos = editor.SelectionStart
    local mark = tMarks[tonumber(Ctrl("matrixlistColor").focusitem)]
    local nextStart = iPos
    local bMark = false
    iPos = editor:IndicatorEnd(mark, nextStart)
    if iPos >= editor.TextLength then iPos = editor:IndicatorEnd(mark, 0) end
    if iPos < editor.TextLength and iPos ~= nextStart then
        nextStart = editor:IndicatorEnd(mark, iPos)
        if nextStart > 0 then
            OnNavigation("Mark")
            editor:SetSel(nextStart, nextStart+1)
            OnNavigation("Mark-")
            bMark = true
        end
    end
    SetInfo(Iif(bMark, '', _T'Marks not Found'), Iif(bMark, '', 'E'))
end
local function GoToMarkUp()
    local curPos = editor.SelectionStart
    local iPos = 0
    local mark = tMarks[tonumber(Ctrl("matrixlistColor").focusitem)]
    local nextStart = iPos
    local bMark = false
    iPos = editor:IndicatorEnd(mark, nextStart)
    if iPos >= curPos then
        iPos = editor:IndicatorEnd(mark, curPos)
        curPos = editor.TextLength
    end
    if iPos < editor.TextLength and iPos ~= nextStart then
        nextStart = editor:IndicatorEnd(mark, iPos)
        local prevPos = iPos
        while iPos < curPos do
            prevPos = iPos
            iPos = editor:IndicatorEnd(mark, nextStart)
            if iPos >= editor.TextLength or iPos == nextStart then break end

            nextStart = editor:IndicatorEnd(mark, iPos)
        end
        OnNavigation("Mark")
        editor:SetSel(prevPos - 1, prevPos)
        OnNavigation("Mark-")
        bMark = true
    end
    SetInfo(Iif(bMark, '', _T'Marks not Found'), Iif(bMark, '', 'E'))
end

local function SetStaticControls()
    local notInFiles = (Ctrl("tabFindRepl").valuepos ~= '2')
    local notRE = (Ctrl("chkRegExp").value == 'OFF')
    local notBS = (Ctrl("chkBackslash").value == 'OFF') or not notInFiles
    local notWW = (Ctrl("chkWholeWord").value == 'OFF')

    if (not notBS) and (not notRE) then
        Ctrl("chkBackslash").value = 'OFF'
        notBS = true
    end

    if (not notWW) and (not notRE) then
        Ctrl("chkWholeWord").value = 'OFF'
        notWW = true
    end
    Ctrl("numStyle").active = Iif(Ctrl("chkInStyle").value == 'ON' and notInFiles, 'YES', 'NO')
    Ctrl("chkInStyle").active = Iif(notInFiles, 'YES', 'NO')
    Ctrl("chkWrapFind").active = Iif(notInFiles, 'YES', 'NO')
    Ctrl("chkWholeWord").active = Iif(notRE, 'YES', 'NO')
    Ctrl("chkRegExp").active = Iif(notBS and notWW, 'YES', 'NO')
    Ctrl("chkBackslash").active = Iif(notInFiles and notRE, 'YES', 'NO')
    Ctrl("btnArrowUp").active = Iif(notInFiles, 'YES', 'NO')
    Ctrl("btnArrowDown").active = Iif(notInFiles, 'YES', 'NO')
    Ctrl("byInputAll").visible = Iif(Ctrl('byInput').value == 'ON', 'YES', 'NO')
    oDeattFnd.onSetStaticControls()
end

local function onMapMColorList(h)
    for i = 1, 5 do
        h["color"..i] = CORE.EditMarkColor(tMarks[i])
    end
end

local function DefaultAction()
    local nT = Ctrl("tabFindRepl").valuepos
    if nT == '0' then FindNext()
    elseif nT == '1' then CORE.ReplaceNext()
    elseif nT == '2' then  FindInFiles()
    elseif nT == '3' then  MarkAll()
    end
end

local function SetFolder()
    local d = iup.filedlg{dialogtype='DIR', parentdialog='SCITE',directory=Ctrl("cmbFolders").value}
    d:popup()
    if d.status ~= '-1' then Ctrl("cmbFolders").value = d.value end
    d:destroy()
end
local function FolderUp()
    Ctrl("cmbFolders").value = Ctrl("cmbFolders").value:gsub('^(.*)\\[^\\]+\\?$','%1')
end

--перехватчики команд меню
local function ActivateFind_l(nTab, s)

    if nTab < 0 then nTab = Ctrl("tabFindRepl").valuepos end
    Ctrl("tabFindRepl").valuepos = nTab

    local wnd = editor
    if output.Focus then wnd = output
    elseif findres.Focus then wnd = findres end

    SetStaticControls()

    if not s then
        if wnd.SelectionStart == wnd.SelectionEnd then s = GetCurrentWord()
        else s = wnd:GetSelText() end
    end
    if wnd.CodePage == 0 then s = s:to_utf8() end
    s = PrepareFindText(s)
    if s ~= '' then Ctrl("cmbFindWhat").value = s end
    local spl = iup.GetDialogChild(iup.GetLayout(), "BottomBarSplit")
    if _G.dialogs['findrepl'] then
        if (tonumber(spl.barsize) == 0 and ((_G.iuprops['bottombar.layout'] or 700500) % 10000 ~= 1000) and _G.iuprops['findrepl.win'] == '2') then
            scite.MenuCommand(IDM_TOGGLEOUTPUT)
        else
            _G.dialogs['findrepl'].ShowDialog()
        end
    elseif _Plugins.findrepl.Bar_obj then
        local tabCtrl = _Plugins.findrepl.Bar_obj.TabCtrl
        local ind
        for i = 0, tabCtrl.count - 1 do
            if iup.GetAttributeId(tabCtrl, "TABTITLE", i) == _Plugins.findrepl.id then ind = i; break end
        end

        tabCtrl.valuepos = ind; _Plugins.functions.OnSwitchFile()
        if _G.iuprops[_Plugins.findrepl.Bar_obj.sciteid..'.win'] == '2' then
            _Plugins.findrepl.Bar_obj.handle.ShowDialog()
        elseif _G.iuprops[_Plugins.findrepl.Bar_obj.sciteid..'.win'] == '3' then
            local s = _Plugins.findrepl.Bar_obj.handle.Split_h()
            if s then s.hidden = "NO" end
        end
    elseif spl.popupside  ~= '0' then
        scite.MenuCommand(IDM_TOGGLEOUTPUT)
    end

    if nTab ~= 2 then Ctrl("numStyle").value = wnd.StyleAt[wnd.SelectionStart];  end

    if s ~= '' and nTab == 1 then iup.SetFocus(Ctrl('cmbReplaceWhat'))
    else iup.SetFocus(Ctrl('cmbFindWhat')) end

    if nTab == 2 then Ctrl('cmbFolders').value = props['FileDir'] end

    if Ctrl('byInput').value == 'ON' and Ctrl('byInputAll').value == 'ON' then onFindEdit(Ctrl("cmbFindWhat"), '', Ctrl("cmbFindWhat").value) end

    onFindEdit(Ctrl('cmbFindWhat'), c, Ctrl("cmbFindWhat").value)
    return true
end

function CORE.ActivateFindDialog(s, nTab)
    ActivateFind_l(nTab or 0, s)
end

local function FindNextSel(bUp)
    if editor:LineFromPosition(editor.SelectionStart) == editor:LineFromPosition(editor.SelectionEnd) then
        str = editor:GetSelText()
        if str ~= '' then
            local prevUp = findSettings.searchUp
            ActivateFind_l(0)

            if ReadSettings() then return end
            OnNavigation("Find")
            findSettings.searchUp = bUp
            local pos = findSettings:FindNext(true)
            OnNavigation("Find-")
            if pos < 0 then SetInfo(_T'Nothing Found', 'E')
            else SetInfo('', '') end
            Ctrl("cmbFindWhat"):SaveHist()

            findSettings.searchUp = prevUp
        end
    end
    return true
end

local function FindNextBack(bUp)
    if not findSettings.findWhat then ReadSettings() end
    if findSettings.findWhat == '' then return false end
    iup.PassFocus()
    local prevUp = findSettings.searchUp
    findSettings.searchUp = bUp
    OnNavigation("Find")
    local pos = findSettings:FindNext(true)
    OnNavigation("Find-")
    if pos < 0 then print("Error: '"..findSettings.findWhat.."' not found") end
    findSettings.searchUp = prevUp
    return pos >= 0
end

local function PassOrClose()
    if _G.dialogs['findrepl'] and (Ctrl("zPin").valuepos == '1' or Ctrl("chkCloseOnESC").value == 'ON') then
        PostAction(true)
    else
        iup.PassFocus()
    end
end

local function kf_cb(h)

    if _G.dialogs['findrepl'] and Ctrl("chkTransparency").value == 'ON' and Ctrl("chkTranspFocus").value == 'ON' then
        local tmr = iup.timer{time = 10; action_cb = function(h)
            h.run = 'NO'
            local hc = iup.GetFocus()
            while hc do
                if hc == _G.dialogs['findrepl'] then return end
                hc = iup.GetParent(hc)
            end
            if _G.dialogs['findrepl'] then popUpFind.opacity = _G.iuprops['settings.findrepl.opacity'] or 200 end
        end}
        tmr.run = "YES"
    end
end

--создание диалога

local function create_dialog_FindReplace()
  containers = {}
  containers["zPin"] = iup.zbox{
    iup.flatbutton{
      impress = "IMAGE_Pin",
      visible = "NO",
      image = "IMAGE_PinPush",
      --size = "11x9",
      canfocus  = "NO",
      flat_action = (function(h) containers["zPin"].valuepos = "1" end),
    },
    iup.flatbutton{
      impress = "IMAGE_PinPush",
      visible = "NO",
      image = "IMAGE_Pin",
      canfocus  = "NO",
      --size = "11x9",
      flat_action = (function(h) containers["zPin"].valuepos = "0" end),
      },
    name = "zPin",
  }
  containers[4] = iup.hbox{
    iup.label{
      title = _T"Find:",
    },
    iup.list{
      name = "cmbFindWhat",
      expand = "HORIZONTAL",
      rastersize = "1x0",
      editbox = "YES",
      dropdown = "YES",
      visibleitems = "18",
      --edit_cb = onFindEdit,
      valuechanged_cb = function(h) onFindEdit(h, nil, h.value) end,
      k_any = (function(_,c) if c..'' == iup.K_PGUP..'' then FolderUp() return iup.IGNORE; elseif c == iup.K_CR then DefaultAction() elseif c == iup.K_ESC then PassOrClose() end; end),
    },
    containers["zPin"],
    iup.flatbutton{           ------------
      name = "BtnOK",
      flat_action = DefAction,
      fontsize = 1, margin = '0x0',
      visible = 'NO'
    },
    margin = "0x00",
    expand = "HORIZONTAL",
    alignment = "ACENTER",

  }

  containers[3] = iup.flatframe{
    containers[4],
    expand = "HORIZONTAL",
    rastersize = "372x29",
    framecolor = iup.GetLayout().bordercolor,
  }

  containers[32] = iup.vbox{
    fb_find{
      image = "IMAGE_search",
      title = _T" next",
      name = "btnFind",
      flat_action = FindNext,
      padding = "5x0"
    },
    fb_find{
      title = _T"Find All",
      flat_action = FindAll,
    },
    margin = "6x6",
    normalizesize = "HORIZONTAL",
  }

  containers[7] = iup.vbox{
    iup.hbox{
        margin = "0x0",
        alignment = 'ACENTER',
        fb_find{
          flat_action = CloseFind,
          name = 'btn_esc',
          size = '1x1',
        },
        iup.hi_toggle{
            name = 'byInput',
            title = _T'While User Input',
            flat_action = SetStaticControls,
            ctrl = true,
        },
        iup.hi_toggle{
            name = 'byInputAll',
            title = _T' - all',
            ctrl = true,
        },
    },
    iup.hbox{
      fb_find{
        padding = "3x",
        title = _T"In Selection",
        flat_action = FindSel,
      },
      fb_find{
        padding = "3x",
        title = _T"In Open Files",
        flat_action = FindInBuffers,
      },
      fb_find{
        padding = "3x",
        title = _T"Count",
        flat_action = GetCount,
      },
      --normalizesize = "HORIZONTAL",
      gap = "3",
      alignment = "ABOTTOM",
      margin = "0x2",
      expand = "VERTICAL",
       margin = "0x0",
    },
      gap = "4",
      margin = "0x6",
      normalizesize = "VERTICAL",
  }

  containers[6] = bgb_find{iup.hbox{
    containers[32],
    containers[7],
    expandchildren = "YES",
  }}

  containers[13] = iup.vbox{
    fb_find{
      title = _T" to:",
      image = "IMAGE_Replace",
      flat_action = CORE.ReplaceNext,
      canfocus = "NO",
      padding = "x2",
    },
    fb_find{
      image = "IMAGE_search",
      title = _T" next",
      padding = "5x3",
      flat_action = FindNext,
      canfocus  = "NO",
    },
    normalizesize = "HORIZONTAL",
  }

  containers[15] = iup.hbox{
    fb_find{
      padding = "3x",
      title = _T"Replace All",
      flat_action = ReplaceAll,
    },
    fb_find{
      padding = "3x",
      title = _T"In Selection",
      flat_action = ReplaceSel,
    },
    fb_find{
      padding = "3x",
      title = _T"In Open Files",
      flat_action = ReplaceInBuffers,
    },
    margin = "0x00",
  }

  containers[14] = iup.vbox{
    iup.list{
      name = "cmbReplaceWhat",
      expand = "HORIZONTAL",
      rastersize = "1x0",
      editbox = "YES",
      dropdown = "YES",
      edit_cb=(function(h, c, new_value) if new_value:find('[\n\r\t]') then _,_,h.value = new_value:find('^([^\n\r\t]*)')return -1 end end),
      visibleitems = "18",
    },
    containers[15],
    alignment = "ARIGHT",
  }

  containers[12] = iup.hbox{
    containers[13],
    containers[14],
    normalizesize = "VERTICAL",
    gap = "3",
    alignment = "ACENTER",
  }

  containers[11] = bgb_find{iup.vbox{
    containers[12],
    gap = "4"
  }}

  containers[17] = iup.hbox{
    iup.label{
      title = _T"In Folder:",
    },
    iup.list{
      name = "cmbFolders",
      expand = "HORIZONTAL",
      rastersize = "1x0",
      editbox = "YES",
      dropdown = "YES",
      visibleitems = "18",
    },
    fb_find{
      image = "IMAGE_ArrowUp",
      flat_action = FolderUp,
      tip = _T"Level Up\n(Press 'PgUp' in the line)",
    },
    fb_find{
      image = "IMAGE_Folder",
      flat_action = SetFolder,
      tip = _T"Change Folder",
    },
    gap = "3",
    alignment = "ACENTER",
    margin = "0x2",
  }

  containers[18] = iup.hbox{
    iup.label{
      size = "31x8",
      title = _T"File Mask:",
    },
    iup.list{
      name = "cmbFilter",
      expand = "HORIZONTAL",
      rastersize = "1x0",
      editbox = "YES",
      dropdown = "YES",
      visibleitems = "18",
    },
    iup.hi_toggle{
      name = "chkSubFolders",
      title = _T"In Subfolders",
      ctrl = true,
    },
    fb_find{
      name = 'btnFindInFiles',
      image = "IMAGE_search",
      padding = "14x0",
      flat_action = FindInFiles,
      tip = _T"Find in Files",
    },
    alignment = "ACENTER",
    margin = "0x00",
    name = "hboxFind"
  }

  containers[16] = bgb_find{iup.vbox{
    containers[17],
    containers[18],
    gap = "4"
  }}

  containers[21] = iup.hbox{
    fb_find{
      padding = "3x",
      title = _T"Mark",
      flat_action = MarkAll,
    },
    fb_find{
      padding = "3x",
      title = _T"Delete",
      flat_action = ClearMark,
    },
    fb_find{
      padding = "3x",
      title = _T"Delete All",
      flat_action = ClearMarkAll,
      padding = "2",
    },
    --normalizesize = "HORIZONTAL",
    margin = "0x00",
  }
  containers[22] = iup.hbox{
    iup.hi_toggle{
      padding = "3x",
      title = _T"In Selection",
      name = "chkMarkInSelection",
      ctrl = true,
    },
    fb_find{
      padding = "3x",
      title = _T"*** Bookmarks",
      flat_action = BookmarkAll,
    },
    gap = "4",
    alignment = "ACENTER",
    margin = "0x00",
  }

  containers[33] = iup.vbox{
    fb_find{
      padding = "x2",
      image = "IMAGE_ArrowUp",
      flat_action = GoToMarkUp,
      tip = _T"Previous Mark",
    },
    fb_find{
      padding = "x2",
      image = "IMAGE_ArrowDown",
      flat_action = GoToMarkDown,
      tip = _T"Next Mark",
    },
    margin = "0x3",
  }
  containers[31] = iup.vbox{
    containers[21],
    containers[22],
    margin = "0x3",
  }
  containers[30] = iup.vbox{
    iup.matrixlist{
      size = "53x0",
      expand = "NO",
      columnorder = "COLOR",
      frametitlehighlight = "No",
      ["rasterheight0"] = "0",
      ["rasterwidth0"] = "0",
      ["rasterwidth1"] = "40",
      hidefocus = "YES",
      numcol = "1",
      ["height0"] = "0",
      numlin = "5",
      heightdef = "5",
      flatscrollbar = "VERTICAL",
      count = "5",
      ["width0"] = "0",
      ["width1"] = "34",
      numlin_visible = "3",
      name="matrixlistColor",
      map_cb = onMapMColorList
    },

  }
  containers[29] = iup.hbox{
    containers[30],
    containers[31],
    containers[33],
    margin = "3x3",
  }
  containers[19] = bgb_find{iup.vbox{
      containers[29],
      margin = "0x00",
  }}
  local dialPrev = 0
  containers[34] = bgb_find{iup.vbox{expand='NO',
      iup.hbox{expand='HORIZONTAL',
          iup.hi_toggle{
              title = _T"Search in Files - Progressbar",
              ctrl = true,
          name = "chkFindProgress", },
          iup.fill{},
          iup.hi_toggle{
              title = _T"Mark when Search",
              ctrl = true,
          name = "chkMarkSearch" },
          margin = "0x0", padding = '0x0'
      };
      iup.hbox{expand = 'HORIZONTAL',
          iup.hi_toggle{
              title = _T"Return focus",
              ctrl = true,
          name = "chkPassFocus", },
          iup.fill{},
          iup.hi_toggle{
              title = _T"Close with ESC",
              ctrl = true,
          name = "chkCloseOnESC" },
          margin = "0x0", padding = '0x0'
      },
      iup.hbox{
          iup.hi_toggle{
              title = _T"Transparency",
              ctrl = true,
          name = "chkTransparency",
          flat_action = function(h)
              if _G.iuprops['findrepl.win'] ~= '0' and Ctrl("chkTranspFocus").value == 'OFF' then popUpFind.opacity = Iif(h.value == 'ON', _G.iuprops['settings.findrepl.opacity'] or 200, 255) end
          end
          },
          iup.dial{
              name = 'vTransparency',
              size = '45x8',
              unit = "DEGREES", density = "0.3",
              ctrl = true,
              valuechanged_cb = function(h)
                  if _G.iuprops['findrepl.win'] ~= '0' and Ctrl("chkTransparency").value == 'ON' then
                      local o = _G.iuprops['settings.findrepl.opacity'] or 200
                      if tonumber(h.value) < dialPrev and o >= 30 then o = o - 3
                      elseif tonumber(h.value) > dialPrev and o < 240 then o = o + 3 end
                      _G.iuprops['settings.findrepl.opacity'] = o
                      popUpFind.opacity = o
                      dialPrev = tonumber(h.value)
                  end
              end;
              getfocus_cb = function(h)
                  dialPrev = 0
              end;
          },
          iup.fill{},
          iup.hi_toggle{
              title = _T"When lost focus",
              name = "chkTranspFocus",
              ctrl = true,
              flat_action = function(h)
                  if _G.iuprops['findrepl.win'] ~= '0' and Ctrl("chkTransparency").value == 'ON' then popUpFind.opacity = Iif(h.value == 'OFF', _G.iuprops['settings.findrepl.opacity'] or 200, 255) end
              end
          },
           expand = "HORIZONTAL", margin = "0x0", padding = '0x0'
      }},

      margin = "10x5",

  }

  containers[5] = iup.flattabs{
    containers[6],
    containers[11],
    containers[16],
    containers[19],
    containers[34],
    ["tabtitle0"] = _T"Find",
    ["tabtitle1"] = _T"Replace",
    ["tabtitle2"] = _T"Find in Files",
    ["tabtitle3"] = _T"Mark",
    ["tabtitle4"] = _T"Preferences",
    canfocus  = "NO",
    name = "tabFindRepl",
    tabchange_cb = function(h)
        scite.RunAsync(SetStaticControls)
    end,
    forecolor = props['layout.txtfgcolor'],
    highcolor = props['layout.txthlcolor'],
    tabslinecolor = iup.GetLayout().bordercolor,
    tabspadding = '10x3',
    extrabuttons = 1,
    extraimage1 = "property_µ",
    extrapresscolor1 = props['layout.bgcolor'],
    bgcolor = props['layout.txtbgcolor'],
    tabsforecolor = props["layout.fgcolor"],
    extrabutton_cb = function(h, button, state) if state==1 then menuhandler:PopUp('MainWindowMenu|View|findrepl') end end
  }

  containers["zUpDown"] = iup.zbox{
    iup.flatbutton{
      impress = "IMAGE_ArrowDown",
      visible = "NO",
      image = "IMAGE_ArrowUp",
      size = "11x9",
      flat_action = (function(h) containers["zUpDown"].valuepos = "1" end),
      name = "btnArrowDown",
    },
    iup.flatbutton{
        impress = "IMAGE_ArrowUp",
        visible = "NO",
        image = "IMAGE_ArrowDown",
        size = "11x9",
        flat_action = (function(h) containers["zUpDown"].valuepos = "0" end),
        name = "btnArrowUp",
    },
    name = "zUpDown",
    bgcolor = iup.GetLayout().bgcolor,
    valuepos = "1",
  }

  containers["hUpDown"] = iup.hbox{
    containers["zUpDown"],
    iup.label{
      title = _T"Up / Down",
      button_cb = (function(_,but, pressed, x, y, status)
        if iup.isbutton1(status) and pressed == 0 and Ctrl('btnArrowUp').active == "YES" then
            containers["zUpDown"].valuepos = Iif(containers["zUpDown"].valuepos == '0', '1', '0')
        end
      end),
    },
    margin = "0x00",
    gap = "00",
  }

  containers[26] = iup.vbox{
    containers["hUpDown"],
    iup.hi_toggle{
      title = _T"Whole Word",
      name = "chkWholeWord",
      flat_action = SetStaticControls,
      map_cb = (function(h) h.value = _G["dialogs.findreplace."..h.name] end),
      ldestroy_cb = (function(h) _G["dialogs.findreplace."..h.name] = h.value end),
    },
    iup.hi_toggle{
      title = _T"Case Sensitive",
      name = "chkMatchCase",
    },
    iup.hi_toggle{
      title = _T"Wrap around",
      name = "chkWrapFind",
      value = "ON",
    },
  }

  containers[28] = iup.hbox{
    iup.hi_toggle{
      title = _T"This Style Only:",
      name = "chkInStyle",
      flat_action = SetStaticControls,
    },
    iup.text{
      mask = "[0-9]+",
      name = "numStyle",
      size = "22x10",
      font = "Segoe UI, 8",
    },
    margin = "0x00",
  }

  containers[27] = iup.vbox{
    iup.hi_toggle{
      title = "Backslash (\\n,\\r,\\t...)",
      name = "chkBackslash",
      flat_action = SetStaticControls,
    },
    iup.hi_toggle{
      title = _T"Regular expressions",
      name = "chkRegExp",
      flat_action = SetStaticControls,
    },
    containers[28],
    iup.zbox{ name = "zbProgress",
        iup.label{
            name = "lblInfo",
            expand = "HORIZONTAL",
        },
        iup.gauge{
        --iup.progressbar{
            name = "progress",
            expand = "HORIZONTAL",
            size = "x8",
            fgcolor = props["layout.borderhlcolor"],
            backcolor = props["layout.bgcolor"],
            flatcolor = props["layout.splittercolor"],
        },
    },
  }

  containers[25] = iup.hbox{
    containers[26],
    containers[27],
  }

  containers[24] = iup.flatframe{
    containers[25],
    framecolor = iup.GetLayout().bordercolor,
  }

  containers[23] = iup.hbox{
    containers[24],
    margin = "3x2",
  }

  containers[2] = iup.vbox{fontsize=iup.GetGlobal("DEFAULTFONTSIZE"),
    containers[3],
    containers[5],
    containers[23],
    margin = "3x3",
    expandchildren = "YES",
    gap = "3",
    name = 'vboxFindRepl',
  }

--[[  containers[1] = iup.dialog{
    containers[2],
    maxbox = "NO",
    minbox = "NO",
    minsize = "384x270",
    toolbox = "YES",
  }]]

  local function set_cb(cont)
      for i = 0, iup.GetChildCount(cont) - 1 do
          local c = iup.GetChild(cont, i)
          c.killfocus_cb = kf_cb
          if iup.GetChildCount(c) ~= 0 then
--[[              if not c.kikillfocus_cb then
              end
          else]]
              set_cb(c)
          end
      end
  end
  local dlg = containers[2]
  set_cb(dlg)

  return containers[2]
end

function CORE.FindNextBack(arg)
    ReadSettings()
    return FindNextBack(arg)
end

local function Init(h)
    _Plugins = h
    CORE.ActivateFind = ActivateFind_l --глобальная ссылка на нашу функцию
    bBlock4reload = false
    AddEventHandler("OnScriptReload", function(bSave, t) bBlock4reload = bSave end)

    oDeattFnd = iup.scitedetachbox{
        create_dialog_FindReplace();
        orientation="HORIZONTAL";barsize=5;minsize="100x100";name="FindReplDetach";defaultesc="FIND_BTN_ESC";
        k_any= (function(h,c) if c == iup.K_CR then DefaultAction() elseif c == iup.K_ESC then PassOrClose() end end),
        sciteid = 'findrepl';  Dlg_Title = _T"Find Replace"; expand = 'HORIZONTAL'; buttonImage = 'IMAGE_search';
        On_Detach = (function(h, hNew, x, y)
            iup.SetHandle("FIND_BTN_ESC",Ctrl('btn_esc'))
            local hMainLayout = iup.GetLayout()
             if not _Plugins.findrepl.Bar_obj then
                _G.iuprops['sidebarctrl.BottomSplit2.value'] = iup.GetDialogChild(hMainLayout, "BottomSplit2").value
                iup.GetDialogChild(hMainLayout, "BottomSplit2").barsize="0"
                iup.GetDialogChild(hMainLayout, "BottomSplit2").value="1000"
            else
                iup.GetDialogChild(hMainLayout, "FinReplExp").state="CLOSE";
            end
            popUpFind = hNew
            popUpFind.getfocus_cb = function() if Ctrl("chkTranspFocus").value == 'ON' then popUpFind.opacity = 255 end end
            popUpFind.opacity = Iif(Ctrl("chkTransparency").value == 'ON' and Ctrl("chkTranspFocus").value == 'OFF', _G.iuprops['settings.findrepl.opacity'] or 200, 255)
        end);
        Dlg_Close_Cb = (function(h)
            local hMainLayout = iup.GetLayout()
            if not _Plugins.findrepl.Bar_obj then
                iup.GetDialogChild(hMainLayout, "BottomSplit2").value = _G.iuprops['sidebarctrl.BottomSplit2.value']
                iup.GetDialogChild(hMainLayout, "BottomSplit2").barsize="3"
            else
                iup.GetDialogChild(hMainLayout, "FinReplExp").state="OPEN";
            end
        end);
        Dlg_Show_Cb = function(h, state) scite.RunAsync(function() if(_G.g_session['LOADED'] and not bBlock4reload) then SetStaticControls() end end) end;
        focus_cb = function(h, f)
            if not _Plugins.findrepl.Bar_obj and CORE.curTopSplitter ~= "BottomBar" and iup.GetDialogChild(iup.GetLayout(), "BottomSplit2").barsize~="0" then
                local s = iup.GetDialogChild(iup.GetLayout(), "BottomBarSplit")
                if s.popupside ~= 0 then s.hidden = 'NO'; CORE.curTopSplitter = "BottomBar"  end
            elseif _Plugins.findrepl.Bar_obj and _Plugins.findrepl.Bar_obj.sciteid ~= CORE.curTopSplitter then
                local s = iup.GetDialogChild(iup.GetLayout(), _Plugins.findrepl.Bar_obj.splitter)
                if s.popupside ~= 0 then s.hidden = 'NO'; CORE.curTopSplitter = _Plugins.findrepl.Bar_obj.sciteid end
            end
        end;
        }
    local hboxPane = iup.GetDialogChild(oDeattFnd, 'findrepl_title_hbox')

    if hboxPane then
        local pin = Ctrl("zPin")
        iup.Detach(pin)
        iup.Insert(hboxPane, iup.GetDialogChild(oDeattFnd, "findrepl_title_btnattach"), pin)
    end

    iup.SetAttribute(oDeattFnd, 'SAVEPREFIX', 'findreplace')

    local bPrevBufSide = 0
    local res = {
        handle = iup.vbox{oDeattFnd, font = iup.GetGlobal("DEFAULTFONT")};
        OnMenuCommand = (function(msg)
            if msg == IDM_FIND then return ActivateFind_l(0)
            elseif msg == IDM_REPLACE then return ActivateFind_l(1)
            elseif msg == IDM_FINDINFILES then return ActivateFind_l(2)
            elseif msg == IDM_FINDNEXT then
                ReadSettings()
                FindNextBack(false)
                Ctrl("cmbFindWhat"):SaveHist()
                return true
            elseif msg == IDM_FINDNEXTBACK then
                ReadSettings()
                FindNextBack(true)
                Ctrl("cmbFindWhat"):SaveHist()
                return true
            elseif msg == IDM_FINDNEXTSEL then return FindNextSel(false)
            elseif msg == IDM_FINDNEXTBACKSEL then return FindNextSel(true)
            end
        end);
        tabs_OnSelect = (function()
            if _Plugins.findrepl.Bar_obj and _Plugins.findrepl.Bar_obj.TabCtrl.value_handle.tabtitle == _Plugins.findrepl.id and not _G.dialogs['findrepl'] then
                iup.SetFocus(Ctrl("cmbFindWhat"))
            end
        end);
        OnSwitchFile = function(file)
            if bPrevBufSide == scite.buffers.GetBufferSide(scite.buffers.GetCurrent()) then CORE.ClearLiveFindMrk() end
            bPrevBufSide = scite.buffers.GetBufferSide(scite.buffers.GetCurrent())
            end;
        }
    res.handle_deattach = oDeattFnd

    function OnFindProgress(state, iAll)
        if state == 0 then
            Ctrl("progress").max = iAll
            Ctrl("progress").value = 0
            Ctrl("progress").text = '0 from '..iAll
            Ctrl("zbProgress").valuepos = 1
        elseif state == 1 then
            Ctrl("progress").value = iAll
            Ctrl("progress").text = math.floor(iAll)..' from '..math.floor(tonumber(Ctrl("progress").max))
        elseif state == 2 then
            Ctrl("zbProgress").valuepos = 0
            Ctrl("btnFindInFiles").image = "IMAGE_search"
            iup.Update(Ctrl("btnFindInFiles"))
            findSettings:MarkResult()
        end
    end

    AddEventHandler("OnInitHildiM", function() scite.RunAsync(CORE.SetFindMarkers); SetStaticControls() end)

    return res
end
g_Ctrl = Ctrl
return {
    title = 'Find Replace Dialog',
    code = 'findrepl',
    sidebar = Init,
    fixedheigth = true,
    description = [[Диалог поиска и замены. Если не подключить
ни к одной из панелей неиспользованных элементах
будет задочен в правом нижнем углу экрана]]
}


