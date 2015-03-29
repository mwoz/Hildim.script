
----------------------------------------------------------
-- tab0:memo_path   Path and Mask
----------------------------------------------------------
require "mblua"
local myId = "Sybase"

local cmb_Subjects
local cmb_listMbTrancport
local chk_RunConnect

local handle = nil
_G["SqlMap"] = nil


local function RunBatch(filePath)
    if props["output.hook"] == 'Y' then return end
	if(editor.Lexer == SCLEX_MSSQL) then

		local inc =props["sys.calcsybase.dir"].."\\BuildM4\\"..cmb_listCalc:get_item_text(-2)
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

function listCalc_addToRecent(strFile)
    cmb_resent.insertitem1 = strFile
--[[	list_resent:insert_item(0, strFile, strFile)
	local i = 1
	while(i < list_resent:count()) do
		if(list_resent:get_item_text(i) == strFile) then
			list_resent:delete_item(i)
		else
			i = i + 1
		end
	end]]
end

function UserScriptHandler(handle,Opaque,iError,msgReplay)
    scite.Open(props["SciteDefaultHome"]..'\\data\\USERSCRIPT.'..props['formenjine.inc'])
    editor:SetText(msgReplay:GetPathValue('Script'))
end

function listCalc_RunBatchWithSciTE()
    RunBatch(props["FilePath"])
end
function listCalc_RunBatchWithSciTESel()
    if props["output.hook"] == 'Y' then return end
	if(editor.Lexer == SCLEX_MSSQL) then

		tmpName=props["backup.path"]:gsub('[^\\]*$', "").."tmpsel.m"
		local strSel = editor:GetSelText():gsub(GetEOL(),"\n")
		local tmpFile = io.open(tmpName, "w")
		tmpFile:write(strSel)
		tmpFile:close()
        RunBatch(tmpName)

	end
end
function listCalc_CompileSelectedTemplate()
    listCalc_addToRecent(props['precompiller.xmlname'])
    precomp_doCompile()
end

local function listMbTrancport_DoLua()
	if chk_RunConnect.value == "ON" then
		dofile(props["sys.calcsybase.dir"].."\\connectmb\\"..iup.GetAttribute(cmb_listMbTrancport, cmb_listMbTrancport.value))
        if _G.iuprops['precompiller.radiususername'] ~= '' then
            handle = mblua.Subscribe(TerminalErrorHandler,("RADIUS.SYS.VBERROR.".._G.iuprops['precompiller.radiususername'] ),nil)
            handle = mblua.Subscribe(UserScriptHandler,("RADIUS.SYS.SCRIPT.".._G.iuprops['precompiller.radiususername'] ),nil)
        end
        btn_Open_Exec.active='YES'
	else
        btn_Open_Exec.active='NO'
		mblua.Destroy()
	end
    _G.iuprops['mbTrancport.file'] = iup.GetAttribute(cmb_listMbTrancport, cmb_listMbTrancport.value)
end


local function OnSwitch()
    if SideBar_obj.ActiveTab == myId then
        txt_Template:set_text(props['precompiller.xmlname'])
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

local function SetSubjProps(h)
    if h.value == '0' then  h.value = '1' end
    str = iup.GetAttribute(h, h.value)
    _G.iuprops['sql.dbcmdsubj'] = str
    if str:find("%.KPLUS") ~= nil then props['sql.type'] = "SYBASE" else props['sql.type'] = "MSSQL" end
end

local function FindTab_Init()
    cmb_listMbTrancport = iup.list{dropdown="YES",visible_items="15", expand='NO',size='70x0', action=listMbTrancport_DoLua, tip='Список доступных мессаджбасов. файлы с их описанием в\nScite\\data\\UserData\\connectmb' }
    cmb_listMbTrancport.map_cb=(function(h) h.value=tonumber(_G.iuprops["sidebar.mb.transport.value"]); if h.value=='0' then h.value='1' ;end; end)
    cmb_Subjects = iup.list{dropdown="YES",visible_items="15",size='70x0', expand='NO', tip='Mb-префикс Db Adapter-а, используемого для посылки запросов при показе списков полей таблиц и пр.\n(Modullar - кастомная база,Radius  - основная)'}
--[[    iup.SetAttribute(cmb_Subjects, 1, "ATRIUM")
    iup.SetAttribute(cmb_Subjects, 2, "RADIUS.KPLUS")
    iup.SetAttribute(cmb_Subjects, 3, "MODULLAR.KPLUS")]]
    cmb_Subjects:FillByHist("mb.dbadapters")

    cmb_Subjects.map_cb=(function(h) h.value=tonumber(_G.iuprops["sidebar.mb.subject.value"]); SetSubjProps(h);end)
    cmb_Subjects.action = SetSubjProps
    chk_RunConnect = iup.toggle{title = "Connect",action=listMbTrancport_DoLua, tip='Соединение с мессаджбасом'}
    btn_Open_Exec = iup.button{image = 'IMAGE_Sub',active='NO', action=(function() sql_ExecCmd() end), tip='Диалог генерации кода запуска\nSQL процедуры(Alt+Shift+E)'}
    TabBar_obj.Tabs.mb =  {
        handle = iup.hbox{  iup.label{title = "Mb:"},
                            cmb_listMbTrancport,
                            chk_RunConnect,
                            iup.label{title = "Adapter:"},
                            cmb_Subjects,
                            btn_Open_Exec,
                            alignment="ACENTER"};
            minsize='200x', OnSideBarClouse=(function() _G.iuprops["sidebar.mb.transport.value"]=cmb_listMbTrancport.value;_G.iuprops["sidebar.mb.subject.value"]=cmb_Subjects.value; end)

    }
    cmb_listMbTrancport:FillByDir("\\connectmb\\*.lua", _G.iuprops['mbTrancport.file'])
end

FindTab_Init()

