local myId = "Abbrev/Bmk"
local list_abbrev

local list_bookmarks
local Abbreviations_USECALLTIPS = tonumber(props['sidebar.abbrev.calltip']) == 1
local isEditor = false
local prevLexer = -1
local abbr_table
local bListModified = false

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

local function lpegCtrlParser()
	--@todo: переписать с использованием lpeg.Cf
    local P, V, Cg, Ct, Cc, S, R, C, Carg, Cf, Cb, Cp, Cmt = lpeg.P, lpeg.V, lpeg.Cg, lpeg.Ct, lpeg.Cc, lpeg.S, lpeg.R, lpeg.C, lpeg.Carg, lpeg.Cf, lpeg.Cb, lpeg.Cp, lpeg.Cmt

	local PosToLine = function (pos) return editor:LineFromPosition(pos-1) end

--v------- common patterns -------v--
	-- basics
	local EOF = P(-1)
	local BOF = P(function(s,i) return (i==1) and 1 end)
	local NL = P"\n"-- + P"\f" -- pattern matching newline, platform-specific. \f = page break marker
	local AZ = R('AZ','az')+"_"
	local N = R'09'
	local ANY =  P(1)
	-- simple tokens
	local IDENTIFIER = AZ * (AZ+N)^0 -- simple identifier, without separators


	local cp = Cp() -- pos capture, Carg(1) is the shift value, comes from start_code_pos
	local cl = cp/PosToLine -- line capture, uses editor:LineFromPosition
--^------- common patterns -------^--
    local    function addAny(p,l)
        return p*S(l:lower()..l:upper())
    end
    local toAny = Cf(C(P'')*C(P(1))^1,addAny)
	local function AnyCase(str)
		return toAny:match(str)
	end



		-- redefine common patterns
		local SPACE = (S(" \t"))^1
		local SC = SPACE
		local NL = (P"\r\n")^1*SC^0

        local dig=C(N^1)
        local pos=Ct(Cg(dig,'x')*P';'*Cg(dig,'y')*P';'*Cg(dig,'w')*P';'*Cg(dig,'h'))

        local attr = Cg(Cmt(SC^1*C(IDENTIFIER)*P'="'*C(P(1-P'"')^0)*P'"',
            function(i,a,p,v)
                if p=='position' then
                    return true,p,pos:match(v,1)
                elseif p=='tag' then
                    return true,'isref',v:find('ddx_ContainerType=Ref')
                else
                    return true,p,v
                end end
            ))
        local attrs = Cf(Ct("") * attr^1*Cg(Cc('isAttr')*Cc(true))*Cg(Cc('inLine')*cl), rawset)
	    local attrsl = Cf(Ct("") * attr^1, rawset)
        local cont=SC^0*AnyCase"<control"
        local ce=Cf(Ct("")*SC^0*AnyCase"</control"*Cg(Cc('inLine')*cl), rawset)
        local ctrl = cont*attrsl*P'/>'*NL

		local def = P{Ct(cont*attrs*SC^0*P'>'*(V(1) + (-ce)*(1-NL)^1 + NL)^0*ce) +ctrl}
		-- resulting pattern, which does the work

		local patt = (def + (1-NL)^1 + NL)^0 * EOF
    return  lpeg.Ct(patt)
end
  local containers = {}
local function Ctrl(s)
    return iup.GetDialogChild(containers[2],s)
end
local function create_dialog_Ref()


  containers[4] = iup.hbox{
    iup.label{
      size = "60x0", title = "Left",
    },
    iup.label{
      size = "60x0", title = "Top",
    },
    iup.label{
      size = "60x0", title = "Height",
    },
    iup.label{
      size = "60x0", title = "Dh",
    },
    gap = "20",
    alignment = "ACENTER",
  }

  containers[5] = iup.hbox{
    iup.list{
      visibleitems = "15", size = "60x0", editbox = "YES", name = "cmbX", mask = "/d+", dropdown = "YES",
    },
    iup.text{
      size = "60x0", name = "numY", mask = "/d+",
    },
    iup.text{
      size = "60x0", name = "numH", mask = "/d+",
    },
    iup.text{
      size = "60x11", name = "numDh", mask = "/d+",
    },
    gap = "20",
    alignment = "ACENTER",
  }

  containers[6] = iup.hbox{
    iup.toggle{
      title = "btn1", name = "chkBtn1",size = "60x0",
    },
    iup.list{
      visibleitems = "15", size = "60x0", editbox = "YES", name = "cmbBtn1", mask = "/d+", dropdown = "YES",
    },
    iup.toggle{
      title = "Code", name = "chkCode", size = "60x0",
    },
    iup.list{
      visibleitems = "15", size = "60x0", editbox = "YES", name = "cmbCode", mask = "/d+", dropdown = "YES",
    },
    gap = "20",
  }

  containers[8] = iup.hbox{
    iup.toggle{
      title = "Name", name = "chkName",size = "60x0",
    },
    iup.list{
      visibleitems = "15", size = "60x0", editbox = "YES", name = "cmbName", mask = "/d+", dropdown = "YES",
    },
    iup.toggle{
      title = "btn2", name = "chkBtn2", size = "60x0",
    },
    iup.toggle{
      title = "Info", name = "chkInfo",
    },
    gap = "20",
  }

  containers[9] = iup.hbox{
    iup.button{
      title = "OK",
      name = "btnOK"
    },
    iup.fill{
    },
    iup.button{
      title = "Clear",
      action = function()
        Ctrl("cmbBtn1").value = ""
        Ctrl("cmbX").value = ""
        Ctrl("cmbCode").value = ""
        Ctrl("cmbName").value = ""
        Ctrl("numDh").value = ""
        Ctrl("numH").value = ""
        Ctrl("numY").value = ""
      end
    },
    iup.button{
      title = "Cancel",
      name = "btnEsc"
    },
  }
   containers[2] = iup.vbox{
    containers[4],
    containers[5],
    containers[6],
    containers[8],
    containers[9],
    margin = "4x4",
    gap = "2",
  }
  return containers[2]
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

local function refControlPos(findSt, findEnd, s, dInd)
    tblXml = lpegCtrlParser():match(editor:GetText(),1)
    local icL = editor:LineFromPosition(editor.CurrentPos)
--debug_prnTb(tblXml,0)
    local Lines = {}
    for w in s:gmatch("[^\n]+") do
       table.insert(Lines,w)
    end
    local defSizes = {}
    for i = 1, 6 do
        defSizes[i] = {}
        _,_,defSizes[i].x,defSizes[i].w,defSizes[i].h = Lines[i]:find('position="(%d+);%d+;(%d+);(%d+)"')
    end

    --debug_prnTb(defSizes, 1)
    local CtrlX, CtrlBtn1W, CtrlCodeW,CtrlNameW = {},{},{},{}
    local CtrlX1, CtrlBtn1W1, CtrlCodeW1,CtrlNameW1 = {},{},{},{}
    CtrlX[defSizes[1].x] = defSizes[1].x
    CtrlBtn1W[defSizes[2].w] = defSizes[2].w
    CtrlCodeW[defSizes[3].w] = defSizes[3].w
    CtrlNameW[defSizes[4].w] = defSizes[4].w

    local iPl,iPY,iPpY, iPX = 0,0,0,0
    local iTmpX,iTmpY,iTmpYp = 0,0, 0

    for k,v in pairs(tblXml) do
        if v.inLine then
            local l = tonumber(v.inLine)
            if l> iPl and l < icL then
                iPX = v.position.x + v.position.w
                iPY = v.position.y + v.position.h
                iPpY = v.position.y
                iPl = l
            end
        end
        if v.position then
            CtrlX[''..v.position.x] = v.position.x
        end
        for ind,arg in pairs(v) do

            if arg.inLine and arg.isAttr ~= true then
                local l = tonumber(arg.inLine)
                if l> iPl and l < icL then
                    iPX = iTmpX
                    iPY = iTmpY
                    iPpY = iTmpYp
                    iPl = l
                end
            end
            if arg.position then
                if arg.isAttr == true then
                    iTmpX = arg.position.x + arg.position.w
                    iTmpY = arg.position.y + arg.position.h
                    iTmpYp = arg.position.y
                    CtrlX[''..arg.position.x] = arg.position.x
                elseif arg.name == 'btn1' then
                    CtrlBtn1W[''..arg.position.w] = tonumber(arg.position.w)
                elseif arg.name == 'Code' then
                    CtrlCodeW[''..arg.position.w] = arg.position.w
                elseif arg.name == 'Name' then
                    CtrlNameW[''..arg.position.w] = arg.position.w
                end
            end
        end
    end
    for s, i in pairs(CtrlX) do table.insert(CtrlX1,(i)) end
    for s, i in pairs(CtrlBtn1W) do table.insert(CtrlBtn1W1,(i)) end
    for s, i in pairs(CtrlCodeW) do table.insert(CtrlCodeW1,(i)) end
    for s, i in pairs(CtrlNameW) do table.insert(CtrlNameW1,(i)) end

    table.sort(CtrlX1)
    table.sort(CtrlBtn1W1)
    table.sort(CtrlCodeW1)
    table.sort(CtrlNameW1)

    local templ = create_dialog_Ref()

    Ctrl('chkBtn1').value = _G.iuprops['abbrev.refdlg.b1'] or 'ON'
    Ctrl('chkCode').value = _G.iuprops['abbrev.refdlg.b2'] or 'ON'
    Ctrl('chkName').value = _G.iuprops['abbrev.refdlg.b3'] or 'ON'
    Ctrl('chkBtn2').value = _G.iuprops['abbrev.refdlg.b4'] or 'ON'
    Ctrl('chkInfo').value = _G.iuprops['abbrev.refdlg.b5'] or 'ON'
    Ctrl('numH').value = _G.iuprops['abbrev.refdlg.h'] or 12
    Ctrl('numDh').value = _G.iuprops['abbrev.refdlg.dh'] or 2

    local bInPrev = (iPl+1==icL)
    iPY = iPY + Ctrl('numDh').value
    iPX = iPX + 10

    local iNewX = -1
    local l = 1
    for i, s in pairs(CtrlX1) do if tonumber(s) > 0
        then iup.SetAttribute(Ctrl("cmbX"), l, s);l=l+1 end
        if iNewX < 0 and iPX <= tonumber(s) then iNewX = tonumber(s) end
    end
    if iNewX < 0 then iNewX = iPX end
    l = 1
    for i, s in pairs(CtrlBtn1W1) do if tonumber(s) > 0 then iup.SetAttribute(Ctrl("cmbBtn1"), l, s);l=l+1 end end
    l = 1
    for i, s in pairs(CtrlCodeW1) do if tonumber(s) > 0 then iup.SetAttribute(Ctrl("cmbCode"), l, s);l=l+1 end end
    l = 1
    for i, s in pairs(CtrlNameW1) do if tonumber(s) > 0 then iup.SetAttribute(Ctrl("cmbName"), l, s);l=l+1 end end

    Ctrl("cmbX").value = 1; Ctrl("cmbBtn1").value = CtrlBtn1W1[1]..''; Ctrl("cmbCode").value = CtrlCodeW1[1]; Ctrl("cmbName").value = CtrlNameW1[1]
    if bInPrev then
        Ctrl('cmbX').value = iPX..''
        Ctrl('numY').value = iPpY..''
    else

        Ctrl('cmbX').value = '10'
        Ctrl('numY').value = iPY..''
    end
    iup.SetHandle("RG_BTN_ESC", Ctrl('btnEsc'))
    iup.SetHandle("RG_BTN_OK", Ctrl('btnOK'))

    local dlg = iup.scitedialog{templ; title="–еф √ритер",defaultenter="RG_BTN_OK",defaultesc="RG_BTN_ESC",tabsize=editor.TabWidth,
        maxbox="NO",minbox ="NO",resize ="YES",shrink ="YES",sciteparent="SCITE", sciteid="abbreveditor"}

    dlg.show_cb=(function(h,state)
        if state == 4 then
            dlg:postdestroy()
        end
    end)
    Ctrl("btnEsc").action = function()
        dlg:postdestroy()
    end

    Ctrl("btnOK").action = function()
        local s = ''
        local x = 0
        local h = tonumber(Ctrl('numH').value)
        if Ctrl('chkBtn1').value == 'ON' then
            s = s..Lines[2]:gsub('position="(%d+);(%d+);%d+;(%d+)"', 'position="%1;%2;'..Ctrl('cmbBtn1').value..';'..h..'"', 1)
            x = x + tonumber(Ctrl('cmbBtn1').value)
        end
        if Ctrl('chkCode').value == 'ON' then
            s = s..Lines[3]:gsub('position="(%d+);(%d+);%d+;(%d+)"', 'position="'..x..';%2;'..Ctrl('cmbCode').value..';'..h..'"', 1)
            x = x + tonumber(Ctrl('cmbCode').value)
        end
        if Ctrl('chkName').value == 'ON' then
            x = x + defSizes[4].x - defSizes[3].x - defSizes[3].w
            s = s..Lines[4]:gsub('position="(%d+);(%d+);%d+;(%d+)"', 'position="'..x..';%2;'..Ctrl('cmbName').value..';'..h..'"', 1)
            x = x + tonumber(Ctrl('cmbName').value)
        end
        if Ctrl('chkBtn2').value == 'ON' then
            x = x + defSizes[5].x - defSizes[4].x - defSizes[4].w
            s = s..Lines[5]:gsub('position="%d+;(%d+);(%d+);(%d+)"', 'position="'..x..';%1;'..h..';'..h..'"', 1)
            x = x + h
        end
        if Ctrl('chkInfo').value == 'ON' then
            x = x + defSizes[6].x - defSizes[5].x - defSizes[5].w
            s = s..Lines[6]:gsub('position="%d+;(%d+);(%d+);(%d+)"', 'position="'..x..';%1;%2;'..h..'"', 1)
            x = x + defSizes[6].w + defSizes[6].x - defSizes[5].x- defSizes[5].w
        end
        s = s..Lines[7]:gsub('ЛREFCTLЫ', '')

        s = Lines[1]:gsub('position="%d+;%d+;%d+;%d+"', 'position="'..Ctrl('cmbX').value..';'..Ctrl('numY').value..';'..x..';'..Ctrl('numH').value..'"', 1)..'\n'..s
        _G.iuprops['abbrev.refdlg.b1'] = Ctrl('chkBtn1').value
        _G.iuprops['abbrev.refdlg.b2'] = Ctrl('chkCode').value
        _G.iuprops['abbrev.refdlg.b3'] = Ctrl('chkName').value
        _G.iuprops['abbrev.refdlg.b4'] = Ctrl('chkBtn2').value
        _G.iuprops['abbrev.refdlg.b5'] = Ctrl('chkInfo').value
        _G.iuprops['abbrev.refdlg.h'] = Ctrl('numH').value
        _G.iuprops['abbrev.refdlg.dh'] = Ctrl('numDh').value

        replAbbr(findSt, findEnd, s, dInd)
        dlg:postdestroy()
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

local function frmControlPos(findSt, findEnd, s, dInd)
    --показываем диалог позиционировани€ контролов
    local dlg2 = _G.dialogs["ctrlgreator"]
    if dlg2 ~= nil then return end --один экземпл€р уже показан
    local tX, tW, tCpt, tA = {},{},{},{}
    local tX1, tW1, tCpt1, tA1 = {},{},{}, {}
    --создаем контролы
    local txtX2 = iup.list{size='60x0',dropdown="YES",editbox="YES",mask="/d+",visibleitems="15"}
    local txtY2 = iup.text{size='60x0',mask="/d+"}
    local txtH2 = iup.text{size='60x0',mask="/d+"}
    local txtW2 = iup.list{size='60x0',dropdown="YES",editbox="YES",mask="/d+",visibleitems="15"}

    local _,_, ctype = s:find('type="(%l+)"')
    local txtCp = iup.list{size='60x0',dropdown="YES",editbox="YES",mask="/d+",visibleitems="15"}
    local function onCmbAll(h)
        if tA1 == nil then return end
        if #tA1 == 0 then return end
        txtX2.value = tA1[tonumber(h.value)][2][1]
        txtW2.value = tA1[tonumber(h.value)][2][2]
        txtCp.value = tA1[tonumber(h.value)][2][3]
    end
    local cmbAll = iup.list{size='60x0',dropdown="YES",visibleitems="15",valuechanged_cb = onCmbAll}
    local function onTxtX2(h,text, item, state)
            local n = tonumber(text)
            for i, s in pairs(tA1) do if tonumber(s[2][1]) >= n then cmbAll.value=i;break;end end
        end
    txtX2.action = onTxtX2
    local txtDx = iup.text{size='35x0',mask="/d+"}
    local bDdx = s:find('tag="ddx_Enabled=Y"')
    local cmbDdx = iup.list{dropdown="YES",visibleitems="5",active=Iif(bDdx, 'YES', 'NO'), value=Iif(bDdx, _G.iuprops['abbrev.ctrldlg.ddx'] or 0, 0)}
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
    txtH2.value = _G.iuprops['abbrev.ctrldlg.h'] or '11'
    txtDx.value = _G.iuprops['abbrev.ctrldlg.dh'] or '1'
    i,i,txtX2.value,txtY2.value,txtW2.value=s:find('position="(%d+);(%d+);(%d+);%d+"')
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
                local _,_,x,y,w,h = sl:find('position="(%d+);(%d+);(%d+);(%d+)"')
                if onSameLine then
                    txtY2.value = y
                    txtX2.value = ''..(tonumber(x or 0) + tonumber(w or 0))
                else
                    txtY2.value = '' ..(tonumber(y or 0) + tonumber(h or 0) + tonumber(txtDx.value or 0))
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
        iup.hbox{iup.label{size='60x0'},cmbAll,iup.label{title='dH'},txtDx,iup.fill{}, cmbDdx,gap=20};
        iup.hbox{gap=20, alignment='ACENTER',
            iup.label{title="Left",size='60x0'},
            iup.label{title="Top",size='60x0'},
            iup.label{title="Width",size='60x0'},
            iup.label{title="Height",size='60x0'},
            iup.label{title="CptWidth",size='60x0'}
        };
        iup.hbox{txtX2,txtY2,txtW2,txtH2,txtCp,gap=20, alignment='ACENTER'};
        iup.hbox{btn_ok,iup.fill{},btn_clear,btn_esc},gap=2,margin="4x4" }

    dlg2 = iup.scitedialog{vbox; title=" онтрол √ритер",defaultenter="CREATE_BTN_OK",defaultesc="CREATE_BTN_ESC",maxbox="NO",minbox ="NO",resize ="NO",
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
            s = s:gsub(' caption=".-"', ''):gsub(' caption_ru=".-"', '')
        end
        if bDdx then
            if cmbDdx.value == '1' then s = s:gsub('tag="ddx_Enabled=Y"', '') end
            if cmbDdx.value == '3' then s = s:gsub('"ddx_Enabled=', '"ddx_MetaBind=') end
            if cmbDdx.value ~= '3' then s = s:gsub(' style="F"', '') end
            _G.iuprops['abbrev.ctrldlg.ddx'] = cmbDdx.value
        end
        _G.iuprops['abbrev.ctrldlg.h'] = txtH2.value
        _G.iuprops['abbrev.ctrldlg.dh'] = txtDx.value

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
        elseif frm == 'REFCTL' then
            refControlPos(findSt, editor.SelectionEnd, s, dInd)
        else
            print('Error: unknown abbrev form: '..frm)
        end
    end)
    if isForm > 0 then return end --запущена форма пользовательских параметров, по окончании она выполнит вставку текста
    replAbbr(findSt, editor.SelectionEnd, s, dInd)
end

local function TryInsAbbrev(bClip)
    if not abbr_table then return end
    local curSel
    if bClip then
        local cpb = iup.clipboard{};
        curSel = iup.GetAttribute(cpb, "TEXT")
        iup.Destroy(cpb)
    else curSel = editor:GetSelText() end

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
        h.tip = s:gsub('\\r', ''):gsub('\\t', '\t'):gsub('\\n', '\r\n')
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
