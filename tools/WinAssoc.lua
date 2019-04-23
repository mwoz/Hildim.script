require "luacom"

if not scite.IsRunAsAdmin() and not _G.g_session['scip.plugins'] then
    if not scite.NewInstance('-d-nP-nRF-h -cmd dolocale("tools\\\\WinAssoc.lua")', 1) then
        print("Not enough rights to perform the operation")
    end
    return
end

local dlg = _G.dialogs["winint"]

local WshShell = luacom.CreateObject('WScript.Shell')
local fso = luacom.CreateObject("Scripting.FileSystemObject");
local reg_backup = 'HKLM\\SOFTWARE\\SciTE\\Script\\WinIntegrator\\';

local tbl_ass, tbl_ass_set
tbl_ass = {}
tbl_ass_set = {}

if dlg == nil then
    local txt_listass, chk_ass, chk_sendTo, txt_listass_set, chk_ass_set
    tbl_ass = {}
    tbl_ass_set = {}
    txt_listass = iup.text{size = '250x0', mask = "(/d|/w|_|;|[à-ÿ]|[À-ß])+"}
    chk_ass = iup.toggle{title = _T"Associate with extensions:"; action = function(h)
        txt_listass.active = Iif(h.value == 'ON', 'YES', 'NO')
    end}

    txt_listass_set = iup.text{size = '180x0', mask = "(/d|/w|_|;|[à-ÿ]|[À-ß])+"}
    chk_ass_set = iup.toggle{title = _T"Process configuration files:"; action = function(h)
        txt_listass_set.active = Iif(h.value == 'ON', 'YES', 'NO')
    end}

    local btn_ok = iup.button  {title = _TH"OK"}
    chk_sendTo = iup.toggle{title = _T'Add HildiM to context menu "Send To.."'}

    iup.SetHandle("WININT_BTN_OK", btn_ok)

    local btn_esc = iup.button  {title = _TH"Cancel"}
    iup.SetHandle("WININT_BTN_ESC", btn_esc)

    local vbox = iup.vbox{
        iup.hbox{chk_ass, iup.fill{}, txt_listass, alignment = 'ACENTER'},
        iup.hbox{chk_sendTo, alignment = 'ACENTER'},
        iup.hbox{chk_ass_set, iup.fill{}, txt_listass_set, alignment = 'ACENTER', expand ='HORIZONTAL'},
        iup.hbox{btn_ok, iup.fill{}, btn_esc},
    gap = 2, margin = "4x4" }
    local result = false
    dlg = iup.scitedialog{vbox; title = _T"Windows Integration", defaultenter = "WININT_BTN_OK", defaultesc = "WININT_BTN_ESC", maxbox = "NO", minbox = "NO", resize = "NO", sciteparent = "SCITE", sciteid = "winint" }
    if _G.g_session['scip.plugins'] then dlg.topmost = 'YES' end

    function dlg:show_cb( state)
        if state == 4 and _G.g_session['scip.plugins'] then
            scite.RunAsync(function() scite.MenuCommand(IDM_QUIT) end)
        end
    end

    function btn_ok:action()
        local function WriteReg(txt, chk, tbl, strBack, strType, strCapt, strIcon)
            if chk.value == 'ON' then
                local l = txt.value
                for t in l:gmatch('[^;]+') do
                    if (tbl[t] or 0) ~= 1 then
                        local current_association
                        luacom.TryCatch(WshShell)
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
                    luacom.TryCatch(WshShell)
                    old_association = WshShell:RegRead(reg_backup..t) or ''
                    luacom.TryCatch(WshShell)
                    WshShell:RegDelete(reg_backup..t);
                    if old_association == '' or old_association == 'SciTE.Session' then
                        luacom.TryCatch(WshShell)
                        WshShell:RegWrite('HKCR\\.'..t..'\\', '');
                        luacom.TryCatch(WshShell)
                        WshShell:RegDelete('HKCR\\.'..t..'\\');
                    else
                        WshShell:RegWrite('HKCR\\.'..t..'\\', old_association);
                    end
                end
            end
            if chk.value == 'OFF' then
                luacom.TryCatch(WshShell)
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
            luacom.TryCatch(fso)
            fso:DeleteFile(WshShell.SpecialFolders("SendTo").."\\HildiM.lnk", true);
        end

        dlg:hide()
        return IUP_CLOSE
    end

    function btn_esc:action()
        dlg:hide()
    end
    dlg.my_init = function()
        local function ReadReg(txt, chk, tbl, strBack, strType, strDef)
            luacom.TryCatch(WshShell)
            txt.value = (WshShell:RegRead(reg_backup..strBack) or '')

            if txt.value == "" then
                txt.value = strDef
                txt.active = 'NO'
                chk.value = 'OFF'
            else
                chk.value = 'ON'
                local tblEr = {}
                local l = txt.value
                for t in l:gmatch('[^;]+') do

                    luacom.TryCatch(WshShell)
                    local chk = WshShell:RegRead('HKCR\\.'..t..'\\')
                    if chk ~= strType then
                        table.insert(tblEr, t)
                        tbl[t] = 0
                    else
                        tbl[t] = 1
                    end
                end
                if #tblEr > 0 then iup.Message("Warning", _T"Associations for the following extensions were changed:\n".. table.concat(tblEr, '\n') ) end
            end
        end

        ReadReg(txt_listass, chk_ass, tbl_ass, 'associations', 'SciTE.File', 'm;xml;inc;lua;form;incl;cform;rform;wform;wiki')
        ReadReg(txt_listass_set, chk_ass_set, tbl_ass_set, 'configs', 'SciTE.Session', 'fileset;config;solution')

        if fso:FileExists(WshShell.SpecialFolders("SendTo").."\\HildiM.lnk") then chk_sendTo.value = 'ON' end
    end
    dlg.my_init()
else
    dlg:show()
    dlg.my_init()
end
