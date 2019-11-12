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
    local function IsVSS()
    end

    local function GetVSSProgect()
        local d = props["FileDir"]:from_utf8():upper()
        if shell.fileexists(d.."\\mssccprj.scc") then return true end
        if props['sybase.projects.dir'] ~= '' and d:find('^'..props['sybase.projects.dir']:upper()) then return true end
        return false
    end

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

        local dlg
        local curFile = props['FilePath']
        dlg = iup.scitedialog{iup.vbox{CORE.panelCaption{title = "History: "..curFile, sciteid = "vsshist", action = function() dlg:postdestroy() end}, list_vss};
                    shrink = "YES", sciteparent = "SCITE", sciteid = "vsshist", bgcolor = props['layout.bgcolor'],
                    tip = 'No Comment',
                    customframedraw = 'YES', customframecaptionheight = -1, customframedraw_cb = CORE.paneldraw_cb}
        local tmax, bScipHide
        bScipHide = false

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

        function list_vss.click_cb(h, lin, col, status)
            local sel = 0
            if h.marked then sel = h.marked:find('1') - 1 end
            iup.SetAttribute(h,  'MARK'..sel..':0', 0)
            iup.SetAttribute(h, 'MARK'..lin..':0', 1)
            h.redraw = lin..'*'
            if iup.isbutton3(status) then
                bScipHide = true
                menuhandler:PopUp('MainWindowMenu|_HIDDEN_|VSS')
            end
        end
        -- list_vss:SetCommonCB(nil, nil, nil, click_cb)
        local function checkFile()
            if curFile ~= props['FilePath'] then
                print("This history for file: "..curFile..'\nCurrent file: '..props['FilePath'])
                return false
            end
            return true
        end

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
            if not checkFile() then return end
            local v = ver()
            if v ~= '' then   COMPARE.CompareVss(v) end
        end
        CompareVer = function()
            if not checkFile() then return end
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
        p_vsscompare = props['vsscompare']
        local wsh = luacom.CreateObject('WScript.Shell')
        if p_vsscompare == '' then
            bOk, p_vsscompare = pcall(function() return wsh:RegRead('HKCU\\Software\\Thingamahoochie\\WinMerge\\Executable') end)
            if not bOk then
                p_vsscompare = nil
            else
                p_vsscompare = '"'..p_vsscompare..'" -e -x -ub %bname %yname'
            end
            props['vsscompare'] = p_vsscompare
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
        local _, strProgect
        d = d:from_utf8():upper()
        local vssDir = props['sybase.projects.dir']:upper()
        if shell.fileexists(d.."\\mssccprj.scc") then
            local fil = io.open(d..'\\'..'mssccprj.scc')
            local strFile = fil:read("*a")
            fil:close()
            _, _, strProgect = string.find(strFile, 'SCC_Project_Name = "([^"]+)')
        elseif vssDir ~= '' and d:find('^'..vssDir) then
            strProgect = d:gsub('^'..vssDir, "$"):gsub("\\", "/")
        end
        if not strProgect then
            print('"mssccprj.scc" not found in current dir')
            return false
        end

        curProj = strProgect
        local ierr, strerr = shell.exec(p_vsspath..' CP "'..strProgect..'"', nil, true, true)
        if ierr ~= 0 then print(strerr) end
        return ierr == 0
    end

    local function getStatAsync(d, f, dbg, dutf, vssDir)
        __DEBUG = dbg

        local ierr, strerr
        shell.set_curent_dir(d) bLocalDir = true

        local _, strProgect
        if shell.fileexists(d.."\\mssccprj.scc") then
            local fil = io.open(d..'\\'..'mssccprj.scc')
            local strFile = fil:read("*a")
            fil:close()
            _, _, strProgect = string.find(strFile, 'SCC_Project_Name = "([^"]+)')
        elseif vssDir ~= '' and d:find('^'..vssDir) then
            strProgect = d:gsub('^'..string.rep('.', string.len(vssDir)), "$"):gsub("\\", "/")
        end

        if not strProgect then
            strerr = '"mssccprj.scc" not found in current dir'
            ierr = -2
        else

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
            CreateDialog(strerr)
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
                {link = '_HIDDEN_|VSS_TAB|Check Out'},
            }
            bAddComon = true
        elseif ierr == 1 then --взят
            local my = strerr:lower():find((' '..username..'%s+exc'):lower())
            if my then
                local _, _, strChecked = strerr:lower():find('exc[%s%d%.:]+([^\n\r]*)')
                if strChecked == props['FileDir']:lower() then
                    t = {
                        {link = '_HIDDEN_|VSS_TAB|Check In'},
                        {link = '_HIDDEN_|VSS_TAB|Undo Check Out'},
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
                {link = '_HIDDEN_|VSS_TAB|Add to Project',},
            }
        elseif ierr >= -1 then
            print(strerr)
        end
        if bAddComon then
            table.insert(t, {link = '_HIDDEN_|VSS_TAB|Get Latest Version', })
            table.insert(t, {link = '_HIDDEN_|VSS_TAB|Show Differences', })
            table.insert(t, {link = '_HIDDEN_|VSS_TAB|Show Differences by HildiM', })
            table.insert(t, {link = '_HIDDEN_|VSS_TAB|Show History', })
            table.insert(t, {'s', separator = 1})
            table.insert(t, {link = '_HIDDEN_|VSS_TAB|Request Comment',})
        end
        for i = 1,  #t do t[i].cpt = _T(t[i][1]); t[i].hlp = "hildim/ui/vss_showmenu.html" end
        return t
    end

    local function OnSwitch_local()
        if props['FileDir']:find('^\\\\') then bLocalDir = false
        else
            shell.set_curent_dir(props['FileDir']:from_utf8()) bLocalDir = true
            tState.ierr = -3
            lanesgen(props['FileDir']:from_utf8():upper(), props['FileNameExt']:from_utf8(), __DEBUG__, props['FileDir'], props['sybase.projects.dir']:upper())
        end
    end

    menuhandler:InsertItem('TABBAR', 'slast',
    {'VSS', visible = function() return bLocalDir and GetVSSProgect() and shell.fileexists(props['FilePath']) end, CreateVSSMenu})
    menuhandler:InsertItem('MainWindowMenu', '_HIDDEN_|s1',{'VSS', plane = 1,{
            {'Get Version', action = function() GetVer() end, },
            {'Show Differences', action = function() CompareVer() end, },
            {'Show Differences by HildiM', action = function() CompareVerH() end, },
            {'Show Comment', action = function() CommentVer() end, },
        }}, nil, _T
    )
    menuhandler:InsertItem('MainWindowMenu', '_HIDDEN_|s1',{'VSS_TAB', plane = 1,{
            {'Add to Project', action = vss_add ,},
            {'Check In', action = vss_checkin, image = 'arrow_curve_090_µ' , },
            {'Check Out', action = vss_checkout, image = 'arrow_curve_270_µ'  , },
            {'Undo Check Out', action = vss_undocheckout,},
            {'Get Latest Version', action = vss_getlatest ,},
            {'Show Differences', action = vss_diff, image = 'edit_diff_µ' ,},
            {'Show Differences by HildiM', action = function() if COMPARE then COMPARE.CompareVss() end end, visible = 'COMPARE', image = 'edit_diff_µ' ,},
            {'Show History', action = vss_hist ,},
            {'Request Comment', check_iuprops = 'vss_showmenu.ask_comment' ,},
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
