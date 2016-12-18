require "luacom"

local dlg = _G.dialogs["winint"]
local txt_listass, chk_ass, tbl_ass, tbl_ass_set, chk_sendTo, txt_listass_set, chk_ass_set
tbl_ass = {}
tbl_ass_set = {}

local WshShell = luacom.CreateObject('WScript.Shell')
local fso = luacom.CreateObject("Scripting.FileSystemObject");
local reg_backup = 'HKLM\\SOFTWARE\\SciTE\\Script\\WinIntegrator\\';

if dlg then
    dlg:destroy()
    dlg = nil
    _G.dialogs["winint"] = nil
end

if dlg == nil then
    txt_listass = iup.text{size = '250x0', mask = "(/d|/w|_|;|[а-я]|[А-Я])+"}
    chk_ass = iup.toggle{title = "Связать с расширениями:"; action = function(h)
        txt_listass.active = Iif(h.value == 'ON', 'YES', 'NO')
    end}

    txt_listass_set = iup.text{size = '180x0', mask = "(/d|/w|_|;|[а-я]|[А-Я])+"}
    chk_ass_set = iup.toggle{title = "Обрабатывать конфигурационные файлы:"; action = function(h)
        txt_listass_set.active = Iif(h.value == 'ON', 'YES', 'NO')
    end}

    local btn_ok = iup.button  {title = "OK"}
    chk_sendTo = iup.toggle{title = 'Добавить HildiM в контекстное меню "Отправить"'}

    iup.SetHandle("WININT_BTN_OK", btn_ok)

    local btn_esc = iup.button  {title = "Cancel"}
    iup.SetHandle("WININT_BTN_ESC", btn_esc)

    local vbox = iup.vbox{
        iup.hbox{chk_ass, iup.fill{}, txt_listass, alignment = 'ACENTER'},
        iup.hbox{chk_sendTo, alignment = 'ACENTER'},
        iup.hbox{chk_ass_set, iup.fill{}, txt_listass_set, alignment = 'ACENTER', expand ='HORIZONTAL'},
        iup.hbox{btn_ok, iup.fill{}, btn_esc},
    gap = 2, margin = "4x4" }
    local result = false
    dlg = iup.scitedialog{vbox; title = "Интеграция с Windows", defaultenter = "WININT_BTN_OK", defaultesc = "WININT_BTN_ESC", maxbox = "NO", minbox = "NO", resize = "NO", sciteparent = "SCITE", sciteid = "winint" }

    function btn_ok:action()
        local function WriteReg(txt, chk, tbl, strBack, strType, strCapt, strIcon)
            if chk.value == 'ON' then
                local l = txt.value
                for t in l:gmatch('[^;]+') do
                    if (tbl[t] or 0) ~= 1 then
                        local current_association
                        luacom.SkipCheckError(WshShell)
                        current_association = WshShell:RegRead('HKCR\\.'..t..'\\')
                        WshShell:RegWrite(reg_backup..t, current_association or '');
                        WshShell:RegWrite('HKCR\\.'..t..'\\', strType);
                    end
                    tbl[t] = -1
                end

                WshShell:RegWrite(reg_backup..strBack, txt.value);
                WshShell:RegWrite('HKCR\\'..strType..'\\', strCapt);
                WshShell:RegWrite('HKCR\\'..strType..'\\DefaultIcon\\', props["SciteDefaultHome"]..'\\Hildim.exe'..strIcon);
                WshShell:RegWrite('HKCR\\'..strType..'\\shell\\open\\command\\', '"'..props["SciteDefaultHome"]..'\\HildiM.exe" "%1"');

            end
            for t, v in pairs(tbl) do
                if v == 1 then
                    local old_association
                    luacom.SkipCheckError(WshShell)
                    old_association = WshShell:RegRead(reg_backup..t);
                    luacom.SkipCheckError(WshShell)
                    WshShell:RegDelete(reg_backup..t);
                    WshShell:RegWrite('HKCR\\.'..t..'\\', old_association);
                end
            end
            if chk.value == 'OFF' then
                luacom.SkipCheckError(WshShell)
                WshShell:RegDelete(reg_backup..strBack);
            end
        end

        WriteReg(txt_listass, chk_ass, tbl_ass, 'associations', 'SciTE.File', 'SciTE file', ',1')
        WriteReg(txt_listass_set, chk_ass_set, tbl_ass_set, 'configs', 'SciTE.Session', 'SciTE session file', '')

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

local function ReadReg(txt, chk, tbl, strBack, strType, strDef)
    luacom.SkipCheckError(WshShell)
    txt.value = (WshShell:RegRead(reg_backup..strBack) or '')

    if txt.value == "" then
        txt.value =strDef
        txt.active = 'NO'
        chk.value = 'OFF'
    else
        chk.value = 'ON'
        local tblEr = {}
        local l = txt.value
        for t in l:gmatch('[^;]+') do

            luacom.SkipCheckError(WshShell)
            local chk = WshShell:RegRead('HKCR\\.'..t..'\\')
            if chk ~= strType then
                table.insert(tblEr, t)
                tbl[t] = 0
            else
                tbl[t] = 1
            end
        end
        if #tblEr > 0 then iup.Message("Warning", "Изменены ассоциации для сдедующих расширений:\n".. table.concat(tblEr, '\n') ) end
    end
end

ReadReg(txt_listass, chk_ass, tbl_ass, 'associations', 'SciTE.File', 'm;xml;inc;lua;form;incl;cform;rform;wform')
ReadReg(txt_listass_set, chk_ass_set, tbl_ass_set, 'configs', 'SciTE.Session', 'fileset;config;solution')

if fso:FileExists(WshShell.SpecialFolders("SendTo").."\\HildiM.lnk") then chk_sendTo.value = 'ON' end
