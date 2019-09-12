require 'shell'
require "luacom"
require "lpeg"
--SSDIR \\SOURCESAFE\SourceSafe\Main\
-- *.sln, *.vbproj, *.xml, *.cform, *.vcproj, *.dsp, *.mdp, *.mak, *.wiki, *.vdp, *.vdproj, *.dbp, *.vsmproj, *.vsmacros, *.hwproj, *.etp, *.cform, *.rform, *.wform, *.mdmp, *.dsw, *.vjsproj, *.csdproj, *.inc, *.m, *.sql, *.incl, *.xml, *.form
local function Init()
    local patt, dlg
    do
        local P, V, Cg, Ct, Cc, S, R, C, Carg, Cf, Cb, Cp, Cmt = lpeg.P, lpeg.V, lpeg.Cg, lpeg.Ct, lpeg.Cc, lpeg.S, lpeg.R, lpeg.C, lpeg.Carg, lpeg.Cf, lpeg.Cb, lpeg.Cp, lpeg.Cmt

        local AZ = R('AZ', 'az') + "_"
        local N = R'09'
        local NL = P'\n' + P'\r\n'
        local SP = S' \t'^1
        local ver = P'*'^1 * P'  Version ' * C(N^1) * S' *'^1 * NL * Cc('')
        local usr = P'User: ' * C((1 - P' Date: ')^1)
        local dt = ' Date:' * SP * C((N + P'.')^1) *(P' '^1 * P'Time:' * SP * C((N + P':')^1)) * NL
        local ch = 'Checked in ' * C((1 - NL)^1) * NL + P'Created'
        local cmt = (P'Comment:' + P'Label comment:') * C((1 - P'*****************')^1) + Cc('') *((1 - P'*****************')^1)
        ver = Ct(ver * usr * dt * ch * cmt)

        local lbl = P'*'^1 * NL * Cc('') * 'Label: ' * C((1 - NL)^1) *NL

        lbl = Ct(lbl * usr * dt * Cc('') *((1 - NL)^1) * NL * cmt)

        patt = Ct((1 - P'*****************')^1*(ver + lbl)^1)
    end

    local CompareVer, GetVer, vss_getlatest, vss_diff, CompareVerH, CommentVer
    local function CreateDialog(strerr)
        local list_vss = iup.matrix{ name = 'list_buffers', fgcolor = props["tabctrl.forecolor"],
            numcol = 8, numcol_visible = 8, cursor = "ARROW", alignment = 'ALEFT', heightdef = 6, markmode = 'LIN', flatscrollbar = "VERTICAL" ,
            readonly = "YES"  , markmultiple = "NO" , height0 = 4, expand = "YES", resizematrix = "YES", propagatefocus = 'YES'  ,
            rasterwidth0 = 30 ,
            rasterwidth1 = 30,
            rasterwidth2 = 100,
            rasterwidth3 = 100,
            rasterwidth4 = 100,
            rasterwidth5 = 100,
            rasterwidth6 = 100,
            rasterwidth7 = 500,
        }
        list_vss:setcell(0, 1, "Ver")
        list_vss:setcell(0, 2, "Label")
        list_vss:setcell(0, 3, "User")
        list_vss:setcell(0, 4, "Date")
        list_vss:setcell(0, 5, "Time")
        list_vss:setcell(0, 6, "Path")
        list_vss:setcell(0, 7, "Comment")

        local dlg = iup.scitedialog{list_vss, sciteparent = "SCITE", sciteid = "vsshist", dropdown = true,shrink="YES",
                    maxbox = 'NO', minbox = 'NO', menubox = 'NO', minsize = '100x200', bgcolor = iup.GetLayout().txtbgcolor, tip = 'No Comment',
                    customframedraw = 'YES', customframecaptionheight = -1, customframedraw_cb = CORE.paneldraw_cb, customframeactivate_cb = CORE.panelactivate_cb(nil)}
        local tmax, bScipHide
        bScipHide = false

        dlg.show_cb = function(h, state)
            if state == 0 then
                local tRep = patt:match(strerr, 1) or {}
                iup.SetAttribute(list_vss, "ADDLIN", "1-"..#tRep)
                tmax = #tRep
                for i = 1,  #tRep do
                    list_vss:setcell(i, 0, i..'')
                    for j = 1, 7 do
                        list_vss:setcell(i, j, (tRep[i][j] or ''):to_utf8())
                    end
                end
                list_vss.redraw = 'ALL'
                dlg.focus_cb = function(h, focus)
                    if focus == 0 and not bScipHide then scite.RunAsync(function() dlg:hide(); h:postdestroy() end) end
                    bScipHide = false
                end
            elseif state == 4 then

            end
        end

        local function click_cb(lin)
            bScipHide = true
            menuhandler:PopUp('MainWindowMenu|_HIDDEN_|VSS')
        end
        list_vss:SetCommonCB(nil, nil, nil, click_cb)

        list_vss.enteritem_cb = (function(h, l, c)
            if l == 0 then h.tip = _T''
            else h.tip = iup.GetAttributeId2(h, '', l, 7)
            end
        end)
        local function ver()
            local sel, v
            sel = list_vss.marked:find('1') - 1
            v = ''
            while v == '' and sel <= tmax do
                v = list_vss:getcell(sel, 1)
                sel = sel + 1
            end
            if v ~= '' then v = ' -V'..v..' '  end
            return v
        end

        dlg.k_any = function(h, k)
            if k == iup.K_ESC then h:hide(); h:postdestroy() end
        end
        GetVer = function()
            local v = ver()
            if v ~= '' then   vss_getlatest(v) end
        end
        CompareVerH = function()
            local v = ver()
            if v ~= '' then   COMPARE.CompareVss(v) end
        end
        CompareVer = function()
            local v = ver()
            if v ~= '' then vss_diff(v) end
        end
        CommentVer = function()
            local sel
            sel = list_vss.marked:find('1') - 1
            print((list_vss:getcell(sel, 7) or ''):from_utf8())
        end
        return dlg
    end

    local bLocalDir = false
    local p_vsscompare, p_vsspath, curProj
    VSS = {}
    local tState = {ierr = -2}            -- -1- какая-то ошибка(не VSS) - -2 - директория не в проекте -3 идет чтение
    local username = luacom.CreateObject('WScript.Network').Username

    if not lanes then
        lanes = require("lanes").configure()
    end

    local linda = lanes.linda()

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
                txt = txt:from_utf8()
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
        d = d:from_utf8()
        local fil = io.open(d..'\\'..'mssccprj.scc')
        local strFile = fil:read("*a")
        fil:close()
        local _, _, strProgect = string.find(strFile, 'SCC_Project_Name = "([^"]+)')
        curProj = strProgect
        local ierr, strerr = shell.exec(p_vsspath..' CP "'..strProgect..'"', nil, true, true)
        if ierr ~= 0 then print(strerr) end
        return ierr == 0
    end

    local function getStatAsync(d, f, dbg, dutf)
        __DEBUG = dbg
        local ierr, strerr
        shell.set_curent_dir(d) bLocalDir = true
        if not shell.fileexists(dutf..'\\'..'mssccprj.scc') then
            strerr = '"mssccprj.scc" not found in current dir'
            ierr = -2
        else
            local fil = io.open(d..'\\'..'mssccprj.scc')
            local strFile = fil:read("*a")
            fil:close()
            local _, _, strProgect = string.find(strFile, 'SCC_Project_Name = "([^"]+)')

            ierr, strerr = shell.exec(p_vsspath..' CP "'..strProgect..'"', nil, true, true)
            if __DEBUG then print("DEBUG:", p_vsspath..' CP "'..strProgect..'"') end
            if ierr ~= 0 then
                strerr = ''..ierr..'   '..p_vsspath..' CP "'..strProgect..'"'
                ierr = -1
            else
                if __DEBUG then print("DEBUG:", p_vsspath..' Status '..f) end
                ierr, strerr = 1, ''
                for i = 1, 10 do
                    ierr, strerr = shell.exec(p_vsspath..' Status '..f, nil, true, true)
                    if ierr ~= 1 or strerr ~= '' then break end
                end

            end
        end

        linda:send( "VSS_ChangeFile", {ierr = ierr, strerr = strerr, file = f})
    end

    local lanesgen = lanes.gen("package,io,string", {required = {"shell"}}, getStatAsync)

    local function receiveVssInfo(t)
        local key, val = linda:receive(t or 5.0, "VSS_ChangeFile")    -- timeout in seconds
        if val == nil then
            --print( "Vss Get Info time out", debug.traceback())
        elseif val.file == props['FileNameExt']:from_utf8() then
            tState.ierr = val.ierr
            tState.strerr = val.strerr
        else
            receiveVssInfo(0)
        end
    end

    AddEventHandler("OnLindaNotify", function(key)
        if key == 'VSS_ChangeFile' then
            if not tState.blocked then receiveVssInfo(0) end
            tState.blocked = false
        end
    end)

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
            if reset_err(shell.exec(p_vsspath..' Add "'..props['FileDir']:from_utf8()..'\\'..props['FileNameExt']:from_utf8()..'" -C'..cmnt, nil, true, true)) and On_vss_CheckIn then
                On_vss_CheckIn(curProj)
            end
        end
    end

    vss_getlatest = function(ver)
        if vss_SetCurrentProject() then
            local v = ver or ''
            local ierr, strerr = shell.exec(p_vsspath..' Diff '..props['FileNameExt']:from_utf8()..v, nil, true, true)
            local stropt = ""
            if ierr == 1 then
                local rez = iup.Alarm(Iif(v == '', _T'Get Latest Version', _T'Get Version'..v), _T"File differs from Source Safe\nReplace an existing file?", _TH"OK", _TH"Cancel")
                if rez ~= 1 then return end

                local attr = shell.getfileattr(props['FilePath'])
                if (attr & 1) ~= 1 then
                    shell.setfileattr(props['FilePath'], attr + 1)
                end
            end
            reset_err(shell.exec(p_vsspath..' Get '..props['FileNameExt']:from_utf8()..v, nil, true, true))
        end
    end

    local function vss_undocheckout()
        if vss_SetCurrentProject() then
            reset_err(shell.exec(p_vsspath..' Undocheckout '..props['FileNameExt']:from_utf8()..' -G-', nil, false, true))
        end
    end

    local function vss_checkout()
        if vss_SetCurrentProject() then
            BlockEventHandler"OnSwitchFile"
            local ierr, strerr = shell.exec(p_vsspath..' Diff '..props['FileNameExt']:from_utf8(), nil, true, true)
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
                reset_err(shell.exec(p_vsspath..' Checkout '..props['FileNameExt']:from_utf8()..stropt, nil, true, true))
            elseif ierr ~= 1 then
                print(strerr)
            end
            UnBlockEventHandler"OnSwitchFile"
        end
    end

    VSS.diff = function(f, tmppath, ver)
        if vss_SetCurrentProject() then
            local v = ver or ''
            local ierr, strerr = shell.exec(p_vsspath..' Diff '..props['FileNameExt']:from_utf8()..v , nil, true, true)
            if ierr == 1 or strerr == '' or ierr == 0 then

                ierr, strerr = shell.exec('CMD /c del /F "'..tmppath..'\\^^'..props['FileNameExt']:from_utf8()..'"', nil, true, true)
                if ierr~= 0 then print(strerr, 1) end

                local cmd = p_vsspath..' Get '..props['FileNameExt']:from_utf8()..v..' -GL"'..tmppath..'"'
                ierr, strerr = shell.exec(cmd, nil, true, true)
                if ierr~= 0 then print(strerr, 2) end

                ierr, strerr = shell.exec('CMD /c rename "'..tmppath..'\\'..props['FileNameExt']:from_utf8()..'" "^^'..props['FileNameExt']:from_utf8()..'"', nil, true, true)
                if ierr~= 0 then print(strerr, 3) end
                f(tmppath..'\\^^'..props['FileNameExt']:from_utf8(), true)
            else
                print(strerr, ierr)
            end
        end
    end

    vss_diff = function(ver)
        if vss_SetCurrentProject() then
            local v = ver or ''
            local ierr, strerr = shell.exec(p_vsspath..' Diff '..props['FileNameExt']:from_utf8()..v, nil, true, true)
            if ierr == 1 then

                local _, tmppath = shell.exec('CMD /c set TEMP', nil, true, true)
                tmppath = string.sub(tmppath, 6, string.len(tmppath) - 2)
                local cmd = p_vsspath..' Get '..props['FileNameExt']:from_utf8()..v..' -GL"'..tmppath..'"'
                ierr, strerr = shell.exec(cmd, nil, true, true)
                if ierr~= 0 then print(strerr) end
                ierr, strerr = shell.exec('CMD /c del /F "'..tmppath..'\\sstmp"', nil, true, true)
                if ierr~= 0 then print(strerr) end
                ierr, strerr = shell.exec('CMD /c rename "'..tmppath..'\\'..props['FileNameExt']:from_utf8()..'" sstmp', nil, true, true)
                if ierr~= 0 then print(strerr) end
                cmd = string.gsub(string.gsub(p_vsscompare, '%%bname', '"'..tmppath..'\\sstmp"'), '%%yname', '"'..props['FileDir']:from_utf8()..'\\'..props['FileNameExt']:from_utf8()..'"')
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
            BlockEventHandler"OnSwitchFile"
            local cmnt = GetComment()
            if not cmnt then return end
            if shell.set_curent_dir(props['FileDir']:from_utf8()) == props['FileDir']:from_utf8() then
                if reset_err(shell.exec(p_vsspath..' Checkin '..props['FileNameExt']:from_utf8()..' -C'..cmnt, nil, false, true)) and On_vss_CheckIn then
                    On_vss_CheckIn(curProj)
                end
            else
                print("Error: Can't set current dir")
            end
            UnBlockEventHandler"OnSwitchFile"
        end
    end

    local function vss_hist()
        if vss_SetCurrentProject() then
            local _, strerr = shell.exec(p_vsspath..' History '..props['FileNameExt']:from_utf8(), nil, true, true)
            --print(strerr)
            --iup.ShowXY(CreateDialog(strerr), 100, 100)
            iup.ShowInMouse(CreateDialog(strerr))
        end
    end

    local function CreateVSSMenu()
        local t = {}
        local VSSContectMenu
        --vss_SetCurrentProject()
        --local ierr, strerr = shell.exec(p_vsspath..' Status '..props['FileNameExt'], nil, true, true)
        shell.set_curent_dir(props['FileDir']:from_utf8())
        if not shell.fileexists(props['FilePath']) then return {} end
        local ierr, strerr = tState.ierr, tState.strerr
        local bAddComon = false

        if ierr == -3 then
            if not shell.fileexists(props['FilePath']) then
                return {}
            else
                receiveVssInfo()
                ierr, strerr = tState.ierr, tState.strerr
                if ierr >= -1 then tState.blocked = true end
            end
        end

        if ierr == 0 then -- не взят
            t = {
                {'Check Out', action = vss_checkout, image = 'arrow_curve_270_µ'  ,},
            }
            bAddComon = true
        elseif ierr == 1 then --взят
            local my = strerr:lower():find((' '..username..'%s+exc'):lower())
            if my then
                local _, _, strChecked = strerr:lower():find('exc[%s%d%.:]+([^\n\r]*)')
                if strChecked == props['FileDir']:lower() then
                    t = {
                        {'Check In', action = vss_checkin, image = 'arrow_curve_090_µ' ,},
                        {'Undo Check Out', action = vss_undocheckout,},
                    }
                else
                    t = {
                        {'Checked In...'..strChecked, action = function() print(strerr) end,},
                    }
                end
                bAddComon = true
            else
                t = {
                    {'Checked By...', action = function() print(strerr) end ,},
                }
                bAddComon = true
            end
        elseif ierr == 100 then --новый
            t = {
                {'Add to Project', action = vss_add ,},
            }
        elseif ierr >= -1 then
            print(strerr)
        end
        if bAddComon then
            table.insert(t, {'Get Latest Version', action = vss_getlatest ,})
            table.insert(t, {'Show Differences', action = vss_diff, image = 'edit_diff_µ' ,})
            table.insert(t, {'Show Differences by HildiM', action = function() if COMPARE then COMPARE.CompareVss() end end, visible = 'COMPARE', image = 'edit_diff_µ' ,})
            table.insert(t, {'Show History', action = vss_hist ,})
            table.insert(t, {'s', separator = 1})
            table.insert(t, {'Request Comment', check_iuprops = 'vss_showmenu.ask_comment' ,})
        end
        for i = 1,  #t do t[i].cpt = _T(t[i][1]); t[i].hlp = "hildim/ui/vss_showmenu.html" end
        return t
    end

    local function OnSwitch_local()
        if props['FileDir']:find('^\\\\') then bLocalDir = false
        else
            shell.set_curent_dir(props['FileDir']:from_utf8()) bLocalDir = true
            tState.ierr = -3
            lanesgen(props['FileDir']:from_utf8(), props['FileNameExt']:from_utf8(), __DEBUG__, props['FileDir'])
        end
    end

    menuhandler:InsertItem('TABBAR', 'slast',
    {'VSS', visible = function() return bLocalDir and shell.fileexists(props["FileDir"].."\\mssccprj.scc") and shell.fileexists(props['FilePath']) end, CreateVSSMenu})
    menuhandler:InsertItem('MainWindowMenu', '_HIDDEN_|s1',{'VSS', plane = 1,{
            {'Get Version', action = function() GetVer() end, },
            {'Show Differences', action = function() CompareVer() end, },
            {'Show Differences by HildiM', action = function() CompareVerH() end, },
            {'Show Comment', action = function() CommentVer() end, },
        }}, nil, _T
    )
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
