
----------------------------------------------------------
-- tab0:memo_path   Path and Mask
----------------------------------------------------------

local txt_Template
local txt_BaseNameSuffix
local txt_RadiusUserName
-- local cmb_resent
local chk_DebugMode, btn_FormRun, btn_AddDoc
local ToolBar_obj

local function template_MoveControls()
    local dlg2 = _G.dialogs["ctrlmoover"]
    if dlg2 == nil then

        local txtX2 = iup.text{size='60x0',mask="[+/-]?/d+"}
        local txtY2 = iup.text{size='60x0',mask="[+/-]?/d+"}
        local txtH2 = iup.text{size='60x0',mask="[+/-]?/d+"}
        local txtW2 = iup.text{size='60x0',mask="[+/-]?/d+"}
        local txtX1 = iup.text{size='60x0',mask="[><]?/d+[><]?/d*"}
        local txtY1 = iup.text{size='60x0',mask="[><]?/d+[><]?/d*"}
        local txtH1 = iup.text{size='60x0',mask="[><]?/d+[><]?/d*"}
        local txtW1 = iup.text{size='60x0',mask="[><]?/d+[><]?/d*"}
        local txtCp = iup.text{size='60x0',mask="[+/-]?/d+"}

        local flag2 = 0

        local btn_ok = iup.button  {title="OK"}
        iup.SetHandle("MOVE_BTN_OK",btn_ok)
        local btn_esc = iup.button  {title="Cancel"}
        iup.SetHandle("MOVE_BTN_ESC",btn_esc)
        local btn_clear = iup.button  {title="Clear"}
        iup.SetHandle("MOVE_BTN_CLEAR",btn_clear)

        local vbox = iup.vbox{
            iup.hbox{iup.label{title="Left",size='60x0'},iup.label{title="Top",size='60x0'},iup.label{title="Width",size='60x0'},iup.label{title="Height",size='60x0'},iup.label{title="CptWidth",size='60x0'},gap=20, alignment='ACENTER'},
            iup.hbox{txtX1,txtY1,txtW1,txtH1,gap=20, alignment='ACENTER'},
            iup.hbox{txtX2,txtY2,txtW2,txtH2,txtCp,gap=20, alignment='ACENTER'},
            iup.hbox{btn_ok,iup.fill{},btn_clear,btn_esc},gap=2,margin="4x4" }


        dlg2 = iup.scitedialog{vbox; title="Контрол Мувер",defaultenter="MOVE_BTN_OK",defaultesc="MOVE_BTN_ESC",maxbox="NO",minbox ="NO",resize ="NO",
        sciteparent="SCITE", sciteid="ctrlmoover"}

        function btn_clear:action()
                txtX2.value = ''
                txtY2.value = ''
                txtH2.value = ''
                txtW2.value = ''
                txtX1.value = ''
                txtY1.value = ''
                txtH1.value = ''
                txtW1.value = ''
                txtCp.value = ''
        end

        function btn_ok:action()
            local function InpValue(t)
                str = t.value
                if str.."" == "" then str = "%d*" end
                if str:find("[<>]") ~= nil then str = "%d+" end
                return "("..str..")"
            end
            local strtempl = 'position="'..InpValue(txtX1)..';'..InpValue(txtY1)..';'..InpValue(txtW1)..';'..InpValue(txtH1)..'"([^\n]*)'
            local iLevel = 0
            local strout = editor:GetSelText():gsub("[^\n]+",function(s)
                local strrow = s
                if s:find('<control') then
                    if iLevel == 0 then
                        strrow = s:gsub(strtempl,function(s1,s2,s3,s4,tt)
                            local function f(s,c)
                                if s=="" then return "" end
                                if c.value:len() == 0 then return s end
                                local sval = c.value:sub(2)
                                if sval == nil then sval = 1 end
                                local sign = c.value:sub(0,1)
                                if sign == "-" then return s*1 - sval*1 end
                                if sign == "+" then return s+sval end
                                return c.value
                            end
                            local function ch(s,c)
                                if s=="" then return true end
                                local z1,n1,z2,n2
                                z1,n1,z2,n2=c.value:match("([><]?)(%d+)([><]?)(%d*)")
                                if z1 ~= nil  then
                                    if n1 == nil then n1 = 0 end
                                    if z1 == "<" and s*1 > n1*1 then return false end
                                    if z1 == ">" and s*1 < n1*1 then return false end
                                    if z2.."" ~= "" then
                                        if n2 == nil then n2 = 0 end
                                        if z2 == "<" and s*1 > n2*1 then return false end
                                        if z2 == ">" and s*1 < n2*1 then return false end
                                    end
                                end
                                return true
                            end
                            if ch(s1,txtX1) and ch(s2,txtY1) and ch(s3,txtW1) and ch(s4,txtH1) then
                                local tt2 = tt:gsub('captionwidth="(%d+)"', function(cw)
                                    return 'captionwidth="'..f(cw,txtCp)..'"'
                                    end
                                )
                                return 'position="'..f(s1,txtX2)..';'..f(s2,txtY2)..';'..f(s3,txtW2)..';'..f(s4,txtH2)..'"'..tt2
                            else
                                return 'position="'..s1..';'..s2..';'..s3..';'..s4..'"'..tt
                            end
                        end)
                    end
                if not s:find('/>') then iLevel = iLevel + 1 end
                elseif s:find('</control') then
                    iLevel = iLevel - 1
                end
                return strrow
            end)

            editor:ReplaceSel(strout)
            dlg2:hide()
        end

        function btn_esc:action()
            dlg2:hide()
        end
    else
        dlg2:show()
    end
end

menuhandler:InsertItem('MainWindowMenu', 'Edit¦Xml¦xxx',
{'FindTextOnSel', plane=1,{
    {'s_FindTextOnSel', separator=1},
    {'Move Controls...',  ru = 'Переместить контролы...', action=template_MoveControls, key = 'Alt+M', active='editor:LineFromPosition(editor.SelectionStart) ~= editor:LineFromPosition(editor.SelectionEnd)'},
}})

function listCalc_addToRecent(strFile)
    cmb_resent.insertitem1 = strFile
    cmb_resent.value = 1

    local i = tonumber(cmb_resent.count)
	while(i > 1) do
		if(iup.GetAttribute(cmb_resent,i) == strFile) then
			cmb_resent.removeitem = i
		end
        i = i - 1
	end
end

function listCalc_CompileSelectedTemplate()
    listCalc_addToRecent(props['precompiller.xmlname'])
    precomp_doCompile()
end

local function SSCtrls()
    if props["FileExt"]:lower() == props['formenjine.xml'] then btn_AddDoc.active='YES'
    else  btn_AddDoc.active='NO' end

    if tonumber(cmb_resent.count) ~= 0 then btn_FormRun.active = 'YES'
    else btn_FormRun.active = 'NO' end
end

local function OnSwitch()
    if ToolBar_obj.handle ~= nil then ToolBar_obj.handle.size = ToolBar_obj.size end
    if editor.Lexer == SCLEX_FORMENJINE then
        ToolBar_obj.Tabs.template.handle.state = 'OPEN'
    else
        ToolBar_obj.Tabs.template.handle.state = 'CLOSE'
    end
    SSCtrls()
end

local function Init(h)

    TEMPLATES = {}
    dofile (props["SciteDefaultHome"].."\\tools\\Etc\\precompiller.lua")
    local SPS = lpeg.S'\n \t\r\f'^0
    local XDIG = lpeg.R'09' + lpeg.R'af' + lpeg.R'AF'
    local CLR = lpeg.P'<' * (lpeg.P'control' + lpeg.P'frame') * (1 - lpeg.S'<>'- lpeg.P'color')^1 * lpeg.P'color' * SPS * "=" * SPS * '"' * lpeg.P'#'^- 1 * lpeg.C(XDIG * XDIG * XDIG * XDIG * XDIG * XDIG) *lpeg.P'"'
    local tmPlClr = lpeg.Ct(lpeg.P{CLR + 1 * lpeg.V(1)}^1)
    local NAME = lpeg.P'<control' * (1 - lpeg.S'<>'- lpeg.P'name')^1 * lpeg.P'name' * SPS * "=" * SPS * '"' * lpeg.C((1 - lpeg.S'"<>')^1) * lpeg.P'"'
    local tmPlCtrl = lpeg.Ct(lpeg.P{NAME + 1 * lpeg.V(1)}^1)

    function TEMPLATES.colors()
        local tClr = tmPlClr:match(editor:GetText(), 1)
        return table.concat(tClr or {}, '|')
    end

    function TEMPLATES.controls()
        local tClr = tmPlCtrl:match(editor:GetText(), 1)
        return table.concat(tClr or {}, '|')
    end

    ToolBar_obj = h
	if _G.iuprops['precompiller.radiususername'] == nil then _G.iuprops['precompiller.radiususername'] = '' end
	txt_RadiusUserName = iup.text{expand='NO',size='70x0', tip='Имя пользователя Radius\nЕсли у пользователя открыта форма DebugTools,\nто собранный шаблон перезарузится'}
	txt_RadiusUserName.map_cb=(function(h)h.value = _G.iuprops['precompiller.radiususername'] end)
    txt_RadiusUserName.valuechanged_cb=(function(h) _G.iuprops['precompiller.radiususername'] = h.value end)

    chk_DebugMode = iup.toggle{title = "Dbg Mode",
                        action=(function(h) _G.iuprops['precompiller.debugmode'] = Iif(h.value == 'ON', 1, 0); props['precompiller.debugmode'] = _G.iuprops['precompiller.debugmode'] end), tip="Если включено, то в собранном шаблоне будут раскоментированы\nстроки, начинающиеся с '#DEBUG\n(может использоваться для вывода отладочной трассировки)"}
    chk_DebugMode.map_cb=(function(h) if _G.iuprops['precompiller.debugmode'] == 1 then h.value = 'ON' end; props['precompiller.debugmode'] = _G.iuprops['precompiller.debugmode'] end)

    cmb_resent = iup.list{dropdown="YES",visibleitems="15", expand='NO', size='150x0',
            action=(function(h, text, item, state) props['precompiller.xmlname'] = text end), tip='Файл для компиляции.\n(Выбор из последних скомпилированных файлов)'}

    btn_AddDoc = iup.button{image = 'IMAGE_AddDocument',bgcolor={0,0,0}, action=(function() iup.PassFocus();precomp_PreCompileTemplate();SSCtrls() end), tip='Проверить текущий шаблон XML на наличие\nошибок и добавить его в данный список(F7)\nдля возможной последующей сборки'}
    btn_FormRun = iup.button{image = 'IMAGE_FormRun', action=listCalc_CompileSelectedTemplate, tip='Собрать выбранный шаблон и отправить\nего по мессаджбасу в Radius'}
    ToolBar_obj.Tabs.template =  {
        handle =iup.expander{iup.hbox{   iup.label{title = "User:"},
                            txt_RadiusUserName,
                            chk_DebugMode,
                            iup.label{title = "Template:"},
                            btn_AddDoc;
                            cmb_resent,
                            btn_FormRun,
                            iup.button{image = 'IMAGE_AlignToGridHS', action=(function() iup.PassFocus();template_MoveControls() end), tip='Диалог позиционирования контролов(Alt+M)'};
                            iup.button{image = 'IMAGE_FormatBasic', action=(function() iup.PassFocus();IndentBlockUp() end), tip='Форматироваине кода на Бэйсик(Ctrl+{)\nЕсли курсор находится в коные строки, закрывающий блок(End If, Next, End Sub...)\nто этот блок будет отформатирован по нашим стандартам'};
                            alignment="ACENTER"
                        };
                        barposition='LEFT',
                        barsize='0',
                        state='CLOSE'
                    };
                    OnSwitchFile = OnSwitch;
                    OnOpen = OnSwitch;
                    OnSave = SSCtrls;
                }
end

return {
    title = 'Шаблоны  Systematica',
    code = 'template',
    toolbar = Init,
    description = [[Работа с FormEnjine шаблонами]]
}



