require "luacom"

local dlg = _G.dialogs["align"]
local txt_listass, chk_ass, tbl_ass, chk_sendTo
tbl_ass = {}

local WshShell = luacom.CreateObject('WScript.Shell')
local fso = luacom.CreateObject("Scripting.FileSystemObject");
local reg_backup = 'HKLM\\SOFTWARE\\SciTE\\Script\\WinIntegrator\\';

if dlg then
    dlg:destroy()
    dlg = nil
    _G.dialogs["align"] = nil
end

if dlg == nil then
    txt_listass = iup.text{size = '250x0', mask = "(/d|/w|_|;|[а-я]|[А-Я])+"}
    local btn_ok = iup.button  {title = "OK"}
    chk_sendTo = iup.toggle{title = 'Добавить HildiM в контекстное меню "Отправить"'}
    chk_ass = iup.toggle{title = "Связать с расширениями"; action = function(h)
        txt_listass.active = Iif(h.value == 'ON', 'YES', 'NO')
    end}

    iup.SetHandle("WININT_BTN_OK", btn_ok)

    local btn_esc = iup.button  {title = "Cancel"}
    iup.SetHandle("WININT_BTN_ESC", btn_esc)

    local vbox = iup.vbox{
        iup.hbox{chk_ass, txt_listass, alignment = 'ACENTER'},
        iup.hbox{chk_sendTo, alignment = 'ACENTER'},
        iup.hbox{btn_ok, iup.fill{}, btn_esc},
    gap = 2, margin = "4x4" }
    local result = false
    dlg = iup.scitedialog{vbox; title = "Интеграция с Windows", defaultenter = "WININT_BTN_OK", defaultesc = "WININT_BTN_ESC", maxbox = "NO", minbox = "NO", resize = "NO", sciteparent = "SCITE", sciteid = "align" }

    function btn_ok:action()
        if chk_ass.value == 'ON' then
            local l = txt_listass.value
            for t in l:gmatch('[^;]+') do
                if (tbl_ass[t] or 0) ~= 1 then
                    local current_association
                    luacom.SkipCheckError(WshShell)
                    current_association = WshShell:RegRead('HKCR\\.'..t..'\\')
                    WshShell:RegWrite(reg_backup..t, current_association or '');
                    WshShell:RegWrite('HKCR\\.'..t..'\\', 'SciTE.File');
                end
                tbl_ass[t] = -1
            end

            WshShell:RegWrite(reg_backup..'associations', txt_listass.value);
            WshShell:RegWrite('HKCR\\SciTE.File\\', 'SciTE file');
            WshShell:RegWrite('HKCR\\SciTE.File\\DefaultIcon\\', props["SciteDefaultHome"]..'\\Hildim.exe,1');
            WshShell:RegWrite('HKCR\\SciTE.File\\shell\\open\\command\\', '"'..props["SciteDefaultHome"]..'\\HildiM.exe" "%1"');

        end
        for t, v in pairs(tbl_ass) do
            if v == 1 then
                local old_association
                luacom.SkipCheckError(WshShell)
                old_association = WshShell:RegRead(reg_backup..t);
                luacom.SkipCheckError(WshShell)
                WshShell:RegDelete(reg_backup..t);
                WshShell:RegWrite('HKCR\\.'..t..'\\', old_association);
            end
        end
        if chk_ass.value == 'OFF' then
            luacom.SkipCheckError(WshShell)
            WshShell:RegDelete(reg_backup..'associations');
        end

        if chk_sendTo.value == 'ON' then
            local oLnk = WshShell:CreateShortcut(WshShell.SpecialFolders("SendTo").. "\\HildiM.lnk")
            oLnk.TargetPath = props["SciteDefaultHome"]..'\\Hildim.exe'
            oLnk:Save()
        else
            luacom.SkipCheckError(fso)
            fso:DeleteFile(WshShell.SpecialFolders("SendTo").."\\HildiM.lnk", true);
        end

        dlg:hide()
        return IUP_CLOSE
    end

    function btn_esc:action()
        dlg:hide()
    end
else
    dlg:show()
end

luacom.SkipCheckError(WshShell)
txt_listass.value = WshShell:RegRead(reg_backup..'associations')

if txt_listass.value == "" then
    txt_listass.active = 'NO'
    chk_ass.value = 'OFF'
    txt_listass.value = 'm;xml;inc;lua;form;incl;cform;rform;wform'
else
    chk_ass.value = 'ON'
    local tblEr = {}
    local l = txt_listass.value
    for t in l:gmatch('[^;]+') do

        luacom.SkipCheckError(WshShell)
        local chk = WshShell:RegRead('HKCR\\.'..t..'\\')
        if chk ~= 'SciTE.File' then
            table.insert(tblEr, t)
            tbl_ass[t] = 0
        else
            tbl_ass[t] = 1
        end
    end
    if #tblEr > 0 then iup.Message("Warning", "Изменены ассоциации для сдедующих расширений:\n".. table.concat(tblEr, '\n') ) end
end

if fso:FileExists(WshShell.SpecialFolders("SendTo").."\\HildiM.lnk") then chk_sendTo.value = 'ON' end
