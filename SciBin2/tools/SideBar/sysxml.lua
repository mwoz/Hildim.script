

local function OnSwitch()
    if TabBar_obj.handle ~= nil then TabBar_obj.handle.size = TabBar_obj.size end
    if editor.Lexer == SCLEX_XML then
        TabBar_obj.Tabs.sysxml.handle.state = 'OPEN'
    else
        TabBar_obj.Tabs.sysxml.handle.state = 'CLOSE'
    end
end

local function FindTab_Init()

    TabBar_obj.Tabs.sysxml =  {
        handle =iup.expander{iup.hbox{   iup.label{title = "123:"}
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


