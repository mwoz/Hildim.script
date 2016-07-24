local myId = "Abbrev/Bmk"
local list_abbrev

local list_bookmarks
local Abbreviations_USECALLTIPS = tonumber(props['sidebar.abbrev.calltip']) == 1
local isEditor = false
local prevLexer = -1
local abbr_table
local bListModified = false
require"lpeg"

ABBREV = {}

local function replAbbr(findSt, findEnd, s, dInd)

    s = s:gsub('%%CLIP(%d+)%%', function(i) if CLIPHISTORY then print(i) ; return CLIPHISTORY.GetClip(i)  else return '' end end)

    editor:BeginUndoAction()
    editor:SetSel(findSt, findEnd)
    editor:ReplaceSel(s)
    local findEnd = editor.CurrentPos
    local l1,l2 = editor:LineFromPosition(findSt),editor:LineFromPosition(findEnd)

    for i = l1 + 1,l2  do
        local ind = scite.SendEditor(SCI_GETLINEINDENTATION,i) + dInd
        scite.SendEditor(SCI_SETLINEINDENTATION,i, 0)  --чтобы избавитьс€ от табов сначала сбрасываем отступ в 0 а потом выставл€ем нужный
        --если просто выставить нужный, и он при этом не изменитс€, табы могут остатьс€
        scite.SendEditor(SCI_SETLINEINDENTATION,i, ind)
        findEnd = findEnd + dInd
    end

    local pos = editor:findtext('|', 0, findSt, findEnd)

    if pos~=nil then
        editor:SetSel(findSt, findEnd)
        editor:SetSel(pos, pos+1)
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
        abbr_table[#abbr_table+1] = {abbr=list_abbrev:getcell(i, 1), exp=list_abbrev:getcell(i, 2)}
    end
end

local function EditAbbrev()

    local abb,expan
    local l = list_getvaluenum(list_abbrev)
	if idx == -1 then
        abb,expan = 0,0
    end
	abb,expan = list_abbrev:getcell(l, 1), list_abbrev:getcell(l,2)

    local btn_upd = iup.button  {title="Save"}
    iup.SetHandle("EDIT_BTN_UPD",btn_upd)
    local btn_esc = iup.button  {title="Cancel"}
    iup.SetHandle("EDIT_BTN_ESC",btn_esc)
    local btn_insert = iup.button  {title="Insert"}
    iup.SetHandle("EDIT_BTN_INS",btn_insert)

    local txt_exp = iup.text{multiline='YES',wordwrap='YES', expand='YES', fontsize='12',value = expan:gsub('\\n', '\n'):gsub('\\r',''):gsub('\\t','\t'):gsub('ђ', '\\')}
    local txt_abr = iup.text{expand='NO', fontsize='12',value =abb, size = '90x0'}

    local vbox = iup.vbox{
        iup.hbox{txt_abr};
        iup.hbox{iup.vbox{txt_exp}};

        iup.hbox{btn_upd,btn_insert,iup.fill{},btn_esc, expand='HORIZONTAL'},
        expandchildren ='YES',gap=2,margin="4x4"}
    local dlg = iup.scitedialog{vbox; title="Edit Abbrev",defaultenter="MOVE_BTN_OK",defaultesc="MOVE_BTN_ESC",tabsize=editor.TabWidth,
        maxbox="NO",minbox ="NO",resize ="YES",shrink ="YES",sciteparent="SCITE", sciteid="abbreveditor", minsize='600x300'}

    dlg.show_cb=(function(h,state)
        if state == 4 then
            dlg:postdestroy()
        end
    end)
    function btn_insert:action()
        list_abbrev.addlin = ''..l
        list_abbrev:setcell(l + 1, 1, txt_abr.value)
        list_abbrev:setcell(l + 1, 2, txt_exp.value:gsub('\\', 'ђ'):gsub('\r','\\r'):gsub('\n','\\n'):gsub('\t','\\t'))
        list_abbrev.redraw = l + 1
        SetModif()
        dlg:postdestroy()
    end

    function btn_upd:action()
        list_abbrev:setcell(l, 1, txt_abr.value)
        list_abbrev:setcell(l, 2, txt_exp.value:gsub('\\', 'ђ'):gsub('\r', '\\r'):gsub('\n', '\\n'):gsub('\t', '\\t'))
        list_abbrev.redraw = l
        SetModif()
        dlg:postdestroy()
    end

    function btn_esc:action()
        dlg:action()
    end
end

local function getParamProxy(...)
    local t = {}
    local arg = {...}
    local i = 1
    if type(arg[3]) == 'string' then
        for p in arg[3]:gmatch("[^\n]+") do
            if p:find('%%l') or p:find('%%o') then
                t[i] = {}
                j = 0
                for o in p:gmatch('[^|]+') do
                    t[i][j] = o
                    j = j + 1
                end
            end
            i = i + 1
        end
    end
    return t, iup.GetParam(...)
end

local function parseParamTemplate(findSt, findEnd, s, dInd, tMap, bContinue, ...)
    if not bContinue then return true end
    local nFind = 1
    local counter = 0
    local ballance = lpeg.P{ "Л" * ((1 - lpeg.S"ЛЫ") + lpeg.V(1))^0 * "Ы" }  --находит фрагмент со сбалансированными скобками
    local pYes = lpeg.C(lpeg.P{#lpeg.P('//') + (ballance + 1) * lpeg.V(1) })
    while true do
        local sBeg, pLong, sEnd = (lpeg.C((1 - lpeg.S"ЛЫ")^0) * lpeg.C(ballance) * lpeg.C(lpeg.P(1)^0)):match(s, 1)  --выводит часть до шаблона, шаблон и после
        --print(tPos1, tPos2)
        if not pLong then
            replAbbr(findSt, findEnd, s, dInd)
            return
        end

        local _, _, mark, nI = pLong:find('^Л([%@%#%?])(%d+)')
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
            if not pLong:find('^//') then
                print("Error: "..pLong)
                return
            end
            pLong = pLong:gsub('^//', '')
            local res = ''
            for i = 1, tonumber(arg[nI]) do
                res = res..pLong:gsub('%[##'..nI..'%]', i)
            end
            pLong = res
        elseif mark == '?' then
            local _, _, sTF = pLong:find('^//(.+)')

            local sTrue, sFalse = (pYes * lpeg.P"//" * lpeg.C(lpeg.P(1)^0)):match(sTF)

            if not sTrue and not sFalse then
                print("Error: "..pLong)
                return
            end
            pLong = Iif(tonumber(arg[nI]) ~= 0, sTrue, sFalse)
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
    --ћен€ем: вставл€ем наш селекшн, коммент в начале убираем,\r убираем, вставл€ем табы, вставл€ем новые строки
    local s =(expan:gsub('%%SEL%%', curSel):gsub('^%-%-.-\\n', ''):gsub('\\r', ''):gsub('\\t', '\t'):gsub('\\n', CORE.EOL())):gsub('ђ', '\\')
    local isForm
    s, isForm = s:gsub('Л(%w+)Ы',
        function(frm)
            local strFile = props['AbbrevPath']:gsub('%.abbrev$', '')..'.'..frm..'.lua'
            if not shell.fileexists(strFile) then print('Error: file for form "Л'..frm..'Ы" ('..strFile..') not exists!') end
            local form = dofile(strFile)
            if not frm then print('Error: unknown abbrev form: "Л'..frm..'" ('..strFile..') dos not return function') end
            form(findSt, editor.SelectionEnd, s, dInd, replAbbr)
    end)
    local bCancel
    if isForm > 0 then return end --запущена форма пользовательских параметров, по окончании она выполнит вставку текста     'Л([^%[]%.-[^%]])Ы'
    s, isForm = s:gsub('Л([^%@%#%?].-)Ы',
        function(frm)
            bCancel = parseParamTemplate(findSt, editor.SelectionEnd, s:gsub('Л([^%@%#%?].-)Ы', ''), dInd, assert(loadstring("return function(g) return g("..frm..") end"))()(getParamProxy))
        end
    )
    if isForm then return bCancel end
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
    if lBegin then
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
	local abbrev_filename = props['AbbrevPath']
    abbr_table = CORE.ReadAbbrevFile(abbrev_filename)
	if not abbr_table then return end
    iup.SetAttribute(list_abbrev, "ADDLIN", "1-"..#abbr_table)
	for i,v in ipairs(abbr_table) do
        list_abbrev:setcell(i, 1, v.abbr)         -- ,size="400x400"
        list_abbrev:setcell(i, 2, v.exp:gsub('\t','\\t'))
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
	local expansion = iup.GetAttribute(list_abbrev, list_abbrev.focus_cell:gsub(':.*', ':2'))
    local sel = editor:GetSelText()
    editor:ReplaceSel('')
    local pos = editor.SelectionStart
    local dInd = (editor:textrange(editor:PositionFromLine(editor:LineFromPosition(pos)),pos)):len()
	InsertAbbreviation(expansion, dInd,sel)
    iup.PassFocus()
end

local function Init()
    --—обыти€ списка функций
    list_abbrev = iup.matrix{
    numcol=2, numcol_visible=2,  cursor="ARROW", alignment='ALEFT', heightdef=6,markmode='LIN', scrollbar="YES" ,
    resizematrix = "YES"  ,readonly="YES"  ,markmultiple="NO" ,height0 = 4, expand = "YES", framecolor="255 255 255",
    rasterwidth0 = 0 ,rasterwidth1 = 60 ,rasterwidth2 = 600 ,
    tip='¬ главном окне введите\nкод из [Abbrev] + (Ctrl+B)'}

	list_abbrev:setcell(0, 1, "Abbrev")         -- ,size="400x400"
	list_abbrev:setcell(0, 2, "Expansion")

	list_abbrev.click_cb = (function(h, lin, col, status)
        if iup.isdouble(status) and iup.isbutton1(status) then
            Abbreviations_InsertExpansion()
        elseif iup.isbutton3(status) then
            h.focus_cell = lin..':'..col
            local mnu = iup.menu{
                iup.item{title="Edit",action=EditAbbrev},
                iup.item{title="Delete",action=(function()
                    local msb = iup.messagedlg{buttons='YESNO', value='Delete?'}
                    msb.popup(msb)
                    if msb.buttonresponse == '1' then
                        local l = list_getvaluenum(list_abbrev)
                        list_abbrev.dellin = ''..l
                    end
                    msb:destroy(msb)
                end)},
                iup.item{title="Move Up",active=Iif(list_getvaluenum(list_abbrev)<2, 'NO', 'YES'),action=(function()
                    local l = list_getvaluenum(list_abbrev)
                    local abb,expan = list_abbrev:getcell(l, 1), list_abbrev:getcell(l,2)

                    --
                    list_abbrev.addlin = ''..(l-2)
                    --iup.SetAttribute(list_abbrev, "COPYLIN"..(l+1), ''..(l-1))
                    list_abbrev:setcell(l-1, 1, abb)
                    list_abbrev:setcell(l-1, 2, expan)
                    list_abbrev.dellin = ''..(l+1)
                    list_abbrev.redraw = (l-1)..'-'..l
                    SetModif()

                end)},
                iup.separator{},
                iup.item{title="Save all",active=Iif(bListModified, 'YES', 'NO'),action=(function()
                    local maxN = tonumber(list_abbrev.numlin)
                    local strOut = ''
                    for i = 1, maxN do
                        strOut = strOut..list_abbrev:getcell(i, 1)..'='..list_abbrev:getcell(i,2)..'\n'
                    end
                    local file = io.open(props["AbbrevPath"], "w")
                    file:write(strOut)
                    file:close()
                    bListModified = false
                    list_abbrev:setcell(0, 1, 'Abbrev')
                    list_abbrev.redraw = 0
                end)},
            }:popup(iup.MOUSEPOS,iup.MOUSEPOS)
        end
    end)
	list_abbrev.tips_cb = (function(h, x, y)
        local s = iup.GetAttribute(h, iup.TextConvertPosToLinCol(h, iup.ConvertXYToPos(h, x, y))..':2')
        h.tip = s:gsub('\\r', ''):gsub('\\t', '\t'):gsub('\\n', '\r\n'):gsub('ђ', '\\')
    end)
	list_abbrev.map_cb = (function(h)
        h.size="1x1"
    end)

	list_abbrev.keypress_cb = (function(_, key, press)
        if press == 0 then return end
        if key == iup.K_CR then  --enter
            Abbreviations_InsertExpansion()
        elseif k == iup.K_ESC then
            iup.PassFocus()
        end
	end)
end

local function ToolBar_Init(h)
    Init()
    local dlg = iup.scitedialog{iup.scrollbox{list_abbrev},sciteparent="SCITE", sciteid="abbrev_popup",dropdown=true,
                maxbox='NO', minbox='NO', menubox='NO', minsize = '100x200', bgcolor='255 255 255'}
    list_abbrev.killfocus_cb = function()
        dlg:hide()
    end

    local box = iup.hbox{
            iup.flatbutton{title = '—писок сокращений', flat_action=(function(h)
                local _, _,left, top = h.screenposition:find('(-*%d+),(-*%d+)')
                dlg:showxy(left,top)
            end), padding='5x2',},
            iup.label{separator = "VERTICAL",maxsize='x22', },
            expand='HORIZONTAL', alignment='ACENTER' , margin = '3x',
    };
    h.Tabs.abbreviations = {
        handle = box;
        OnSwitchFile = Abbreviations_ListFILL;
        OnSave = Abbreviations_ListFILL;
        OnOpen = Abbreviations_ListFILL;
        OnMenuCommand = (function(msg)
            if msg == IDM_ABBREV then TryInsAbbrev(false) return true;
            elseif msg == IDM_INS_ABBREV then TryInsAbbrev(true) return true;
            end
        end);
        on_SelectMe = (function()  Abbreviations_ListFILL();end)
        }
end

local function Tab_Init()
    Init()
    SideBar_Plugins.abbreviations = {
        handle = list_abbrev;
        OnSwitchFile = Abbreviations_ListFILL;
        OnSave = Abbreviations_ListFILL;
        OnOpen = Abbreviations_ListFILL;
        OnMenuCommand = (function(msg)
            if msg == IDM_ABBREV then TryInsAbbrev(false) return true;
            elseif msg == IDM_INS_ABBREV then TryInsAbbrev(true) return true;
            end
        end);
        on_SelectMe = (function()  Abbreviations_ListFILL();end)
        }
end

return {
    title = 'Abbreviations',
    code = 'abbreviations',
    sidebar = Iif( ('¶'..(_G.iuprops["settings.toolbars.layout"] or '')..'¶'):find('¶Abbrev.lua¶'), nil, Tab_Init),
    toolbar = Iif( ('¶'..(_G.iuprops["settings.user.rightbar"] or '')..'¶'..(_G.iuprops["settings.user.leftbar"] or '')..'¶'):find('¶Abbrev.lua¶'),  nil, ToolBar_Init)

}
