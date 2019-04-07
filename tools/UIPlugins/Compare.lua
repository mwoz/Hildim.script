local tSet, onDestroy
local function Init_hidden()
    require 'Compare'
    require 'luacom'
    COMPARE = {}
    local bActive = 0
    local eOffsets = {}
    local tCompare = {left = {}, right = {}}
    local tabL = iup.GetDialogChild(iup.GetLayout(), 'TabCtrlLeft')
    local tabR = iup.GetDialogChild(iup.GetLayout(), 'TabCtrlRight')
    local lastEditLine
    local markerMask = 0
    local mark = CORE.InidcFactory('Compare.Inline', _T'Marking differences in the compared line', INDIC_BOX, 255, 0)
    local tmpPath
    tmpFiles = {}
    local gitInstall, bGitActive
    local onUpdateUI_local

    for i = 0, 4 do
        --markerMask = markerMask | (1 << (Compare.Markers['MARKER_CHANGED_SYMBOL'] + i))
        markerMask = markerMask | (1 << (Compare.Markers['MARKER_MOVED_LINE'] + i))
    end

    local maskLinesADM = (1 << Compare.Markers['MARKER_MOVED_LINE']) |
    (1 << Compare.Markers['MARKER_ADDED_LINE']) |
    (1 << Compare.Markers['MARKER_REMOVED_LINE'])

    local function Marker(e, l)
        return e:MarkerGet(l) & markerMask
    end

    if not gitInstall then
        gitInstall = 1
        iErr = pcall(function() luacom.CreateObject('WScript.Shell'):RegRead('HKCU\\Software\\TortoiseGit\\CurrentVersion') end)
        if not iErr then gitInstall = 0 end
    end

    tSet = (_G.iuprops['compare_settings'] or {})
    if (tSet.version or 0) < 1 then
        tSet.version = 1
        tSet.DetectMove = true
        tSet.IncludeSpace = true
        tSet.AddLine = true
        tSet.UseSymbols = true
        tSet.Color_added = 14745568
        tSet.Color_deleted = 14737663
        tSet.Color_changed = 14811135
        tSet.Color_moved = 16773857
        tSet.Color_blank = 15000804
    end

    local function ApplySettings()
        Compare.Settings.IncludeSpace = tSet.IncludeSpace
        Compare.Settings.DetectMove = tSet.DetectMove
        Compare.Settings.AddLine = tSet.AddLine
        Compare.Settings.UseSymbols = tSet.UseSymbols
        Compare.Settings.Color_added = tSet.Color_added
        Compare.Settings.Color_deleted = tSet.Color_deleted
        Compare.Settings.Color_changed = tSet.Color_changed
        Compare.Settings.Color_moved = tSet.Color_moved
        Compare.Settings.Color_blank = tSet.Color_blank
    end

    local function addSBColors(sb, side)
        iup.SetAttributeId2(sb, "COLORID", 2, -1, "")
        iup.SetAttributeId2(sb, "COLORID", 2, Compare.Markers['MARKER_ADDED_LINE'], CORE.Rgb2Str(tSet.Color_added))
        iup.SetAttributeId2(sb, "COLORID", 2, Compare.Markers['MARKER_REMOVED_LINE'], CORE.Rgb2Str(tSet.Color_deleted))
        iup.SetAttributeId2(sb, "COLORID", 2, Compare.Markers['MARKER_MOVED_LINE'], CORE.Rgb2Str(tSet.Color_moved))
        iup.SetAttributeId2(sb, "COLORID", 2, Compare.Markers['MARKER_CHANGED_LINE'], CORE.Rgb2Str(tSet.Color_changed))

        iup.SetAttributeId2(sb, "COLORID", 2, MARKER_MAX + 1, Iif(side == 1, 2, 1))
    end

    local function CompareSetInd()

        local i1 = editor.IndicatorCurrent
        local i2 = coeditor.IndicatorCurrent
        editor.IndicatorCurrent = mark
        coeditor.IndicatorCurrent = mark
        coeditor.Zoom = editor.Zoom
        Compare.Compare()
        editor.IndicatorCurrent = i1
        coeditor.IndicatorCurrent = i2
    end

    local function SetAnnotationStiles(e)
        if e.AnnotationStyleOffset == 0 then
            e.AnnotationStyleOffset = e:AllocateExtendedStyles(10)
        end
        eOffsets[e] = e.AnnotationStyleOffset
        e.StyleBack[eOffsets[e]] = Compare.Settings.Color_blank
    end

    local function fPath(tabS)
        return scite.buffers.NameAt(math.tointeger(iup.GetAttribute(tabS, "TABBUFFERID"..iup.GetAttribute(tabS, "VALUEPOS"))) or 0)
    end

    local bRunScroll

    local function ScrollWindows(e1, e2, flag)
        if (bActive & 4) == 4 and not bRunScroll then
            bRunScroll = true
            if (flag & SC_UPDATE_V_SCROLL) ~= 0 and e2.FirstVisibleLine ~= e1.FirstVisibleLine then
                e2.FirstVisibleLine = e1.FirstVisibleLine
            end
            if (flag & SC_UPDATE_H_SCROLL) ~= 0 and e2.XOffset ~= e1.XOffset then
                e2.XOffset = e1.XOffset
            end
            bRunScroll = false
        end
    end

    local function ClearWindow(e)
        e:AnnotationClearAll()
        for i = 0, 8 do
            e:MarkerDeleteAll(Compare.Markers['MARKER_MOVED_LINE'] + i)
        end
        local curind = e.IndicatorCurrent
        e.IndicatorCurrent = mark
        e:IndicatorClearRange(0, e.Length)

        e.IndicatorCurrent = curind
    end

    local function Reset()
        ClearWindow(editor)
        ClearWindow(coeditor)
        if (bActive & 4) ~= 4 then
            if (bActive & 1) == 1 then
                tCompare.right[tCompare.left[fPath(tabL)]] = "-"
            end
            if (bActive & 2) == 2 then
                tCompare.left[tCompare.right[fPath(tabR)]] = "-"
            end
        end
        tCompare.left[fPath(tabL)] = nil
        tCompare.right[fPath(tabR)] = nil
        bActive = 0
        editor.CaretLineVisibleAlways = false
        coeditor.CaretLineVisibleAlways = false

        CORE.SetFindMarkers()
    end

    local function StartCompare(bScipReset)
        if not bScipReset then
            SetAnnotationStiles(editor)
            SetAnnotationStiles(coeditor)

            addSBColors(iup.GetDialogChild(iup.GetLayout(), 'Source'), 1)
            addSBColors(iup.GetDialogChild(iup.GetLayout(), 'CoSource'), 2)

            if bActive == 7 then Reset() end
        end
        bActive = 7
        editor.CaretLineVisibleAlways = true
        coeditor.CaretLineVisibleAlways = true

        CompareSetInd()
        tCompare.left[fPath(tabL)] = fPath(tabR)
        tCompare.right[fPath(tabR)] = fPath(tabL)
        ScrollWindows(editor, coeditor, SC_UPDATE_V_SCROLL | SC_UPDATE_H_SCROLL)
    end

    local function OnSwitch_local()
        if (gitInstall or 0) == 1 then
            local p = props['FilePath']
            bGitActive = false
            repeat
                p = p:gsub('\\[^\\]*$', '')
                if shell.fileexists(p..'\\.git') then
                    bGitActive = true
                    break
                end
            until not p:find('\\')
        end
        if tCompare.right[fPath(tabR)] == "-" or tCompare.left[fPath(tabL)] == "-" then
            Reset()
            return
        end
        bActive = 0
        if tCompare.left[fPath(tabL)] then bActive = bActive | 1 end
        if tCompare.right[fPath(tabR)] then bActive = bActive | 2 end
        if bActive == 3 and tCompare.right[fPath(tabR)] == fPath(tabL) then bActive = bActive | 4 end
        editor.CaretLineVisibleAlways = (bActive == 7)
        coeditor.CaretLineVisibleAlways = (bActive == 7)
        if bActive > 0 then
            SetAnnotationStiles(editor)
            SetAnnotationStiles(coeditor)

            addSBColors(iup.GetDialogChild(iup.GetLayout(), 'Source'), 1)
            addSBColors(iup.GetDialogChild(iup.GetLayout(), 'CoSource'), 2)
        else
            CORE.SetFindMarkers()
        end

    end

    local function onClose(t1, t2, source, bScipClear)
        if t1[source] then
            t2[t1[source]] = "-"
            if not bScipClear then Reset() end
        end
    end

    local function prevDif()
        local rotate = true
        local le = editor:LineFromPosition(editor.SelectionStart)
::docstart::
        local m = Marker(editor, le)
        if m > 0 then
            while m == Marker(editor, le) do
                le = le - 1
            end
        else
            if editor.AnnotationLines[le] > 0 then le = le - 1 end
        end

        local le2 = editor:MarkerPrevious(le, markerMask)
        local lMin = 0
        if le2 > - 1 then lMin = le2 end

        local lco2 = -1
        for i = le, lMin, -1 do
            if editor.AnnotationLines[i] > 0 then
                lco2 = i
                break
            end
        end

        if le2 < 0 and lco2 < 0 and rotate then
            le = editor:LineFromPosition(editor.Length - 1)
            print"Continue search from document start"
            rotate = false
            goto docstart
        end

        if le2 < 0 and lco2 < 0 then print"Prevouse diff not found"; return end
        if le2 < 0 then le2 = lco2 end
        if lco2 < 0 then lco2 = le2 end

        local l = Iif(le2 > lco2, le2, lco2)
        editor:EnsureVisible(l)
        editor:EnsureVisibleEnforcePolicy(l)

        m = Marker(editor, l)
        local l2
        if m > 0 then
            l2 = l
            while m == Marker(editor, l2) do
                l2 = l2 - 1
            end
            editor.SelectionStart = editor:PositionFromLine(l2 + 1)
            editor.SelectionEnd = editor:PositionFromLine(l + 1) - 2
        else
            l2 = l + 1
            editor.SelectionStart = editor:PositionFromLine(l2) - 2
            editor.SelectionEnd = editor:PositionFromLine(l2)
        end
    end

    local function nextDiff()
        local le = editor:LineFromPosition(editor.CurrentPos)
        local rotate = true

        local m = Marker(editor, le)
::docend::
        if m > 0 then
            while m == Marker(editor, le) do
                le = le + 1
            end
        else
            if editor.AnnotationLines[le] > 0 then le = le + 1 end
        end

        local le2 = editor:MarkerNext(le, markerMask)
        local lMax = -1
        if lMax < 0 then lMax = editor.LineCount end

        local lco2 = -1
        for i = le, lMax do
            if editor.AnnotationLines[i] > 0 then
                lco2 = i
                break
            end
        end

        if le2 < 0 and lco2 < 0 and rotate then
            le = 0
            print"Continue search from document end"
            rotate = false
            goto docend
        end

        if le2 < 0 and lco2 < 0 then print"Next diff not found"; return end
        if le2 < 0 then le2 = lco2 end
        if lco2 < 0 then lco2 = le2 end

        local l = Iif(le2 < lco2, le2, lco2)
        editor:EnsureVisible(l)
        editor:EnsureVisibleEnforcePolicy(l)

        m = Marker(editor, l)
        local l2
        if m > 0 then
            l2 = l
            while m == Marker(editor, l2) do
                l2 = l2 + 1
            end
            editor.SelectionStart = editor:PositionFromLine(l)
            editor.SelectionEnd = editor:PositionFromLine(l2) - 2
        else
            l2 = l + 1
            editor.SelectionStart = editor:PositionFromLine(l2) - 2
            editor.SelectionEnd = editor:PositionFromLine(l2)
        end

    end

    local function copyToSide(side)
        local function MoveEnd(e, p)
            while e.CharAt[p] ~= 10 and e.CharAt[p] ~= 13 do
                p = p + 1
            end
            return p
        end

        local lStart = editor:LineFromPosition(editor.SelectionStart)
        local lEnd = editor:LineFromPosition(editor.SelectionEnd)
        local lCoStart = coeditor:DocLineFromVisible(editor:VisibleFromDocLine(lStart))
        local lCoEnd = coeditor:DocLineFromVisible(editor:VisibleFromDocLine(lEnd))

        local pStart = editor.SelectionStart
        local pCoStart

        pStart = editor:PositionFromLine(lStart)
        if editor.CharAt[pStart] ~= 10 and editor.CharAt[pStart] ~= 13 then
            pCoStart = coeditor:PositionFromLine(lCoStart)

            if Marker(editor, lStart) & maskLinesADM > 0 then
                pStart = pStart - 2 -- Marker(editor, editor:PositionFromLine(lStart - 1))
                pCoStart = MoveEnd(coeditor, pCoStart)
            end
        else
            pCoStart = coeditor:PositionFromLine(lCoStart)
            if Marker(editor, lStart) & maskLinesADM == 0 then pCoStart = MoveEnd(coeditor, pCoStart) end
        end

        local pEnd = editor.SelectionEnd
        local pCoEnd
        pEnd = MoveEnd(editor, pEnd)
        pCoEnd = MoveEnd(coeditor, coeditor:PositionFromLine(lCoEnd))

        local s
        if scite.buffers.GetBufferSide(scite.buffers.GetCurrent()) ~= side then
            coeditor.TargetStart = pCoStart
            coeditor.TargetEnd = pCoEnd
            coeditor:ReplaceTarget(editor:textrange(pStart, pEnd))
        else
            editor.TargetStart = pStart
            editor.TargetEnd = pEnd
            editor:ReplaceTarget(coeditor:textrange(pCoStart, pCoEnd))
        end
        StartCompare(true)
        lastEditLine = editor.LineCount + 1
        onUpdateUI_local(false, true, 0)
    end

    local function CompareToFile(strName, bTmp)
        if scite.CompareEncodingFile(strName, editor:GetText()) then
            print((_T"Files are identical"):from_utf8())
            if bTmp then shell.delete_file(strName) end
            return
        end
        local strCur = props['FilePath']
        local strExt = props['FileExt']
        local zoom = editor.Zoom
        local fvl = editor.FirstVisibleLine
        --scite.BlockUpdate(UPDATE_BLOCK)
        BlockEventHandler"OnSwitchFile"
        BlockEventHandler"OnNavigation"
        BlockEventHandler"OnUpdateUI"
        BlockEventHandler"OnOpen"
        BlockEventHandler"OnClose"
        BlockEventHandler"OnTextChanged"
        BlockEventHandler"OnBeforeOpen"
        scite.Open(strName)

        if bTmp then tmpFiles[props['FilePath']] = true end

        scite.MenuCommand(IDM_CHANGETAB)
        scite.SetLexer(strExt)

        scite.Open(strCur)

        --coeditor:GrabFocus()
        editor:GrabFocus()
        editor.Focus = true
        UnBlockEventHandler"OnClose"
        UnBlockEventHandler"OnOpen"
        UnBlockEventHandler"OnUpdateUI"
        UnBlockEventHandler"OnNavigation"
        UnBlockEventHandler"OnSwitchFile"
        UnBlockEventHandler"OnBeforeOpen"
        UnBlockEventHandler"OnTextChanged"

        --scite.BlockUpdate(UPDATE_FORCE)
        bActive = 0
        editor.FirstVisibleLine = fvl
        StartCompare()
        --debug_prnArgs(tCompare)
        editor.Zoom = zoom
        coeditor.Zoom = zoom
    end

    function COMPARE.To(strName)
        CompareToFile(strName, false)
    end
    function COMPARE.Start()
        Reset()
        StartCompare()
    end

    local function prepareTmpPath()
        if not tmpPath then
            tmpPath = luacom.CreateObject('Scripting.FileSystemObject'):GetSpecialFolder(2).Path..'\\_HildiM\\'
        end
        if shell.greateDirectory(tmpPath) then
            return tmpPath..'^^'..props['FileNameExt']
        end
    end

    local function CompareGit()
        if not tmpPath then
            tmpPath = luacom.CreateObject('Scripting.FileSystemObject'):GetSpecialFolder(2).Path..'\\_HildiM\\'
        end
        shell.greateDirectory(tmpPath)
        shell.set_curent_dir(props['FileDir']..'\\')

        local iErr, str = shell.exec('git branch -v', nil, true, true)
        if iErr ~= 0 or not str then
            print("No git branch found:", str)
            return
        end

        local _, _, sh = str:find('* %w+ (%w+)')
        local pNew = prepareTmpPath()
        cmd = 'TortoiseGitProc.exe /command:cat /path:"'..props['FilePath']..
            '" /savepath:"'..pNew..'" /revision:'..sh

        iErr, str = shell.exec(cmd, nil, true, true)
        if iErr ~= 0 then
            print(str)
            return
        end

        CompareToFile(pNew, true)
        tmpFiles[pNew] = true
    end

    function COMPARE.CompareVss()
        VSS.diff(CompareToFile, prepareTmpPath():gsub('\\[^\\]+$', ''))
    end

    local function CompareSelfTitled(strPath)
        local strfile = (strPath or ((tSet.selfTitledDir or '')..'\\'))..props['FileNameExt']
        local s = strfile
        if shell.fileexists(strfile) then
            CompareToFile(strfile)
        else
            print('File '..s..' not found')
        end
    end

    local function ColorSettings()
        local ret, added, deleted, changed, moved, blank =
        iup.GetParam(_T"Comparison Color Preferences'..'^compare",
            nil,
            _T'Lines color'..'%t\n'..
            _T'Added'..':%c\n'..
            _T'Deleted'..':%c\n'..
            _T'Changed'..':%c\n'..
            _T'Moved'..':%c\n'..
            _T'Blank'..':%c\n',
            CORE.Rgb2Str(tSet.Color_added),
            CORE.Rgb2Str(tSet.Color_deleted),
            CORE.Rgb2Str(tSet.Color_changed),
            CORE.Rgb2Str(tSet.Color_moved),
            CORE.Rgb2Str(tSet.Color_blank)
        )
        if ret then
            tSet.Color_added   = CORE.Str2Rgb(added  , tSet.Color_added  )
            tSet.Color_deleted = CORE.Str2Rgb(deleted, tSet.Color_deleted)
            tSet.Color_changed = CORE.Str2Rgb(changed, tSet.Color_changed)
            tSet.Color_moved   = CORE.Str2Rgb(moved  , tSet.Color_moved  )
            tSet.Color_blank   = CORE.Str2Rgb(blank  , tSet.Color_blank  )
            ApplySettings()
            Compare.SetStyles()
        end
    end


    AddEventHandler("OnOpen", OnSwitch_local)
    AddEventHandler("OnSwitchFile", OnSwitch_local)

    local function OnClose_local(file, side_in)
        if tmpFiles[file] then
            tmpFiles[file] = nil
            if shell.fileexists(file) then
                shell.delete_file(file)
            end
        end
        if (bActive & 4) == 4 and not side_in then
            Reset()
        elseif bActive > 0 or side_in then
            local side = side_in or scite.buffers.GetBufferSide(scite.buffers.GetCurrent())
            if side == 0 or side_in then
                onClose(tCompare.left, tCompare.right, file, side_in)
            else
                onClose(tCompare.right, tCompare.left, file, side_in)
            end
        end
    end

    AddEventHandler("OnClose", OnClose_local)
    AddEventHandler("OnMenuCommand", function(cmd)
        if cmd == IDM_CHANGETAB then
            local side = side_in or scite.buffers.GetBufferSide(scite.buffers.GetCurrent())
            if side == 0 then
                onClose(tCompare.left, tCompare.right, props['FilePath'], side_in)
            else
                onClose(tCompare.right, tCompare.left, props['FilePath'], side_in)
            end
        end
    end)
    AddEventHandler("OnCloseFileset", function(tfiles)
        for i = 1,  #tfiles do
            local side = 0
            local path = tfiles[i]
            if path:find('^>') then
                side = 1
                path = path:gsub('^>', '')
            end
            if tmpFiles[path] then
                tmpFiles[path] = nil
                if shell.fileexists(path) then
                    shell.delete_file(path)
                end
            end
            if tCompare.left[path] then
                tCompare.right[tCompare.left[path]] = '-'
                tCompare.left[path] = nil
            elseif tCompare.right[path] then
                tCompare.left[tCompare.right[path]] = '-'
                tCompare.right[path] = nil
            end
        end
        OnSwitch_local()
    end)

    local bInvertCE = false
    onUpdateUI_local = function(bModified, bSelection, flag)
        ScrollWindows(editor, coeditor, flag)
        if (bActive & 4) == 4 and tSet.Recompare then
            if coeditor.Zoom ~= editor.Zoom then coeditor.Zoom = editor.Zoom end
            if bSelection == 1 and (lastEditLine and lastEditLine ~= editor:LineFromPosition(editor.CurrentPos)) then
                local fvl = editor.FirstVisibleLine
                editor.VScrollBar = false
                coeditor.VScrollBar = false
                ClearWindow(editor)
                ClearWindow(coeditor)
                CompareSetInd()
                editor.FirstVisibleLine = fvl
                editor.VScrollBar = true
                coeditor.VScrollBar = true
                lastEditLine = nil
                bInvertCE = true
            end
            if not lastEditLine and bModified == 1 then
                lastEditLine = editor:LineFromPosition(editor.CurrentPos)
            end
            if flag & SC_UPDATE_SELECTION > 0 then
                local coP = coeditor:PositionFromLine(coeditor:DocLineFromVisible(editor:VisibleFromDocLine(editor:LineFromPosition(editor.CurrentPos))))
                coeditor.SelectionStart = coP
                coeditor.SelectionEnd = coP
                coeditor.CurrentPos = coP
            end
        end
    end
    AddEventHandler("OnUpdateUI", onUpdateUI_local)

    AddEventHandler("CoOnUpdateUI", function(bModified, bSelection, flag)
        if bInvertCE then
            ScrollWindows(editor, coeditor, flag)
            bInvertCE = false
        else
            ScrollWindows(coeditor, editor, flag)
        end
    end)


    onDestroy = function()
        for f, _ in pairs(tmpFiles) do
            shell.delete_file(f)
        end
        _G.iuprops['compare_settings'] = tSet;
        COMPARE = nil
        CORE.FreeIndic(mark)
    end

    local tmr
    AddEventHandler("OnInitHildiM", function()
        local cnt = 0
        tmr = iup.timer{time = 20, run = 'NO', action_cb = function()
            cnt = cnt + 1
            if cnt > 200 or Compare.Init(iup.GetDialogChild(iup.GetLayout(), "Source").hwnd, iup.GetDialogChild(iup.GetLayout(), "CoSource").hwnd) == 0 then
                tmr.run = 'NO'

                ApplySettings()

                Compare.SetStyles()
            end
            if cnt > 20 then
                tmr.run = 'NO'
                print("Compare plugin error: not connected")
            end
        end}
        tmr.run = 'YES'
    end)

    local function bCanCpyLeft()
        local e = Iif(scite.buffers.GetBufferSide(scite.buffers.GetCurrent()) == 0, editor, coeditor)
        return not e.ReadOnly and bActive == 7
    end

    local function bCanCpyRight()
        local e = Iif(scite.buffers.GetBufferSide(scite.buffers.GetCurrent()) == 1, editor, coeditor)
        return not e.ReadOnly and bActive == 7
    end

    local function bCanNewComp()
        local s = scite.buffers.GetBufferSide(scite.buffers.GetCurrent())
        return ((s + 1) & bActive) == 0
    end

    local function bCanCompareSide()
        return ((_G.iuprops['coeditor.win'] or '')~= '2') and (bActive == 0 or bActive == 7)
    end

    local item = {'&Comparison', {
		{'Compare to &Other View', key = 'Alt+=', action = StartCompare, active = bCanCompareSide},
		{'C&lear Highlighting', action = Reset, image = 'cross_script_µ' },
        {'s1', separator = 1},
        {'Compare to &Git', action = CompareGit, visible = function() return gitInstall == 1 end, active = function() return bGitActive end, image = 'edit_diff_µ'},
        {'Compare to &Vss', action = COMPARE.CompareVss, visible = 'VSS', active = bCanNewComp, image = 'edit_diff_µ'},
        {'s2', separator = 1},
		{'&Next Difference', key = 'Alt+Down', action = nextDiff, active = function() return bActive == 7 end, image='IMAGE_ArrowDown'},
		{'&Previous Difference', key = 'Alt+Up', action = prevDif, active = function() return bActive == 7 end, image = 'IMAGE_ArrowUp'},
		{'Copy &Left', key = 'Alt+Left', action = function() copyToSide(0) end, active = bCanCpyLeft, image = 'control_double_180_µ'},
		{'Copy &Right', key = 'Alt+Right', action = function() copyToSide(1) end, active = bCanCpyRight, image = 'control_double_µ'},
        {'s3', separator = 1},
		{'&Recompare when moved to other line', check = function() return tSet.Recompare end, action = function() tSet.Recompare = not tSet.Recompare; _G.iuprops['compare_settings'] = tSet end},
		{'Ignore &Spaces', check = function() return tSet.IncludeSpace end, action = function() tSet.IncludeSpace = not tSet.IncludeSpace;  ApplySettings{}; _G.iuprops['compare_settings'] = tSet end},
		{'&Identify moved lines', check = function() return tSet.DetectMove end, action = function() tSet.DetectMove = not tSet.DetectMove; ApplySettings(); _G.iuprops['compare_settings'] = tSet end},
		{'&Add Blank Lines', check = function() return tSet.AddLine end, action = function() tSet.AddLine = not tSet.AddLine; ApplySettings(); _G.iuprops['compare_settings'] = tSet end},
		{'&Use Icons', check = function() return tSet.UseSymbols end, action = function() tSet.UseSymbols = not tSet.UseSymbols; ApplySettings(); _G.iuprops['compare_settings'] = tSet end},
		{'Color Pre&ferences', action = ColorSettings, image='color_µ'},
    }}
    menuhandler:AddMenu(item, "hildim/ui/compare.html", _T)
    local function compareVis(bFavor)
        local path = FILEMAN.Directory(bFavor)
        if not path then return false end
        if path:upper() == (props['FileDir']..'\\'):upper() then return false end
        if path:find('^\\\\') then return true end
        return shell.fileexists(path..props['FileNameExt'])
    end
    local function compareVisFile()
        if FILEMAN.Directory() then return false end
        return (FILEMAN.FullPath() or ''):upper() ~= (props['FileDir']..'\\'):upper()
    end
    menuhandler:PostponeInsert('MainWindowMenu', '_HIDDEN_|Fileman_sidebar|sxxx',
        {'Compare', plane = 1, {
            {"Compare to same named from this folder",  action = function()
                CompareSelfTitled(FILEMAN.Directory())
            end, visible = compareVis},
            {"Compare to Active", action = function()
                local path = FILEMAN.FullPath()
                CompareToFile(path, false)
            end, visible = compareVisFile},
    }}, "hildim/ui/compare.html", _T)

    menuhandler:PostponeInsert('MainWindowMenu', '_HIDDEN_|Favorites_sidebar|sxxx',
        {'Compare', plane = 1, visible = function() return compareVis(true) end, {
            {'s_cmp', separator = 1},
            {"Compare to same named from this folder",  action = function()
                CompareSelfTitled(FILEMAN.Directory(true))
            end},
    }}, "hildim/ui/compare.html", _T)

end
return {
    title = _T'File Comparison',
    destroy = function() onDestroy() end,
    hidden = Init_hidden,
}
