local txtCol, txtSel, lblSel, txtLine, lblCode
local isColor = false
local needCoding = false

local function ColorDlg()
    local txtCol, txtSel, lblSel, txtLine
    local t = editor:GetText()
    local tc={};tc['0 0 0']=true;tc['255 255 255']=true
    for r,g,b in t:gmatch('["#](%x%x)(%x%x)(%x%x)[%W]') do
        tc[((('0x'..r)+0)..' '..(('0x'..g)+0)..' ' ..(('0x'..b)+0))] = true
    end
    for r,g,b in t:gmatch('RGB%( *&H(%x%x)[, ]+&H(%x%x)[, ]+&H(%x%x)') do
        tc[((('0x'..r)+0)..' '..(('0x'..g)+0)..' ' ..(('0x'..b)+0))] = true
    end
    for r,g,b in t:gmatch('RGB%( *([0-9]+)[, ]+([0-9]+)[, ]+([0-9]+)') do
       tc[r..' '..g..' '..b] = true
    end
    local tc2={}
    for c, _ in pairs(tc) do
        table.insert(tc2,c)
    end
    local txtSample, clp, clb,txtOutB,txtOutF,txtT,txtG,txtB
    local nTip,nCel, cB,cF = -1,0
    local function StaticControls()
        local prim,sec,r,g,b = iup.GetAttributeId(clp,'CELL',cF),iup.GetAttributeId(clp,'CELL',cB)
        txtSample.bgcolor = sec
        txtSample.fgcolor = prim
        local _,_,r,g,b = prim:find('([0-9]+) ([0-9]+) ([0-9]+)')
        txtOutF.value = string.format('RGB(%i, %i, %i)    #%02x%02x%02x',r,g,b,r,g,b)
        _,_,r,g,b = sec:find('([0-9]+) ([0-9]+) ([0-9]+)')
        txtOutB.value = string.format('RGB(%i, %i, %i)    #%02x%02x%02x',r,g,b,r,g,b)
        local c = Iif(nTip==-1,prim,sec)
    end
    local function ByTxt(h)
        local rgb=((('0x'..txtR.Value)+0)..' '..(('0x'..txtG.Value)+0)..' ' ..(('0x'..txtB.Value)+0))
        clb.rgb= rgb
        iup.SetAttributeId(clp,'CELL', nCel,rgb )
        StaticControls()
    end

    clb=iup.colorbrowser{}

    txtSample = iup.text{readonly='YES',value='some text some text some text ';expand='HORIZONTAL';maxsize=clb.rastersize;}
    txtOutF = iup.text{readonly='YES';expand='HORIZONTAL'}
    txtOutB = iup.text{readonly='YES';expand='HORIZONTAL'}
    txtR = iup.text{mask='[abcdef0-9][abcdef0-9]?';expand='NO';size='40x0', value='ff';action=ByTxt,valuechanged_cb=(function(h) if h.value=='' then h.value=0 end; end),}
    txtG = iup.text{mask='[abcdef0-9][abcdef0-9]?';expand='NO';size='40x0', value='00';action=ByTxt,valuechanged_cb=(function(h) if h.value=='' then h.value=0 end; end),}
    txtB = iup.text{mask='[abcdef0-9][abcdef0-9]?';expand='NO';size='40x0', value='00';action=ByTxt,valuechanged_cb=(function(h) if h.value=='' then h.value=0 end; end),}

    clp=iup.colorbar{num_parts=math.floor((#tc2)^0.5);num_cells=#tc2;show_secondary='YES';expand='NO';rastersize='260x200';
        select_cb = (function(h,cell,tp)
            local rgb = iup.GetAttributeId(h,'CELL',cell), tp
            nTip=tp
            nCel=cell
            if tp == -1 then cF = cell else cB = cell end
            clb.rgb= rgb
            local _,_,r,g,b = rgb:find('([0-9]+) ([0-9]+) ([0-9]+)')
            txtR.value = string.format('%02x',r)
            txtG.value = string.format('%02x',g)
            txtB.value = string.format('%02x',b)
            StaticControls()
        end)
    }

    for i, c in pairs(tc2) do
        iup.SetAttributeId(clp,'CELL', i-1, c)
    end
    clb.drag_cb=(function(h,r,g,b)
        iup.SetAttributeId(clp,'CELL', nCel,r..' '..g..' '..b )
        txtR.value = string.format('%02x',r)
        txtG.value = string.format('%02x',g)
        txtB.value = string.format('%02x',b)
        StaticControls()
    end)

    local dlg = iup.scitedialog{
        iup.hbox{
          iup.vbox{
            clb;
            iup.hbox{txtR;txtG;txtB};
            txtSample;txtOutF;txtOutB,
          expand='NO'};
        clp};
        title="Colors",defaultenter="MOVE_BTN_OK",defaultesc="MOVE_BTN_ESC",tabsize=editor.TabWidth,
        maxbox="NO",minbox ="NO",shrink ="YES",sciteparent="SCITE", sciteid="color",resize='NO',
        map_cb=(function() cB,cF=clp.secondary_cell,clp.primary_cell; StaticControls()end)}

    dlg.show_cb=(function(h,state)                             -- "#e0e0e0"  "999999"
        if state == 4 then
            dlg:postdestroy()
        end
    end)
end


local function ShowCurrentColour(pos, word)
	if pos ~= 0 then
		if word:match('%x%x%x%x%x%x') then
            local _,_,r,g,b= word:find('(%x%x)(%x%x)(%x%x)')
            lblSel.bgcolor = (('0x'..r)+0)..' '..(('0x'..g)+0)..' ' ..(('0x'..b)+0);isColor=true
		elseif word == 'RGB' then
            local le = editor:GetLine(editor:LineFromPosition(pos))     --[, ]+%)
            local f,_,r,g,b= le:find('RGB%( *([0-9]+)[, ]+([0-9]+)[, ]+([0-9]+)')
            if f then
                 lblSel.bgcolor = r..' '..g..' '..b ;isColor=true
            else
                f,_,r,g,b= le:find('RGB%( *&H(%x%x)[, ]+&H(%x%x)[, ]+&H(%x%x)')
                if f then
                    lblSel.bgcolor = (('0x'..r)+0)..' '..(('0x'..g)+0)..' ' ..(('0x'..b)+0) ;isColor=true
                end
            end
		elseif isColor then
            lblSel.bgcolor = iup.GetGlobal('DLGBGCOLOR') ;isColor=false
		end
    elseif isColor then
        lblSel.bgcolor = iup.GetGlobal('DLGBGCOLOR') ;isColor=false
	end
end

local function UpdateStatusCodePage(mode)
	if mode == nil then mode = props["editor.unicode.mode"] end
    mode = tonumber(mode)
	if mode == IDM_ENCODING_UCS2BE then
		return 'UTF-16 BE'
	elseif mode == IDM_ENCODING_UCS2LE then
		return 'UTF-16 LE'
	elseif mode == IDM_ENCODING_UTF8 then
		return 'UTF-8 BOM'
	elseif mode == IDM_ENCODING_UCOOKIE then
		return 'UTF-8'
	else
		if props["character.set"]=='255' then
			return 'DOS-866'
		elseif props["character.set"]=='204' then
			return 'WIN-1251'
		elseif tonumber(props["character.set"])==0 then
			return 'CP1252'
		elseif props["character.set"]=='238' then
			return 'CP1250'
		elseif props["character.set"]=='161' then
			return 'CP1253'
		elseif props["character.set"]=='162' then
			return 'CP1254'
		else
			return '???'
		end
	end
end

local function OnSwitch()
    lblCode.title = UpdateStatusCodePage()
    local t = 1000000
    if editor.Lexer ~= SCLEX_MSSQL then
        t = 200
    end
    iup.GetGlobal('DLGBGCOLOR')
    scite.SendEditor(SCI_SETMOUSEDWELLTIME, t)
    needCoding = (scite.SendEditor(SCI_GETCODEPAGE) ~= 0)
end

local function _OnUpdateUI()
    if not editor.Focus then return end

    txtCol.value = scite.SendEditor(SCI_GETCOLUMN, editor.CurrentPos) + scite.SendEditor(SCI_GETSELECTIONNANCHORVIRTUALSPACE, 0) + 1
    txtSel.value = editor.SelectionEnd - editor.SelectionStart
    txtLine.value = editor:LineFromPosition(editor.CurrentPos) + 1
end
local function GoToPos()
    OnNavigation("Go")
    local line = tonumber(txtLine.value) - 1
    local col = tonumber(txtCol.value) - 1
    local lineStart = editor:PositionFromLine(line)
    local ln = editor:PositionFromLine(line + 1) - 2 - lineStart
    if ln > col then
        editor:SetSel(lineStart + col, lineStart + col )
    else
        editor:SetSel(lineStart + ln, lineStart + ln)
        scite.SendEditor(SCI_SETSELECTIONNANCHORVIRTUALSPACE, 0, col-ln)
        scite.SendEditor(SCI_SETSELECTIONNCARETVIRTUALSPACE, 0, col-ln)
    end
    OnNavigation("Go-")
    iup.PassFocus()
end
local zbox_s;
local function FindTab_Init()
    local sTip = '(Ctrl+G) Нажмите Enter для перехода на позицию'
    txtCol = iup.text{size='25x'; mask='[0-9]*', tip=sTip,
             k_any=(function(_,c) if c == iup.K_CR then GoToPos() elseif c == iup.K_ESC then iup.PassFocus() end end)}
    txtLine = iup.text{size='25x'; mask='[0-9]*', tip=sTip,
             k_any=(function(_,c) if c == iup.K_CR then GoToPos() elseif c == iup.K_ESC then iup.PassFocus() end end)}
    txtSel = iup.text{size='25x'; readonly='YES', bgcolor=iup.GetGlobal('DLGBGCOLOR'), canfocus  = "NO"}
    lblCode = iup.label{size='50x'}
    lblSel = iup.text{size = '200x0'; readonly='YES',canfocus="NO", bgcolor=iup.GetGlobal('DLGBGCOLOR'),
        tip='Число вхождений выделенного слова',
        tips_cb=(function(h,x,y)
            h.tip='Число вхождений выделенного слова'..Iif(editor.Lexer == SCLEX_FORMENJINE,'\nПоказ цвета под курсором', '')
        end);
        button_cb = (function(h, but, pressed, x, y, status)
            if iup.isdouble(status) and iup.isbutton1(status) then
                ColorDlg()
            elseif iup.isbutton3(status) then
                local mnu = iup.menu
                {
                  iup.item{title="Открыть палитру",action=ColorDlg}
                }:popup(iup.MOUSEPOS,iup.MOUSEPOS)
              return -1
            end
        end)}
    local function onSpellContext(_,but, pressed, x, y, status)
        if but == 51 and pressed == 0 then --right

            local mnu = iup.menu
            {
              iup.item{title="Проверить выделенный фрагмент",action=spell_Selected},
              iup.item{title="Проверить фрагмент с учетом подсветки",action=spell_ByLex},
              iup.item{title="Показать список ошибок",action=spell_ErrorList},
            }:popup(iup.MOUSEPOS,iup.MOUSEPOS)
        end
    end
    local sTip='Режим автоматической проверки\nорфографии(Ctrl+Alt+F12)'
    zbox_s = iup.zbox{name = "Spelling_zbox",
        iup.button{image='IMAGE_CheckSpelling2';impress='IMAGE_CheckSpelling'; tip=sTip;canfocus="NO";
            map_cb=(function(_) if _G.iuprops["spell.autospell"] == "1" then zbox_s.valuepos=1 else zbox_s.valuepos=0 end end);
            action=(function(_) _G.iuprops["spell.autospell"] = "1"; zbox_s.valuepos=1 end);
            button_cb=onSpellContext;
        };
        iup.button{image='IMAGE_CheckSpelling';impress='IMAGE_CheckSpelling2'; tip=sTip;canfocus="NO";
            action=(function(_) _G.iuprops["spell.autospell"] = "0"; zbox_s.valuepos=0 end);
            button_cb=onSpellContext;
        };
    }
    StatusBar_obj.Tabs.statusbar = {
        handle = iup.hbox{
            iup.label{title='Line: '; fontstyle='Bold'};   --sdfds esvdf
            txtLine;
            iup.label{title='Colimn: '; fontstyle='Bold'};   --sdfds esvdf
            txtCol;
            iup.label{title='Selection: '; fontstyle='Bold'};
            txtSel;
            lblSel;
            zbox_s;
            expand='HORIZONTAL', minsize='200x', alignment='ACENTER',gap='8',margin='3x0' ,
            lblCode,
        };
        OnUpdateUI = _OnUpdateUI;
        OnDwellStart = ShowCurrentColour;
        OnOpen=OnSwitch;
        OnSwitchFile=OnSwitch;
        OnMenuCommand=(function(cmd, source)
            if cmd == IDM_GOTO then
                iup.SetFocus(txtLine)
                return true
            elseif cmd >= 150 and cmd <= 154 then
                lblCode.title = UpdateStatusCodePage(cmd)
            end
        end);
        SetFindRes = (function(what,count)
                            if count > 0 then
                                if needCoding then what = what:from_utf8(1251) end
                                lblSel.value=what..'   :'..count..' entry'
                            else lblSel.value=''
                    end end)
        }

end

FindTab_Init()


