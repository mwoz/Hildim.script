local myId = "Abbrev/Bmk"
local list_abbrev

local list_bookmarks
local Abbreviations_USECALLTIPS = tonumber(props['sidebar.abbrev.calltip']) == 1
local isEditor = false
local prevLexer = -1
local abbr_table
local bListModified = false

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

    local txt_exp = iup.text{multiline='YES',wordwrap='YES', expand='YES', fontsize='12',value = expan:gsub('\\n', '\n'):gsub('\\r',''):gsub('\\t','\t')}
    local txt_abr = iup.text{expand='NO', fontsize='12',value =abb, size = '90x0'}

    local vbox = iup.vbox{
        iup.hbox{txt_abr};
        iup.hbox{iup.vbox{txt_exp}};

        iup.hbox{btn_upd,btn_insert,iup.fill{},btn_esc, expand='HORIZONTAL'},
        expandchildren ='YES',gap=2,margin="4x4"}
    local dlg = iup.scitedialog{vbox; title=" онтрол √ритер",defaultenter="MOVE_BTN_OK",defaultesc="MOVE_BTN_ESC",tabsize=editor.TabWidth,
        maxbox="NO",minbox ="NO",resize ="YES",shrink ="YES",sciteparent="SCITE", sciteid="abbreveditor", minsize='600x300'}

    dlg.show_cb=(function(h,state)
        if state == 4 then
            dlg:postdestroy()
        end
    end)
    function btn_insert:action()
        list_abbrev.addlin = ''..l
        list_abbrev:setcell(l + 1, 1, txt_abr.value)
        list_abbrev:setcell(l + 1, 2, txt_exp.value:gsub('\r','\\r'):gsub('\n','\\n'):gsub('\t','\\t'))
        list_abbrev.redraw = l + 1
        SetModif()
        dlg:postdestroy()
    end

    function btn_upd:action()
        list_abbrev:setcell(l, 1, txt_abr.value)
        list_abbrev:setcell(l, 2, txt_exp.value:gsub('\r','\\r'):gsub('\n','\\n'):gsub('\t','\\t'))
        list_abbrev.redraw = l
        SetModif()
        dlg:postdestroy()
    end

    function btn_esc:action()
        dlg:postdestroy()
    end
end
local function replAbbr(findSt, findEnd, s, dInd)
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

local function frmControlPos(findSt, findEnd, s, dInd)
    --показываем диалог позиционировани€ контролов
    local dlg2 = _G.dialogs["ctrlgreator"]
    if dlg2 ~= nil then return end --один экземпл€р уже показан
    local tX, tW, tCpt, tA = {},{},{},{}
    local tX1, tW1, tCpt1, tA1 = {},{},{}, {}
    --создаем контролы
    local txtX2 = iup.list{size='60x0',dropdown="YES",editbox="YES",mask="/d+",visible_items="15"}
    local txtY2 = iup.text{size='60x0',mask="/d+"}
    local txtH2 = iup.text{size='60x0',mask="/d+"}
    local txtW2 = iup.list{size='60x0',dropdown="YES",editbox="YES",mask="/d+",visible_items="15"}

    local _,_, ctype = s:find('type="(%l+)"')
    local txtCp = iup.list{size='60x0',dropdown="YES",editbox="YES",mask="/d+",visible_items="15"}
    local function onCmbAll(h)
        if tA1 == nil then return end
        if #tA1 == 0 then return end
        txtX2.value = tA1[tonumber(h.value)][2][1]
        txtW2.value = tA1[tonumber(h.value)][2][2]
        txtCp.value = tA1[tonumber(h.value)][2][3]
    end
    local cmbAll = iup.list{size='60x0',dropdown="YES",visible_items="15",valuechanged_cb = onCmbAll}
    local function onTxtX2(h,text, item, state)
            local n = tonumber(text)
            for i, s in pairs(tA1) do if tonumber(s[2][1]) >= n then cmbAll.value=i;break;end end
        end
    txtX2.action = onTxtX2
    local bDdx = s:find('tag="ddx_Enabled=Y"')
    local cmbDdx = iup.list{dropdown="YES",visible_items="5",active=Iif(bDdx, 'YES', 'NO'), value=Iif(bDdx, _G.iuprops['abbrev.ctrldlg.ddx'] or 0, 0)}
    iup.SetAttribute(cmbDdx, 1, '')
    iup.SetAttribute(cmbDdx, 2, 'ddx_Enabled')
    iup.SetAttribute(cmbDdx, 3, 'ddx_MetaBind')
    --найдем в тексте все контролы и извлечем из них все горизонтальные координаты - дл€ выбора
    local b,e = 0,-1
    local body
    while true do
        b,e,body = editor:findtext('<control \\(.+?\\)>', SCFIND_REGEXP, e + 1)
        if not b then break end
        body = editor:textrange(b,e)
        local xI, wI, cI = 0,0,0
        --сначала пишем в имена - дл€ избежани€ дублировани€
        body:gsub('position="(%d+);%d+;(%d+);%d+"', function(x,w) xI=x; wI=w; tX[x] = tonumber(x); tW[w] = tonumber(w) end)
        body:gsub('captionwidth="(%d+)"', function(cp)
            cI = cp
            tCpt[cp] = tonumber(cp)
            local l = tonumber(cp) + tonumber(xI)
            tX[''..l] = l
            l = tonumber(wI) - tonumber(cp)
            tW[''..l] = l
        end)
        if tonumber(xI) > 0 and tonumber(wI) > 0 then tA[xI..','..wI..','..cI] = {xI, wI, cI} end
    end
    --перепишем все таблицы по индексам и отсортируем
    for s, i in pairs(tX) do table.insert(tX1,i) end
    for s, i in pairs(tW) do table.insert(tW1,i) end
    for s, i in pairs(tCpt) do table.insert(tCpt1,i) end
    for i, t in pairs(tA) do table.insert(tA1,{i,t}) end

    table.sort(tX1)
    table.sort(tW1)
    table.sort(tCpt1)
    table.sort(tA1,function(a,b)
        local ta,tb = a[2], b[2]
        if ta[1] == tb[1] then
            if ta[2] == tb[2] then
                return tonumber(ta[3])<tonumber(tb[3])
            else
                return tonumber(ta[2])<tonumber(tb[2])
            end
        else
            return tonumber(ta[1])<tonumber(tb[1])
        end
    end)

    --заполним списки комбобоксов
    local l = 1
    for i, s in pairs(tX1) do if tonumber(s) > 0 then iup.SetAttribute(txtX2, l, s);l=l+1 end end
    l = 1
    for i, s in pairs(tW1) do if tonumber(s) > 0 then iup.SetAttribute(txtW2, l, s);l=l+1 end end
    l = 1
    for i, s in pairs(tCpt1) do if tonumber(s) > 0 then iup.SetAttribute(txtCp, l, s);l=l+1 end end
    for i, s in pairs(tA1) do iup.SetAttribute(cmbAll, i, s[1]) end
    txtX2.value=1;txtW2.value=1;txtCp.value=1;cmbAll.value=1


    local i,str
    i,i,txtX2.value,txtY2.value,txtW2.value,txtH2.value=s:find('position="(%d+);(%d+);(%d+);(%d+)"')
    i,i,str=s:find('captionwidth="(%d+)"')
    local bIsRef = (nil ~= s:find('name="btn1"'))
    if i == nil and not bIsRef then
        txtCp.value=''
        txtCp.active='NO'
    else
        txtCp.active='YES'
        txtCp.value=str
    end

    --найдем предыдущий контрол и по нему выставим координаты в нашем
    local icL = editor:LineFromPosition(editor.CurrentPos)

    local onSameLine = true
    local iDepth = 0
    for i = icL - 1, 1, -1 do
        local x,y,w
        local sl = editor:GetLine(i)
        if sl:find('^%s+$') then
            onSameLine = false --считаем, что если предыдуща€ строка пуста, то контрол на новой строке
        elseif sl:find('<frame ') then
            break
        elseif sl:find('</control>') then
            iDepth = iDepth + 1
        elseif sl:find('<control ') then
            if not sl:find('/>') then iDepth = iDepth - 1 end
            if iDepth == 0 then
                local _,_,x,y,w = sl:find('position="(%d+);(%d+);(%d+);%d+"')
                if onSameLine then
                    txtY2.value = y
                    txtX2.value = ''..(tonumber(x) + tonumber(w))
                else
                    txtY2.value = '' ..(tonumber(y) + 12)
                end
                break
            end
        end
    end
    onTxtX2(txtX2,txtX2.value, nil, nil)
    onCmbAll(cmbAll)
    ---

    local btn_ok = iup.button  {title="OK"}
    iup.SetHandle("CREATE_BTN_OK",btn_ok)
    local btn_esc = iup.button  {title="Cancel"}
    iup.SetHandle("CREATE_BTN_ESC",btn_esc)
    local btn_clear = iup.button  {title="Clear"}
    iup.SetHandle("CREATE_BTN_CLEAR",btn_clear)

    local vbox = iup.vbox{
        iup.hbox{iup.label{size='60x0'},cmbAll,iup.fill{}, cmbDdx,gap=20};
        iup.hbox{gap=20, alignment='ACENTER',
            iup.label{title="Left",size='60x0'},
            iup.label{title="Top",size='60x0'},
            iup.label{title="Width",size='60x0'},
            iup.label{title="Height",size='60x0'},
            iup.label{title="CptWidth",size='60x0'}
        };
        iup.hbox{txtX2,txtY2,txtW2,txtH2,txtCp,gap=20, alignment='ACENTER'};
        iup.hbox{btn_ok,iup.fill{},btn_clear,btn_esc},gap=2,margin="4x4" }

    dlg2 = iup.scitedialog{vbox; title=" онтрол √ритер",defaultenter="MOVE_BTN_OK",defaultesc="MOVE_BTN_ESC",maxbox="NO",minbox ="NO",resize ="NO",
    sciteparent="SCITE", sciteid="ctrlgreator"}
    dlg2.show_cb=(function(h,state)
        if state == 4 then
            dlg2:postdestroy()
        end
    end)
    function btn_clear:action()
            txtX2.value = ''
            txtY2.value = ''
            txtH2.value = ''
            txtW2.value = ''
            txtCp.value = ''
    end

    function btn_ok:action()

        s = s:gsub('position="%d+;%d+;%d+;%d+"', 'position="'..txtX2.value..';'..txtY2.value..';'..txtW2.value..';'..txtH2.value ..'"', 1):gsub('ЛFMCTLЫ', '')
        local bNoCapt = false
        if txtCp.active=='YES' then s = s:gsub('captionwidth="%d+"',
        function()
            if txtCp.value == '0' then
                txtCp.value = true
                return ''
            end
            return 'captionwidth="'..txtCp.value..'"'
        end) end
        if tonumber(txtCp.value) == 0 and (ctype ~= 'button' and ctype ~= 'label' and ctype ~= 'link' and ctype ~= 'checkbox') then
            s = s:gsub('caption=".-"', ''):gsub('caption_ru=".-"', '')
        end
        if bDdx then
            if cmbDdx.value == '1' then s = s:gsub('tag="ddx_Enabled=Y"', '') end
            if cmbDdx.value == '3' then s = s:gsub('"ddx_Enabled=', '"ddx_MetaBind=') end
            _G.iuprops['abbrev.ctrldlg.ddx'] = cmbDdx.value
        end

        replAbbr(findSt, findEnd, s, dInd)
        dlg2:postdestroy()
    end

    function btn_esc:action()
        dlg2:postdestroy()
    end
end

local function InsertAbbreviation(expan,dInd,curSel)
    local findSt = editor.SelectionStart
    --ћен€ем: вставл€ем наш селекшн, коммент в начале убираем,\r убираем, вставл€ем табы, вставл€ем новые строки
    local s =(expan:gsub('%%SEL%%', curSel):gsub('^%-%-.-\\n', ''):gsub('\\r', ''):gsub('\\t', '\t'):gsub('\\n', '\r\n'))
    local isForm
    s, isForm = s:gsub('Л(%w+)Ы',
    function(frm)
        if frm == 'FMCTL' then
            frmControlPos(findSt, editor.SelectionEnd, s, dInd)
        else
            print('Error: unknown abbrev form: '..frm)
        end
    end)
    if isForm > 0 then return end --запущена форма пользовательских параметров, по окончании она выполнит вставку текста
    replAbbr(findSt, editor.SelectionEnd, s, dInd)
end

local function TryInsAbbrev()
    local curSel = editor:GetSelText()
    local pos = editor.SelectionStart
    local lBegin = editor:textrange(editor:PositionFromLine(editor:LineFromPosition(pos)),pos)
	for i,v in ipairs(abbr_table) do
        if lBegin:sub(-v.abbr:len()):lower() == v.abbr:lower() then
            if curSel ~= "" then editor:ReplaceSel() end
            editor.SelectionStart = editor.SelectionStart - v.abbr:len()
            local dInd = lBegin:len() - v.abbr:len()
            InsertAbbreviation(v.exp,dInd, curSel)
            return
        end
	end
    print("Error Abbrev not found in: '"..lBegin.."'")
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
    abbr_table = ReadAbbrevFile(abbrev_filename)
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

local function Abbreviations_Init()
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
                    list_abbrev:hhhh(99)
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
        h.tip = s:gsub('\\r', ''):gsub('\\t', '\t'):gsub('\\n', '\r\n')
    end)


	list_abbrev.keypress_cb = (function(_, key, press)
        if press == 0 then return end
        if key == 13 then  --enter
            Abbreviations_InsertExpansion()
        end
	end)

    SideBar_obj.Tabs.abbreviations = {
        handle = list_abbrev;
        OnSwitchFile = Abbreviations_ListFILL;
        OnSave = Abbreviations_ListFILL;
        OnOpen = Abbreviations_ListFILL;
        OnMenuCommand = (function(msg) if msg == IDM_ABBREV then TryInsAbbrev() return true;end end);
        on_SelectMe = (function()  Abbreviations_ListFILL();end)
        }
end

Abbreviations_Init()

