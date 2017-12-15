

local function Init_hidden()
require 'Compare'
    local bActive = false
    local eOffsets = {}
    local tCompare = {left = {}, right = {}}
    local tabL = iup.GetDialogChild(iup.GetLayout(), 'TabCtrlLeft')
    local tabR = iup.GetDialogChild(iup.GetLayout(), 'TabCtrlRight')
    local lastEditLine
    -- iup.GetAttribute(iup.GetDialogChild(iup.GetLayout(), 'TabCtrlRight'), "VALUEPOS")
    -- iup.GetAttribute(, "VALUEPOS")
    -- iup.GetAttribute(iup.GetDialogChild(iup.GetLayout(), 'TabCtrlLeft'), "TABTIP1")

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
            e:MarkerDeleteAll(i)
        end
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
        Compare.Compare()
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
        if (bActive & 4) == 4 then
            if bSelection == 1 and (lastEditLine and lastEditLine ~= editor:LineFromPosition(editor.CurrentPos)) then
                ClearWindow(editor)
                ClearWindow(coeditor)
                Compare.Compare()
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
    -- Compare.Settings.Color_blank = 111222333
    -- print(Compare.Settings.Color_blank)
    -- Compare.Compare()
    local item = {'Compare', ru = 'Сравнение', {
		{'Compare', ru = 'Сравнить', action = StartCompare, active = "(_G.iuprops['coeditor.win'] or '')=='0'"},
		{'Clear', ru = 'Очистить', action = Reset, active = "(_G.iuprops['coeditor.win'] or '')=='0'"},
    }}
    menuhandler:AddMenu(item)

end
return {
    title = 'Сравнение файлов',
    hidden = Init_hidden,
}
