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


local cmb_Action, chk_ign, cmb_syscust, txt_objmask, txt_datamask, list_obj, list_data, cmb_mask, btnRun

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

    mblua.Request(funCallback,msg,10,msgOpaq)
    msg:Destroy()
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
        print("Get Object Info Error: "..iError)
        return true
    end
    if msgReplay:GetPathValue("ErrorMessage") ~= nil and msgReplay:GetPathValue("ErrorMessage") ~='' then
        print(msgReplay:GetPathValue("ErrorMessage"))
        return true
    end
end

local function OnSwitch()
    local bEn = false
    if props['FileExt'] == 'xml' then
        local t_xml = xml.eval(editor:GetText())
        if t_xml then if t_xml[0] ~= 'template' then bEn = true end end
    end
    btnRun.active = Iif(bEn, 'YES', 'NO')
end

local function OnOpenLocal()

end

local function SetReply(handle,Opaque,iError,msgReplay)
    if dbCheckError(iError, msgReplay) then return end
    print(msgReplay:ToString())
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

    dbAddProcParam(msgParams, "Usr", 'atrium', AD_VarChar, AD_ParamInput, 64)
    dbAddProcParam(msgParams, "Action", action, AD_VarChar, AD_ParamInput, 64)
    dbAddProcParam(msgParams, "XmlData"          , strXml, AD_VarChar, AD_ParamInput, strXml:len() + 1)
    dbAddProcParam(msgParams, "Object_Id"        , objId, AD_Double, AD_ParamOutput, 4)
    dbAddProcParam(msgParams, "IgnoreIdentifiers", IgnId, AD_VarChar, AD_ParamInput, 1)
    dbAddProcParam(msgParams, "IgnoreRevision"   , "Y", AD_VarChar, AD_ParamInput, 1)
  print(msgParams:ToString())
    dbRunProc(obj..'_IUD', msgParams, SetReply, 10, nil)

end

local function ApplyMetadata(t_xml)

    local strXml = t_xml:str()

    local msgParams = mblua.CreateMessage()

    dbAddProcParam(msgParams, "Metadata"          , strXml, AD_VarChar, AD_ParamInput, strXml:len() + 1)
    dbAddProcParam(msgParams, "ExecMode", 'R', AD_VarChar, AD_ParamInput, 1)
    dbAddProcParam(msgParams, "ObjectMask", iup.GetAttribute(cmb_mask, cmb_mask.value), AD_VarChar, AD_ParamInput, 3)

  print(msgParams:ToString())
    dbRunProc('mpGenerateSql', msgParams, SetReply, 10, nil)
end

local function SelectMetadata()
    --"select __DATA_MODEL_MODE = 'S', __INDEX_AUTO_ON = 1\n"..
   local sql =  "select top 100 __DATA_MODEL_MODE = 'S', __INDEX_AUTO_ON = 1, ObjectType_Code,ObjectType_Name,TableName from ObjectType where ObjectType_Code like ('"..iup.GetAttribute(cmb_syscust, cmb_syscust.value).."."..txt_objmask.value.."%')"

    dbRunSql(sql, function(handle,Opaque,iError,msgReplay)
        if dbCheckError(iError, msgReplay) then return end
        local _, mc = msgReplay:Counts()
        iup.SetAttribute(list_obj, "DELLIN", "1-"..list_obj.numlin)
        iup.SetAttribute(list_obj, "ADDLIN", "1-"..mc)
        for i = 0, mc - 1 do
            list_obj:setcell(i + 1, 1, msgReplay:Message(i):GetPathValue('ObjectType_Code'))
            list_obj:setcell(i + 1, 2, msgReplay:Message(i):GetPathValue('ObjectType_Name'))
            list_obj:setcell(i + 1, 3, msgReplay:Message(i):GetPathValue('TableName'))
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
    local nm = iup.GetAttributeId2(list_obj, '', sel, 1):gsub('.*%.(.*)', '%1')
    local sql =  "select top 100 __DATA_MODEL_MODE = 'S', __INDEX_AUTO_ON = 1, "..nm.."_Id, "..nm.."_Code from "..tbl.." where "..nm.."_Code like ('"..txt_datamask.value.."%')"
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
    end,10,nil)
end

local function RunXml()
    local t_xml = xml.eval(editor:GetText())
    local strObjType = t_xml[0]
    if strObjType == 'Template' then
        ApplyMetadata(t_xml)
    else
        PutData(t_xml,strObjType)
    end
end

local function Data_GetSql()
    local sel = list_obj.marked:find('1') - 1
    local strProc = iup.GetAttributeId2(list_obj, '', sel, 3)..'_Get'

    sel = list_data.marked:find('1') - 1
    local id = tonumber(iup.GetAttributeId2(list_data, '', sel, 1))
    return "declare @XmlData tLongText\n"..
    "exec "..strProc.." 'atrium', "..id..", @XmlData output\n"..
    "select @XmlData as [xml]"
end
local function Data_OpenNew()
    dbRunSql(Data_GetSql(),function(handle,Opaque,iError,msgReplay)
        if dbCheckError(iError, msgReplay) then return end
        scite.MenuCommand(IDM_NEW)
        editor:SetText(xml.eval(msgReplay:GetPathValue('xml')):str())
        scite.MenuCommand(1468)
    end,10,nil)
end

local function Data_Unload()
    local strName = iup.GetAttributeId2(list_obj, '', list_obj.marked:find('1') - 1, 3):gsub('.*%.(.*)', '%1')..'.'..
        iup.GetAttributeId2(list_data, '', list_data.marked:find('1') - 1, 1)

    dbRunSql(Data_GetSql(), function(handle,Opaque,iError,msgReplay)
        if dbCheckError(iError, msgReplay) then return end
        local strPath = props['FileDir']..'\\'..strName..'.xml'
        local f = io.open(strPath, "w")
        f:write(xml.eval(msgReplay:GetPathValue('xml')):str())
        f:close()
        scite.Open(strPath)
        scite.MenuCommand(1468)
    end,10,nil)
end

local function Metadata_OpenNew()
    local sel = list_obj.marked:find('1') - 1
    local sql =  "select  Metadata from ObjectType where ObjectType_Code = '"..iup.GetAttributeId2(list_obj, '', sel, 1).."'"
    dbRunSql(sql, function(handle,Opaque,iError,msgReplay)
        if dbCheckError(iError, msgReplay) then return end
        scite.MenuCommand(IDM_NEW)
        editor:SetText(xml.eval(msgReplay:GetPathValue('Metadata')):str())
        scite.MenuCommand(1468)
    end,10,nil)
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
        f:write(xml.eval(msgReplay:GetPathValue('Metadata')):str())
        f:close()
        scite.Open(strPath)
        scite.MenuCommand(1468)
    end,10,nil)
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
    cmb_mask.value = 1
    btnRun = iup.button{image = 'IMAGE_FormRun', action=RunXml, tip='Обработка всего файла'}


    cmb_syscust = iup.list{dropdown="YES",visible_items="15",size='70x0', expand='NO', tip='Сохранение/Удаление объекта'}
    iup.SetAttribute(cmb_syscust, 1, "%")
    iup.SetAttribute(cmb_syscust, 2, "system")
    iup.SetAttribute(cmb_syscust, 3, "custom")
    cmb_syscust.value = 1

    txt_objmask = iup.text{expand='HORIZONTAL',tip='Маска метаданных'}
    list_obj = iup.matrix{
    numcol=3, numcol_visible=3,  cursor="ARROW", alignment='ALEFT', heightdef=6,markmode='LIN', scrollbar="YES" ,
    resizematrix = "YES"  ,readonly="YES"  ,markmultiple="NO" ,height0 = 4, expand = "YES", framecolor="255 255 255",
    width0 = 0 ,rasterwidth1 = 150 ,rasterwidth2 = 150 ,rasterwidth3= 150}
  	list_obj:setcell(0, 1, "Code")
  	list_obj:setcell(0, 2, "Name")
  	list_obj:setcell(0, 3, "Table")
    list_obj.click_cb = (function(h, lin, col, status)
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
              iup.item{title="Выгрузить и открыть в текущей дериктории",action=Metadata_Unload},
              iup.separator{},
              iup.item{title="Удалить",action=Metadata_Delete},
            }:popup(iup.MOUSEPOS,iup.MOUSEPOS)
        end
    end)

    txt_datamask = iup.text{expand='HORIZONTAL',tip='Маска кода объекта,\nвыбранного в верхнем гриде'}
    list_data = iup.matrix{
    numcol=2, numcol_visible=2,  cursor="ARROW", alignment='ALEFT', heightdef=6,markmode='LIN', scrollbar="YES" ,
    resizematrix = "YES"  ,readonly="YES"  ,markmultiple="NO" ,height0 = 4, expand = "YES", framecolor="255 255 255",
    width0 = 0 ,rasterwidth1 = 50 ,rasterwidth2= 350}
    list_data:setcell(0, 1, "Id")
    list_data:setcell(0, 2, "Code")

    list_data.click_cb = (function(h, lin, col, status)
        local sel = 0
        if list_data.marked then sel = list_data.marked:find('1') - 1 end
        iup.SetAttribute(list_data,  'MARK'..sel..':0', 0)
        iup.SetAttribute(list_data, 'MARK'..lin..':0', 1)
        list_data.redraw = lin..'*'
        if iup.isbutton3(status) then
            h.focus_cell = lin..':'..col
            local mnu = iup.menu
            {
              iup.item{title="Открыть как новый файл",action=Data_OpenNew},
              iup.item{title="Выгрузить и открыть в текущей дериктории",action=Data_Unload},
              iup.separator{},
              iup.item{title="Удалить",action=Metadata_Delete},
            }:popup(iup.MOUSEPOS,iup.MOUSEPOS)
        end
    end)

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
}
end

FindTab_Init()


