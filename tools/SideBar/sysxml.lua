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


local cmb_Action, chk_ign

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

    print(msg:ToString())

    mblua.Request(funCallback,msg,10,msgOpaq)
    msg:Destroy()
end

local function OnSwitch()
    if TabBar_obj.handle ~= nil then TabBar_obj.handle.size = TabBar_obj.size end
    if editor.Lexer == SCLEX_XML then
        TabBar_obj.Tabs.sysxml.handle.state = 'OPEN'
    else
        TabBar_obj.Tabs.sysxml.handle.state = 'CLOSE'
    end
end

local function SetReply(handle,Opaque,iError,msgReplay)
    if iError ~= 0 then
        print("Get Object Info Error: "..iError)
        return
    end
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

    dbRunProc(obj..'_IUD', msgParams, SetReply, nil, nil)

end

local function ApplyMetadata(t_xml)
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

local function FindTab_Init()
    cmb_Action = iup.list{dropdown="YES",visible_items="15",size='70x0', expand='NO', tip='Mb-префикс Db Adapter-а, используемого для посылки запросов при показе списков полей таблиц и пр.\n(Modullar - кастомная база,Radius  - основная)'}
    iup.SetAttribute(cmb_Action, 1, "insupd")
    iup.SetAttribute(cmb_Action, 2, "delete")
    cmb_Action.value = 1
    chk_ign = iup.toggle{title = "Ign. Id-s"}

    --iup.toogle
    TabBar_obj.Tabs.sysxml =  {
        handle =iup.expander{iup.hbox{
                                iup.label{title = "Action"},
                                cmb_Action,
                                chk_ign,
                                iup.button{image = 'IMAGE_FormRun', action=RunXml, tip='Обработка всего файла'},
                                alignment="ACENTER"
                        };
                        barposition='LEFT',
                        barsize='0',
                        state='CLOSE'
                    };
                    OnSwitchFile = OnSwitch;
                    OnOpen = OnSwitch;
                }
end

FindTab_Init()


