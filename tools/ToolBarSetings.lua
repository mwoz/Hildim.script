--[[ƒиалог редактировани€ гор€чих клавиш]]
require "menuhandler"
local tblView = {}, tblUsers
local defpath = props["SciteDefaultHome"].."\\data\\home\\userMenuBars.lua"

local function viewMenu(tMnu, tView, path)
    local tN, tSub
    for i,t in ipairs(tMnu) do
        tN = {}
        local tui = {}
        if not t.link then
            if t[2] == nil then
                tN.leafname = menuhandler:get_title(t, true)
                if t.separator then
                    tN.leafname = '-----------'
                    tui.separator = true
                else
                    tui.path = path..'¶'..t[1]
                    local keyStr
                    if t.key then
                        tui.default = t.key
                        keyStr = t.key
                    end
                    if tblUsers and tblUsers[tui.path] then
                        tN.color = "92 92 255"
                        tui.user = tblUsers[tui.path]
                        keyStr = tblUsers[tui.path]
                    end
                    if keyStr then tN.leafname = tN.leafname..'  Л'..keyStr..'Ы' end
                    if t.image then tN.image = t.image; tui.image = t.image; end
                    tui.title = menuhandler:get_title(t, true)
                end
            elseif type(t[2]) == 'table' then
                --tSub = {}
                tN = {}
                tN.branchname = menuhandler:get_title(t, true)
                viewMenu(t[2], tN, path..'¶'..t[1])
            end
        end
        tN.userid = tui
        table.insert(tView, tN)
    end
end

local function Show()

    local list_lex, dlg, bBlockReset, tree_btns
    local btn_ok = iup.button  {title="OK"}
    local btn_esc = iup.button  {title="Cancel"}
    iup.SetHandle("TOOLBARSETT_BTN_OK",btn_ok)
    iup.SetHandle("TOOLBARSETT_BTN_ESC",btn_esc)
    btn_esc.action = function()
        dlg:hide()
        dlg:postdestroy()
    end

    local tree_hk = iup.text{size='100x'}

    btn_ok.action = function()
        local str = ''
        for i = 1,  iup.GetAttribute(tree_btns, "TOTALCHILDCOUNT0") do
            local p = tree_btns:GetUserId(i) or '---'
            if str ~= '' then str = str..'З' end
            str = str..p
        end
        _G.iuprops["settings.user.toolbar"] = str
        dlg:hide()
        dlg:postdestroy()
    end

    tree_hk = iup.tree{minsize = '0x5', size=_G.iuprops["sidebar.functions.tree_sol.size"],
        dragsource ='YES',dragtypes = "YYYYYYY",  }

    local drag_id
    tree_hk.dragbegin_cb = function(h, x, y)
        drag_id = iup.ConvertXYToPos(h, x, y)
        if iup.GetAttributeId(tree_hk, 'KIND', drag_id) == 'BRANCH' then return -1 end
        local tui = tree_hk:GetUserId(drag_id)
        if not tui or tui.added then return -1 end
        return true
    end

    tree_hk.dragdatasize_cb = function(ih, typ)  return 1 end
    tree_hk.dragdata_cb = function(ih, typ) return true end

    tree_btns = iup.tree{minsize = '0x5', size=_G.iuprops["sidebar.functions.tree_sol.size"],
        droptarget ='YES', droptypes = "YYYYYYY", dragsource ='YES',dragtypes = "YYYYYYY", showdragdrop = 'YES'}

    tree_btns.dropdata_cb = function(h, typ, data, size, x, y)
        local id = iup.ConvertXYToPos(h, x, y)
        if id < 0 then id = 0 end
        iup.SetAttributeId(h,"ADDLEAF", id, iup.GetAttributeId(tree_hk, 'TITLE', drag_id))
        id = iup.GetAttribute(h, 'LASTADDNODE')
        local tui = tree_hk:GetUserId(drag_id)
        iup.SetAttributeId(h,"IMAGE", id, tui.image)
        if not tui.separator then
            h:SetUserId(id, tui.path)
            iup.SetAttributeId(tree_hk, 'COLOR', drag_id, '92 92 255')
            tui.added = true
            tree_hk:GetUserId(drag_id, tui)
        end
        return true
    end


    tree_btns.dragbegin_cb = function(h, x, y)
        local id = iup.ConvertXYToPos(h, x, y)
        if not h:GetUserId(id) then return -1 end
        for i = 1,  iup.GetAttribute(tree_hk, "TOTALCHILDCOUNT0") do
            local tui = tree_hk:GetUserId(i)
            if tui and h:GetUserId(id) == tui.path then
                drag_id = i
                iup.SetAttributeId(tree_hk, 'COLOR', drag_id, '0 0 0')
                tui.added = false
                tree_hk:GetUserId(drag_id, tui)
                iup.SetAttributeId(h, "DELNODE", id, "SELECTED")
                return true
            end
        end
        return -1
    end

    tree_btns.dragdatasize_cb = function(ih, typ)  return 1 end
    tree_btns.dragdata_cb = function(ih, typ) return true end

    local vbox = iup.vbox{
        iup.hbox{iup.vbox{tree_hk},tree_btns};
        iup.hbox{btn_ok, iup.fill{}, btn_esc},
        expandchildren ='YES',gap=2,margin="4x4"}
    dlg = iup.scitedialog{vbox; title="Ќастройка пользовательской панели инструментов",defaultenter="TOOLBARSETT_BTN_OK",defaultesc="TOOLBARSETT_BTN_ESC",tabsize=editor.TabWidth,
        maxbox="NO",minbox ="NO",resize ="YES",shrink ="YES",sciteparent="SCITE", sciteid="LexersSetup", minsize='300x600'}

    dlg.show_cb=(function(h,state)
        if state == 4 then
            dlg:postdestroy()
        end
    end)
    if shell.fileexists(defpath) then tblUsers = assert(loadfile(defpath))() end
    tblView.branchname = 'Menus'
    --viewMenu(sys_Menus.MainWindowMenu, tblView, 'MainWindowMenu')

    for ups,submnu in pairs(sys_Menus) do
        local tb = {}
        tb.branchname = ups
        table.insert(tblView, 0, tb)
        viewMenu(submnu, tb, ups)
    end

    iup.TreeAddNodes(tree_hk, tblView)

    local str = _G.iuprops["settings.user.toolbar"] or ''
    local id = 0
    for p in str:gmatch('[^З]*') do
        if p == '---' then
            iup.SetAttributeId(tree_btns,"ADDLEAF", id, '-----------')
            id = iup.GetAttribute(tree_btns, 'LASTADDNODE')
        else
            for i = 1,  iup.GetAttribute(tree_hk, "TOTALCHILDCOUNT0") do
                local tui = tree_hk:GetUserId(i)
                if tui and tui.path == p then
                    iup.SetAttributeId(tree_hk, 'COLOR', i, '92 92 255')
                    tui.added = true
                    tree_hk:SetUserId(i, tui)


                    iup.SetAttributeId(tree_btns,"ADDLEAF", id, iup.GetAttributeId(tree_hk, 'TITLE', i))
                    id = iup.GetAttribute(tree_btns, 'LASTADDNODE')
                    iup.SetAttributeId(tree_btns,"IMAGE", id, tui.image)

                    tree_btns:SetUserId(id, tui.path)

                    break
                end
            end
        end
    end

end

Show()
