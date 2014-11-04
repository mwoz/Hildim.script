
----------------------------------------------------------
-- tab0:memo_path   Path and Mask
----------------------------------------------------------


local cmb_listCalc

_G["SqlMap"] = nil


local function RunBatch(filePath)
    if props["output.hook"] == 'Y' then return end
	if editor.Lexer == SCLEX_MSSQL then
     print(cmb_listCalc.value)
		local inc =props["sys.calcsybase.dir"].."\\BuildM4\\"..iup.GetAttribute(cmb_listCalc, cmb_listCalc.value)
        local vbRun = props["SciteDefaultHome"].."\\tools\\RunSql.vbs"
        --local vbRun = props["sys.calcsybase.dir"].."\\RunSql.vbs"
        cmd = 'cscript //nologo "'..vbRun..'" "'..filePath..'" "'..props["sybase.projects.dir"]..'\\" "'..inc..'"'

        props["output.hook"] = 'Y'

		local p0 = props["command.1.*"]
		local p1 = props["command.mode.1.*"]
		props["command.name.1.*"] = 'tmp'
		props["command.1.*"] = cmd
		props["command.mode.1.*"] = 'subsystem:console'
        scite.MenuCommand(9001)

		props["command.1.*"] = p0
		props["command.mode.1.*"] = p1
	end
end
-- Возвращает текущий символ перевода строки
local function GetEOL()
	local eol = "\r\n"
	if editor.EOLMode == SC_EOL_CR then
		eol = "\r"
	elseif editor.EOLMode == SC_EOL_LF then
		eol = "\n"
	end
	return eol
end

function listCalc_SmartErrorMapping()
    local lineFrom,lineEnd
--Найдем самую Длинную строку
    local nLines = scite.SendEditor(SCI_GETLINECOUNT)
    local ml = 0
    local f1stLine = editor.FirstVisibleLine
    local startSel = editor.SelectionStart
    local endSel = editor.SelectionEnd
    lineFrom = editor:LineFromPosition(editor.SelectionStart)
    lineEnd = editor:LineFromPosition(editor.SelectionEnd)
    editor:BeginUndoAction()
    for i = 1, nLines,1 do
        local j = editor:LineLength(i)
        if j > ml then ml = j end
    end
    for i = nLines - 2, 0,-1 do
        local j = editor:LineLength(i)
        local strRep = string.rep(' ', ml - j)..'--&&'..(i+1)..'  '

        j = j + editor:PositionFromLine(i) - 2
        local st = editor.StyleAt[j]
        if st~= 4 and st ~= 8 and st~=16 then
            scite.SendEditor(SCI_SETTARGETSTART, j)
            scite.SendEditor(SCI_SETTARGETEND, j)
            editor:ReplaceTarget(strRep)
        end
    end
    editor:EndUndoAction()
    editor:SetSel(editor:PositionFromLine(lineFrom), scite.SendEditor(SCI_GETLINEENDPOSITION,lineEnd))
    local tmpF = io.open(props["SciteDefaultHome"]..'\\data\\tmpmap.sql', "w")
    local strText =editor:GetSelText():gsub(GetEOL(),"\n")

    _G["SqlMap"] = '?'
    tmpF:write(strText)
    tmpF:close()
    editor:Undo()

    editor.SelectionStart = startSel
    editor.SelectionEnd = endSel
    editor.FirstVisibleLine = f1stLine

    RunBatch(props["SciteDefaultHome"]..'\\data\\tmpmap.sql')

end

function listCalc_RunBatchWithSciTE()
    RunBatch(props["FilePath"])
end
function listCalc_RunBatchWithSciTESel()
    if props["output.hook"] == 'Y' then return end
	if editor.Lexer == SCLEX_MSSQL then

		tmpName=props["backup.path"]:gsub('[^\\]*$', "").."tmpsel.m"
		local strSel = editor:GetSelText():gsub(GetEOL(),"\n")
		local tmpFile = io.open(tmpName, "w")
		tmpFile:write(strSel)
		tmpFile:close()
        RunBatch(tmpName)

	end
end

local function _OnKey(key, shift, ctrl, alt, char)
	if shift and ctrl and alt and key == 82 then
        if  chk_RunConnect:get_checked() then
            if handle ~= nil then mblua.UnSubscribe() end
            mblua.Destroy()
            handle = nil
        end
	end
end

local function OnSwitch()
    if TabBar_obj.handle ~= nil then TabBar_obj.handle.size = TabBar_obj.size end
    if editor.Lexer == SCLEX_MSSQL then
        TabBar_obj.Tabs.m4.handle.state = 'OPEN'
    else
        TabBar_obj.Tabs.m4.handle.state = 'CLOSE'
    end
end

local function FindTab_Init()
    cmb_listCalc = iup.list{dropdown="YES",visible_items="15", expand='NO',size='120x0', tip='Список доступных вариантов для исполнения в базе (build)\nи компиляции в SQL (compile). \nФайлы нахлдятся в директории Scite\\data\\UserData\\BuildM4'  }
    cmb_listCalc.map_cb = (function(h) h.value=tonumber(_G.iuprops["sidebar.m4.value"] or '1'); end)
    TabBar_obj.Tabs.m4 = {

        handle = iup.expander{iup.hbox{
                    iup.label{title = "M4:"},
                    cmb_listCalc,
                    iup.button{image = 'IMAGE_FormRun', action=listCalc_RunBatchWithSciTE, tip='Обработка всего файла'},
                    iup.button{image = 'IMAGE_RunPart',action=listCalc_RunBatchWithSciTESel, tip='Обработка выделенного фрагмента'},
                    iup.button{image = 'IMAGE_WithLineNumber',action=listCalc_SmartErrorMapping, tip='Обработка выделенного фрагмента с нумерацией строк\nВ случае возникновения ошибок исполнения Scite более точно выделит ее в файле)'};
                    alignment="ACENTER"
                };
                barposition='LEFT',
                barsize='0'
            };
            OnSwitchFile = OnSwitch;
            OnOpen = OnSwitch;
            OnSideBarClouse=(function() _G.iuprops["sidebar.m4.value"]=cmb_listCalc.value; end)
        }
    cmb_listCalc:FillByDir("\\buildm4\\*.vbs", _G.iuprops['sql.compile.file'])
end

FindTab_Init()


