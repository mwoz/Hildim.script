
----------------------------------------------------------
-- tab0:memo_path   Path and Mask
----------------------------------------------------------

local txt_Template
local txt_BaseNameSuffix
local txt_RadiusUserName
-- local cmb_resent
local chk_DebugMode, btn_FormRun, btn_AddDoc


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
    if props["FileExt"]:lower() == 'xml' then btn_AddDoc.active='YES'
    else  btn_AddDoc.active='NO' end

    if tonumber(cmb_resent.count) ~= 0 then btn_FormRun.active = 'YES'
    else btn_FormRun.active = 'NO' end
end

local function OnSwitch()
    if TabBar_obj.handle ~= nil then TabBar_obj.handle.size = TabBar_obj.size end
	local ext = props["FileExt"]:lower() -- a bit unsafe...
    if ext == 'xml' or ext == 'inc' then
        TabBar_obj.Tabs.template.handle.state = 'OPEN'
    else
        TabBar_obj.Tabs.template.handle.state = 'CLOSE'
    end
    SSCtrls()
end

local function FindTab_Init()

	if props['precompiller.radiususername'] == nil then props['precompiller.radiususername'] = '' end
	txt_RadiusUserName = iup.text{expand='NO',size='70x0', tip='��� ������������ Radius\n���� � ������������ ������� ����� DebugTools,\n�� ��������� ������ �������������'}
	txt_RadiusUserName.map_cb=(function(h)h.value = props['precompiller.radiususername'] end)
    txt_RadiusUserName.valuechanged_cb=(function(h) props['precompiller.radiususername'] = h.value end)

    chk_DebugMode = iup.toggle{title = "Dbg Mode",
                        action=(function(h) if h.value == 'ON' then props['precompiller.debugmode'] = 1
                                            else props['precompiller.debugmode'] = 0 end end), tip="���� ��������, �� � ��������� ������� ����� ����������������\n������, ������������ � '#DEBUG\n(����� �������������� ��� ������ ���������� �����������)"}
    chk_DebugMode.map_cb=(function(h) if props['precompiller.debugmode'] == '1' then h.value = 'ON' end end)

    cmb_resent = iup.list{dropdown="YES",visible_items="15", expand='NO', size='150x0',
            action=(function(h, text, item, state) props['precompiller.xmlname'] = text end), tip='���� ��� ����������.\n(����� �� ��������� ���������������� ������)'}

    btn_AddDoc = iup.button{image = 'IMAGE_AddDocument',bgcolor={0,0,0}, action=(function() iup.PassFocus();precomp_PreCompileTemplate();SSCtrls() end), tip='��������� ������� ������ XML �� �������\n������ � �������� ��� � ������(F7)'}
    btn_FormRun = iup.button{image = 'IMAGE_FormRun', action=listCalc_CompileSelectedTemplate, tip='������� ��������� ������ � ���������\n��� �� ����������� � Radius'}
    TabBar_obj.Tabs.template =  {
        handle =iup.expander{iup.hbox{   iup.label{title = "User:"},
                            txt_RadiusUserName,
                            chk_DebugMode,
                            iup.label{title = "Template:"},
                            btn_AddDoc;
                            cmb_resent,
                            btn_FormRun,
                            iup.button{image = 'IMAGE_AlignToGridHS', action=(function() iup.PassFocus();template_MoveControls() end), tip='������ ���������������� ���������(Alt+M)'};
                            iup.button{image = 'IMAGE_FormatBasic', action=(function() iup.PassFocus();IndentBlockUp() end), tip='�������������� ���� �� ������(Ctrl+{)\n���� ������ ��������� � ����� ������, ����������� ����(End If, Next, End Sub...)\n�� ���� ���� ����� �������������� �� ����� ����������'};
                            alignment="ACENTER"
                        };
                        barposition='LEFT',
                        barsize='0'
                    };
                    OnSwitchFile = OnSwitch;
                    OnOpen = OnSwitch;
                    OnSave = SSCtrls;
                }
end

FindTab_Init()


