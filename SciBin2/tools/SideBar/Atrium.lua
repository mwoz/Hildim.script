require "mblua"
require("LuaXml")

local AD_Char = 129
local AD_VarChar = 200
local AD_Integer = 3
local AD_Double = 5
local AD_DBTimeStamp = 135
local AD_LongVarBinary = 205

--направление для параметров процедур (по adodb::ParameterDirectionEnum)
local AD_ParamInput = 1          --Default. Indicates that the parameter represents an input parameter.
local AD_ParamInputOutput = 3    --Indicates that the parameter represents both an input and output parameter.
local AD_ParamOutput = 2         --Indicates that the parameter represents an output parameter."
local AD_ParamReturnValue = 4    --Indicates that the parameter represents a return value.
local AD_ParamUnknown = 0        --Indicates that the parameter direction is unknown
local XMLCAPT = '<?xml version="1.0" encoding="Windows-1251" standalone="yes"?>\n'

local cmb_Action, chk_ign, cmb_syscust, txt_objmask, txt_datamask, list_obj, list_data, cmb_mask, btnRun
local cmb_RefDepth, cmb_apDept, chk_IncludeExt

local function dbAddProcParam(msgParams, strName, varValue, enumType, enumDirection ,lSize )
    msgParams:SetPathValue(strName.."\\Value"    ,varValue)
    msgParams:SetPathValue(strName.."\\Type"     ,enumType)
    msgParams:SetPathValue(strName.."\\Direction",enumDirection)
    msgParams:SetPathValue(strName.."\\Size"     ,lSize)
end

local function dbRunProc(strProc, msgParams, funCallback, timeout, opaque)
    local msg = mblua.CreateMessage()
    msg:Subjects(_G.iuprops['sql.dbcmdsubj']..".EXEC_CMD")

    msg:SetPathValue("type", "procedure")
    msg:SetPathValue("sql", strProc)
    if msgParams ~= nil then msg:AttachMessage("params", msgParams) end

    mblua.Request(funCallback,msg,timeout,opaque)
    msg:Destroy()
end

local function ProbablyToUTF(str)
    if _G.iuprops['atrium.data.win1251'] ~= 'ON' then return str:to_utf8(1251)
    else return str end
end

local function dbRunSql(sql, funCallback, timeout, opaque)
    local msg = mblua.CreateMessage()
    msg:Subjects(_G.iuprops['sql.dbcmdsubj']..".EXEC_CMD")
    msg:SetPathValue("type","text")
    msg:SetPathValue("sql",sql)
    msg:SetPathValue("__TIMEOUT",timeout)
    mblua.Request(funCallback, msg, timeout, opaque)
end

local function dbCheckError(iError, msgReplay)
    if iError ~= 0 then
        print("Error: "..iError)
        return true
    end
    if msgReplay:GetPathValue("ErrorMessage") ~= nil and msgReplay:GetPathValue("ErrorMessage") ~='' then
        print("Error: "..msgReplay:GetPathValue("ErrorMessage"))
        return true
    end
end

local function OnSwitch()
    props['are.you.sure.close'] = Iif(props['FileNameExt']:find('^%^'),0,1)
    local bEn = (editor.Lexer == SCLEX_XML or editor.Lexer == SCLEX_FORMENJINE)
    btnRun.active = Iif(bEn, 'YES', 'NO')
end

local function OnOpenLocal()

end

local function Data_GetSql(strProc, id)
    if not strProc then
        local sel = list_obj.marked:find('1') - 1
        strProc = iup.GetAttributeId2(list_obj, '', sel, 3)..'_Get'
    end
    if not id then
        local sel = list_data.marked:find('1') - 1
        id = tonumber(iup.GetAttributeId2(list_data, '', sel, 1))
    end
    return "declare @XmlData tLongText\n"..
    "exec "..strProc.." 'atrium', "..id..", @XmlData output, "..
    (cmb_RefDepth.value-1)..', '..(cmb_apDept.value-1)..', '..Iif(chk_IncludeExt.value=='ON', "'Y'", "'N'")..'\n'..
    "select @XmlData as [xml]"
end

local function TryCleanUp()
    if _G.iuprops['atrium.data.cleanup']=='ON' then
        local strText = editor:GetText()
        strText = strText:gsub('[^\n]*<RecDate_Ins>[^\n]*\n', '')
        strText = strText:gsub('[^\n]*<RecDate_Upd>[^\n]*\n', '')
        strText = strText:gsub('[^\n]*<Revision>[^\n]*\n', '')
        strText = strText:gsub(' xsi:nil="true"', '')
        strText = strText:gsub(' xmlns:xsi="[^>]*', '')
        strText = strText:gsub('[^\n]*<[%w_]*_Id/?>[^\n]*\n', '')
        strText = strText:gsub('[^\n]*<[%w_]*_Id_[%w_]+/?>[^\n]*\n', '')
        local _,_,id = strText:find('^<%w+%.(%w+)')
        strText = strText:gsub('[^\n]*<'..id..'_Id>[^\n]*\n', '')
        editor:SetText(strText)
    end
end

local function SetReply(handle,msgOpaque,iError,msgReplay)
    if dbCheckError(iError, msgReplay) then return end
    print(msgReplay:ToString())
    if msgOpaque:GetPathValue("Type", "") == 'DATA' then
        dbRunSql(Data_GetSql(msgOpaque:GetPathValue("Proc", ""), msgReplay:GetPathValue("Object_Id", 0)), function(handle,Opaque,iError,msgR)
            if dbCheckError(iError, msgR) then return end
            editor:SetText(ProbablyToUTF(xml.eval(msgR:GetPathValue('xml')):str()))
            TryCleanUp()
        end, 20, nil)
    end
end

local function PutData(t_xml,strObjType)
    local _,_,s_c, obj = strObjType:find('^([^.]*)%.(.*)')

    local t_id = t_xml:find(obj..'_Id')
    local objId
    if t_id ~= nil then objId = tonumber(t_id[1]) end

    local IgnId = Iif(chk_ign.value == 'ON', 'Y', 'N')
    local action = iup.GetAttribute(cmb_Action, cmb_Action.value)
    local strXml = t_xml:str()

    local msgParams = mblua.CreateMessage()
    local msgOpaq = mblua.CreateMessage()
    msgOpaq:SetPathValue("Type"    ,'DATA')
    msgOpaq:SetPathValue("Proc"    ,obj..'_Get')
    msgOpaq:SetPathValue("id"    ,objId)

    if tonumber(props["editor.unicode.mode"]) ~= IDM_ENCODING_DEFAULT then strXml = strXml:from_utf8(1251) end

    dbAddProcParam(msgParams, "Usr", 'atrium', AD_VarChar, AD_ParamInput, 64)
    dbAddProcParam(msgParams, "Action", action, AD_VarChar, AD_ParamInput, 64)
    dbAddProcParam(msgParams, "XmlData"          , strXml, AD_VarChar, AD_ParamInput, strXml:len() + 1)
    dbAddProcParam(msgParams, "Object_Id"        , objId, AD_Double, AD_ParamOutput, 4)
    dbAddProcParam(msgParams, "IgnoreIdentifiers", IgnId, AD_VarChar, AD_ParamInput, 1)
    dbAddProcParam(msgParams, "IgnoreRevision"   , "Y", AD_VarChar, AD_ParamInput, 1)
    dbRunProc(obj..'_IUD', msgParams, SetReply, 20, msgOpaq)

end

local function ApplyMetadata(strXml)
    local msgParams = mblua.CreateMessage()
    if tonumber(props["editor.unicode.mode"]) ~= IDM_ENCODING_DEFAULT then strXml = strXml:from_utf8(1251) end

    dbAddProcParam(msgParams, "Metadata"          , strXml, AD_VarChar, AD_ParamInput, strXml:len() + 1)
    dbAddProcParam(msgParams, "ExecMode", 'R', AD_VarChar, AD_ParamInput, 1)
    dbAddProcParam(msgParams, "ObjectMask", iup.GetAttribute(cmb_mask, cmb_mask.value), AD_VarChar, AD_ParamInput, 3)

    dbRunProc('mpGenerateSql', msgParams, SetReply, 20, nil)
end

local function SelectMetadata()
    --"select __DATA_MODEL_MODE = 'S', __INDEX_AUTO_ON = 1\n"..
   local sql =  "select top 100 __DATA_MODEL_MODE = 'S', __INDEX_AUTO_ON = 1, ObjectType_Code,ObjectType_Name,TableName, "..
   "convert(xml, Metadata).value('(/Template/DataModel/Tables/Table/Fields/Field[@type=''ObjectCode'']/@name)[1]', 'nvarchar(max)') as [CodeField]"..
   " from ObjectType where ObjectType_Code like ('"..iup.GetAttribute(cmb_syscust, cmb_syscust.value).."."..txt_objmask.value.."%')  order by ObjectType_Code"

    dbRunSql(sql, function(handle,Opaque,iError,msgReplay)
        if dbCheckError(iError, msgReplay) then return end
        local _, mc = msgReplay:Counts()
        iup.SetAttribute(list_obj, "DELLIN", "1-"..list_obj.numlin)
        iup.SetAttribute(list_obj, "ADDLIN", "1-"..mc)
        for i = 0, mc - 1 do
            list_obj:setcell(i + 1, 1, msgReplay:Message(i):GetPathValue('ObjectType_Code'))
            list_obj:setcell(i + 1, 2, msgReplay:Message(i):GetPathValue('ObjectType_Name'))
            list_obj:setcell(i + 1, 3, msgReplay:Message(i):GetPathValue('TableName'))
            list_obj:setcell(i + 1, 4, msgReplay:Message(i):GetPathValue('CodeField'))
        end
        if mc > 0 then
            iup.SetAttribute(list_obj,  'MARK1:0', 1)
            iup.SetAttribute(list_data, "DELLIN", "1-"..list_data.numlin)
            iup.SetFocus(list_obj)
        end
        --print(msgReplay:ToString())
        --msgReplay:Destroy()
        list_obj.redraw = "ALL"
    end,10,nil)
end

local function SelectData()
    if not list_obj.marked then return end
    local sel = list_obj.marked:find('1')
    if not sel then return end
    sel = sel - 1
    local tbl = iup.GetAttributeId2(list_obj, '', sel, 3)
    local nm = iup.GetAttributeId2(list_obj, '', sel, 3):gsub('^.-([%w_]+)$', '%1')
    local cd = iup.GetAttributeId2(list_obj, '', sel, 4)
    local sql
    if cd == nil then
        if list_obj:getcell(sel,1) == 'system.ObjectTypeForm' then
            sql = "select top 100 __DATA_MODEL_MODE = 'S', __INDEX_AUTO_ON = 1, f.ObjectTypeForm_Id, (o.ObjectType_Code + '.' + v.Name) as [ObjectTypeForm_Code] from ObjectTypeForm f\n"..
            "inner join ObjectType o on o.ObjectType_Id = f.ObjectType_Id\n"..
            "inner join ChoiceValue v on v.Value = f.FormType\n"..
            "inner join Choice c on c.Choice_Id = v.Choice_Id and c.Choice_Code = 'system.FormType'\n"..
            "where (o.ObjectType_Code + '.' + f.FormType) like ('"..txt_datamask.value.."%') order by o.ObjectType_Code"
        else
            sql =  "select top 100 __DATA_MODEL_MODE = 'S', __INDEX_AUTO_ON = 1, "..nm.."_Id from "..tbl
            if tonumber(txt_datamask.value) ~= nil then sql =  sql.." where "..nm.."_Id >= "..tonumber(txt_datamask.value).." order by "..nm.."_Id" end
        end
    else
        sql =  "select top 100 __DATA_MODEL_MODE = 'S', __INDEX_AUTO_ON = 1, "..nm.."_Id, "..cd.." from "..tbl.." where "..cd.." like ('"..txt_datamask.value.."%') order by "..cd
    end
    dbRunSql(sql, function(handle,Opaque,iError,msgReplay)
        if dbCheckError(iError, msgReplay) then return end
        local _, mc = msgReplay:Counts()
        iup.SetAttribute(list_data, "DELLIN", "1-"..list_data.numlin)
        iup.SetAttribute(list_data, "ADDLIN", "1-"..mc)
        for i = 0, mc - 1 do
            list_data:setcell(i + 1, 1, msgReplay:Message(i):GetPathValue(nm..'_Id'))
            list_data:setcell(i + 1, 2, msgReplay:Message(i):GetPathValue(nm..'_Code'))
        end
        list_data.redraw = "ALL"
    end,20,nil)
end

local function PutReport()
    local strXml = editor:GetText()
    if tonumber(props["editor.unicode.mode"]) ~= IDM_ENCODING_DEFAULT then strXml = strXml:from_utf8(1251) end
    local msgParams = mblua.CreateMessage()
    dbAddProcParam(msgParams, "FormData" , strXml, AD_VarChar, AD_ParamInput, strXml:len() + 1)
    dbRunProc('Report_Register', msgParams, function(handle,Opaque,iError,msgReplay)
        print(msgReplay:ToString())
        if msgReplay:GetPathValue('Error') == '0' then
            local msg = mblua.CreateMessage()
            strSubj = 'SYSM.SAVEREPORT'
            if _G.iuprops["precompiller.radiususername"] ~= '' then
                strSubj = strSubj..'.'.._G.iuprops["precompiller.radiususername"]
            end
            msg:Subjects(strSubj)
            -- msg:SetPathValue("TemplPath",precomp_strRootDir.."..\\tmp\\debug.xml")
            local strXml2 = editor:GetText()
            if tonumber(props["editor.unicode.mode"]) ~= IDM_ENCODING_DEFAULT then strXml2 = strXml2:from_utf8(1251) end
            msg:SetPathValue("ExtText",strXml2)
            _G['formengine.reloadtemplate'] = true
            mblua.Request(function(handle,Opaque,iError,msgReplay)
            _G['formengine.reloadtemplate'] = false
                if iError == 0 then
                    print(msgReplay:GetPathValue("strReplay"))
                else
                    print("Terminal not responded")
                end
            end,msg,3,nil)
            --mblua.Publish(msg)
            msg:Destroy()
        end
    end, 20, nil)
end

local function PutForm(objectType, formType)
    if objectType == nil or formType == nil then
        print('Incorrect Custom form!')
        return
    end
    local strXml = editor:GetText()
    if tonumber(props["editor.unicode.mode"]) ~= IDM_ENCODING_DEFAULT then strXml = strXml:from_utf8(1251) end
    local msgParams = mblua.CreateMessage()
    dbAddProcParam(msgParams, "FormXml" , strXml, AD_VarChar, AD_ParamInput, strXml:len() + 1)
    dbRunProc('ObjectTypeForm_Import', msgParams, function(handle,Opaque,iError,msgReplay)
        print(msgReplay:ToString())
        if msgReplay:GetPathValue('Error') == '0' then
            local msg = mblua.CreateMessage()
            strSubj = 'SYSM.SAVETEMPLATE'
            if _G.iuprops["precompiller.radiususername"] ~= '' then
                strSubj = strSubj..'.'.._G.iuprops["precompiller.radiususername"]
            end
            msg:Subjects(strSubj)
            -- msg:SetPathValue("TemplPath",precomp_strRootDir.."..\\tmp\\debug.xml")
            local strXml2 = editor:GetText()
            if tonumber(props["editor.unicode.mode"]) ~= IDM_ENCODING_DEFAULT then strXml2 = strXml2:from_utf8(1251) end
            msg:SetPathValue("ExtText",strXml2)
            _G['formengine.reloadtemplate'] = true
            mblua.Request(function(handle,Opaque,iError,msgReplay)
            _G['formengine.reloadtemplate'] = false
                if iError == 0 then
                    print(msgReplay:GetPathValue("strReplay"))
                    if props['formengine.runafter'] == '1' then formenjine_RunTemplate("") end
                else
                    print("Terminal not responded")
                end
            end,msg,3,nil)
            --mblua.Publish(msg)
            msg:Destroy()
        end
    end, 20, nil)
end

function atrium_RunXml()
    if btnRun.active == 'NO' then return end
    local t_xml = xml.eval(editor:GetText():gsub('^<[?].->\r?\n?',''))
    local strObjType = t_xml[0]
    if strObjType == 'Template' then
        ApplyMetadata(editor:GetText():gsub('^<[?].->\r?\n?',''))
    elseif strObjType == 'Form' and t_xml['type'] == 'Report' then
        PutReport()
    elseif strObjType == 'Form' then
        PutForm(t_xml['objectType'], t_xml['type'])
    elseif strObjType == 'template' then
        print('Not Supported!')
    else
        PutData(t_xml,strObjType)
    end
end

local function Data_OpenNewChoice(strObj)
    local strSql = "declare @XmlData tLongText, @id tId\n"..
    "select @id=Choice_Id from Choice where Choice_Code='"..strObj.."'\n"..
    "exec Choice_Get 'atrium', @id, @XmlData output\n"..
    "select @XmlData as [xml]"
    dbRunSql(strSql,function(handle,Opaque,iError,msgReplay)
        props['scite.new.file'] = '^Choice.xml'
        if dbCheckError(iError, msgReplay) then return end
        scite.MenuCommand(IDM_NEW)
        if _G.iuprops['atrium.data.win1251'] ~= 'ON' then scite.MenuCommand(IDM_ENCODING_UCS2LE) end
        editor:SetText(ProbablyToUTF(xml.eval(msgReplay:GetPathValue('xml')):str()))
    end,20,nil)
end

local function Data_OpenNew()
    local sel = list_obj.marked:find('1') - 1
    local oName = list_obj:getcell(sel,1)
    if oName == 'system.ObjectTypeForm' or oName == 'system.Report' then
        oName = oName:gsub('system.','')
        sel = list_data.marked:find('1') - 1
        local sql = "select f.FormData \n"..
        "from "..oName.." f\n"..
        "where f."..oName.."_Id = "..list_data:getcell(sel,1)

        dbRunSql(sql,function(handle,Opaque,iError,msgReplay)
            if dbCheckError(iError, msgReplay) then return end
            props['scite.new.file'] = '^'..list_data:getcell(sel,2)..Iif(oName == 'ObjectTypeForm', '.cform', '.rform')
            scite.MenuCommand(IDM_NEW)
            if _G.iuprops['atrium.data.win1251'] ~= 'ON' then scite.MenuCommand(IDM_ENCODING_UCS2LE) end
            editor:SetText(ProbablyToUTF(msgReplay:GetPathValue('FormData')))
        end,20,nil)
    else
        dbRunSql(Data_GetSql(),function(handle,Opaque,iError,msgReplay)
            if dbCheckError(iError, msgReplay) then return end
            props['scite.new.file'] = '^'..iup.GetAttributeId2(list_obj, '', list_obj.marked:find('1') - 1, 1):gsub('.*%.(.*)', '%1')..'.'..
                    (iup.GetAttributeId2(list_data, '', list_data.marked:find('1') - 1, 2) or iup.GetAttributeId2(list_data, '', list_data.marked:find('1') - 1, 1))..'.xml'
            scite.MenuCommand(IDM_NEW)
            if _G.iuprops['atrium.data.win1251'] ~= 'ON' then scite.MenuCommand(IDM_ENCODING_UCS2LE) end
            editor:SetText(ProbablyToUTF(xml.eval(msgReplay:GetPathValue('xml')):str()))
            TryCleanUp()
        end,20,nil)
    end
end

local function Data_Unload()
    local sel = list_obj.marked:find('1') - 1
    local oName = list_obj:getcell(sel,1)
    if oName == 'system.ObjectTypeForm' or oName == 'system.Report' then
        oName = oName:gsub('system.','')
        sel = list_data.marked:find('1') - 1
        local sql = "select f.FormData \n"..
        "from "..oName.." f\n"..
        "where f."..oName.."_Id = "..list_data:getcell(sel,1)

        local strName = list_data:getcell(sel,2)

        dbRunSql(sql, function(handle,Opaque,iError,msgReplay)
            if dbCheckError(iError, msgReplay) then return end
            local strPath = props['FileDir']..'\\'..strName..'.'..Iif(oName == 'ObjectTypeForm', 'cform', 'rform')
            local f = io.open(strPath, "w")
            f:write('')
            f:flush()
            f:close()
            scite.Open(strPath)
            if _G.iuprops['atrium.data.win1251'] ~= 'ON' then scite.MenuCommand(IDM_ENCODING_UCS2LE) end
            editor:SetText(ProbablyToUTF(msgReplay:GetPathValue('FormData')))
            scite.MenuCommand(IDM_SAVE)
        end,20,nil)
    else
        local strName = iup.GetAttributeId2(list_obj, '', list_obj.marked:find('1') - 1, 1):gsub('.*%.(.*)', '%1')..'.'..
            (iup.GetAttributeId2(list_data, '', list_data.marked:find('1') - 1, 2) or iup.GetAttributeId2(list_data, '', list_data.marked:find('1') - 1, 1))

        dbRunSql(Data_GetSql(), function(handle,Opaque,iError,msgReplay)
            if dbCheckError(iError, msgReplay) then return end
            local strPath = props['FileDir']..'\\'..strName..'.xml'
            local f = io.open(strPath, "w")
            f:write('')
            f:flush()
            f:close()
            scite.Open(strPath)
            if _G.iuprops['atrium.data.win1251'] ~= 'ON' then scite.MenuCommand(IDM_ENCODING_UCS2LE) end
            editor:SetText(ProbablyToUTF(xml.eval(msgReplay:GetPathValue('xml')):str()))
            TryCleanUp()
            scite.MenuCommand(IDM_SAVE)
        end,20,nil)
    end
end

local function Metadata_OpenNewArg(strObj)
    local sql =  "select  Metadata from ObjectType where ObjectType_Code = '"..strObj.."'"
    dbRunSql(sql, function(handle,Opaque,iError,msgReplay)
        if dbCheckError(iError, msgReplay) then return end
        if props['scite.new.file']..'' == '' then
            props['scite.new.file'] = '^'..iup.GetAttributeId2(list_obj, '', list_obj.marked:find('1') - 1, 1)..'.xml'
        end
        scite.MenuCommand(IDM_NEW)
        if _G.iuprops['atrium.data.win1251'] ~= 'ON' then scite.MenuCommand(IDM_ENCODING_UCS2LE) end
        editor:SetText(ProbablyToUTF(msgReplay:GetPathValue('Metadata')))
        scite.MenuCommand(1468)
    end,20,nil)
end

local function Metadata_OpenNew()
    local sel = list_obj.marked:find('1') - 1
    local strObj = iup.GetAttributeId2(list_obj, '', sel, 1)
    Metadata_OpenNewArg(strObj)
end

local function Metadata_NewData()
    local sel = list_obj.marked:find('1') - 1
    iup.GetAttributeId2(list_obj, '', sel, 1)
    local strName = iup.GetAttributeId2(list_obj, '', sel, 1)

    local msgParams = mblua.CreateMessage()

    dbAddProcParam(msgParams, "ObjectCode" , strName, AD_VarChar, AD_ParamInput, 512)
    dbAddProcParam(msgParams, "XmlData", 'R', AD_VarChar, AD_ParamOutput, 999999)

    dbRunProc('ObjectType_Pattern', msgParams, function(handle,Opaque,iError,msgReplay)
        scite.MenuCommand(IDM_NEW)
        if _G.iuprops['atrium.data.win1251'] ~= 'ON' then scite.MenuCommand(IDM_ENCODING_UCS2LE) end
        editor:SetText(ProbablyToUTF(msgReplay:GetPathValue('XmlData')))
        scite.MenuCommand(1468)
    end, 20, nil)
end

local function Metadata_Unload()
    local sel = list_obj.marked:find('1') - 1
    iup.GetAttributeId2(list_obj, '', sel, 1)
    local strName = iup.GetAttributeId2(list_obj, '', sel, 1)
    local sql =  "select  Metadata from ObjectType where ObjectType_Code = '"..strName.."'"

    dbRunSql(sql, function(handle,Opaque,iError,msgReplay)
        if dbCheckError(iError, msgReplay) then return end
        local strPath = props['FileDir']..'\\'..strName..'.xml'
        local f = io.open(strPath, "w")
        f:write('')
        f:flush()
        f:close()
        scite.Open(strPath)
        if _G.iuprops['atrium.data.win1251'] ~= 'ON' then scite.MenuCommand(IDM_ENCODING_UCS2LE) end
        --local sText = msgReplay:GetPathValue('Metadata'):gsub('\r', '')
        editor:SetText(ProbablyToUTF(msgReplay:GetPathValue('Metadata')))
        scite.MenuCommand(IDM_SAVE)
        scite.MenuCommand(1468)
    end,20,nil)
end

local function OpenChoiceMeta()
    if editor.Lexer ~= SCLEX_XML then return end

    if editor.StyleAt[editor.CurrentPos] ~= 6 then return end
    local pb = editor.CurrentPos
    local pe = pb
    while editor.StyleAt[pb] == 6 do pb = pb -1 end
    while editor.StyleAt[pe] == 6 do pe = pe +1 end
    local obj = editor:textrange(pb + 2,pe - 1)
    local _,_,typ = obj:find('^(%w+)%.%w+$')
    if typ ~= 'system' and typ ~= 'custom' then return end
    local lN = editor:LineFromPosition(pb)
    local lin = editor:textrange(editor:PositionFromLine(lN), editor.LineEndPosition[lN])
    _,_,typ = lin:find(' type="(%w+)"')
    if typ == 'Reference' then
        props['scite.new.file'] = '^Reference.xml'
        Metadata_OpenNewArg(obj)
    elseif typ == 'tChoice' then
        Data_OpenNewChoice(obj)
    elseif lin:find('<ExternalRef ') then
        props['scite.new.file'] = '^Reference.xml'
        Metadata_OpenNewArg(obj)
    end
end

local function OnDoubleClickLocal(shift, ctrl, alt)
    if not shift or ctrl or alt then return end
    OpenChoiceMeta()
end
local function FindTab_Init()
    cmb_Action = iup.list{dropdown="YES",visible_items="15",size='70x0', expand='NO', tip='Сохранение/Удаление объекта'}
    iup.SetAttribute(cmb_Action, 1, "insupd")
    iup.SetAttribute(cmb_Action, 2, "delete")
    cmb_Action.value = 1
    chk_ign = iup.toggle{title = "Ign. Id-s", tip='Игнорироапть Id объекта при вставке\n(вставить копию)'}
    cmb_mask = iup.list{dropdown="YES",visible_items="15",size='30x0', expand='NO', tip='program scripts|schema scripts|schema+program'}
    iup.SetAttribute(cmb_mask, 1, "P")
    iup.SetAttribute(cmb_mask, 2, "S")
    iup.SetAttribute(cmb_mask, 3, "SP")
    iup.SetAttribute(cmb_mask, 4, "SD")
    iup.SetAttribute(cmb_mask, 5, "SDP")
    cmb_mask.value = 1
    btnRun = iup.button{image = 'IMAGE_FormRun', action=atrium_RunXml, tip='Обработка всего файла'}


    cmb_syscust = iup.list{dropdown="YES",visible_items="15",size='70x0', expand='NO', tip='Сохранение/Удаление объекта'}
    iup.SetAttribute(cmb_syscust, 1, "%")
    iup.SetAttribute(cmb_syscust, 2, "system")
    iup.SetAttribute(cmb_syscust, 3, "custom")
    cmb_syscust.value = 1

    --txt_objmask = iup.text{expand='HORIZONTAL',tip='Маска метаданных'}
    txt_objmask = iup.list{editbox = "YES",dropdown="YES",visible_items="15",expand='HORIZONTAL',tip='Маска метаданных'}
    iup.SetAttribute(txt_objmask, 1, "Choice")
    iup.SetAttribute(txt_objmask, 2, "ObjectTypeForm")
    iup.SetAttribute(txt_objmask, 3, "Report")
    txt_objmask.k_any = (function(h,k) if k == iup.K_CR then SelectMetadata() end end)
    txt_objmask.action = (function(h,text,item,state) if state == 1 then txt_objmask.value = text; SelectMetadata() end end)

    cmb_RefDepth = iup.list{dropdown="YES",visible_items="15",size='20x0', expand='NO', tip='Reference Repth'}
    iup.SetAttribute(cmb_RefDepth, 1, "0")
    iup.SetAttribute(cmb_RefDepth, 2, "1")
    iup.SetAttribute(cmb_RefDepth, 3, "2")
    iup.SetAttribute(cmb_RefDepth, 4, "3")
    cmb_RefDepth.value = 1

    cmb_apDept = iup.list{dropdown="YES",visible_items="15",size='20x0', expand='NO', tip='Reference Repth'}
    iup.SetAttribute(cmb_apDept, 1, "0")
    iup.SetAttribute(cmb_apDept, 2, "1")
    iup.SetAttribute(cmb_apDept, 3, "2")
    iup.SetAttribute(cmb_apDept, 4, "3")
    cmb_apDept.value = 2

    chk_IncludeExt = iup.toggle{title='En.ApM', tip='Enrich Appendix Multiple'}

    list_obj = iup.matrix{
    numcol=4, numcol_visible=4,  cursor="ARROW", alignment='ALEFT', heightdef=6,markmode='LIN', scrollbar="YES" ,
    resizematrix = "YES"  ,readonly="YES"  ,markmultiple="NO" ,height0 = 4, expand = "YES", framecolor="255 255 255",
    width0 = 0 ,rasterwidth1 = 150 ,rasterwidth2 = 150 ,rasterwidth3= 150,rasterwidth4= 15}
  	list_obj:setcell(0, 1, "Code")
  	list_obj:setcell(0, 2, "Name")
  	list_obj:setcell(0, 3, "Table")
--[[    list_obj.click_cb = (function(h, lin, col, status)
        local sel = 0
        if list_obj.marked then sel = list_obj.marked:find('1') - 1 end
        if sel ~= lin then iup.SetAttribute(list_data, "DELLIN", "1-"..list_data.numlin) end
        iup.SetAttribute(list_obj,  'MARK'..sel..':0', 0)
        iup.SetAttribute(list_obj, 'MARK'..lin..':0', 1)
        list_obj.redraw = lin..'*'
        if iup.isbutton3(status) then
            h.focus_cell = lin..':'..col
            local mnu = iup.menu
            {
              iup.item{title="Открыть как новый файл",action=Metadata_OpenNew},
              iup.item{title="Выгрузить и открыть в текущей директории",action=Metadata_Unload},
              iup.separator{},
              iup.item{title="Открыть новый файл с данными",action=Metadata_NewData},
              iup.separator{},
              iup.item{title="Добавить XML заголовок",value=_G.iuprops['atrium.metadata.xmlcapt'],action=(function() _G.iuprops['atrium.metadata.xmlcapt']=Iif(_G.iuprops['atrium.metadata.xmlcapt']=='ON','OFF','ON') end)},
            }:popup(iup.MOUSEPOS,iup.MOUSEPOS)
        end
    end)]]
    local function obj_mnu()
            local mnu = iup.menu
            {
              iup.item{title="Открыть как новый файл",action=Metadata_OpenNew},
              iup.item{title="Выгрузить и открыть в текущей директории",action=Metadata_Unload},
              iup.separator{},
              iup.item{title="Открыть новый файл с данными",action=Metadata_NewData},
              iup.separator{},
              iup.item{title="Добавить XML заголовок",value=_G.iuprops['atrium.metadata.xmlcapt'],action=(function() _G.iuprops['atrium.metadata.xmlcapt']=Iif(_G.iuprops['atrium.metadata.xmlcapt']=='ON','OFF','ON') end)},
            }:popup(iup.MOUSEPOS,iup.MOUSEPOS)
    end
    local function obj_resel(old_l)
        iup.SetAttribute(list_data, "DELLIN", "1-"..list_data.numlin)
    end
    list_obj:SetCommonCB(nil,obj_resel,nil,obj_mnu)

    txt_datamask = iup.text{expand='HORIZONTAL',tip='Маска кода объекта,\nвыбранного в верхнем гриде'}
    txt_datamask.k_any = (function(h,k) if k == iup.K_CR then SelectData() end end)
    list_data = iup.matrix{
    numcol=2, numcol_visible=2,  cursor="ARROW", alignment='ALEFT', heightdef=6,markmode='LIN', scrollbar="YES" ,
    resizematrix = "YES"  ,readonly="YES"  ,markmultiple="NO" ,height0 = 4, expand = "YES", framecolor="255 255 255",
    width0 = 0 ,rasterwidth1 = 50 ,rasterwidth2= 350}
    list_data:setcell(0, 1, "Id")
    list_data:setcell(0, 2, "Code")

    local function dat_mnu()
        local mnu = iup.menu
        {
          iup.item{title="Открыть как новый файл",action=Data_OpenNew},
          iup.item{title="Выгрузить и открыть в текущей директории",action=Data_Unload},
          iup.separator{},
          iup.item{title="Не выгружать ID и технические поля",value=_G.iuprops['atrium.data.cleanup'],action=(function() _G.iuprops['atrium.data.cleanup']=Iif(_G.iuprops['atrium.data.cleanup']=='ON','OFF','ON') end)},
          iup.item{title="WIN-1251",value=_G.iuprops['atrium.data.win1251'],action=(function() _G.iuprops['atrium.data.win1251']=Iif(_G.iuprops['atrium.data.win1251']=='ON','OFF','ON') end)},
        }:popup(iup.MOUSEPOS,iup.MOUSEPOS)
    end
    list_data:SetCommonCB(Data_OpenNew,nil,nil,dat_mnu)

    --iup.toogle
    SideBar_obj.Tabs.atrium =  {
handle =iup.split{
    iup.vbox{
        iup.hbox{
            cmb_syscust,
            txt_objmask,
            iup.button{image = "IMAGE_search", action=SelectMetadata},
            alignment="ACENTER", gap="3", margin="3x7"
        };
        list_obj;
    },iup.vbox{
        iup.hbox{
            iup.expander{iup.hbox{
                    iup.label{title=' Ref Dp: '},
                    cmb_RefDepth,
                    iup.label{title=' ApM.Dp: '},
                    cmb_apDept, chk_IncludeExt,
                    alignment="ACENTER", gap="3", margin="3x0"
                },
                barposition='LEFT', state='CLOSE', autoshow='YES'
            },
            txt_datamask,
            iup.button{image = "IMAGE_search", action=SelectData},
        },

        list_data,
        iup.hbox{
            iup.label{title = "Action:"},
            cmb_Action,
            chk_ign,
            cmb_mask,
            btnRun,
            alignment="ACENTER", gap="3", margin="3x7"
        };
    };
orientation="HORIZONTAL", name='splitAtrium'};

    OnSwitchFile = OnSwitch;
    OnOpen = OnSwitch;
    OnDoubleClick = OnDoubleClickLocal
}
end

FindTab_Init()

 AddEventHandler("GoToObjectDefenition", OpenChoiceMeta)

