require "mblua"
local msg_SqlObjectMap = nil
local msg_SqlFields = mblua.CreateMessage()
local msgPath = props["sys.calcsybase.dir"].."\\sqlobject.map"
local maxListsItems = 16
local current_poslst = nil
local bIsListVisible = false
local strObjToShow = nil
local luaForRun =nil
local reloaded = false
-- Преобразовывает стринг в паттерн для поиска
local function fPattern(str)
	local str_out = ''
	for i = 1, string.len(str) do
		str_out = str_out..'%'..string.sub(str, i, i)
	end
    if str_out ~= '' then str_out = "["..str_out.."]" end
	return str_out
end
local fillup_chars = fPattern'. (*+=-&,'
local bIsListVisible = false

local function AnyCase(str)
    local ch, CH
    local res = ''
    for i = 1, #str do
        ch = str:sub(i,i):lower()
        CH = ch:upper()
        res = res..'['..CH..ch..']'
    end
    return res
end
local upWords = {AnyCase('update')..'[^%w_]',AnyCase('insert')..'[^%w_]','[%w_%)][%s]+'..AnyCase('select')..'[^%w_]',AnyCase('delete')..'[^%w_]',AnyCase('begin')..'[^%w_]',AnyCase('go')..'[^%w_]',AnyCase('declare')..'[^%w_]', '<!%[CDATA%[[^%w_]'}
--local upWords = {'update','insert','[^\\(]+select'}

local function IsSql()
    return editor.Lexer == SCLEX_MSSQL or (cmpobj_GetFMDefault() == SCE_FM_SQL_DEFAULT)
end
local function AddObjectFromFile(filename)
    local j = 0
    local fname = filename:lower()
    if fname:find("\\update") then return end
    if fname:find("\\upgrade") then return end
    for line in io.lines(fname) do
        j = j + 1
        if line == nil then break end
        local s,e,w
        s,e,typ,w = line:lower():find("create%s+([%w_]+)%s+([%w_%.]+)")
        if s~=nil then
            typ = typ:lower()
            if typ=='proc' or typ=='procedure' or typ=='view' or typ=='table' or typ=='trigger' or typ=='function'  then
                s = w:find("%.")
                if(s~=nil) then w = w:sub(s+1); end

                msg_SqlObjectMap:SetPathValue(w.."\\file", fname:lower())
                msg_SqlObjectMap:SetPathValue(w.."\\line", j)
            end
        end
    end
end

local sql_objects={}
local function sql_FillMapFile_tread()
--Считываем мессадж с объектами из сорсов и сохраняем его в файле
    print("Start reload sql object map")

    local cmd =
        "package.cpath = '"..props["SciteDefaultHome"].."\\tools\\LuaLib\\?.dll;'..package.cpath\n"..
        "local strPath='"..props["sys.SqlObjects.folders"].."'\n"..
        "local strOut = '"..msgPath.."'\n"
    cmd = cmd:gsub('\\', '\\\\')

    local file = io.open(props["SciteDefaultHome"].."\\tools\\resetmap.lua")
    cmd = cmd..file:read('*a')
    file:close()

    props['script.blockrestart'] = 'Y'
    scite.RunLuaThread(cmd,"resetmap.lua+3 strings in header|:::LUA::: sql_ResetMap()")

end

function sql_FillMapFile()
--Считываем мессадж с объектами из сорсов и сохраняем его в файле
    --local strPath="f:\\Projects\\Radius\\Modules\\;f:\\Projects\\Sql\\"
    local strPath=props["sys.SqlObjects.folders"]

    local dirName


    local function dir(strPath)
        local p = strPath
        local files = shell.findfiles(p.."*")
        if not files then return end
        if #files < 3 then return end

        for i, filenameT in ipairs(files) do
            filename = string.lower(filenameT.name)
            if filenameT.isdirectory then
                if filename ~= '.' and filename ~= '..' then dir(p..filename.."\\") end
            else
               if filename:lower():find('%.m$') or filename:lower():find('%.sql$') then
                   AddObjectFromFile(p..filename)
                end
            end
        end
    end

    if msg_SqlObjectMap then msg_SqlObjectMap:Destroy() end
    msg_SqlObjectMap = nil
    msg_SqlObjectMap = mblua.CreateMessage()
    for dirName in string.gmatch(strPath, "[^;]+") do
        dir(dirName.."\\")
    end
    msg_SqlObjectMap:Store(msgPath)
end

function sql_GoToDefinition(strSelText)

    if msg_SqlObjectMap ~= nil then

        if not strSelText then strSelText = GetCurrentWord() end
        local _strSelText = strSelText:lower()
        if _strSelText == '' then return end
        --if strSelText:find("\\")  then return end

        strFile =  msg_SqlObjectMap:GetPathValue(_strSelText.."\\file")

        if strFile ~= nil then
            OnNavigation("Def")
            strFile = strFile:lower()
            if props["FilePath"]:lower() ~= strFile then
                scite.Open(strFile)
            end
            local ln = msg_SqlObjectMap:GetPathValue(_strSelText.."\\line") -1
            scite.SendEditor(SCI_SETFIRSTVISIBLELINE,ln)
            editor:SetSel(editor:PositionFromLine(ln),editor:PositionFromLine(ln+1)-1)
            OnNavigation("Def-")
        else
            print("Объект не найден")
        end
    end
end

AddEventHandler("GoToObjectDefenition", function(txt)
    if IsSql() then
        sql_GoToDefinition(txt)
        return true
    end
    return false
end)

local function local_OnOpen()
    local ext = props["FileExt"]:lower()
    props["output.hook"] = 'N'
    if ext == "m" or ext == "sql" or ext == "inc" or ext == "xml" or ext == "incl" or ext == "form" then
        if msg_SqlObjectMap == nil then
            local file = io.open(msgPath)
            if file then
                io.close(file)
                msg_SqlObjectMap = mblua.RestoreMessage(msgPath)
            end
            if not reloaded and _G.iuprops['sqlobject.mapreloadtime'] ~= os.date():sub(0,8) then
                reloaded = true
                sql_FillMapFile_tread ()
                -- if props['sidebar.pan'] ~= '1' then  end
            end
        end
    else
        if msg_SqlObjectMap ~= nil then
            msg_SqlObjectMap:Destroy()
            msg_SqlObjectMap = nil
        end
    end
end

function sql_ResetMap()
    print("Sql object map reloaded")
    if msg_SqlObjectMap ~= nil then
        msg_SqlObjectMap:Destroy()
        msg_SqlObjectMap = nil
    end
    local file = io.open(msgPath)
    if file then
        io.close(file)
        msg_SqlObjectMap = mblua.RestoreMessage(msgPath)
    end
    props['script.blockrestart'] = ''
    _G.iuprops['sqlobject.mapreloadtime'] = os.date():sub(0,8)
end

local function local_OnSave()
    local ext = props["FileExt"]:lower()

    if ext == "m" or ext == "sql" then
        local msg = msg_SqlObjectMap:Execute("GET WHERE file='"..props["FilePath"]:lower().."'")
        local i,_,Name
        local _,msgCount = msg:Counts()
        for i = 0, msgCount-1 do
            _,_, Name = msg:Message(i):Subjects()
            msg_SqlObjectMap:RemoveMessage(Name)
        end
        msg:Destroy()
        AddObjectFromFile(props["FilePath"])
        msg_SqlObjectMap:Store(msgPath)
    end
end

local function findUp(iPos)

    local strText = editor:textrange(0,iPos)
    local iSpos = 1
    local iRez = 1
    for i=1,#upWords do
        local strW = upWords[i]
        while iSpos ~= nill do
            iSpos = strText:find(strW,iSpos)
            if iSpos ~= nill then iRez = iSpos;iSpos = iSpos+1 end
        end
        iSpos = iRez
    end

    return strText:sub(iSpos,-1)
end

local function findDown(iPos)
    local strText = editor:textrange(iPos,editor.Length)
    for i=1,#upWords do
        local strW = upWords[i]
        local iSpos = strText:find(strW)
        if iSpos ~= nill then
            iRez = iSpos
            strText = strText:sub(1,iSpos-1)
        end
    end
    return strText
end

local function ShowUserList(nPos,sId, preinp)

    local sep = '•'
    local msg = msg_SqlFields:GetMessage(sId)
    local _,msgCnt = msg:Counts()

    local i
    local s=''
    for i=0,msgCnt-1 do
        if s ~= '' then s=s..sep end
        s=s..msg:Message(i):GetPathValue('Fields_Name')
    end
    if s ~= '' then
        editor.AutoCSeparator = string.byte(sep)
        scite.SendEditor(SCI_AUTOCSETMAXHEIGHT,maxListsItems)

        editor:UserListShow(msg:GetPathValue('id'), s)

        if preinp ~= nil and preinp ~= '' then msg_SqlFields:RemoveMessage(sId)  end

        bIsListVisible = true
        local dLen = 0
        if preinp ~= nil then dLen = preinp:len() end
        current_poslst = editor.CurrentPos - dLen
        bIsListVisible = true
    end

end

local sql_isSql = "OFF"
function sql_ExecCmd()
    local dlg = _G.dialogs["sqlproc"]
    if dlg == nil then
        local txt_search = iup.text{value=sText,size='150x0', tip='Текст процедуры'}
        local txt_msg = iup.text{value="m",size='50x0', tip='Имя мессаджа, в который будут прописаныы парамтеры'}
        local tgl_lng = iup.toggle {title="In Sql",
                        value=sql_isSql,
                        action=(function(c) if c.value=='ON' then txt_msg.active='NO' else txt_msg.active='YES' end end),
                        tip='Генерировать вызов процедуры в из SQL/nЕсли не отмечено - генерится код заполнения параметров на бэйсике'}

        local btn_ok = iup.button  {title="OK"}
        iup.SetHandle("SQL_BTN_OK",btn_ok)

        local btn_esc = iup.button  {title="Cancel"}
        iup.SetHandle("SQL_BTN_ESC",btn_esc)

        local vbox = iup.vbox{
            iup.hbox{iup.label{title="Процедура:", gap=3},txt_search, tgl_lng, alignment='ACENTER'},
            iup.hbox{iup.label{title="мессадж:", gap=3},txt_msg, alignment='ACENTER'},
            iup.hbox{btn_ok,iup.fill{},btn_esc},
            gap=2,
            margin="4x4"
        }
        local result = false
        local function onshow_cb(h,state)
            if state == 0 then
                if props["FileExt"]:lower()=='m' then
                    tgl_lng.value = 'ON'
                    tgl_lng.active = 'NO'
                    txt_msg.active = 'NO'
                else
                    tgl_lng.value = 'OFF'
                    tgl_lng.active = 'YES'
                    txt_msg.active = 'YES'
                end
            end
        end
        dlg = iup.scitedialog{vbox; title="Вызов SQL процедуры",defaultenter="SQL_BTN_OK",defaultesc="SQL_BTN_ESC",maxbox="NO",minbox ="NO",resize ="NO", sciteparent="SCITE", sciteid="sqlproc",show_cb=onshow_cb}

        function btn_ok:action()
            sql_isSql = tgl_lng.value
            local strKustomSelect
            if  props['sql.type'] == 'MSSQL' then
                strKustomSelect="select 'S' as '__DATA_MODEL_MODE', '0' as '__INDEX_AUTO_OFF'\n"..
                              "select convert(varchar,ORDINAL_POSITION) as '__DATA_PATH',convert(varchar,PARAMETER_NAME) as var_name, DATA_TYPE as type_name, CHARACTER_MAXIMUM_LENGTH as length, PARAMETER_MODE as mode\n"..
                              "from INFORMATION_SCHEMA.PARAMETERS t\n"..
                              "where SPECIFIC_NAME ='%s' and SPECIFIC_SCHEMA='dbo'\n"..
                              "order by ORDINAL_POSITION\n"

                strKustomSelect = strKustomSelect:format(txt_search.value)
            else
                strKustomSelect="select 'S' as '__DATA_MODEL_MODE', '0' as '__INDEX_AUTO_OFF'\n"..
                              "select convert(varchar,c.colid) as '__DATA_PATH',convert(varchar,c.name) as var_name, t.name as type_name, c.length, case c.status2 when 2 then 'OUT' else 'IN' end as mode\n"..
                              "from %s..sysobjects o, %s..syscolumns c, %s..systypes t\n"..
                              "where o.id=c.id and c.usertype=t.usertype and o.name='%s'\n"..
                              "order by c.colid\n"
                strTbl ='Kustom'..props['sql.basenamesuffix']

                strKustomSelect = strKustomSelect:format(strTbl,strTbl,strTbl,txt_search.value)
            end
            local msg = mblua.CreateMessage()
            local strSub=_G.iuprops['sql.dbcmdsubj']..".EXEC_CMD"
            msg:Subjects(strSub)
            msg:SetPathValue("type","text")
            msg:SetPathValue("sql",strKustomSelect)
            msg:SetPathValue("__TIMEOUT",15)
            local msgOpaq = mblua.CreateMessage()
            msgOpaq:SetPathValue("obj",txt_search.value)
            msgOpaq:SetPathValue("msg",txt_msg.value)
            msgOpaq:SetPathValue("isSql",tgl_lng.value)
            mblua.Request(function(handle,Opaque,iError,msgReplay)
                if iError ~= 0 then
                    print("Get Object Info Error: "..iError)
                    return
                end
                if msgReplay:GetPathValue("ErrorMessage") ~= nil and msgReplay:GetPathValue("ErrorMessage") ~='' then
                    print(msgReplay:GetPathValue("ErrorMessage"))
                    return
                end
                local _, iMsg = msg:Counts()
                if Opaque:GetPathValue("isSql") == "ON" then
                    local strDeclare = ""
                    local strExec = ""

                    local iCnt
                    for iCnt=1,iMsg do
                        if strDeclare ~= "" then
                            strDeclare = strDeclare..", "
                            strExec = strExec..", "
                        end
                        strDeclare = strDeclare..msg:GetMessage(iCnt):GetPathValue("var_name")
                        strExec = strExec..msg:GetMessage(iCnt):GetPathValue("var_name")

                        local strType = msg:GetMessage(iCnt):GetPathValue("type_name")
                        strDeclare = strDeclare.." "..strType
                        if strType == "varchar" or strType == "char" or strType == "numeric" then
                            strDeclare = strDeclare.."("..msg:GetMessage(iCnt):GetPathValue("length")..")"
                        end
                        local status = msg:GetMessage(iCnt):GetPathValue("mode")
                        if status == 'OUT' or status == 'INOUT' then
                            strExec = strExec.." output"
                        end
                    end
                    strDeclare = "declare "..strDeclare.."\nexec "..Opaque:GetPathValue("obj").." "..strExec
                    editor:ReplaceSel(strDeclare)
                else
                    local strVbs = ""
                    local strName, strType, strNum, strDirection, strMsg
                    strMsg = Opaque:GetPathValue("msg")
                    for iCnt=1,iMsg do
                        strName = string.gsub(msg:GetMessage(iCnt):GetPathValue("var_name"),"@","")
                        local strT = msg:GetMessage(iCnt):GetPathValue("type_name")
                        strType = "adLongVarBinary"
                        if strT == "char" or strT == "varchar" or strT == "nvarchar" or strT == "nchar" then
                            strType = "adVarChar"
                        elseif strT=="numeric" or strT == "float" then
                            strType = "adDouble"
                        elseif strT=="int" then
                            strType = "adInteger"
                        elseif strT=="datetime" then
                            strType = "adDBTimeStamp"
                        end
                        strNum = "0"
                        if strType == "adVarChar" then
                            strNum = msg:GetMessage(iCnt):GetPathValue("length")..""
                        end
                        strDirection = "adParamInput"
                        if msg:GetMessage(iCnt):GetPathValue("mode") == 'OUT' then strDirection = "adParamOutput" end
                        if msg:GetMessage(iCnt):GetPathValue("mode") == 'INOUT' then strDirection = "adParamInputOutput" end
                        strVbs = strVbs..'dbAddProcParam '..strMsg..', "'..strName..'",, '..strType..', '..strDirection..', '..strNum..'\n'
                    end
                    strVbs = strVbs..'dbRunProc "'..Opaque:GetPathValue("obj")..'", '..strMsg..', "<callback>", db_timeout_std, Null'
                    editor:ReplaceSel(strVbs)
                end

                Opaque:Destroy()

            end,msg,10,msgOpaq)
            msg:Destroy()

            dlg:hide()
            --[[iup.Destroy(dlg)]];
        end

        function btn_esc:action()
            dlg:hide()
            --[[iup.Destroy(dlg)]];
        end
    else
        dlg:show()
    end
end

local function GetObjects(strscheme, strBase)
    local strSub = _G.iuprops['sql.dbcmdsubj']..".EXEC_CMD"
    local strKustomSelect
    if  props['sql.type'] == 'MSSQL' then
        strKustomSelect="select 'S' as '__DATA_MODEL_MODE', '0' as '__INDEX_AUTO_OFF'\n"..
                        "select TABLE_NAME as '__DATA_PATH',convert(varchar,TABLE_NAME) as Fields_Name\n"..
                        "from INFORMATION_SCHEMA.TABLES c\n"..
                        "where TABLE_SCHEMA='%s'\n"..
                        "order by TABLE_NAME\n"
        strKustomSelect = strKustomSelect:format(strscheme)
    else
        strKustomSelect="select 'S' as '__DATA_MODEL_MODE', '0' as '__INDEX_AUTO_OFF'\n"..
                        "select convert(varchar,id) as '__DATA_PATH',convert(varchar,o.name) as Fields_Name\n"..
                        "from %s..sysobjects o, %s..sysusers u\n"..
                        "where o.uid = u.uid and (o.type = 'U' or o.type = 'V' or o.type = 'P') and u.name = '%s'\n"..
                        "order by o.name\n"
        strKustomSelect = strKustomSelect:format(strBase, strBase, strscheme)
    end
--print(strKustomSelect)
    local msg = mblua.CreateMessage()
    msg:Subjects(strSub)
    msg:SetPathValue("type","text")
    msg:SetPathValue("sql",strKustomSelect)
    msg:SetPathValue("__TIMEOUT",15)
    local msgOpaq = mblua.CreateMessage()
    msgOpaq:SetPathValue("pos",editor.CurrentPos)
    msgOpaq:SetPathValue("obj",strscheme)
    mblua.Request(function(handle,Opaque,iError,msgReplay)
        if iError ~= 0 then
            print("Get Object Lists Error: "..iError)
            return
        end
        local _,msgCnt = msgReplay:Counts()
        if 0 == msgCnt then
            print("Get Object Lists Error: Unknown object: "..Opaque:GetPathValue("obj"))
            --msgReplay:Destroy()
            return
        end
        local objName = Opaque:GetPathValue("obj")
        if not msg_SqlFields:ExistsMessage(objName) then
            _,msgCnt = msgReplay:Counts()
            msgReplay:SetPathValue('id',msgCnt+1000)
            --msg_SqlFields:AttachMessage(objName,msgReplay)
            local mm=msg_SqlFields:GetMessage(objName)
            mm:CopyFrom(msgReplay)
        else
            --msgReplay:Destroy()
        end
        local prevPos = Opaque:GetPathValue("pos")

        if editor.CurrentPos == prevPos then
            ShowUserList(prevPos,objName)
        end

        Opaque:Destroy()

    end,msg,10,msgOpaq)
    msg:Destroy()
end

local function GetObjInfo(strObj,strTbl,strOwner,strObject, lb)
    local strSub=_G.iuprops['sql.dbcmdsubj']..".EXEC_CMD"
    local strKustomSelect="select 'S' as '__DATA_MODEL_MODE', '0' as '__INDEX_AUTO_OFF'\n"..
                          "select convert(varchar,c.colid) as '__DATA_PATH',convert(varchar,c.name) as Fields_Name\n"..
                          "from %s..sysobjects o, %s..syscolumns c\n"..
                          "where o.id=c.id and o.name='%s'\n"..
                          "and c.name like '"..lb.."%%'\n"..
                          "order by c.name\n"
    strKustomSelect = strKustomSelect:format(strTbl,strTbl,strObject)
--print(strKustomSelect,strSub)
    local msg = mblua.CreateMessage()
    msg:Subjects(strSub)
    msg:SetPathValue("type","text")
    msg:SetPathValue("sql",strKustomSelect)
    msg:SetPathValue("__TIMEOUT",15)
    local msgOpaq = mblua.CreateMessage()
    msgOpaq:SetPathValue("pos",editor.CurrentPos)
    msgOpaq:SetPathValue("obj",strObj)
    msgOpaq:SetPathValue("preinput",lb)
    mblua.Request(function(handle,Opaque,iError,msgReplay)
        if iError ~= 0 then
            print("Get Object Info Error: "..iError)
            return
        end
        local _,msgCnt = msgReplay:Counts()
        if 0 == msgCnt then
            print("Get Object Info Error: Unknown object: "..Opaque:GetPathValue("obj"))
            --msgReplay:Destroy()
            return
        end
        local objName = Opaque:GetPathValue("obj")
        if not msg_SqlFields:ExistsMessage(objName) then
            _,msgCnt = msgReplay:Counts()
            msgReplay:SetPathValue('id',msgCnt+1000)
            --msg_SqlFields:AttachMessage(objName,msgReplay)
            local mm=msg_SqlFields:GetMessage(objName)
            mm:CopyFrom(msgReplay)
        else
            --msgReplay:Destroy()
        end
        local prevPos = Opaque:GetPathValue("pos")

        if editor.CurrentPos == prevPos then
            ShowUserList(prevPos,objName, Opaque:GetPathValue("preinput"))
        end

        Opaque:Destroy()

    end,msg,10,msgOpaq)
    msg:Destroy()
    --msgOpaq:Destroy()
end

local function OnUserListSelection_local(tp,str)
    if tp > 999 then
        editor:SetSel(current_poslst, editor.CurrentPos)
        editor:ReplaceSel(str)
        bIsListVisible = false
    end
    scite.SendEditor(SCI_AUTOCSETCHOOSESINGLE,true)
    bIsListVisible = false
end

local function ProcessObjInfo(pos, strLine, preinp)
    local strAllText = findUp(pos)..findDown(pos)

    _,_,strObj= strAllText:find('([%w_#%.{}]+) +'..strLine..'[ ,\n\r]')
    if strObj == nil then strObj = strLine end
    if strObj:find('#') ~= nil then return end

    --Нормализуем объект
    local _,_,strTbl,strOwner,strObject = strObj:find('^([^%.]-)%.?([^%.]-)%.?([^%.]+)$')
    if strObject == nil then return end

    local sql_BaseNameSuffix = props['sql.basenamesuffix']
    if strTbl == '' then

    else
        strTbl =strTbl:gsub('__KPLUS_BASE__','kplus'..sql_BaseNameSuffix)
        strTbl =strTbl:gsub('__KUSTOM_BASE__','Kustom'..sql_BaseNameSuffix)
        strTbl =strTbl:gsub('__ARCHIVE_BASE__','KplusArchive'..sql_BaseNameSuffix)
        strTbl =strTbl:gsub('__KPLUSGLOBAL_BASE__','KplusGlobal'..sql_BaseNameSuffix)
        strTbl =strTbl:gsub('%{appKustomDB%}','Kustom'..sql_BaseNameSuffix)

    end
    --if strOwner == 'dbo' then strOwner = '' end
    strObj = strTbl..'.'..strOwner..'.'..strObject
    if preinp ~= '' then msg_SqlFields:RemoveMessage(strObj)  end
    if msg_SqlFields:ExistsMessage(strObj) and preinp == '' then
        --ShowUserList(editor.CurrentPos,strObj)
        strObjToShow = strObj
    else
        GetObjInfo(strObj,strTbl,strOwner,strObject, preinp:lower())
    end
end

function ShowListManualySql()
    local curPos = editor.CurrentPos
    local str = editor:textrange(editor:PositionFromLine(editor:LineFromPosition(curPos)), editor.CurrentPos)
    local _, tstart, strObj, lineBeg = str:find('(%w*)%.(%w*)$')
    if not tstart then return end
    ProcessObjInfo(curPos, strObj, lineBeg)
end

local function local_OnChar(char)

    if bIsListVisible and string.find(char,fillup_chars) then
    --обеспечиваем вставку выбранного в листе значения вводе одного из завершающих символов(fillup_chars - типа (,. ...)
    --делать это через  SCI_AUTOCSETFILLUPS неудобно - не поддерживается пробел, и  start_chars==fillup_chars - лист сразу же закрывается,
        if scite.SendEditor(SCI_AUTOCACTIVE) then
            --editor:SetSel(editor:WordStartPosition(editor.CurrentPos), editor.CurrentPos)
            scite.SendEditor(SCI_AUTOCCOMPLETE)
            editor:ReplaceSel(char)
        else
            bIsListVisible = false
        end
    end
    if char ~= "." then return end
    --[[local ext = props["FileExt"]:lower()
    if ext ~= "m" and ext ~= "sql" then return end]]
    if not IsSql()  then return end
    local pos = editor.CurrentPos

    local strLine = editor:textrange(editor:PositionFromLine(editor:LineFromPosition(pos)),pos-1)
    local iObj = strLine:find('[%w_%.]+$')
    if iObj == nil then return end
    strLine = strLine:sub(iObj)

    if (strLine == 'dbo' or strLine == 'custom' or strLine == 'kplus') and props['sql.type'] == 'MSSQL' then
        GetObjects(strLine, '')
        return
    end
    local _,strObj
    _,_,strObj= strLine:find('([%w_#{}]+)%.$')
--print(strObj,strLine, props['sql.type'] )
    if (strLine == 'dbo' or strLine == 'kplus'
        or strObj == '__KPLUS_BASE__'
        or strObj == '__KUSTOM_BASE__'
        or strObj == '__ARCHIVE_BASE__'
        or strObj == '__KPLUSGLOBAL_BASE__'
        or strObj == '{appKustomDB}'
        ) and props['sql.type'] == 'SYBASE' then
        strschem = 'dbo'
        local sql_BaseNameSuffix = props['sql.basenamesuffix']
        if strLine == 'dbo' or strLine == 'kplus' then
            strschem = strLine
            strObj = ""
--[[            if props["FileExt"]:lower() == 'xml' then
                strObj = 'kplus'..sql_BaseNameSuffix
            else
                strObj = 'Kustom'..sql_BaseNameSuffix
            end]]
        elseif strObj == '__KPLUS_BASE__' then
            strObj = 'kplus'..sql_BaseNameSuffix
        elseif strObj == '__KUSTOM_BASE__' or strObj == '{appKustomDB}' then
            strObj =  'Kustom'..sql_BaseNameSuffix
        elseif strObj == '__ARCHIVE_BASE__' then
            strObj =  'KplusArchive'..sql_BaseNameSuffix
        elseif strObj == '__KPLUSGLOBAL_BASE__' then
            strObj =  'KplusGlobal'..sql_BaseNameSuffix
        end
        GetObjects(strschem, strObj)
        return
    end
    ProcessObjInfo(pos, strLine, '')

end

local function local_OnUpdateUI()
    if strObjToShow ~= nil then
        ShowUserList(editor.CurrentPos,strObjToShow)
        strObjToShow = nil
    end
end

AddEventHandler("OnOpen", local_OnOpen)
AddEventHandler("OnSwitchFile", local_OnOpen)
AddEventHandler("OnSave", local_OnSave)
AddEventHandler("OnChar", local_OnChar)
AddEventHandler("OnUpdateUI", local_OnUpdateUI)
AddEventHandler("OnUserListSelection", OnUserListSelection_local)
AddEventHandler("OnSendEditor", function(id_msg, wp, lp)
	if id_msg == SCN_NOTYFY_OUTPUTCMD then
        if props["output.hook"] == 'Y' then
            local out = string.gsub(lp, "(Server '?(%S+)'?, Procedure '?([_%w]+)'?, Line (%d+):?\r\n([^\r]*))", function(sAll,s,proc,lns,err)

                local j = editor:LineFromPosition(editor:findtext("__CMD_DROP_....("..proc..")", SCFIND_REGEXP, 0, editor.Length))
                if _G["SqlMap"] ~= nil then
                    if _G["SqlMap"] == '?' then
                        local file = io.input(props["SciteDefaultHome"].."\\data\\tmp.sql")
                        _G["SqlMap"] = file:read('*a')
                        file:close()
                    end
                    local iGo = false
                    local i=-1
                    local jj=0
                    local mp = 0
                    local ptrn = string.lower('create +proc[^\n]*'..proc)
                    local sMap = _G["SqlMap"]
                        for str in string.gmatch(sMap, "[^\n\r]*\n") do
                            i=i+1
                            jj = jj+1
                            str = str:lower()

                            if (not iGo) then
                                if str:sub(1,2) == 'go' then i = 0 end
                                if str:find(ptrn) then  iGo = true end
                            end
                            if iGo then
                                local b = string.match(str,'%-%-%&%&(%d+)')
                                if b~=nil then mp=b end
                                if i >= (lns+0) then
                                    return props["FilePath"].."("..mp ..",0) "..proc.."\r\n"..sAll
                                end

                            end
                        end

                    return str
                else
                    return props["FilePath"].." ("..j+lns ..",0) "..proc..sAll
                end
            end
            )
            print(out)
            return 11  --возвращаем не 0, чтобы скайт ничего не печатал
        elseif string.sub(lp, 0, 9) == ':::LUA:::' then
            luaForRun = string.sub(lp, 10)
            return 11
        end
    elseif id_msg == SCN_NOTYFY_OUTPUTEXIT then
        if luaForRun then
            print(' ')
            local s = luaForRun
            luaForRun = nil
            _G["SqlMap"] = nil
            dostring(s)

        end
        props["output.hook"] = 'N'
	end
end)
