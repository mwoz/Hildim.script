require "shell"

local function local_OnPaste()
    local nSelection = scite.SendEditor(SCI_GETSELECTIONS)
    if nSelection <=1 then return false end
    local strClp=shell.get_clipboard()
    if strClp:find('[\n\r]') then
        scite.SendEditor(SCI_SETMULTIPASTE,0,0)
        return false
    else
        scite.SendEditor(SCI_SETMULTIPASTE,1,1)
        return false
    end
end
AddEventHandler("OnMenuCommand", function(msg, source)
	if msg == IDM_PASTE then -- (Ctrl+V)
		return local_OnPaste() -- true не дает выполнится встроенной команде
	end
end)

local function do_Unselect()
    local nSelection = scite.SendEditor(SCI_GETSELECTIONS)
    if nSelection <= 1 then return end
    local tbl_pos = {}
    local maxPos = 0
    for i = 0, nSelection-1 do
        local selStart = scite.SendEditor(SCI_GETSELECTIONNSTART,i,i)
        local selEnd = scite.SendEditor(SCI_GETSELECTIONNEND,i,i)
        table.insert(tbl_pos, {selStart, selEnd})
    end


    for i = 1, nSelection - 1 do
        if i == 1 then
            scite.SendEditor(SCI_SETSELECTION,tbl_pos[i][1],tbl_pos[i][2])
        else
            scite.SendEditor(SCI_ADDSELECTION,tbl_pos[i][1],tbl_pos[i][2])
        end
    end
end

local isSetMulty = false
AddEventHandler("OnClick", function(shift, ctrl, alt)
    isSetMulty = (scite.SendEditor(SCI_GETSELECTIONS)>1 and ctrl and not alt and not shift)

end)

AddEventHandler("OnMouseButtonUp", function(ctrl)
    if isSetMulty and not ctrl then do_Unselect() end
    isSetMulty = false
end)

