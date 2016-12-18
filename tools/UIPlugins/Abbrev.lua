-- Version: 1.0
-- Author:
---------------------------------------------------
-- Description:
---------------------------------------------------
local list_abbrev

local function Init()
    local text = props['CurrentSelection']
    local myId = "Abbrev/Bmk"

    local list_bookmarks
    local Abbreviations_USECALLTIPS = tonumber(props['sidebar.abbrev.calltip']) == 1
    local isEditor = false
    local prevLexer = -1
    local abbr_table
    local bListModified = false
    require"lpeg"
    local bMenuMode = false
    local bToolBar = false
    local showPopUp, editMode

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
        s = s:gsub('�', function(i) cnt = cnt + 1; return Iif(cnt == 1, '�', '') end )

        editor:BeginUndoAction()
        editor:SetSel(findSt, findEnd)
        editor:ReplaceSel(s)
        local findEnd = editor.CurrentPos
        local l1, l2 = editor:LineFromPosition(findSt), editor:LineFromPosition(findEnd)

        for i = l1 + 1, l2 do
            local ind = scite.SendEditor(SCI_GETLINEINDENTATION, i) + dInd
            scite.SendEditor(SCI_SETLINEINDENTATION, i, 0)  --����� ���������� �� ����� ������� ���������� ������ � 0 � ����� ���������� ������
            --���� ������ ��������� ������, � �� ��� ���� �� ���������, ���� ����� ��������
            scite.SendEditor(SCI_SETLINEINDENTATION, i, ind)
            findEnd = findEnd + dInd
        end

        local pos = editor:findtext('�', 0, findSt, findEnd)

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

        local txt_exp = iup.text{multiline = 'YES', wordwrap = 'YES', expand = 'YES', fontsize = '12', value = expan:gsub('\\n', '\n'):gsub('\\r', ''):gsub('\\t', '\t'):gsub('�', '\\')}
        local txt_abr = iup.text{expand = 'NO', fontsize = '12', value = abb, size = '90x0'}

        local bCur = iup.flatbutton{title = ' � Cursor', flat_action = function() txt_exp.insert = '�' end}
        local bSC = iup.flatbutton{title = ' ��� Sel/Clip', flat_action = function() txt_exp.insert = '���' end}
        local bTxt = iup.flatbutton{title = ' �@1� Text', flat_action = function() txt_exp.insert = '�@1�' end}
        local bNum = iup.flatbutton{title = ' �#1�� Numeric', flat_action = function() txt_exp.insert = '�#1�'..(txt_exp.selectedtext or '')..'�' end}
        local bChoise = iup.flatbutton{title = ' �?1��� Choice', flat_action = function() txt_exp.insert = '�?1�'..(txt_exp.selectedtext or '')..'��' end}
        local bForm = iup.flatbutton{title = ' �...� Form', flat_action = function() txt_exp.append = [[�
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
�]] end}

local vbox = iup.vbox{
    iup.hbox{txt_abr, bCur, bSC, bTxt, bNum, bChoise, bForm, gap = '20'};
    iup.hbox{iup.vbox{txt_exp}};

    iup.hbox{btn_upd, iup.fill{}, btn_esc, expand = 'HORIZONTAL'},
expandchildren = 'YES', gap = 2, margin = "4x4"}                                    --[[txt_exp.insert = '�?1�'..'(txt_exp.selectedtext or '')'..'�.....�' ]]
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
        list_abbrev:setcell(l, 2, txt_exp.value:gsub('\\', '�'):gsub('\r', '\\r'):gsub('\n', '\\n'):gsub('\t', '\\t'))
        list_abbrev.redraw = l
    else
        list_abbrev.addlin = ''..l
        list_abbrev:setcell(l + 1, 1, txt_abr.value)
        list_abbrev:setcell(l + 1, 2, txt_exp.value:gsub('\\', '�'):gsub('\r', '\\r'):gsub('\n', '\\n'):gsub('\t', '\\t'))
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
        return t, assert(loadstring(strGp))()(arg)
    end

    local function parseParamTemplate(findSt, findEnd, s, dInd, tMap, bContinue, ...)
        if not bContinue then return true end
        local nFind = 1
        local counter = 0
        local ballance = lpeg.P{ "�" * ((1 - lpeg.S"��") + lpeg.V(1))^0 * "�" }  --������� �������� �� ����������������� ��������
        local pYes = lpeg.C(lpeg.P{#lpeg.P('�') + (ballance + 1) * lpeg.V(1) })
        while true do
            local sBeg, pLong, sEnd = (lpeg.C((1 - lpeg.S"��")^0) * lpeg.C(ballance) * lpeg.C(lpeg.P(1)^0)):match(s, 1)  --������� ����� �� �������, ������ � �����
            --print(tPos1, tPos2)
            if not pLong then
                replAbbr(findSt, findEnd, s, dInd)
                return
            end

            local _, _, mark, nI = pLong:find('^�([%@%#%?])(%d+)')
            if not nI or tonumber(nI) > #arg then
                bContinue = false
                print("Error: "..pLong)
                return
            end
            nI = tonumber(nI)
            pLong = pLong:gsub('^..%d+', ''):gsub('�$', '')
            if mark == '@' then
                if tMap[nI] and tMap[nI][arg[nI] + 1] then
                    val = tMap[nI][arg[nI] + 1];
                else
                    val = tostring(arg[nI])
                end
                pLong = val
            elseif mark == '#' then
                if not pLong:find('^�') then
                    print("Error: "..pLong)
                    return
                end
                pLong = pLong:gsub('^�', '')
                local res = ''
                for i = 1, tonumber(arg[nI]) do
                    res = res..pLong:gsub('%[##'..nI..'%]', i)
                end
                pLong = res
            elseif mark == '?' then
                local _, _, sTF = pLong:find('^�(.+)')

                local tVals = (lpeg.Ct(lpeg.P{pYes *( lpeg.P('�') * lpeg.V(1)^- 1)})):match(pLong..'�')
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
        --������: ��������� ��� �������, ������� � ������ �������,\r �������, ��������� ����, ��������� ����� ������
        local s =(expan:gsub('���', curSel):gsub('^%-%-.-\\n', ''):gsub('\\r', ''):gsub('\\t', '\t'):gsub('\\n', CORE.EOL())):gsub('�', '\\')
        local isForm
        s, isForm = s:gsub('�(%w+)�',
            function(frm)
                local strFile = abrPath():gsub('%.abbrev$', '')..'.'..frm..'.lua'
                if not shell.fileexists(strFile) then print('Error: file for form "�'..frm..'�" ('..strFile..') not exists!') end
                local form = dofile(strFile)
                if not frm then print('Error: unknown abbrev form: "�'..frm..'" ('..strFile..') dos not return function') end
                form(findSt, editor.SelectionEnd, s:gsub('�.*�', ''), dInd, replAbbr)
        end)
        local bCancel
        if isForm > 0 then return end --�������� ����� ���������������� ����������, �� ��������� ��� �������� ������� ������     '�([^%[]%.-[^%]])�'
        s, isForm = s:gsub('�([^%@%#%?�].-)�',
            function(frm)
                bCancel = parseParamTemplate(findSt, editor.SelectionEnd, s:gsub('�([^%@%#%?].-)�', ''), dInd, assert(loadstring("return function(g) return g("..frm..") end"))()(getParamProxy))
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


    --������� ������ �������
    list_abbrev = iup.matrix{
        numcol = 2, numcol_visible = 2, cursor = "ARROW", alignment = 'ALEFT', heightdef = 6, markmode = 'LIN', scrollbar = "YES" ,
        resizematrix = "YES"  , readonly = "YES"  , markmultiple = "NO" , height0 = 4, expand = "YES", framecolor = "255 255 255",
        rasterwidth0 = 0 , rasterwidth1 = 60 , rasterwidth2 = 600 ,
    tip = '� ������� ���� �������\n��� �� [Abbrev] + (Ctrl+B)'}

	list_abbrev:setcell(0, 1, "Abbrev")         -- ,size="400x400"
	list_abbrev:setcell(0, 2, "Expansion")

    list_abbrev.tips_cb = (function(h, x, y)
        local s = iup.GetAttribute(h, iup.TextConvertPosToLinCol(h, iup.ConvertXYToPos(h, x, y))..':2')
        h.tip = s:gsub('\\r', ''):gsub('\\t', '\t'):gsub('\\n', '\r\n'):gsub('�', '\\')
    end)

	list_abbrev.map_cb = function(h)
        h.size = "1x1"
    end

	list_abbrev.keypress_cb = function(_, key, press)
        if press == 0 then return end
        if key == iup.K_CR then --enter
            Abbreviations_InsertExpansion()
        elseif k == iup.K_ESC then
            iup.PassFocus()
        end
	end

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
        if lin == 0 then return end

        if iup.GetAttributeId2(list_abbrev, 'MARK', lin, 0) ~= '1' then
            list_abbrev.marked = nil
            iup.SetAttributeId2(list_abbrev, 'MARK', lin, 0, 1)
            list_abbrev.redraw = 'ALL'
        end

        if clickPos == iup.GetGlobal("CURSORPOS") then
            --��� ������ ����� ����� ����������  mousemove - ���� ���������� ������. ��� �������� ��� ���������, ����� ��������� �������� ����
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

    function list_abbrev:button_cb(button, pressed, x, y, status)
        if button == iup.BUTTON1 and (iup.isdouble(status) or (bToolBar and pressed == 0 and list_abbrev.cursor == "ARROW")) then
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
                iup.item{title = "�������", action = function() bMenuMode = false ;EditAbbrev(true) end},
                iup.item{title = "��������", action = function() bMenuMode = false ;EditAbbrev(false) end},
                iup.item{title = "�������", action =(function()
                    local l = list_getvaluenum(list_abbrev)
                    list_abbrev.dellin = ''..l
                end)},
                iup.separator{},
                iup.item{title = "��������� ���", active = Iif(bListModified, 'YES', 'NO'), action =(function()
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
    local dlg = iup.scitedialog{iup.scrollbox{list_abbrev}, sciteparent = "SCITE", sciteid = "abbrev", dropdown = true,
                maxbox='NO', minbox='NO', menubox='NO', minsize = '100x200', bgcolor='255 255 255'}
    list_abbrev.killfocus_cb = function()
        if not bMenuMode then dlg:hide() end
    end
    return dlg
end

local function ToolBar_Init(h)
    bToolBar = true
    local onselect = Init()
    local dlg = createDlg()

    local fbutton = iup.flatbutton{title = '������ ����������', flat_action=(function(h)
                local _, _,left, top = h.screenposition:find('(-*%d+),(-*%d+)')
                dlg:showxy(left,top)
            end), padding='5x2',}

    local box = iup.hbox{
            fbutton,
            iup.label{separator = "VERTICAL",maxsize='x22', },
            expand='HORIZONTAL', alignment='ACENTER' , margin = '3x',
    };
    showPopUp = function() fbutton:flat_action() end
    h.Tabs.abbreviations = {
        handle = box;
        on_SelectMe = onselect
        }
end

local function Tab_Init(h)
    local onselect = Init()
    h.abbreviations = {
        handle = list_abbrev;
        on_SelectMe = onselect
        }
end

local function Hidden_Init(h)
    bToolBar = true
    Init()
    local dlg = createDlg()
    menuhandler:InsertItem('MainWindowMenu', 'Tools�s2',
        {'Abbreviations List', ru = '������ ����������', action = function() iup.ShowInMouse(dlg) end,}
    )
end

return {
    title = 'Abbreviations',
    code = 'abbreviations',
    sidebar = Tab_Init,
    toolbar = ToolBar_Init,
    hidden = Hidden_Init,
    tabhotkey = "Alt+Shift+A",
    description = [[������ ����������. �� ������� ������� �������
����� �������� ������ ���������� �� ������
� ���������� �� ��������������� �������� ������]]
}
