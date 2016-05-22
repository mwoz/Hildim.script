--[[������ �������������� ������� ������]]
local tblView = {}, tblUsers
local defpath = props["SciteDefaultHome"].."\\tools\\UIPlugins\\"

local function settings2tbl(str, side)
        local defpath = props["SciteDefaultHome"].."\\tools\\UIPlugins\\"
        local function piCode(pI)
            if pI.code == 'findrepl' then
                return 'Pane{type="FIND"}'
            else
                return pI.code
            end
            return pI.code
        end
        if str == '' then
            return side..' = function() return nil end'
        end
        local tSide = {}
        local tCur

        for p in str:gmatch('[^�]+') do
            local _,_, pname, pf = p:find('(.-)(�?)$')
            if pf ~= '' then
                tCur = {title = pname}
                table.insert(tSide, tCur)
            else
                table.insert(tCur, pname)
            end
        end

        local strTabs = side..'= function() return{\n'
        for i = 1, #tSide do
            tCur = tSide[i]
            local pI = dofile(defpath..tCur[1])
--            pI.sidebar()
            local tabName = tCur.title
            if #tCur == 1 then
                strTabs = strTabs..'Pane{"'..pI.code..'", tabtitle = "'..tabName..'"},\n'
            else
                local strPrev = '"'..piCode(pI)..'"'
                local bfixedheigth = pI.fixedheigth
                for j = 2, #tCur do
                    pI = dofile(defpath..tCur[j])
--                    pI.sidebar()
                    print(pI.code, j, tCur[j])
                    strPrev = 'Pane{'..strPrev..', "'..piCode(pI)..'", '
                    if bfixedheigth or pI.fixedheigth then
                        strPrev = strPrev..'type="VBOX", '
                    else
                        strPrev = strPrev..' orientation="HORIZONTAL", type="SPLIT", name = "split'..pI.code..'", '
                    end
                    if j == #tCur then
                        strPrev = strPrev..'tabtitle = "'..tabName..'", '
                    end
                    strPrev = strPrev..'}'
                end
                strTabs = strTabs..strPrev..',\n'
            end
        end
        return strTabs.."} end"
end

local function Show()

    local list_lex, dlg, bBlockReset, tree_right
    local btn_ok = iup.button  {title="OK"}
    iup.SetHandle("TOOLBARSETT_BTN_OK",btn_ok)

    local tree_plugins = iup.text{size='100x'}

    btn_ok.action = function()
        local function SaveTree(h)
            local str = ''
            for i = 1,  iup.GetAttribute(h, "TOTALCHILDCOUNT0") do
                if str ~= '' then str = str..'�' end
                if iup.GetAttributeId(h, "KIND", i) == "BRANCH" then
                    if iup.GetAttributeId(h, "CHILDCOUNT", i) ~= '0' then
                        str = str.. iup.GetAttributeId(h, "TITLE", i)..'�'
                    end
                else
                    str = str..h:GetUserId(i)
                end

            end
            return str
        end
        -- _G.iuprops["settings.user.leftbar"] = SaveTree(tree_left)
        -- _G.iuprops["settings.user.rightbar"] = SaveTree(tree_right)
        print(settings2tbl(SaveTree(tree_left),"tbArgLeft"))
        print(settings2tbl(SaveTree(tree_right),"tbArgRight"))
        dlg:hide()
        dlg:postdestroy()
    end

    tree_plugins = iup.tree{size = '120x',
        droptarget ='YES', droptypes = "XXXXX", dragsource ='YES',dragtypes = "XXXXX"  }
    tree_plugins.dragdatasize_cb = function(ih, typ)  return 1 end
    tree_plugins.dragdata_cb = function(ih, typ) return true end

    local dragName, dragPath, drag_id

    local function dropdata_cb(h, typ, data, size, x, y)
        local id = iup.ConvertXYToPos(h, x, y)
        if id < 0 then id = 0 end
        if h:GetUserId(id) == "" then id = 1 end
        iup.SetAttributeId(h,"ADDLEAF", id, dragName)
        id = iup.GetAttribute(h, 'LASTADDNODE')
        h:SetUserId(id, dragPath)
        drag_id = nil
        return true
    end

    local function dragbegin_cb(h, x, y)
        local id = iup.ConvertXYToPos(h, x, y)
        if iup.GetAttributeId(h, 'KIND', id) == 'BRANCH' then return -1 end
        dragName = iup.GetAttributeId(h, 'TITLE', id)
        dragPath = h:GetUserId(id)
        iup.SetAttributeId(h, "DELNODE", id, "SELECTED")
        drag_id = id
        return true
    end
    local function dragend_cb(h, action)
        if drag_id then
            iup.SetAttributeId(h,"ADDLEAF", drag_id - 1, dragName)
            id = iup.GetAttribute(h, 'LASTADDNODE')
            h:SetUserId(id, dragPath)
        end
    end

    local function showrename_cb(h, id)
        if iup.GetAttributeId(h, "KIND", id) == "BRANCH" and not h:GetUserId(id) then return true end
        return -1
    end

    local function rightclick_cb(h, id)
        local sAct = 'NO'
        if tonumber(iup.GetAttribute(h, "COUNT")) > 2 and iup.GetAttributeId(h, "KIND", id) == "BRANCH"
           and iup.GetAttributeId(h, "CHILDCOUNT", id) == '0' then sAct = 'YES' end
        iup.menu
        {
            iup.item{title="Add Tab", action=function()
                iup.SetAttributeId(h, "ADDBRANCH", 0, "<New Tab>")
            end};
            iup.item{title="Remove Tab", active = sAct, action=function()
                iup.SetAttributeId(h, "DELNODE", id, "SELECTED")
            end};
        }:popup(iup.MOUSEPOS,iup.MOUSEPOS)
    end

    local function dragdrop_cb(h,drag_id, drop_id, isshift, iscontrol)
        if iscontrol == 1 then return -1 end
        if tonumber(iup.GetAttributeId(h, "DEPTH", drop_id)) > 1 or
           (tonumber(iup.GetAttributeId(h, "DEPTH", drop_id)) == 1
            and (iup.GetAttributeId(h, "STATE", drop_id) or 'EXPANDED') == 'EXPANDED') then iup.SetAttributeId(h, "STATE", drop_id, 'COLLAPSED'); return -1 end
        return -4
    end

    tree_plugins.dragbegin_cb = dragbegin_cb
    tree_plugins.dragend_cb = dragend_cb


    tree_right = iup.tree{size = '120x', showrename = 'YES',
        droptarget ='YES', droptypes = "XXXXX", dragsource ='YES',dragtypes = "XXXXX", showdragdrop = 'YES'}

    tree_left = iup.tree{size = '120x', showrename = 'YES',
        droptarget ='YES', droptypes = "XXXXX", dragsource ='YES',dragtypes = "XXXXX", showdragdrop = 'YES'}

    tree_right.dropdata_cb = dropdata_cb
    tree_left.dropdata_cb = dropdata_cb
    tree_plugins.dropdata_cb = dropdata_cb


    tree_right.dragdrop_cb = dragdrop_cb
    tree_left.dragdrop_cb = dragdrop_cb

    tree_right.rightclick_cb = rightclick_cb
    tree_left.rightclick_cb = rightclick_cb

    tree_right.showrename_cb = showrename_cb
    tree_left.showrename_cb = showrename_cb

    tree_right.dragbegin_cb = dragbegin_cb
    tree_left.dragbegin_cb = dragbegin_cb

    tree_right.dragdatasize_cb = function(ih, typ)  return 1 end
    tree_right.dragdata_cb = function(ih, typ) return true end
    tree_left.dragdatasize_cb = function(ih, typ)  return 1 end
    tree_left.dragdata_cb = function(ih, typ) return true end


    local vbox = iup.vbox{
        iup.hbox{tree_left, iup.vbox{tree_plugins},tree_right};
        iup.hbox{btn_ok},
        expandchildren ='YES',gap=2,margin="4x4"}
    dlg = iup.scitedialog{vbox; title="��������� ���������������� ������ ������������",defaultenter="TOOLBARSETT_BTN_OK",defaultesc="LEX_BTN_ESC",tabsize=editor.TabWidth,
        maxbox="NO",minbox ="NO",resize ="YES",shrink ="YES",sciteparent="SCITE", sciteid="LexersSetup", minsize='x400'}


    dlg.show_cb=(function(h,state)
        if state == 4 then
            dlg:postdestroy()
        end
    end)

    iup.SetAttributeId(tree_left,"ADDBRANCH", 0, "<New Tab>")
    iup.SetAttributeId(tree_right,"ADDBRANCH", 0, "<New Tab>")

    tree_left:SetUserId(0, '')
    tree_right:SetUserId(0, '')

    local table_dir = shell.findfiles(defpath..'*.lua')

    local j = 0
    local function RestoreTree(h, str)
        if str == '' then return end
        iup.SetAttributeId(h, "DELNODE", 1, "SELECTED")
        local k = 0
        local lastBr
        for p in str:gmatch('[^�]+') do
            local _,_, pname, pf = p:find('(.-)(�?)$')
            if pf ~= '' then
                if lastBr then
                    iup.SetAttributeId(h, "INSERTBRANCH", lastBr, pname)
                else
                    iup.SetAttributeId(h, "ADDBRANCH", k, pname)
                end
                k = k + 1
                lastBr = k
            else
                local bFound = false
                for i = 1, #table_dir do
                    if table_dir[i].name == pname then
                        table.remove(table_dir, i)
                        bFound = true
                        break
                    end
                end
                if bFound then
                    local pI = dofile(props["SciteDefaultHome"].."\\tools\\UIPlugins\\"..pname)
                    iup.SetAttributeId(h, "ADDLEAF", k, pI.title)
                    k = k + 1
                    h:SetUserId(k, pname)
                end
            end
        end
    end

    RestoreTree(tree_right, _G.iuprops["settings.user.rightbar"] or '')
    RestoreTree(tree_left, _G.iuprops["settings.user.leftbar"] or '')

    for i = 1, #table_dir do
        local pI = dofile(defpath..table_dir[i].name)
        if pI and pI.sidebar then
            iup.SetAttributeId(tree_plugins, "ADDLEAF", j, pI.title)
            j = j + 1
            tree_plugins:SetUserId(j, table_dir[i].name)
        end
    end

end

Show()
