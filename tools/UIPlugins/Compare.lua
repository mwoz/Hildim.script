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
    local mark = CORE.InidcFactory('Compare.Inline', '���������� �������� � ������ ���������', INDIC_BOX, 255, 0)
    local tmpPath
    local tmpFiles = {}
    local gitInstall, bGitActive

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
    end

    local function StartCompare()
        if not eOffsets[editor] then --��������������� ��� ������ ������� - ����� ������ Editor pane is not accessible at this time.
            SetAnnotationStiles(editor)
            SetAnnotationStiles(coeditor)
        end
        if bActive == 7 then Reset() end

        bActive = 7
        CompareSetInd()
        tCompare.left[fPath(tabL)] = fPath(tabR)
        tCompare.right[fPath(tabR)] = fPath(tabL)
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
        if bActive > 0 then
            SetAnnotationStiles(editor)
            SetAnnotationStiles(coeditor)
        end

    end

    local function onClose(t1, t2, source, bScipClear)
        if t1[source] then
            t2[t1[source]] = "-"
            if not bScipClear then Reset() end
        end
    end

    local function prevDif()
        local le = editor:LineFromPosition(editor.SelectionStart)

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

        if le2 < 0 and lco2 < 0 then print"Next diff not found"; return end
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

        local m = Marker(editor, le)
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

        if editor.CharAt[pStart] ~= 10 and editor.CharAt[pStart] ~= 13 then
            pStart = editor:PositionFromLine(lStart)
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
        StartCompare()
    end

    local function CompareToFile(strName, bTmp)
        local strCur = props['FilePath']
        local strExt = props['FileExt']
        local zoom = editor.Zoom
        --scite.BlockUpdate(UPDATE_BLOCK)
        BlockEventHandler"OnSwitchFile"
        BlockEventHandler"OnNavigation"
        BlockEventHandler"OnUpdateUI"
        BlockEventHandler"OnOpen"
        BlockEventHandler"OnClose"
        BlockEventHandler"OnTextChanged"
        BlockEventHandler"OnBeforeOpen"
        scite.Open(strName)

        if bTmp then tmpFiles[strName] = true end

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
        StartCompare()
        --debug_prnArgs(tCompare)
        editor.Zoom = zoom
        coeditor.Zoom = zoom
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
        if iErr ~= 0 then
            print(str)
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

    local function CompareSelfTitled()
        local strfile = (tSet.selfTitledDir or '')..'\\'..props['FileNameExt']
        local s = strfile
        if shell.fileexists(strfile) then
            CompareToFile(strfile)
        else
            print('File '..s..' not found')
        end
    end

    local function SetSelfTitledDir()
        local ret, dir =
        iup.GetParam("����� ���������� ��� ��������� � �����������^compare",
            function(ih, param_index)
                if param_index == -2 then
                    local p = iup.GetParamHandle(ih, 'PARAM0')
                    p.dialogtype = 'DIR'
                    p.directory = tSet.selfTitledDir or ''
                end
                return 1
            end,
            'Directory:%f\n',
            tSet.selfTitledDir or ''
        )
        if ret then tSet.selfTitledDir = dir end
    end

    local function ColorSettings()
        local ret, added, deleted, changed, moved, blank =
        iup.GetParam("��������� ������ ���������^compare",
            nil,
            'Added:%c\n'..
            'Deleted:%c\n'..
            'Changed:%c\n'..
            'Moved:%c\n'..
            'Blank:%c\n',
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

    AddEventHandler("OnUpdateUI", function(bModified, bSelection, flag)
        ScrollWindows(editor, coeditor, flag)
        if (bActive & 4) == 4 and tSet.Recompare then
            if coeditor.Zoom ~= editor.Zoom then coeditor.Zoom = editor.Zoom end
            if bSelection == 1 and (lastEditLine and lastEditLine ~= editor:LineFromPosition(editor.CurrentPos)) then
                ClearWindow(editor)
                ClearWindow(coeditor)
                CompareSetInd()
                lastEditLine = nil
            end
            if not lastEditLine and bModified == 1 then
                lastEditLine = editor:LineFromPosition(editor.CurrentPos)
            end

        end
    end)



    AddEventHandler("CoOnUpdateUI", function(bModified, bSelection, flag)
        ScrollWindows(coeditor, editor, flag)
    end)


    onDestroy = function()
        for f, _ in pairs(tmpFiles) do
            shell.delete_file(f)
        end
        _G.iuprops['compare_settings'] = tSet;
        COMPARE = nil
        CORE.FreeIndic(mark)
    end

    Compare.Init(iup.GetDialogChild(iup.GetLayout(), "Source").hwnd, iup.GetDialogChild(iup.GetLayout(), "CoSource").hwnd)

    ApplySettings()

    Compare.SetStyles()

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

    local item = {'Compare', ru = '���������', {
		{'Compare', ru = '��������', key = 'Alt+=', action = StartCompare, active = bCanCompareSide},
		{'Clear backlight', ru = '�������� ���������', action = Reset, image='cross_script_�' },
        {'s1', separator = 1},
        {'Compare to Git', ru = '�������� � Git', action = CompareGit, visible = function() return gitInstall == 1 end, active = function() return bGitActive end, image='edit_diff_�'},
        {'Compare to Vss', ru = '�������� � Vss', action = COMPARE.CompareVss, visible = 'VSS', active = bCanNewComp, image = 'edit_diff_�'},
        {'Compare to Self-Titled', ru = '�������� � ����������� ��...', action = CompareSelfTitled, active = function() return ((tSet.selfTitledDir or '' and bCanNewComp())) ~= '' end},
        {'Directory For Comparing', ru = '���������� ��� ���������', action = SetSelfTitledDir, active = function() return true end},
        {'s2', separator = 1},
		{'Next Difference', ru = '��������� ��������', key = 'Alt+D', action = nextDiff, active = function() return bActive == 7 end, image='IMAGE_ArrowDown'},
		{'Prevouse Difference', ru = '���������� ��������', key = 'Alt+U', action = prevDif, active = function() return bActive == 7 end, image='IMAGE_ArrowUp'},
		{'Copy To Left', ru = '����������� �����', key = 'Alt+L', action = function() copyToSide(0) end, active = bCanCpyLeft, image='control_double_180_�'},
		{'Copy To Right', ru = '����������� ������', key = 'Alt+R', action = function() copyToSide(1) end, active = bCanCpyRight, image='control_double_�'},
        {'s3', separator = 1},
		{'Recompare by changing line', ru = '���������� ������ ��� ��������� ������', check = function() return tSet.Recompare end, action = function() tSet.Recompare = not tSet.Recompare end},
		{'Ignore Space', ru = '������������ �������', check = function() return tSet.IncludeSpace end, action = function() tSet.IncludeSpace = not tSet.IncludeSpace;  ApplySettings{} end},
		{'Detect Move', ru = '���������� ������������ ������', check = function() return tSet.DetectMove end, action = function() tSet.DetectMove = not tSet.DetectMove; ApplySettings() end},
		{'Add Empty Line', ru = '��������� ������ ������', check = function() return tSet.AddLine end, action = function() tSet.AddLine = not tSet.AddLine; ApplySettings() end},
		{'Use Icons', ru = '������������ ������', check = function() return tSet.UseSymbols end, action = function() tSet.UseSymbols = not tSet.UseSymbols; ApplySettings() end},
		{'Color Settings', ru = '��������� ������', action = ColorSettings, image='color_�'},
    }}
    menuhandler:AddMenu(item)

end
return {
    title = '��������� ������',
    destroy = onDestroy,
    hidden = Init_hidden,
}
