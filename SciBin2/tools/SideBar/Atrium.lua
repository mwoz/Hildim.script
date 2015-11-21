require "mblua"
require("LuaXml")

local AD_Char = 129
local AD_VarChar = 200
local AD_Integer = 3
local AD_Double = 5
local AD_DBTimeStamp = 135
local AD_LongVarBinary = 205

--����������� ��� ���������� �������� (�� adodb::ParameterDirectionEnum)
local AD_ParamInput = 1          --Default. Indicates that the parameter represents an input parameter.
local AD_ParamInputOutput = 3    --Indicates that the parameter represents both an input and output parameter.
local AD_ParamOutput = 2         --Indicates that the parameter represents an output parameter."
local AD_ParamReturnValue = 4    --Indicates that the parameter represents a return value.
local AD_ParamUnknown = 0        --Indicates that the parameter direction is unknown
local XMLCAPT = '<?xml version="1.0" encoding="Windows-1251" standalone="yes"?>\n'

local cmb_Action, chk_ign, cmb_syscust, txt_objmask, txt_datamask, list_obj, list_data, cmb_mask, btnRun
local cmb_RefDepth, cmb_apDept, chk_IncludeExt,cmb_dataShem,exp_dataSchem,exp_dataOptions

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

local function AtriumCompare(strPath, strContent)
    local _, tmppath=shell.exec('CMD /c set TEMP',nil,true,true)
    tmppath=string.sub(tmppath,6,string.len(tmppath)-2)..'\\atrtmp'
    local f = io.open(tmppath, "w")
    strContent = strContent:gsub('\r\n','\n')
    f:write(strContent)
    f:flush()
    f:close()
    cmd=string.gsub(string.gsub(props['vsscompare'],'%%bname','"'..strPath..'"'),'%%yname','"'..tmppath..'"')
    shell.exec(cmd)
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
    if cmb_mask.value == '6' then --drop
        local msb = iup.messagedlg{buttons='YESNO', value='������� �������� �� ����?'}
        msb.popup(msb)
        if msb.buttonresponse == '1' then
            local t_xml = xml.eval(strXml)
            local code = t_xml['code']
            local msgParams = mblua.CreateMessage()
            dbAddProcParam(msgParams, "ObjectType_Code", code, AD_VarChar, AD_ParamInput, code:len() + 1)
                dbRunProc('mpDropMetadata', msgParams, function(handle,Opaque,iError,msgReplay)
                    print("�������� ���������� '"..code.."'. �����: "..msgReplay:ToString())
            end, 20, nil)
        end
        msb:destroy(msb)
    else
        local msgParams = mblua.CreateMessage()
        if tonumber(props["editor.unicode.mode"]) ~= IDM_ENCODING_DEFAULT then strXml = strXml:from_utf8(1251) end

        dbAddProcParam(msgParams, "Metadata"          , strXml, AD_VarChar, AD_ParamInput, strXml:len() + 1)
        dbAddProcParam(msgParams, "ExecMode", 'R', AD_VarChar, AD_ParamInput, 1)
        dbAddProcParam(msgParams, "ObjectMask", iup.GetAttribute(cmb_mask, cmb_mask.value), AD_VarChar, AD_ParamInput, 3)

        dbRunProc('mpGenerateSql', msgParams, SetReply, 20, nil)
    end
end

local function SelectData()
    if not list_obj.marked then return end
    local sel = list_obj.marked:find('1')
    if not sel then return end
    sel = sel - 1
    local tbl = iup.GetAttributeId2(list_obj, '', sel, 3)
    local bSceme
    if tbl == 'dbo.ObjectTypeForm' or tbl == 'dbo.Choice' then
        exp_dataOptions.barsize = '0'
        exp_dataOptions.state = 'CLOSE'
        exp_dataSchem.state = 'OPEN'
        bSceme = true
    elseif tbl == 'dbo.Report' then
        exp_dataOptions.barsize = '0'
        exp_dataOptions.state = 'CLOSE'
        exp_dataSchem.state = 'CLOSE'
        bSceme = false
    else
        exp_dataOptions.barsize = '20'
        exp_dataSchem.state = 'CLOSE'
        bSceme = false
    end
    iup.Refresh(exp_dataOptions)

    local nm = iup.GetAttributeId2(list_obj, '', sel, 3):gsub('^.-([%w_]+)$', '%1')
    local cd = iup.GetAttributeId2(list_obj, '', sel, 4)
    local sql
    local code = Iif(bSceme, iup.GetAttribute(cmb_dataShem, cmb_dataShem.value)..'.', '')..Trim(txt_datamask.value)
    if cd == nil then
        if list_obj:getcell(sel,1) == 'system.ObjectTypeForm' then
            sql = "select top 100 __DATA_MODEL_MODE = 'S', __INDEX_AUTO_ON = 1, f.ObjectTypeForm_Id, (o.ObjectType_Code + '.' + v.Tag + case when f.Presentation = '' then '' else '.' + f.Presentation end) as [ObjectTypeForm_Code] from ObjectTypeForm f\n"..
            "inner join ObjectType o on o.ObjectType_Id = f.ObjectType_Id\n"..
            "inner join ChoiceValue v on v.Value = f.FormType\n"..
            "inner join Choice c on c.Choice_Id = v.Choice_Id and c.Choice_Code = 'system.FormType'\n"..
            "where (o.ObjectType_Code + '.' + f.FormType) like ('"..code.."%') order by o.ObjectType_Code"
        else
            sql =  "select top 100 __DATA_MODEL_MODE = 'S', __INDEX_AUTO_ON = 1, "..nm.."_Id from "..tbl
            if tonumber(txt_datamask.value) ~= nil then sql =  sql.." where "..nm.."_Id >= "..tonumber(txt_datamask.value).." order by "..nm.."_Id" end
        end
    else
        sql =  "select top 100 __DATA_MODEL_MODE = 'S', __INDEX_AUTO_ON = 1, "..nm.."_Id, "..cd.." from "..tbl.." where "..cd.." like ('"..code.."%') order by "..cd
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

local function SelectMetadata(bPreset)
    --"select __DATA_MODEL_MODE = 'S', __INDEX_AUTO_ON = 1\n"..
   local sql =  "select top 100 __DATA_MODEL_MODE = 'S', __INDEX_AUTO_ON = 1, ObjectType_Code,ObjectType_Name,TableName, "..
   "convert(xml, Metadata).value('(/Template/DataModel/Tables/Table/Fields/Field[@type=''ObjectCode'']/@name)[1]', 'nvarchar(max)') as [CodeField]"..
   " from ObjectType where ObjectType_Code like ('"..iup.GetAttribute(cmb_syscust, cmb_syscust.value).."."..Trim(txt_objmask.value)..Iif(bPreset, "", "%").."')  order by ObjectType_Code"

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
        if bPreset then
            SelectData();
            iup.SetFocus(txt_datamask)
        end
    end,10,nil)
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

            if props['formengine.runafter'] == '1' then msg:SetPathValue("Open","Y") end

            _G['formengine.reloadtemplate'] = true
            mblua.Request(function(handle,Opaque,iError,msgReplay)
            _G['formengine.reloadtemplate'] = false
                if iError == 0 then
                    print(msgReplay:GetPathValue("strReplay"))
                    if props['formengine.runafter'] == '1' then
                        props['formengine.runafter'] = ''
                        if msgReplay:GetPathValue("PID") then  shell.activate_proc_wnd(msgReplay:GetPathValue("PID")) end
                    end
                else
                    print("Terminal not responded")
                end
            end,msg,3,nil)
            --mblua.Publish(msg)
            msg:Destroy()
        end
    end, 20, nil)
end

local function PutForm(objectType, formType, formPresent)
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
            if props['formengine.runafter'] == '1' then msg:SetPathValue("Open","Y") end
            _G['formengine.reloadtemplate'] = true
            mblua.Request(function(handle,Opaque,iError,msgReplay)
            _G['formengine.reloadtemplate'] = false
                if iError == 0 then
                    print(msgReplay:GetPathValue("strReplay"))
                    if props['formengine.runafter'] == '1' then
                        props['formengine.runafter'] = ''
                        if msgReplay:GetPathValue("PID") then  shell.activate_proc_wnd(msgReplay:GetPathValue("PID")) end
                    end
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
        PutForm(t_xml['objectType'], t_xml['type'], t_xml['presentation'])
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

local function Data_Unload(bCompare)
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
            if bCompare == true then
                AtriumCompare(strPath, msgReplay:GetPathValue('FormData'))
            else
                local f = io.open(strPath, "w")
                f:write('')
                f:flush()
                f:close()
                scite.Open(strPath)
                if _G.iuprops['atrium.data.win1251'] ~= 'ON' then scite.MenuCommand(IDM_ENCODING_UCS2LE) end
                editor:SetText(ProbablyToUTF(msgReplay:GetPathValue('FormData')))
                scite.MenuCommand(IDM_SAVE)
            end
        end,20,nil)
    else
        local strName = iup.GetAttributeId2(list_obj, '', list_obj.marked:find('1') - 1, 1):gsub('.*%.(.*)', '%1')..'.'..
            (iup.GetAttributeId2(list_data, '', list_data.marked:find('1') - 1, 2) or iup.GetAttributeId2(list_data, '', list_data.marked:find('1') - 1, 1))

        dbRunSql(Data_GetSql(), function(handle,Opaque,iError,msgReplay)
            if dbCheckError(iError, msgReplay) then return end
            local strPath = props['FileDir']..'\\'..strName..'.xml'
            if bCompare == true then
                AtriumCompare(strPath, msgReplay:GetPathValue('FormData'))
            else
                local f = io.open(strPath, "w")
                f:write('')
                f:flush()
                f:close()
                scite.Open(strPath)
                if _G.iuprops['atrium.data.win1251'] ~= 'ON' then scite.MenuCommand(IDM_ENCODING_UCS2LE) end
                editor:SetText(ProbablyToUTF(xml.eval(msgReplay:GetPathValue('xml')):str()))
                TryCleanUp()
                scite.MenuCommand(IDM_SAVE)
            end
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

local function Metadata_Unload(bCompare)
    local sel = list_obj.marked:find('1') - 1
    iup.GetAttributeId2(list_obj, '', sel, 1)
    local strName = iup.GetAttributeId2(list_obj, '', sel, 1)
    local sql =  "select  Metadata from ObjectType where ObjectType_Code = '"..strName.."'"

    dbRunSql(sql, function(handle,Opaque,iError,msgReplay)
        if dbCheckError(iError, msgReplay) then return end
        local strPath = props['FileDir']..'\\'..strName..'.xml'
        if bCompare==true then
            AtriumCompare(strPath, msgReplay:GetPathValue('Metadata'))
        else
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
        end
    end,20,nil)
end

local function GetEHXml(strType)
    local sel = list_obj.marked:find('1') - 1
    iup.GetAttributeId2(list_obj, '', sel, 1)
    local fType = iup.GetAttributeId2(list_obj, '', sel, 1)
    local msg = mblua.CreateMessage()
    local strSubj = 'SYSM.SAVETEMPLATE'
    if _G.iuprops["precompiller.radiususername"] ~= '' then
        strSubj = strSubj..'.'.._G.iuprops["precompiller.radiususername"]
    end
    msg:Subjects(strSubj)    msg:SetPathValue("Command","GetTemplate")
    msg:SetPathValue("ObjectType",fType)
    msg:SetPathValue("FormType",strType)

    mblua.Request(function(handle,Opaque,iError,msgReplay)
--[[        if iError ~= 0 then
            print('��������� ������� - �������� �� ��������')
            return
        end]]
        props['scite.new.file'] = '^'..msgReplay:GetPathValue("FileName")
        scite.MenuCommand(IDM_NEW)
        if _G.iuprops['atrium.data.win1251'] ~= 'ON' then scite.MenuCommand(IDM_ENCODING_UCS2LE) end
        editor:SetText(ProbablyToUTF(msgReplay:GetPathValue('xml')))
        --scite.MenuCommand(1468)
    end
    ,msg,15,null)
    msg:Destroy()
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
    cmb_Action = iup.list{dropdown="YES",visibleitems="15",size='70x0', expand='NO', tip='����������/�������� �������'}
    iup.SetAttribute(cmb_Action, 1, "insupd")
    iup.SetAttribute(cmb_Action, 2, "delete")
    cmb_Action.value = 1
    chk_ign = iup.toggle{title = "Ign. Id-s", tip='������������ Id ������� ��� �������\n(�������� �����)'}
    cmb_mask = iup.list{dropdown="YES",visibleitems="15",size='30x0', expand='NO', tip='program scripts|schema scripts|schema+program'}
    iup.SetAttribute(cmb_mask, 1, "P")
    iup.SetAttribute(cmb_mask, 2, "S")
    iup.SetAttribute(cmb_mask, 3, "SP")
    iup.SetAttribute(cmb_mask, 4, "SD")
    iup.SetAttribute(cmb_mask, 5, "SDP")
    iup.SetAttribute(cmb_mask, 6, "Drop")
    cmb_mask.value = 1
    btnRun = iup.button{image = 'IMAGE_FormRun', action=atrium_RunXml, tip='��������� ����� �����'}


    cmb_syscust = iup.list{dropdown="YES",visibleitems="15",size='70x0', expand='NO', tip='����������/�������� �������'}
    iup.SetAttribute(cmb_syscust, 1, "%")
    iup.SetAttribute(cmb_syscust, 2, "system")
    iup.SetAttribute(cmb_syscust, 3, "custom")
    cmb_syscust.value = 1


    txt_objmask = iup.list{editbox = "YES",dropdown="YES",visibleitems="15",expand='HORIZONTAL',tip='����� ����������'}
    iup.SetAttribute(txt_objmask, 1, "Choice")
    iup.SetAttribute(txt_objmask, 2, "ObjectTypeForm")
    iup.SetAttribute(txt_objmask, 3, "Report")
    txt_objmask.k_any = (function(h,k) if k == iup.K_CR then SelectMetadata(false) end end)
    txt_objmask.action = (function(h,text,item,state)
        if state == 1 then
            cmb_syscust.value = 2
            txt_objmask.value = text;
            SelectMetadata(true)
        end
    end)

    cmb_RefDepth = iup.list{dropdown="YES",visibleitems="15",size='20x0', expand='NO', tip='Reference Repth'}
    iup.SetAttribute(cmb_RefDepth, 1, "0")
    iup.SetAttribute(cmb_RefDepth, 2, "1")
    iup.SetAttribute(cmb_RefDepth, 3, "2")
    iup.SetAttribute(cmb_RefDepth, 4, "3")
    cmb_RefDepth.value = 1

    cmb_apDept = iup.list{dropdown="YES",visibleitems="15",size='20x0', expand='NO', tip='Reference Repth'}
    iup.SetAttribute(cmb_apDept, 1, "0")
    iup.SetAttribute(cmb_apDept, 2, "1")
    iup.SetAttribute(cmb_apDept, 3, "2")
    iup.SetAttribute(cmb_apDept, 4, "3")
    cmb_apDept.value = 2

    chk_IncludeExt = iup.toggle{title='En.ApM', tip='Enrich Appendix Multiple'}

    list_obj = iup.matrix{
    numcol=4, numcol_visible=4,  cursor="ARROW", alignment='ALEFT', heightdef=6,markmode='LIN', scrollbar="YES" ,
    resizematrix = "YES"  ,readonly="YES"  ,markmultiple="NO" ,height0 = 4, expand = "YES", framecolor="255 255 255",
    width0 = 0 ,rasterwidth1 = 150 ,rasterwidth2 = 150 ,rasterwidth3= 150,rasterwidth4= 15, map_cb = (function(h) h.size="1x1" end)}
  	list_obj:setcell(0, 1, "Code")
  	list_obj:setcell(0, 2, "Name")
  	list_obj:setcell(0, 3, "Table")
    local function Compare()
        Metadata_Unload(true)
    end
    local function obj_mnu()
        local mDif = nil
        if list_obj.marked then
            if shell.fileexists(props["FileDir"]..'//'..iup.GetAttributeId2(list_obj, '', list_obj.marked:find('1') - 1, 1)..'.xml') then
                mDif = iup.item{title="�������� � ������ � ������� ����������",action=Compare}
            end
        end
        local mnu = iup.menu
            {
              iup.item{title="������� ��� ����� ����",action=Metadata_OpenNew},
              iup.item{title="��������� � ������� � ������� ����������",action=Metadata_Unload}, nil,
              mDif,
              iup.separator{},
              iup.item{title="������� ����� ���� � �������",action=Metadata_NewData},
              iup.submenu{title='������� EH �����',
                  iup.menu{
                    iup.item{title="�����",action=function() GetEHXml('C') end, },
                    iup.item{title="�������",action=function() GetEHXml('B')  end,},
                    iup.item{title="������ ��������",action=function() GetEHXml('F') end,},
                    iup.item{title="�����",action=function() GetEHXml('S') end,},
                  }
              },
              iup.separator{},
              iup.item{title="�������� XML ���������",value=_G.iuprops['atrium.metadata.xmlcapt'],action=(function() _G.iuprops['atrium.metadata.xmlcapt']=Iif(_G.iuprops['atrium.metadata.xmlcapt']=='ON','OFF','ON') end)},
            }:popup(iup.MOUSEPOS,iup.MOUSEPOS)
    end
    local function obj_resel(old_l)
        iup.SetAttribute(list_data, "DELLIN", "1-"..list_data.numlin)
    end
    list_obj:SetCommonCB(nil,obj_resel,nil,obj_mnu)

    txt_datamask = iup.text{expand='HORIZONTAL',tip='����� ���� �������,\n���������� � ������� �����'}
    txt_datamask.k_any = (function(h,k) if k == iup.K_CR then SelectData() end end)
    list_data = iup.matrix{
    numcol=2, numcol_visible=2,  cursor="ARROW", alignment='ALEFT', heightdef=6,markmode='LIN', scrollbar="YES" ,
    resizematrix = "YES"  ,readonly="YES"  ,markmultiple="NO" ,height0 = 4, expand = "YES", framecolor="255 255 255",
    width0 = 0 ,rasterwidth1 = 50 ,rasterwidth2= 350, map_cb = (function(h) h.size="1x1" end)}
    list_data:setcell(0, 1, "Id")
    list_data:setcell(0, 2, "Code")
    local function CompareData()
        Data_Unload(true)
    end
    local function dat_mnu()
        local mDif = nil
        if list_obj.marked then
            local oExt = list_obj:getcell(list_obj.marked:find('1') - 1 ,1)
            if oExt == 'system.ObjectTypeForm' then oExt = '.cform'
            elseif oExt == 'system.Report' then oExt = '.rform'
            else oExt = '.xml' end
            if list_data.marked and shell.fileexists(props["FileDir"]..'\\'..(iup.GetAttributeId2(list_data, '', list_data.marked:find('1') - 1, 2) or iup.GetAttributeId2(list_data, '', list_data.marked:find('1') - 1, 1))..oExt) then
                mDif = iup.item{title="�������� � ������ � ������� ����������",action=CompareData}
            end
        end
        local mnu = iup.menu
        {
          iup.item{title="������� ��� ����� ����",action=Data_OpenNew},
          iup.item{title="��������� � ������� � ������� ����������",action=Data_Unload},
          mDif,
          iup.separator{},
          iup.item{title="�� ��������� ID � ����������� ����",value=_G.iuprops['atrium.data.cleanup'],action=(function() _G.iuprops['atrium.data.cleanup']=Iif(_G.iuprops['atrium.data.cleanup']=='ON','OFF','ON') end)},
          iup.item{title="WIN-1251",value=_G.iuprops['atrium.data.win1251'],action=(function() _G.iuprops['atrium.data.win1251']=Iif(_G.iuprops['atrium.data.win1251']=='ON','OFF','ON') end)},
        }:popup(iup.MOUSEPOS,iup.MOUSEPOS)
    end
    list_data:SetCommonCB(Data_OpenNew,nil,nil,dat_mnu)


    cmb_dataShem = iup.list{dropdown="YES",visibleitems="15",size='40x0', expand='NO', tip='����������/�������� �������'}
    iup.SetAttribute(cmb_dataShem, 1, "%")
    iup.SetAttribute(cmb_dataShem, 2, "system")
    iup.SetAttribute(cmb_dataShem, 3, "custom")
    cmb_dataShem.value = 1
    exp_dataSchem = iup.expander{iup.hbox{
        cmb_dataShem,
        },
        barposition='LEFT', state='CLOSE', barsize = '0', visible='NO'
    }
    exp_dataOptions = iup.expander{iup.hbox{
            iup.label{title=' Ref Dp: '},
            cmb_RefDepth,
            iup.label{title=' ApM.Dp: '},
            cmb_apDept, chk_IncludeExt,
            alignment="ACENTER", gap="3", margin="3x0"
        },
        barposition='LEFT', state='CLOSE', autoshow='YES'
    }
    --iup.toogle
    SideBar_Plugins.atrium =  {
handle =iup.split{
    iup.vbox{
        iup.scrollbox{iup.hbox{
            cmb_syscust,
            txt_objmask,
            iup.button{image = "IMAGE_search", action=function() SelectMetadata(false) end},
            alignment="ACENTER", gap="3", margin="3x7"
        },scrollbar='NO', minsize='x35', maxsize='x35', expand="HORIZONTAL",};
        list_obj;
    },iup.vbox{
        iup.scrollbox{iup.hbox{
            exp_dataSchem,
            exp_dataOptions,
            txt_datamask,
            iup.button{image = "IMAGE_search", action=SelectData},
        },scrollbar='NO', minsize='x29', maxsize='x29', expand="HORIZONTAL",};

        list_data,
        iup.scrollbox{iup.hbox{
            iup.label{title = "Action:"},
            cmb_Action,
            chk_ign,
            cmb_mask,
            btnRun,
            alignment="ACENTER", gap="3",
        },scrollbar='NO', minsize='x29', maxsize='x29', expand="HORIZONTAL",};
    };
orientation="HORIZONTAL", name='splitAtrium',layoutdrag = 'NO'};

    OnSwitchFile = OnSwitch;
    OnOpen = OnSwitch;
    OnDoubleClick = OnDoubleClickLocal
}
end

FindTab_Init()

 AddEventHandler("GoToObjectDefenition", OpenChoiceMeta)

local function FieldsSql(objectType, path, condition)
return
" select top 100 __DATA_MODEL_MODE = 'S', __INDEX_AUTO_ON = 1                                                             \n"..
" declare @path nvarchar(4000), @fld nvarchar(100), @object_code nvarchar(100)                                            \n"..
" declare @x xml, @hdoc int, @strPath varchar(256)                                                                        \n"..
" Set @path = '"..path.."'                                                                                                \n"..
" set @object_code = '"..objectType.."'                                                                                   \n"..
" while LEN(@path) > 1                                                                                                    \n"..
" begin                                                                                                                   \n"..
" 	set @fld = SUBSTRING(@path,1, CHARINDEX('/', @path,1)-1)                                                              \n"..
" 	set @path = SUBSTRING(@path, CHARINDEX('/', @path,1 )+1, 4000)                                                        \n"..
" 	select @x = CONVERT(xml, d.Metadata),                                                                                 \n"..
" 	@strPath = case                                                                                                       \n"..
" 		when d.Category = 'R' or d.Category = 'D'  then '/Template/DataModel/Tables/Table[@type=''Master'']/Fields/Field' \n"..
" 		when d.Category = 'E'  then '/Template/DataModel/Tables/Table[@type=''AppendixSingle'']/Fields/Field'             \n"..
" 		when d.Category = 'P' or d.Category = 'W' then '/Template/DataModel/Fields/Field'                                 \n"..
" 		end                                                                                                               \n"..
" 	from ObjectType d                                                                                                     \n"..
" 	where d.ObjectType_Code = @object_code                                                                                \n"..
" 	exec sp_xml_preparedocument @hdoc out, @x                                                                             \n"..
" 	select @object_code = obj from openxml(@hdoc, @strPath) with                                                          \n"..
" 	(                                                                                                                     \n"..
" 		name varchar(500) 'attribute::name',                                                                              \n"..
" 		obj varchar(500) 'attribute::object'		                                                                      \n"..
" 	)where name =  @fld                                                                                                   \n"..
" 	exec sp_xml_removedocument @hdoc		                                                                              \n"..
" end                                                                                                                     \n"..
" 	select @x = CONVERT(xml, d.Metadata),                                                                                 \n"..
" 	@strPath = case                                                                                                       \n"..
" 		when d.Category = 'R' or d.Category = 'D'  then '/Template/DataModel/Tables/Table[@type=''Master'']/Fields/Field' \n"..
" 		when d.Category = 'E'  then '/Template/DataModel/Tables/Table[@type=''AppendixSingle'']/Fields/Field'             \n"..
" 		when d.Category = 'P' or d.Category = 'W' then '/Template/DataModel/Fields/Field'                                 \n"..
" 		end                                                                                                               \n"..
" 	from ObjectType d                                                                                                     \n"..
" 	where d.ObjectType_Code = @object_code	                                                                              \n"..
" 	exec sp_xml_preparedocument @hdoc out, @x                                                                             \n"..
" 	select name from openxml(@hdoc, @strPath) with                                                                        \n"..
" 	(                                                                                                                     \n"..
" 		name varchar(500) 'attribute::name',                                                                              \n"..
" 		typ varchar(32) 'attribute::type'		                                                                          \n"..
" 	)where "..condition.."                                                                                                \n"..
" 	exec sp_xml_removedocument @hdoc                                                                                      \n"

end

function atrium_controlList(clbk)
    local t_xml = xml.eval(editor:GetText())
    local f_clb = clbk

    dbRunSql(FieldsSql(t_xml['objectType'], '/', '1=1'),
    (function(handle,Opaque,iError,msgReplay)
        if dbCheckError(iError, msgReplay) then return end
        local _, mc = msgReplay:Counts()
        local strLst = ''
        for i = 0, mc - 1 do
            if i>0 then strLst = strLst..'|' end
            strLst = strLst..msgReplay:Message(i):GetPathValue('name')
        end
        f_clb(strLst)
    end)
    ,20,nil)
end

function atrium_columnList(clbk)
    local function fnd(tb)
        for k,v in pairs(tb) do
            if type(v) == 'table' then
                if v[0] == 'Form' or v[0] == 'Columns' or v[0] == 'Lookup' then
                    local res = fnd(v)
                    if res then
                        if v['code'] then return v['code']..'/'..res
                        else return res end
                    end
                elseif v[0] == 'Column' then
                    if v['code'] == '' then return '' end
                end
            end
        end
    end

    local t_xml = xml.eval(editor:GetText())
    local path = fnd(t_xml)
    local f_clb = clbk
    if not path then return end

    dbRunSql(FieldsSql(t_xml['objectType'], path, "typ <> 'Reference' and typ <> 'Asset'"),
    (function(handle,Opaque,iError,msgReplay)
        if dbCheckError(iError, msgReplay) then return end
        local _, mc = msgReplay:Counts()
        local strLst = ''
        for i = 0, mc - 1 do
            if i>0 then strLst = strLst..'|' end
            strLst = strLst..msgReplay:Message(i):GetPathValue('name')
        end
        f_clb(strLst)
    end)
    ,20,nil)
end

function atrium_lookupList(clbk)
    local function fnd(tb)
        for k,v in pairs(tb) do
            if type(v) == 'table' then
                if v[0] == 'Form' or v[0] == 'Columns' or v[0] == 'Lookup' then
                    --print(v[0],v['code'])
                    if v['code'] == '' then return '' end
                    local res = fnd(v)
                    if res then
                        if v['code'] then return v['code']..'/'..res
                        else return res end
                    end
                end
            end
        end
    end

    local t_xml = xml.eval(editor:GetText())
    local path = fnd(t_xml)
    local f_clb = clbk
    if not path then return end

    dbRunSql(FieldsSql(t_xml['objectType'], path, "typ = 'Reference' or typ = 'Asset'"),
    (function(handle,Opaque,iError,msgReplay)
        if dbCheckError(iError, msgReplay) then return end
        local _, mc = msgReplay:Counts()
        local strLst = ''
        for i = 0, mc - 1 do
            if i>0 then strLst = strLst..'|' end
            strLst = strLst..msgReplay:Message(i):GetPathValue('name')
        end
        f_clb(strLst)
    end)
    ,20,nil)
end
