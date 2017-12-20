local tSet
local function Init_hidden()
require 'Compare'
    local bActive = 0
    local eOffsets = {}
    local tCompare = {left = {}, right = {}}
    local tabL = iup.GetDialogChild(iup.GetLayout(), 'TabCtrlLeft')
    local tabR = iup.GetDialogChild(iup.GetLayout(), 'TabCtrlRight')
    local lastEditLine
    local markerMask = 0
    local mark = 15

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

    tSet = (_G.iuprops['compare_settings'] or {})
    if (tSet.version or 0) < 1 then
        tSet.version = 1
        tSet.DetectMove = true
        tSet.IncludeSpace = true
        tSet.AddLine = true
        tSet.Color_added = 14745568
        tSet.Color_deleted = 14737663
        tSet.Color_changed = 10020839
        tSet.Color_moved = 11643021
        tSet.Color_blank = 15000804
    end

    local function ApplySettings()
        Compare.Settings.IncludeSpace = tSet.IncludeSpace
        Compare.Settings.DetectMove = tSet.DetectMove
        Compare.Settings.AddLine = tSet.AddLine
        Compare.Settings.UseSymbols = tSet.UseSymbols
        Compare.Settings.Color_added   = tSet.Color_added
        Compare.Settings.Color_deleted = tSet.Color_deleted
        Compare.Settings.Color_changed = tSet.Color_changed
        Compare.Settings.Color_moved   = tSet.Color_moved
        Compare.Settings.Color_blank = tSet.Color_blank
    end

    local function CompareSetInd()
        local i1 = editor.IndicatorCurrent
        local i2 = coeditor.IndicatorCurrent
        editor.IndicatorCurrent   = mark
        coeditor.IndicatorCurrent = mark
        Compare.Compare()
        editor.IndicatorCurrent   = i1
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
        return iup.GetAttribute(tabS, "TABTIP"..iup.GetAttribute(tabS, "VALUEPOS"))
    end

    local bRunScroll

    local function ScrollWindows(e1, e2, flag)
        if (bActive & 4) == 4 and not bRunScroll then
            bRunScroll = true
            if (flag & SC_UPDATE_V_SCROLL) ~= 0 then
                e2.FirstVisibleLine = e1.FirstVisibleLine
            end
            if (flag & SC_UPDATE_H_SCROLL) ~= 0 then
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
        if not eOffsets[editor] then --доинициализация при первом запуске - иначе ошибка Editor pane is not accessible at this time.
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

    local function onClose(t1, t2, source)
        if t1[source] then
            t2[t1[source]] = "-"
            Reset()
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
        if le2 > -1 then lMin = le2 end

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

    local function CompareToFile(strName)
        local strCur = props['FilePath']
        local strExt = props['FileExt']

        scite.Open(strName)
        scite.MenuCommand(IDM_CHANGETAB)
        scite.SetLexer(strExt)

        StartCompare()

        --scite.MenuCommand(IDM_NEXTFILESTACK)
        editor:GrabFocus()
        editor.Focus = true;
    end

    local function CompareVss()
        VSS.diff(CompareToFile)
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
        iup.GetParam("Настройки цветов сравнения^CompareColorSettings",
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
        local function Rgb2Str(rgb)
            return ''..(rgb & 255)..' '..((rgb >> 8) & 255)..' '..((rgb >> 16) & 255)
        end
        local function Str2Rgb(s, def)
            local _, _, r, g, b = s:find('(%d+) (%d+) (%d+)')
            if r then
                return (b << 16)|(g << 8)|r
            end
            return def
        end
        local ret, added, deleted, changed, moved, blank =
        iup.GetParam("Настройки цветов сравнения^CompareColorSettings",
            nil,
            'Added:%c\n'..
            'Deleted:%c\n'..
            'Changed:%c\n'..
            'Moved:%c\n'..
            'Blank:%c\n',
            Rgb2Str(tSet.Color_added),
            Rgb2Str(tSet.Color_deleted),
            Rgb2Str(tSet.Color_changed),
            Rgb2Str(tSet.Color_moved),
            Rgb2Str(tSet.Color_blank)
        )
        if ret then
            tSet.Color_added = Str2Rgb(added  , tSet.Color_added  )
            tSet.Color_deleted = Str2Rgb(deleted, tSet.Color_deleted)
            tSet.Color_changed = Str2Rgb(changed, tSet.Color_changed)
            tSet.Color_moved = Str2Rgb(moved  , tSet.Color_moved  )
            tSet.Color_blank = Str2Rgb(blank  , tSet.Color_blank  )
            ApplySettings()
            Compare.SetStyles()
        end
    end


    AddEventHandler("OnOpen", OnSwitch_local)
    AddEventHandler("OnSwitchFile", OnSwitch_local)

    AddEventHandler("OnClose", function(source)
        if (bActive & 4) == 4 then
            Reset()
        elseif bActive > 0 then
            local side = scite.buffers.GetBufferSide(scite.buffers.GetCurrent())
            if side == 0 then
                onClose(tCompare.left, tCompare.right, source)
            else
                onClose(tCompare.right, tCompare.left, source)
            end
        end
    end)

    AddEventHandler("OnUpdateUI", function(bModified, bSelection, flag)
        ScrollWindows(editor, coeditor, flag)
        if (bActive & 4) == 4 and tSet.Recompare then
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


    Compare.Init(iup.GetDialogChild(iup.GetLayout(), "Source").hwnd, iup.GetDialogChild(iup.GetLayout(), "CoSource").hwnd)

    ApplySettings()

    Compare.SetStyles()

    -- Compare.Settings.Color_blank = 111222333
    -- print(Compare.Settings.Color_blank)
    -- Compare.Compare()
    local item = {'Compare', ru = 'Сравнение', {
		{'Compare', ru = 'Сравнить', key = 'Alt+=', action = StartCompare, active = "(_G.iuprops['coeditor.win'] or '')=='0'"},
		{'Clear', ru = 'Очистить', action = Reset, active = function() return bActive > 0 end},
        {'s1', separator = 1},
        {'Compare to Vss', ru = 'Сравнить с Vss', action = CompareVss, visible = 'VSS', active = function() return true end},
        {'Compare to Self-Titled', ru = 'Сравнить с одноименным из...', action = CompareSelfTitled, active = function() return (tSet.selfTitledDir or '') ~= '' end},
        {'Directory For Comparing', ru = 'Директория для сравнения', action = SetSelfTitledDir, active = function() return true end},
        {'s2', separator = 1},
		{'Next Difference', ru = 'Следующее различие', key = 'Alt+D', action = nextDiff, active = function() return bActive == 7 end},
		{'Prevouse Difference', ru = 'Предыдущее различие', key = 'Alt+U', action = prevDif, active = function() return bActive == 7 end},
		{'Copy To Left', ru = 'Скопировать влево', key = 'Alt+L', action = function() copyToSide(0) end, active = function() return bActive == 7 end},
		{'Copy To Eight', ru = 'Скопировать вправо', key = 'Alt+R', action = function() copyToSide(1) end, active = function() return bActive == 7 end},
        {'s3', separator = 1},
		{'Recompare by changing line', ru = 'Сравнивать заново при изменении строки', check = function() return tSet.Recompare end, action = function() tSet.Recompare = not tSet.Recompare end},
		{'Ignore Space', ru = 'Игнорировать пробелы', check = function() return tSet.IncludeSpace end, action = function() tSet.IncludeSpace = not tSet.IncludeSpace;  ApplySettings{} end},
		{'Detect Move', ru = 'Определять перемещенные строки', check = function() return tSet.DetectMove end, action = function() tSet.DetectMove = not tSet.DetectMove; ApplySettings() end},
		{'Add Empty Line', ru = 'Добавлять пустые строки', check = function() return tSet.AddLine end, action = function() tSet.AddLine = not tSet.AddLine; ApplySettings() end},
		{'Use Icons', ru = 'Использовать иконки', check = function() return tSet.UseSymbols end, action = function() tSet.UseSymbols = not tSet.UseSymbols; ApplySettings() end},
		{'Color Settings', ru = 'Настройки цветов', action = ColorSettings},
    }}
    menuhandler:AddMenu(item)

end
return {
    title = 'Сравнение файлов',
    destroy = function() _G.iuprops['compare_settings'] = tSet end,
    hidden = Init_hidden,
}
