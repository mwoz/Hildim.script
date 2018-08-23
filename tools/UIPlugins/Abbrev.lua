-- Version: 1.0
-- Author:
---------------------------------------------------
-- Description:
---------------------------------------------------
local list_abbrev, showPopUp, editMode
local bMenuMode = false
local bToolBar = false

local function Init()
    local text = props['CurrentSelection']
    local myId = "Abbrev/Bmk"

    local list_bookmarks
    local Abbreviations_USECALLTIPS = tonumber(props['sidebar.abbrev.calltip']) == 1
    local isEditor = false
    local prevLexer = -1
    local abbr_table
    local bListModified = false

    ABBREV = {}

    local function abrPath()
        if not editor.LexerLanguage then
            if editor_LexerLanguage():find('script_') then
                return props['SciteDefaultHome']..'\\abbrev\\'..editor_LexerLanguage()..'.abbrev'
            end
        end
        return props['AbbrevPath']
    end

    local function replAbbr(findSt, findEnd, s, dInd)

        s = s:gsub('%%CLIP(%d+)%%', function(i) if CLIPHISTORY then return CLIPHISTORY.GetClip(i) else return '' end end)
        local cnt = 0
        s = s:gsub('¶', function(i) cnt = cnt + 1; return Iif(cnt == 1, '¶', '') end )

        editor:AutoCCancel()
        editor:BeginUndoAction()
        editor:SetSel(findSt, findEnd)
        editor:ReplaceSel(s)
        local findEnd = editor.CurrentPos
        local l1, l2 = editor:LineFromPosition(findSt), editor:LineFromPosition(findEnd)

        for i = l1 + 1, l2 do
            local ind = editor.LineIndentation[i] + dInd
            editor.LineIndentation[i] = 0  --чтобы избавитьс€ от табов сначала сбрасываем отступ в 0 а потом выставл€ем нужный
            --если просто выставить нужный, и он при этом не изменитс€, табы могут остатьс€
            editor.LineIndentation[i] = ind
            findEnd = findEnd + dInd
        end

        local pos = editor:findtext('¶', 0, findSt, findEnd)

        if pos~= nil then
            editor:SetSel(findSt, findEnd)
            editor:SetSel(pos, pos + 1)
            editor:ReplaceSel('')
        end
        editor:EndUndoAction()
    end

    local function SetModif()
        bListModified = true
        list_abbrev:setcell(0, 1, 'Abbrev*')
        list_abbrev.redraw = 0
        abbr_table = {}
        for i = 1, list_abbrev.count - 1 do
            abbr_table[#abbr_table + 1] = {abbr = list_abbrev:getcell(i, 1), exp = list_abbrev:getcell(i, 2)}
        end
    end

    local function EditAbbrev(bNew)
        editMode = Iif(bNew, "NEW", "CHANGE")
        local abb, expan
        local l = list_getvaluenum(list_abbrev)
        if idx == -1 then
            abb, expan = 0, 0
        end
        abb, expan = list_abbrev:getcell(l, 1) or '', list_abbrev:getcell(l, 2) or ''

        local btn_upd = iup.button  {title = Iif(editMode == "CHANGE", "Update", "Insert")}
        iup.SetHandle("EDIT_BTN_UPD", btn_upd)
        local btn_esc = iup.button  {title = "Cancel"}
        iup.SetHandle("EDIT_BTN_ESC", btn_esc)

        local txt_exp = iup.text{multiline = 'YES', wordwrap = 'YES', expand = 'YES', fontsize = '12', value = expan:gsub('\\n', '\n'):gsub('\\r', ''):gsub('\\t', '\t'):gsub('ђ', '\\')}
        local txt_abr = iup.text{expand = 'NO', fontsize = '12', value = abb, size = '90x0'}

        local bCur = iup.flatbutton{title = ' ¶ Cursor', flat_action = function() txt_exp.insert = '¶' end}
        local bSC = iup.flatbutton{title = ' ЛЗЫ Sel/Clip', flat_action = function() txt_exp.insert = 'ЛЗЫ' end}
        local bTxt = iup.flatbutton{title = ' Л@1Ы Text', flat_action = function() txt_exp.insert = 'Л@1Ы' end}
        local bNum = iup.flatbutton{title = ' Л#1ЗЫ Numeric', flat_action = function() txt_exp.insert = 'Л#1З'..(txt_exp.selectedtext or '')..'Ы' end}
        local bChoise = iup.flatbutton{title = ' Л?1ЗЗЫ Choice', flat_action = function() txt_exp.insert = 'Л?1З'..(txt_exp.selectedtext or '')..'ЗЫ' end}
        local bForm = iup.flatbutton{title = ' Л...Ы Form', flat_action = function() txt_exp.append = [[Л
"Title",
nil,
"Boolean(0,1): %b\n"..
"Boolean: %b[No,Yes]\n"..
"Integer: %i[0,255]\n"..
"Sep1 %t\n"..
"String: %s\n"..
"Options-int: %o|item0|item1|item2|\n"..
"List-int: %l|item0|item1|item2|item3|item4|item5|item6|\n"..
"Options-int: %O|item0|item1|item2|\n"..
"List-int: %L|item0|item1|item2|item3|item4|item5|item6|\n",
0,0,0,'',0,0,0,0
Ы]] end}

local vbox = iup.vbox{
    iup.hbox{txt_abr, bCur, bSC, bTxt, bNum, bChoise, bForm, gap = '20'};
    iup.hbox{iup.vbox{txt_exp}};

    iup.hbox{btn_upd, iup.fill{}, btn_esc, expand = 'HORIZONTAL'},
expandchildren = 'YES', gap = 2, margin = "4x4"}                                    --[[txt_exp.insert = 'Л?1З'..'(txt_exp.selectedtext or '')'..'З.....Ы' ]]
local dlg = iup.scitedialog{vbox; title = "Edit Abbrev", defaultenter = "MOVE_BTN_OK", defaultesc = "MOVE_BTN_ESC", tabsize = editor.TabWidth,
maxbox = "NO", minbox = "NO", resize = "YES", shrink = "YES", sciteparent = "SCITE", sciteid = "abbreveditor", minsize = '600x300'}

dlg.show_cb =(function(h, state)
    if state == 4 then
        dlg:postdestroy()
        if bToolBar then showPopUp() end
    end
end)

function btn_upd:action()
    if editMode == 'CHANGE' then
        list_abbrev:setcell(l, 1, txt_abr.value)
        list_abbrev:setcell(l, 2, txt_exp.value:gsub('\\', 'ђ'):gsub('\r', '\\r'):gsub('\n', '\\n'):gsub('\t', '\\t'))
        list_abbrev.redraw = l
    else
        list_abbrev.addlin = ''..l
        list_abbrev:setcell(l + 1, 1, txt_abr.value)
        list_abbrev:setcell(l + 1, 2, txt_exp.value:gsub('\\', 'ђ'):gsub('\r', '\\r'):gsub('\n', '\\n'):gsub('\t', '\\t'))
        list_abbrev.redraw = l + 1
    end
    SetModif()
    dlg:postdestroy()
    if bToolBar then showPopUp() end
    editMode = nil
end

function btn_esc:action()
    dlg:postdestroy()
    if bToolBar then showPopUp() end
end

    end

    local function getParamProxy(...)
        local t = {}
        local arg = {...}
        local i = 1
        local newArg = ''
        if type(arg[3]) == 'string' then
            for p in arg[3]:gmatch("[^\n]+") do
                if p:find('%%L') or p:find('%%O') then
                    t[i] = {}
                    j = 0
                    for o in p:gmatch('[^|]+') do
                        t[i][j] = o
                        j = j + 1
                    end
                    p = p:gsub('%%L', '%%l'):gsub('%%O', '%%o')
                end
                i = i + 1
                newArg = newArg..p..'\n'
            end
            arg[3] = newArg
        end
        local strGp = 'return function(arg) return iup.GetParam('
        for i = 1,  #arg do
            strGp = strGp..Iif(i > 1, ', ', '')..'arg['..i..']'
        end
        strGp = strGp..') end'
        return t, assert(load(strGp))()(arg)
    end

    local function parseParamTemplate(findSt, findEnd, s, dInd, tMap, bContinue, ...)
        if not bContinue then return true end
        local nFind = 1
        local counter = 0
        local ballance = lpeg.P{ "Л" * ((1 - lpeg.S"ЛЫ") + lpeg.V(1))^0 * "Ы" }  --находит фрагмент со сбалансированными скобками
        local pYes = lpeg.C(lpeg.P{#lpeg.P('З') + (ballance + 1) * lpeg.V(1) })
        while true do
            local sBeg, pLong, sEnd = (lpeg.C((1 - lpeg.S"ЛЫ")^0) * lpeg.C(ballance) * lpeg.C(lpeg.P(1)^0)):match(s, 1)  --выводит часть до шаблона, шаблон и после
            --print(tPos1, tPos2)
            if not pLong then
                replAbbr(findSt, findEnd, s, dInd)
                return
            end

            local _, _, mark, nI = pLong:find('^Л([%@%#%?])(%d+)')
            local arg = table.pack(...)
            if not nI or tonumber(nI) > #arg then
                bContinue = false
                print("Error: "..pLong)
                return
            end
            nI = tonumber(nI)
            pLong = pLong:gsub('^..%d+', ''):gsub('Ы$', '')
            if mark == '@' then
                if tMap[nI] and tMap[nI][arg[nI] + 1] then
                    val = tMap[nI][arg[nI] + 1];
                else
                    val = tostring(arg[nI])
                end
                pLong = val
            elseif mark == '#' then
                if not pLong:find('^З') then
                    print("Error: "..pLong)
                    return
                end
                pLong = pLong:gsub('^З', '')
                local res = ''
                for i = 1, tonumber(arg[nI]) do
                    res = res..pLong:gsub('%[##'..nI..'%]', i)
                end
                pLong = res
            elseif mark == '?' then
                local _, _, sTF = pLong:find('^З(.+)')

                local tVals = (lpeg.Ct(lpeg.P{pYes *( lpeg.P('З') * lpeg.V(1)^- 1)})):match(pLong..'З')
                if not tVals or #tVals < tonumber(arg[nI]) + 2 then
                    print("Error: "..pLong)
                    return
                end
                pLong = tVals[tonumber(arg[nI]) + 2] or ''
            else
                assert(false, 'Internal Error')
            end
            s = sBeg..pLong..sEnd
            counter = counter + 1
            if counter > 1000 then
                print("Error: Abbreviation Template is performed more than 1000 times. Perhaps loop...")
                return
            end
        end
    end

    local function InsertAbbreviation(expan, dInd, curSel)
        local findSt = editor.SelectionStart
        if MACRO and expan:find('^MACRO:') then
            if findSt ~= editor.SelectionEnd then
                editor:ReplaceSel('')
                findSt = editor.SelectionStart
            end
            scite.RunAsync(function() MACRO.PlayMacro(expan:gsub('^MACRO:', '')) end)
            return
        end
        --ћен€ем: вставл€ем наш селекшн, коммент в начале убираем,\r убираем, вставл€ем табы, вставл€ем новые строки
        local s =(expan:gsub('ЛЗЫ', curSel):gsub('^%-%-.-\\n', ''):gsub('\\r', ''):gsub('\\t', '\t'):gsub('\\n', CORE.EOL())):gsub('ђ', '\\')
        local isForm
        s, isForm = s:gsub('Л(%w+)Ы',
            function(frm)
                local strFile = abrPath():gsub('%.abbrev$', '')..'.'..frm..'.lua'
                if not shell.fileexists(strFile) then print('Error: file for form "Л'..frm..'Ы" ('..strFile..') not exists!') end
                local form = dofile(strFile)
                if not frm then print('Error: unknown abbrev form: "Л'..frm..'" ('..strFile..') dos not return function') end
                form(findSt, editor.SelectionEnd, s:gsub('Л.*Ы', ''), dInd, replAbbr)
        end)
        local bCancel
        if isForm > 0 then return end --запущена форма пользовательских параметров, по окончании она выполнит вставку текста     'Л([^%[]%.-[^%]])Ы'
        s, isForm = s:gsub('Л([^%@%#%?З].-)Ы',
            function(frm)
                bCancel = parseParamTemplate(findSt, editor.SelectionEnd, s:gsub('Л([^%@%#%?].-)Ы', ''), dInd, assert(load("return function(g) return g("..frm..") end"))()(getParamProxy))
            end
        )
        if isForm > 0 then return bCancel end
        replAbbr(findSt, editor.SelectionEnd, s, dInd)
    end

    local function internal_TryInsAbbrev(bClip, strFull)
        local curSel
        if bClip then
            local cpb = iup.clipboard{};
            curSel = iup.GetAttribute(cpb, "TEXT")
            iup.Destroy(cpb)
        else curSel = editor:GetSelText() end

        local pos = editor.SelectionStart
        local lBegin = editor:textrange(editor:PositionFromLine(editor:LineFromPosition(pos)), pos)
        --debug_prnArgs(abbr_table)
        for i, v in ipairs(abbr_table) do
            if not strFull or (strFull:lower() == v.abbr:lower()) then
                if lBegin:sub(-v.abbr:len()):lower() == v.abbr:lower() then
                    if curSel ~= "" then editor:ReplaceSel() end
                    editor.SelectionStart = editor.SelectionStart - v.abbr:len()
                    local dInd = lBegin:len() - v.abbr:len()
                    return true, lBegin, InsertAbbreviation(v.exp, dInd, curSel)
                end
            end
        end
        return false, lBegin
    end

    ABBREV.TryInsAbbrev = function(strFull)
        if not abbr_table then return end
        return internal_TryInsAbbrev(false, strFull)
    end

    local function TryInsAbbrev(bClip)
        if not abbr_table then return end
        local res, lBegin = internal_TryInsAbbrev(bClip, nil)
        if not res then
            print("Error Abbrev not found in: '"..lBegin.."'")
        end
    end

    ----------------------------------------------------------
    -- list_bookmarks   Bookmarks
    ----------------------------------------------------------
    local table_bookmarks = {}

    local function GetBufferNumber()
        local buf = props['BufferNumber']
        if buf == '' then buf = 1 else buf = tonumber(buf) end
        return buf
    end

    function ABBREV.GetById(id)
        for i, v in ipairs(abbr_table) do
            if v.abbr == id then
                return v.exp
            end
        end
        return nil
    end

    ----------------------------------------------------------
    --list_abbrev   Abbreviations
    ----------------------------------------------------------
    local function Abbreviations_ListFILL()
        if editor.Lexer == prevLexer then return end
        prevLexer = editor.Lexer

        iup.SetAttribute(list_abbrev, "DELLIN", "1-"..list_abbrev.numlin)
        local abbrev_filename = abrPath()
        abbr_table = CORE.ReadAbbrevFile(abbrev_filename)
        if not abbr_table then return end
        iup.SetAttribute(list_abbrev, "ADDLIN", "1-"..#abbr_table)
        for i, v in ipairs(abbr_table) do
            list_abbrev:setcell(i, 1, v.abbr)         -- ,size="400x400"
            --print(iup.GetAttribute(list_abbrev, "FONT"..i..':1'))
            list_abbrev:setcell(i, 2, v.exp:gsub('\t', '\\t'))
        end
        table.sort(abbr_table, function(a, b)
            if a.abbr:len() == b.abbr:len() then return a.abbr < b.abbr end
            return a.abbr:len() > b.abbr:len()
        end)
        bListModified = false
        list_abbrev:setcell(0, 1, 'Abbrev')
        list_abbrev.redraw = 'ALL'
    end

    local function Abbreviations_InsertExpansion()
        if not list_abbrev.marked then return end
        local lin = list_abbrev.marked:sub(2):find("1")
        if not lin then return end

        local expansion = iup.GetAttribute(list_abbrev, lin..':2')
        local sel = editor:GetSelText()
        editor:ReplaceSel('')
        local pos = editor.SelectionStart
        local dInd = (editor:textrange(editor:PositionFromLine(editor:LineFromPosition(pos)), pos)):len()
        InsertAbbreviation(expansion, dInd, sel)
        iup.PassFocus()
    end

    --—обыти€ списка функций
    list_abbrev = iup.matrix{name = 'list_abbrev',
        numcol = 2, numcol_visible = 2, cursor = "ARROW", alignment = 'ALEFT', heightdef = 6, markmode = 'LIN', flatscrollbar = "YES" ,
        resizematrix = "YES"  ,readonly = "YES"  , markmultiple = "NO" , height0 = 4, expand = "YES", framecolor = iup.GetLayout().txtbgcolor,
        map_cb = (function(h) h.size = "1x1" end), rasterwidth0 = 0 ,
        rasterwidth1 = _G.iuprops['list_abbrev.rw1'] or 60 ,
        rasterwidth2 = _G.iuprops['list_abbrev.rw2'] or 600,
    tip = _T'In the main window, enter the code\nfrom [Abbrev] and press (Ctrl+B)'}

	list_abbrev:setcell(0, 1, "Abbrev")         -- ,size="400x400"
	list_abbrev:setcell(0, 2, "Expansion")

    list_abbrev.tips_cb = (function(h, x, y)
        local s = iup.GetAttribute(h, iup.TextConvertPosToLinCol(h, iup.ConvertXYToPos(h, x, y))..':2')
        h.tip = s:gsub('\\r', ''):gsub('\\t', '\t'):gsub('\\n', '\r\n'):gsub('ђ', '\\')
    end)

	--[[list_abbrev.map_cb = function(h)
        h.size = "1x1"
    end

	list_abbrev.keypress_cb = function(_, key, press)
        if press == 0 then return end
        if key == iup.K_CR then --enter
            Abbreviations_InsertExpansion()
        elseif k == iup.K_ESC then
            iup.PassFocus()
        end
	end]]

    local droppedLin = nil
    local clickPos = ""
    function list_abbrev:leavewindow_cb()
        if bMenuMode then return end
        list_abbrev.marked = nil

        list_abbrev.redraw = 'ALL'
        list_abbrev.cursor = "ARROW"
        droppedLin = nil;
    end
    function list_abbrev:mousemove_cb(lin, col)
--[[        if lin == 0 then return end

        if iup.GetAttributeId2(list_abbrev, 'MARK', lin, 0) ~= '1' then
            list_abbrev.marked = nil
            iup.SetAttributeId2(list_abbrev, 'MARK', lin, 0, 1)
            list_abbrev.redraw = 'ALL'
        end]]

        if clickPos == iup.GetGlobal("CURSORPOS") then
            --ѕри первом клике ложно посылаетс€  mousemove - если установлен тултип. тут отсекаем это сообщение, чтобы нормально сработал клик
            clickPos = ""
            return
        end

        local lBtn = (shell.async_mouse_state() < 0)
        if (droppedLin == nil) and lBtn then
            droppedLin = lin;
            list_abbrev.cursor = "RESIZE_NS"
        end
        if lin and lBtn and lin ~= droppedLin then
            local cur1 = list_abbrev:getcell(lin, 1)
            local cur2 = list_abbrev:getcell(lin, 2)

            list_abbrev:setcell(lin, 1, list_abbrev:getcell(droppedLin, 1))
            list_abbrev:setcell(lin, 2, list_abbrev:getcell(droppedLin, 2))

            list_abbrev:setcell(droppedLin, 1, cur1)
            list_abbrev:setcell(droppedLin, 2, cur2)

            droppedLin = lin
            list_abbrev.redraw = 'ALL'
            SetModif()
        end
    end

    iup.drop_cb_to_list(list_abbrev, Abbreviations_InsertExpansion)

    function list_abbrev:button_cb(button, pressed, x, y, status)
        if button == iup.BUTTON1 and (iup.isdouble(status)) then
            Abbreviations_InsertExpansion()
        elseif button == iup.BUTTON1 and pressed == 1 then
            clickPos = iup.GetGlobal("CURSORPOS")
        elseif button == iup.BUTTON1 and pressed == 0 then
            droppedLin = nil; list_abbrev.cursor = "ARROW"
        elseif button == iup.BUTTON3 and pressed == 0 then
            bMenuMode = true
            local lin = math.floor(iup.ConvertXYToPos(list_abbrev, x, y) / 3)
            local col = iup.ConvertXYToPos(list_abbrev, x, y) % 3
            list_abbrev.focus_cell = lin..':'..col
            local mnu = iup.menu{
                iup.item{title = _T"Create", action = function() bMenuMode = false ;EditAbbrev(true) end},
                iup.item{title = _T"Change", action = function() bMenuMode = false ;EditAbbrev(false) end},
                iup.item{title = _T"Delte", action =(function()
                    local l = list_getvaluenum(list_abbrev)
                    list_abbrev.dellin = ''..l
                end)},
                iup.separator{},
                iup.item{title = _T"Save All", active = Iif(bListModified, 'YES', 'NO'), action =(function()
                    local maxN = tonumber(list_abbrev.numlin)
                    local strOut = ''
                    for i = 1, maxN do
                        strOut = strOut..list_abbrev:getcell(i, 1)..'='..list_abbrev:getcell(i, 2)..'\n'
                    end
                    local file = io.open(abrPath(), "w")
                    file:write(strOut)
                    file:close()
                    bListModified = false
                    list_abbrev:setcell(0, 1, 'Abbrev')
                    list_abbrev.redraw = 0
                end)},
            }:popup(iup.MOUSEPOS, iup.MOUSEPOS)
            bMenuMode = false
        end
    end

    AddEventHandler("OnSwitchFile", Abbreviations_ListFILL)
    AddEventHandler("OnSave", Abbreviations_ListFILL)
    AddEventHandler("OnOpen", Abbreviations_ListFILL)
    AddEventHandler("OnMenuCommand", (function(msg)
            if msg == IDM_ABBREV then TryInsAbbrev(false) return true;
            elseif msg == IDM_INS_ABBREV then TryInsAbbrev(true) return true;
            end
        end))

    return Abbreviations_ListFILL
end

local function createDlg()
    local dlg = iup.scitedialog{list_abbrev, sciteparent = "SCITE", sciteid = "abbrev", dropdown = true,shrink="YES",
                maxbox = 'NO', minbox = 'NO', menubox = 'NO', minsize = '100x200', bgcolor = iup.GetLayout().txtbgcolor,
                customframedraw = Iif(props['layout.standard.decoration'] == '1', 'NO', 'YES'), customframecaptionheight = -1, customframedraw_cb = CORE.paneldraw_cb, customframeactivate_cb = CORE.panelactivate_cb(flat_title)}
    list_abbrev.killfocus_cb = function()
        if not bMenuMode then dlg:hide() end
    end
    dlg.resize_cb = function(h)
        list_abbrev.rasterwidth2 = nil
        list_abbrev.fittosize = 'COLUMNS'
    end
    dlg.show_cb = function(h, state)
        if state == 0 then
            list_abbrev.rasterwidth2 = nil
            list_abbrev.fittosize = 'COLUMNS'
        end
    end
    menuhandler:InsertItem('MainWindowMenu', 'Edit|s3',
        {'Abbreviation List', action = function() iup.ShowInMouse(dlg) end, key = 'Alt+Shift+B'}
    , nil, _T)
    bIsList = true
    return dlg
end

local function ToolBar_Init(h)
    bToolBar = true
    local onselect = Init()
    local dlg = createDlg()

    local fbutton = iup.flatbutton{title = _T'Abbreviation List', flat_action =(function(h)
                local _, _, left, top = h.screenposition:find('(-*%d+),(-*%d+)')
                if iup.GetParent(iup.GetParent(h)).name == 'StatusBar' then
                    local _, _, _, dy = dlg.rastersize:find('(%d*)x(%d*)')
                    top = top - dy
                end
                dlg:showxy(left,top)
            end), padding='5x2',}

    local box = iup.hbox{
            fbutton,
            iup.label{separator = "VERTICAL",maxsize='x22', },
            expand='HORIZONTAL', alignment='ACENTER' , margin = '3x',
    };
    showPopUp = function() fbutton:flat_action() end
    return {
        handle = box;
        on_SelectMe = onselect
        }
end

local function Tab_Init(h)
    local function onResize_local()
        list_abbrev.FitColumns(2, false)()
    end
    local onselect = Init()
    AddEventHandler("OnResizeSideBar", function(sciteid)
        if h.abbreviations.Bar_obj.sciteid == sciteid then
            list_abbrev.rasterwidth2 = nil
            list_abbrev.fittosize = 'COLUMNS'
        end
    end)
    AddEventHandler("OnResizeSideBar", function(sciteid)
        if h.atrium.Bar_obj.sciteid == sciteid then onResize_local() end
    end)
    return {
        handle = iup.backgroundbox{list_abbrev, bgcolor = iup.GetLayout().txtbgcolor};
        on_SelectMe = onselect
        }

end

local function Hidden_Init(h)
    bToolBar = true
    Init()
    local dlg = createDlg()
    showPopUp = function() iup.ShowInMouse(dlg) end
end

return {
    title = 'Abbreviations',
    code = 'abbreviations',
    sidebar = Tab_Init,
    toolbar = ToolBar_Init,
    statusbar = ToolBar_Init,
    hidden = Hidden_Init,
    tabhotkey = "Alt+Shift+A",
    destroy = function() ABBREV = nil end,
    description = [[—писок сокращений. ѕо нажатию гор€чей клавиши
перед курсором ищетс€ сокращение из списка
и замен€етс€ на соответствующий фрагмент текста]]
}
