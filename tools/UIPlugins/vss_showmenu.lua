require 'shell'
require "luacom"
--SSDIR \\SOURCESAFE\SourceSafe\Main\
-- *.sln, *.vbproj, *.xml, *.cform, *.vcproj, *.dsp, *.mdp, *.mak, *.wiki, *.vdp, *.vdproj, *.dbp, *.vsmproj, *.vsmacros, *.hwproj, *.etp, *.cform, *.rform, *.wform, *.mdmp, *.dsw, *.vjsproj, *.csdproj, *.inc, *.m, *.sql, *.incl, *.xml, *.form
local function Init()
    local bLocalDir = false
    local p_vsscompare, p_vsspath, curProj
    VSS = {}
    do
        local bOk
        local wsh = luacom.CreateObject('WScript.Shell')
        bOk, p_vsscompare = pcall(function() return wsh:RegRead('HKCU\\Software\\Thingamahoochie\\WinMerge\\Executable') end)
        if not bOk then
            p_vsscompare = nil
        else
            p_vsscompare = '"'..p_vsscompare..'" -e -x -ub %bname %yname'
        end

        bOk, p_vsspath = pcall(function() return wsh:RegRead('HKLM\\Software\\Microsoft\\VisualStudio\\SxS\\VSS_8\\8.0') end)
        if not bOk then
            p_vsspath = nil
            error('SourceSafe not found')
        else
            p_vsspath = '"'..p_vsspath..'ss.exe"'
        end
    end

    local function GetComment()
        if _G.iuprops['vss_showmenu.ask_comment'] == 1 then
            local ret, txt = iup.GetParam(_T"Comment",
                function(h, id)
                    if id == -6 then
                        h.rastersize = '700x200'
                    end
                    return 1
                end,
                _T'Text'..'%m\n'
                ,
                ''
            )
            if ret then
                --txt = txt:from_utf8()
                txt = txt:gsub('^%s', ""):gsub('%s$', "")
                if txt == '' then txt = "-" end
                return '"'..txt..'"'
            end
            return nil
        else
            return "-"
        end
    end

    function vss_SetCurrentProject(dir)
        local d = dir or props['FileDir']
        if not shell.fileexists(d..'\\'..'mssccprj.scc') then
            print('"mssccprj.scc" not found in current dir')
            return false
        end
        local fil = io.open(d..'\\'..'mssccprj.scc')
        local strFile = fil:read("*a")
        fil:close()
        local _, _, strProgect = string.find(strFile, 'SCC_Project_Name = "([^"]+)')
        curProj = strProgect
        local ierr, strerr = shell.exec(p_vsspath..' CP "'..strProgect..'"', nil, true, true)
        if ierr ~= 0 then print(strerr) end
        return ierr == 0
    end

    local function reset_err(ierr, strerr)
        if ierr + 0 == 0 then
            CORE.DoRevert()
            return true
        else
            print(strerr)
        end
    end

    local function vss_add()
        if vss_SetCurrentProject() then
            local cmnt = GetComment()
            if not cmnt then return end
            if reset_err(shell.exec(p_vsspath..' Add "'..props['FileDir']..'\\'..props['FileNameExt']..'" -C'..cmnt, nil, true, true)) and On_vss_CheckIn then
                On_vss_CheckIn(curProj)
            end
        end
    end

    local function vss_getlatest()
        if vss_SetCurrentProject() then
            local ierr, strerr = shell.exec(p_vsspath..' Diff '..props['FileNameExt'], nil, true, true)
            local stropt = ""
            if ierr == 1 then
                local rez = iup.Alarm(_T'Get Latest Version', _T"File differs from Source Safe\nReplace an existing file?", _TH"OK", _TH"Cancel")
                if rez ~= 1 then return end

                local attr = shell.getfileattr(props['FilePath'])
                if (attr & 1) ~= 1 then
                    shell.setfileattr(props['FilePath'], attr + 1)
                end
            end
            reset_err(shell.exec(p_vsspath..' Get '..props['FileNameExt'], nil, true, true))
        end
    end

    local function vss_undocheckout()
        if vss_SetCurrentProject() then
            reset_err(shell.exec(p_vsspath..' Undocheckout '..props['FileNameExt']..' -G-', nil, false, true))
        end
    end

    local function vss_checkout()
        if vss_SetCurrentProject() then
            local ierr, strerr = shell.exec(p_vsspath..' Diff '..props['FileNameExt'], nil, true, true)
            local stropt = ""
            if ierr == 1 then
                local rez = iup.Alarm(_T'Check Out', _T"File differs from Source Safe\nReplace an existing file?", _TH"OK", _TH"No", _TH"Cancel")
                if rez == 3 then return end
                ierr = 0
                if rez == 1 then

                else
                    stropt = " -G-"
                end
            end
            if ierr == 0 then
                local attr = shell.getfileattr(props['FilePath'])
                if (attr & 1) ~= 1 then
                    shell.setfileattr(props['FilePath'], attr + 1)
                end
                reset_err(shell.exec(p_vsspath..' Checkout '..props['FileNameExt']..stropt, nil, true, true))
            elseif ierr ~= 1 then
                print(strerr)
            end
        end
    end

    VSS.diff = function(f, tmppath)
        if vss_SetCurrentProject() then
            local ierr, strerr = shell.exec(p_vsspath..' Diff '..props['FileNameExt'], nil, true, true)
            if ierr == 1 or strerr == '' or ierr == 0 then

                ierr, strerr = shell.exec('CMD /c del /F "'..tmppath..'\\^^'..props['FileNameExt']..'"', nil, true, true)
                if ierr~= 0 then print(strerr, 1) end

                local cmd = p_vsspath..' Get '..props['FileNameExt']..' -GL"'..tmppath..'"'
                ierr, strerr = shell.exec(cmd, nil, true, true)
                if ierr~= 0 then print(strerr, 2) end

                ierr, strerr = shell.exec('CMD /c rename "'..tmppath..'\\'..props['FileNameExt']..'" "^^'..props['FileNameExt']..'"', nil, true, true)
                if ierr~= 0 then print(strerr, 3) end
                f(tmppath..'\\^^'..props['FileNameExt'], true)
            else
                print(strerr, ierr)
            end
        end
    end

    local function vss_diff()
        if vss_SetCurrentProject() then
            local ierr, strerr = shell.exec(p_vsspath..' Diff '..props['FileNameExt'], nil, true, true)
            if ierr == 1 then

                local _, tmppath = shell.exec('CMD /c set TEMP', nil, true, true)
                tmppath = string.sub(tmppath, 6, string.len(tmppath) - 2)
                local cmd = p_vsspath..' Get '..props['FileNameExt']..' -GL"'..tmppath..'"'
                ierr, strerr = shell.exec(cmd, nil, true, true)
                if ierr~= 0 then print(strerr) end
                ierr, strerr = shell.exec('CMD /c del /F "'..tmppath..'\\sstmp"', nil, true, true)
                if ierr~= 0 then print(strerr) end
                ierr, strerr = shell.exec('CMD /c rename "'..tmppath..'\\'..props['FileNameExt']..'" sstmp', nil, true, true)
                if ierr~= 0 then print(strerr) end
                cmd = string.gsub(string.gsub(p_vsscompare, '%%bname', '"'..tmppath..'\\sstmp"'), '%%yname', '"'..props['FileDir']..'\\'..props['FileNameExt']..'"')
                shell.exec(cmd)
            elseif strerr == '' or ierr == 0 then
                print('No differences')
            else
                print(strerr, ierr)
            end
        end
    end

    local function vss_checkin()
        if vss_SetCurrentProject() then
            local cmnt = GetComment()
            if not cmnt then return end
            if reset_err(shell.exec(p_vsspath..' Checkin '..props['FileNameExt']..' -C'..cmnt, nil, true, true)) and On_vss_CheckIn then
                On_vss_CheckIn(curProj)
            end
        end
    end

    local function vss_hist()
        if vss_SetCurrentProject() then
            local _, strerr = shell.exec(p_vsspath..' History '..props['FileNameExt'], nil, true, true)
            print(strerr)
        end
    end

    local function CreateVSSMenu()
        local t = {}
        local VSSContectMenu
        vss_SetCurrentProject()
        local ierr, strerr = shell.exec(p_vsspath..' Status '..props['FileNameExt'], nil, true, true)
        if ierr == 0 then -- не взят
            t = {
                {'Check Out', action = vss_checkout, image = 'arrow_curve_270_µ'  ,},
                {'Get Latest Version', action = vss_getlatest ,},
                {'Show Differences', action = vss_diff, image = 'edit_diff_µ' ,},
                {'Show Differences by HildiM', action = function() if COMPARE then COMPARE.CompareVss() end end, visible = 'COMPARE', image = 'edit_diff_µ' ,},
                {'Show History', action = vss_hist ,},
                {'s', separator = 1},
                {'Request Comment', check_iuprops = 'vss_showmenu.ask_comment' ,},
            }
        elseif ierr == 1 then --взят
            t = {
                {'Check In', action = vss_checkin, image = 'arrow_curve_090_µ' ,},
                {'Undo Check Out', action = vss_undocheckout,},
                {'Get Latest Version', action = vss_getlatest ,},
                {'Show Differences', action = vss_diff, image = 'edit_diff_µ' ,},
                {'Show Differences by HildiM', action = function() if COMPARE then COMPARE.CompareVss() end end, visible = 'COMPARE', image = 'edit_diff_µ' ,},
                {'Show History', action = vss_hist ,},
                {'s', separator = 1},
                {'Request Comment', check_iuprops = 'vss_showmenu.ask_comment' ,},
            }
        elseif ierr == 100 then --новый
            t = {
                {'Add to Project', action = vss_add ,},
            }
        else
            print(strerr)
        end
        for i = 1,  #t do t[i].cpt = _T(t[i][1]); t[i].hlp = "hildim/ui/vss_showmenu.html" end
        return t
    end

    local function OnSwitch_local()
        if props['FileDir']:find('^\\\\') then bLocalDir = false
        else shell.set_curent_dir(props['FileDir']) bLocalDir = true end
    end

    menuhandler:InsertItem('TABBAR', 'slast',
    {'VSS', visible = function() return bLocalDir and shell.fileexists(props["FileDir"].."\\mssccprj.scc") end, CreateVSSMenu})

    AddEventHandler("OnSwitchFile", OnSwitch_local)
    AddEventHandler("OnOpen", OnSwitch_local)

end
return {
    title = 'Подменю для команд VSS в контекстном меню таба (вкладки)',
    hidden = Init,
    destroy = function() VSS = nil end,
    description = [[Добавление подменю для работы с VSS
в меню таба окна]]
}
