
----------------------------------------------------------
-- tab0:memo_mask   Path and Mask
----------------------------------------------------------
local current_path = ''
local file_mask = ''
local list_favorites
local memo_mask
local memo_path
local list_dir
local split_s
local bymemokey=0
local sort_by_tyme = _G.iuprops['sidebar.fileman.timesort']
local chkByTime
local bListOpened = false
local m_prevSel = 0
local _Plugins
local zPath, zMemo
local bIsRenamed

local function ReplaceWithoutCase(text, s_find, s_rep)
	local i, j = 1
	local replaced = nil
	repeat
		i, j = text:lower():find(s_find:lower(), j, true)
		if j == nil then return text, replaced end
		text = text:sub(1, i-1)..s_rep..text:sub(j+1)
		replaced = true
	until false
end

FILEMAN = {}

function GetExtImage(strName)
    local _, _, ext = strName:find('%.([^%.]+)$')
    if ext=='inc' or ext=='incl' then return 'IMAGE_Library'
    elseif ext=='xml' or ext=='form' then return 'IMAGE_Frame'
    elseif ext=='m' then return 'IMAGE_Sub'
    elseif ext=='sql' then return 'IMAGE_String'
    elseif ext=='lua' then return 'IMGLEAF'
    else return 'IMGPAPER'
    end
end

local function getListDir()
    return list_dir
end

function FILEMAN.FullPath()
    local ld = getListDir()
    if not ld or not ld.marked then return '' end
    local lin = ld.marked:sub(2):find("1")
    return (current_path..ld:getcell(lin, 2)):gsub('\\%.%.', '')
end

function FILEMAN.RelativePath(sep)
    local lin = list_dir.marked:sub(2):find("1")
    local fName = list_dir:getcell(lin, 2)
    local sRet = CORE.RelativePath(current_path)..fName
    if sep and type(sep) == 'string' then sRet = sRet:gsub('\\', sep) end
    return sRet
end
----------------------------------------------------------
-- tab0:list_dir   File Manager
----------------------------------------------------------
local FileMan_ListFILL
local function FileMan_ListFILLByMask(strMask)
    file_mask = strMask
    FileMan_ListFILL()
end

FileMan_ListFILL = function(blockUpdate)
    memo_path.value = current_path
    if current_path == '' then return end

    local table_dir = shell.findfiles(current_path..'*')
    if not table_dir then return end
    table.sort(table_dir, function(a, b)
        if a.isdirectory ~= b.isdirectory then return a.isdirectory end
        if a.isdirectory or not sort_by_tyme then
            return a.name:lower() < b.name:lower()
        else
            return a.writetime > b.writetime
        end
    end)

    local maskVal = (file_mask..'*'):gsub('%.', '%%.'):gsub('%*', '.*'):lower()
    maskVal = '^'..maskVal..'$'
    local j = 0

    for i = 1, #table_dir do
        if (not table_dir[i].isdirectory) and (not table_dir[i].name:lower():find(maskVal) or (table_dir[i].attributes & 2) == 2) then
            j = j + 1
        end
    end

    iup.SetAttribute(list_dir, "DELLIN", "1-"..list_dir.numlin)
    iup.SetAttribute(list_dir, "ADDLIN", "1-"..(#table_dir - 1 - j))
    local prevL = #table_dir - 1 - j
    list_dir:setcell(1, 1, 'IMAGE_UpFolder')
    list_dir:setcell(1, 2, '..')
    list_dir:setcell(1, 3, 0)
    list_dir:setcell(1, 4, 'd')
    local j = 2
    local dc = 0

    for i = 1, #table_dir do
        if table_dir[i].isdirectory then
            dc = dc + 1
            local n, a = table_dir[i].name, table_dir[i].attributes
            if file_mask == '' and n ~= "." and n ~= ".." and not n:find('^%$') and (a & 2) == 0 and (a & 4) == 0 then
                list_dir:setcell(j, 1, 'IMAGE_Folder')
                list_dir:setcell(j, 2, n)
                list_dir:setcell(j, 3, a)
                list_dir:setcell(j, 4, 'd')
                j = j + 1
            end
        else
            if table_dir[i].name:lower():find(maskVal) and (table_dir[i].attributes & 2) ~= 2 then
                list_dir:setcell(j, 1, GetExtImage(table_dir[i].name))
                list_dir:setcell(j, 2, table_dir[i].name:to_utf8())
                list_dir:setcell(j, 3, table_dir[i].attributes)
                list_dir:setcell(j, 4, '')
                if (table_dir[i].attributes & 1) == 1 then
                    iup.SetAttributeId2(list_dir, 'FGCOLOR', j, 2, '100 100 100')
                end
                j = j + 1
            end
        end
    end
    list_dir.numlin_noscroll = 1
    if j < prevL + 1 and (file_mask ~= '') then iup.SetAttribute(list_dir, 'DELLIN', (j)..'-'..prevL) end
    local d = Iif(file_mask == '', dc, 2)
    list_dir.focus_cell = d..":1"
    iup.SetAttributeId2(list_dir, 'MARK', d, 0, '1')
    if not blockUpdate then list_dir.redraw = "ALL" end
end

local function FileMan_ToggleSort()
    sort_by_tyme = not sort_by_tyme
    _G.iuprops['sidebar.fileman.timesort'] = sort_by_tyme
    FileMan_ListFILL()
end

local function FileMan_ListFillDir(strPath)
    current_path = strPath:match('(.*\\)')
    if current_path == nil then current_path = '' end
    local table_folders = shell.findfiles(strPath..'*')
    if not table_folders then
        iup.SetAttribute(list_dir, "DELLIN", "1-"..list_dir.numlin)
        return  strPath:len()-(strPath:find('[:%$]') or strPath:len())>0
    end


    table.sort(table_folders, function(a, b) return a.name:lower() < b.name:lower() end)

    iup.SetAttribute(list_dir, "DELLIN", "1-"..list_dir.numlin)
    iup.SetAttribute(list_dir, "ADDLIN", "1-"..#table_folders)

    local j = 1
    for i = 1, #table_folders do
        local a = table_folders[i].attributes
        if table_folders[i].isdirectory and (a & 2) == 0 and (a & 4) == 0 and not table_folders[i].name:find('^%$') then
            list_dir:setcell(j, 1, 'IMAGE_Folder')
            list_dir:setcell(j, 2, table_folders[i].name:to_utf8())
            list_dir:setcell(j, 3, a)
            list_dir:setcell(j, 4, 'd')
            j = j + 1
        end
    end
    if j< #table_folders+1 then iup.SetAttribute(list_dir, "DELLIN", (j).."-"..#table_folders) end
    iup.SetAttribute(list_dir, 'MARK1:0', 1)
    list_dir.focus_cell = "1:1"
    list_dir.redraw = "ALL"
end

local function FileMan_GetSelectedItem(idx)
    local l = list_getvaluenum(list_dir)
    if idx == nil then idx = l end
	if idx == -1 then return '' end
	return list_dir:getcell(idx, 2), list_dir:getcell(idx, 4), tonumber(list_dir:getcell(idx, 3)), idx
end

function FILEMAN.Directory(bFavorit)
    if bFavorit then
        local idx = list_getvaluenum(list_favorites)
        if idx == null then return nil end
        local path = list_favorites:getcell(idx , 3)
        if path:gsub('.+\\', '') ~= '' then return nil end
        return path
    else
        if not list_dir.marked then return false end
        local lin = list_dir.marked:sub(2):find("1")
        return Iif((list_dir:getcell(lin, 4) or '') == 'd', current_path..FileMan_GetSelectedItem()..'\\', nil)
    end
end

local function FileMan_ChangeDir()
    local d = iup.filedlg{dialogtype='DIR',  parentdialog='SCITE'}
    d:popup()
    local newPath = d.value
    d:destroy()

	if newPath == nil then return end
	if newPath:match('[\\/]$') then
		current_path = newPath
	else
		current_path = newPath..'\\'
	end
	FileMan_ListFILL()
end


local function FileMan_FileExecWithSciTE(cmd, mode)
	local p0 = props["command.0.*"]
	local p1 = props["command.mode.0.*"]
	props["command.name.0.*"] = 'tmp'
	props["command.0.*"] = cmd
	if mode == nil then mode = 'console' end
	props["command.mode.0.*"] = 'subsystem:'..mode..',savebefore:no'
	scite.MenuCommand(9000)
	props["command.0.*"] = p0
	props["command.mode.0.*"] = p1
end

local function FileMan_FileExec(params)
	if params == nil then params = '' end
	local filename = FileMan_GetSelectedItem()
	if filename == '' then return end
	local file_ext = filename:match("[^.]+$")
	if file_ext == nil then return end
	file_ext = '%*%.'..string.lower(file_ext)

	local function CommandBuild(lng)
		local cmd = props['command.build.$(file.patterns.'..lng..')']
		cmd = cmd:gsub(props["FilePath"], current_path..filename)
		return cmd
	end
	-- Lua
	if string.match(props['file.patterns.lua'], file_ext.."$") then
		dofile(current_path..filename)
	-- Batch
	elseif string.match(props['file.patterns.batch'], file_ext.."$") then
		FileMan_FileExecWithSciTE(CommandBuild('batch'))
		return
	-- WSH
	elseif string.match(props['file.patterns.wscript']..props['file.patterns.wsh'], file_ext.."$") then
		FileMan_FileExecWithSciTE(CommandBuild('wscript'))
	-- Other
	else
		local ret, descr = shell.exec(current_path..filename..params)
		if not ret then
			print (">Exec: "..filename)
			print ("Error: "..descr)
		end
	end
end

local function FileMan_FileExecWithParams()
	if scite.ShowParametersDialog('Exec "'..FileMan_GetSelectedItem()..'". Please set params:') then
		local params = ''
		for p = 1, 4 do
			local ps = props[tostring(p)]
			if ps ~= '' then
				params = params..' '..ps
			end
		end
		FileMan_FileExec(params)
	end
end

local function mybar_Switch(n)
    _Plugins.fileman.Bar_obj.TabCtrl.valuepos = n -1
    for _,tbs in pairs(_Plugins) do
        if tbs.tabs_OnSelect and _Plugins.fileman.Bar_obj.TabCtrl.value_handle.tabtitle == tbs.id then tbs.tabs_OnSelect() end
    end
end

local function OpenFile(filename)
    scite.Open(filename)
    if iup.GetGlobal("SHIFTKEY") == 'OFF' then
        if (_G.iuprops['sidebarfileman.restoretab'] or 'OFF') == 'ON' then scite.RunAsync(function() mybar_Switch(m_prevSel + 1) end)
        elseif (_G.iuprops['sidebarfileman.restoretab'] or 'OFF') == '1' then scite.RunAsync(function()  mybar_Switch(1) end)
        end
    else
        CORE.ScipHidePannel()
    end
    iup.PassFocus()
end
local prev_filename = ''
local function FileMan_OpenItem()
	local dir_or_file, attr = FileMan_GetSelectedItem()
	if dir_or_file == '' then return end
    if attr == 'd' then
		if dir_or_file == '..' then
			local new_path = current_path:gsub('(.*\\).*\\$', '%1')
			current_path = new_path
		else
			current_path = current_path..dir_or_file..'\\'
		end
        if zMemo.valuepos == '0' then memo_mask.value = '' end
		FileMan_ListFILLByMask(memo_mask.value)
	else
        local _,_,ext = dir_or_file:find('%.([^%.]*)$')
        ext = (ext or ''):lower()
        if string.find('.exe.lnk.doc.docx.xls.xlsx.pdf.chm.', '%.'..ext..'%.') then
            FileMan_FileExec()
            return
        end
        prev_filename = current_path..dir_or_file
		OpenFile(prev_filename)
	end
end

local function FileMan_OpenSelectedItems()
	local si = list_getvaluenum(list_dir)
    local dir_or_file, attr = FileMan_GetSelectedItem(si)
    if attr ~= 'd' then
        OpenFile(current_path..dir_or_file)
    end
end
----------------------------------------------------------
-- tab0:list_favorites   Favorites
---------------------------------------------------------- ,
local list_fav_table = {}

local prevFileName = ''
local function Favorites_ListFILL_l(bReset)
    if not bReset and (prevFileName == props['FilePath']) then return end
    prevFileName = props['FilePath']
    local function getName(s)
		local fname = s[1]:gsub('.+\\','')
		if fname == '' then fname = s[1]:gsub('.+\\(.-)\\','%1') end
        return fname
    end
    local function getIcon(s)
		local fname = s:gsub('.+\\','')
		if fname == '' then
            return 'IMAGE_Folder'
        end
        return GetExtImage(s)
    end

    iup.SetAttribute(list_favorites, "DELLIN", "1-"..list_favorites.numlin)
	table.sort(list_fav_table,
		function(a, b)

			local isAses = a[2]
			local isBses = b[2]
			if (isAses and isBses) or not (isAses or isBses) then
				return getName(a):lower() < getName(b):lower()
			else
				return isBses
			end
		end
	)
    iup.SetAttribute(list_favorites, "ADDLIN", "1-"..#list_fav_table)
	for i, s in ipairs(list_fav_table) do
        list_favorites:setcell(i, 1, getIcon(s[1]))
        list_favorites:setcell(i, 2, s.alias)
        list_favorites:setcell(i, 3, s[1])
    end
    list_favorites.redraw = "ALL"
end

local function Favorites_OpenList()
    list_fav_table = {}
    local tblIn = _G.iuprops['FileMan.Favorits'] or {}
    for i = 1,  #tblIn do
        table.insert(list_fav_table, {ReplaceWithoutCase(tblIn[i][1], '$(SciteDefaultHome)', props['SciteDefaultHome']), false, alias = tblIn[i].alias})
    end
    bListOpened = true
end


local function Favorites_SaveList()
	if bListOpened then
        local tOut = {}
        for i = 1, #list_fav_table do
            table.insert(tOut, {ReplaceWithoutCase(list_fav_table[i][1], props['SciteDefaultHome'], '$(SciteDefaultHome)'), alias = list_fav_table[i].alias})
        end
        _G.iuprops['FileMan.Favorits'] = tOut
	end
end

local function Favorites_AddFile()
	local fname, attr = FileMan_GetSelectedItem()
	if fname == '' then return end
	fname = current_path..fname
	if attr == 'd' then
		fname = fname:gsub('\\%.%.$', '')..'\\'
	end
    table.insert(list_fav_table, {fname, false, alias = fname:gsub('^.-([^\\]+)\\?$', '%1')})
	Favorites_ListFILL_l(true)
	Favorites_SaveList()
end

local function FileMan_ChangeReadOnly()
    local fname, d, attr = FileMan_GetSelectedItem()
	if fname == '' then return end
	fname = current_path..fname
    l = list_getvaluenum(list_dir)
    if (attr & 1) == 1 then
        attr = attr - 1
    else
        attr = attr + 1
    end
    shell.setfileattr(fname, attr)
    attr = shell.getfileattr(fname)
    list_dir:setcell(l, 3, attr)
    if (attr & 1) == 1 then
        iup.SetAttributeId2(list_dir, 'FGCOLOR', l, 2, '100 100 100')
    else
        iup.SetAttributeId2(list_dir, 'FGCOLOR', l, 2, '0 0 0')
    end
end

local function FileMan_Delete()
    local fname, d, attr = FileMan_GetSelectedItem()
	if fname == '' or d == 'd' then return end
	fname = current_path..fname
    local msb = iup.Alarm(_T"Delete File", _T'Do You really want to delete the selected file\n'..fname..'?', _TH'Yes', _TH'No')
    if msb == 1 then
        local lRes = shell.delete_file(fname)
        --local lRes = shell.rename_file(fname, current_path..'aa')
        if lRes == 0 then
            FileMan_ListFILL()
        else
            print('File '..fname..' not deleted!')
        end
    end
end

local prevName
local function FileMan_CheckRename(c,lin, col, mode, update)
    if mode == 1 then
        if prevName == nil then return -1 end
    end
end

local function FileMan_DoRename(c, lin, col)
    local fname, d, attr, idx = FileMan_GetSelectedItem()
    if fname ~= prevName then
        if bIsRenamed then
            list_dir:setcell(idx, 2, prevName)
        else
            local lRes = shell.rename_file(current_path..prevName, current_path..fname)
            if lRes ~= 0 then
                FileMan_ListFILL()
                print('File '..prevName..' not renamed!')
            end
            list_dir.focus_cell = (idx - 1)..":1"
            if prevName == props['FileNameExt'] then
                OnSwitchFile(props['FileNamePath'])
            end
        end
    end
    bIsRenamed = nil
    prevName = nil
end

local function FileMan_Rename()
    local fname, d, attr = FileMan_GetSelectedItem()
    prevName = fname
    local l = list_getvaluenum(list_dir)
	if fname == '' or d == 'd' then return end

    CORE.ScipHidePannel()
    list_dir.focus_cell = l..":2"
    iup.SetAttribute(list_dir, 'READONLY', 'NO')
    bIsRenamed = true
    iup.SetAttribute(list_dir, 'EDIT_MODE', 'YES')
end

local function Favorits_DoRename(c, lin, col)
    list_fav_table[lin].alias = list_favorites:getcell(lin, col)
    Favorites_SaveList()
end

local bRenameFavor = false
local function Favorites_Rename()
    local l = list_getvaluenum(list_favorites)

    list_favorites.focus_cell = l..":2"
    bRenameFavor = true
    iup.SetAttribute(list_favorites, 'EDIT_MODE', 'YES')
end

local function Favorites_AddCurrentBuffer()
	table.insert(list_fav_table, {props['FilePath'], false, alias = props['FilePath']:gsub('^.-([^\\]+)\\?$', '%1')})
	Favorites_ListFILL_l(true)
    Favorites_SaveList()
end

local function Favorites_AddFileName_l(fName) --для добавления из других библиотек
    table.insert(list_fav_table, {fName, true, alias = fName:gsub('^.-([^\\]+)\\?$', '%1')})
end

local function Favorites_Clear_l()
    if _Plugins.fileman.Bar_obj.Active  ~= true then return end
    for i = #list_fav_table,1,-1 do
        if list_fav_table[i][2] then table.remove(list_fav_table,i) end
    end
	Favorites_ListFILL_l(true)
end

local function Favorites_DeleteItem()
	local idx = list_getvaluenum(list_favorites)
    local pth = list_favorites:getcell(idx, 3)
	if idx == nil then return end
	iup.SetAttribute(list_favorites, "DELLIN", idx)
    for i = 1,  #list_fav_table do
        if list_fav_table[i][1] == pth then
            table.remove (list_fav_table, i)
            break
        end
    end

	Favorites_SaveList()
end

local function Favorites_OpenFile()
	local idx = list_getvaluenum(list_favorites)
	if idx == null then return end
	local fname = list_favorites:getcell(idx,3)
        prev_filename = fname
	if fname:match('\\$') then
		current_path = fname
		FileMan_ListFILL()
	else
		OpenFile(fname)
	end
end

function FILEMAN.OpenFolder(fname)
    local itab
    local h = _Plugins.fileman.Bar_obj.TabCtrl
    for i = 0, h.count do
        if iup.GetAttributeId(h, 'TABTITLE', i) == _Plugins.fileman.id then
            mybar_Switch(i + 1)
            current_path = fname
            FileMan_ListFILL()
            return
        end
    end
end

local function ensureVisible()
    local sel = 1
    if list_dir.marked then sel = list_dir.marked:find('1') end
    sel = sel - 1
    for i = 0, list_dir.count - 1 do
        if list_dir:getcell(i, 2) ~= nil and list_dir:getcell(i, 2):upper() == props['FileNameExt']:upper() then
            iup.SetAttributeId2(list_dir, 'MARK', sel, 0, 0)
            iup.SetAttributeId2(list_dir, 'MARK', i, 0, 1)
            list_dir.focus_cell = i..":1"
            list_dir.redraw = "ALL"
            iup.SetAttribute(list_dir, 'SHOW', i..":1")
        end
    end
end

local function OnSwitch(bForse, bRelist)
    if zPath.valuepos == '1' or bIsRenamed then return end
    if prev_filename:upper() == props['FilePath']:upper() then return end
    prev_filename = ''
    if true or bForse or (_Plugins.fileman.Bar_obj.TabCtrl.value_handle.tabtitle == _Plugins.fileman.id) then
        if bForse then iup.SetFocus(memo_mask) end
        local path = props['FileDir']
        if path == '' then path = _G.iuprops['sidebarfileman.restoretab'] end
        if path ~= '' then
            current_path = path:gsub('\\$', '')..'\\'
            -- print(current_path, current_path)
            -- if bClearMask then memo_mask:set_text = "" end
            --print(debug.traceback())
            if zPath.valuepos == '0' then FileMan_ListFILL(true) end
            ensureVisible()
            list_dir.redraw = "ALL"
        end
    end
    if bRelist then
        Favorites_OpenList()
        Favorites_ListFILL_l()
    end
end

local function memoNav(h, key)
    local deltaUpDown = Iif(h == list_dir, 0, 1)
    if key == iup.K_DOWN then --down
        local sel = 1
        if list_dir.marked then sel = list_dir.marked:find('1') end
        sel = sel - 1
        if sel < list_dir.count - 1 then
            iup.SetAttribute(list_dir, 'MARK'..(sel)..':0', 0)
            iup.SetAttribute(list_dir, 'MARK'..(sel + 1)..':0', 1)
            list_dir.focus_cell = (sel + deltaUpDown)..":1"
            list_dir.show = (sel + 2)..':*'
            list_dir.redraw = "ALL"
        end
        return - 1
    elseif key == iup.K_UP then --up
        local sel = list_dir.marked:find('1')
        if sel == nil then sel = list_dir.count + 2 end
        sel = sel - 1
        if sel > 1 then
            iup.SetAttribute(list_dir, 'MARK'..(sel)..':0', 0)
            iup.SetAttribute(list_dir, 'MARK'..(sel - 1)..':0', 1)
            list_dir.focus_cell = (sel - deltaUpDown)..":1"
            list_dir.show = (sel - 2)..':*'
            list_dir.redraw = "ALL"
        end
        return - 1
    elseif (key == iup.K_HOME and deltaUpDown == 0) or iup.XkeyCtrl(iup.K_HOME) == key then --up
        local sel = list_dir.marked:find('1')
        if sel ~= nil then iup.SetAttribute(list_dir, 'MARK'..(sel - 1)..':0', 0) end
        sel = 2
        iup.SetAttribute(list_dir, 'MARK'..(sel)..':0', 1)
        list_dir.focus_cell = (sel)..":1"
        list_dir.redraw = "ALL"
        list_dir.show = (sel)..':*'
        return - 1
    elseif (key == iup.K_END and deltaUpDown == 0) or iup.XkeyCtrl(iup.K_END)==key then --up
        local sel = list_dir.marked:find('1')
        if sel ~= nil then iup.SetAttribute(list_dir, 'MARK'..(sel - 1)..':0', 0) end
        sel = list_dir.count - 1
        iup.SetAttribute(list_dir, 'MARK'..(sel)..':0', 1)
        list_dir.focus_cell = (sel)..":1"
        list_dir.show = (sel)..':*'
        list_dir.redraw = "ALL"
        return - 1
    elseif key == iup.K_CR then
        if not bIsRenamed and (memo_path.value:find('^%w:[\\/]') or memo_path.value:find('[\\/][\\/]%w+[\\/]%w%$[\\/]')) then
            current_path = memo_path.value:gsub('[\\/][^\\/]*$', '')..'\\'
            FileMan_OpenItem()
            memo_path.caretpos = memo_path.count
        elseif bIsRenamed then
            bIsRenamed = nil
        end
    elseif key == iup.K_ESC then --escape
        iup.PassFocus()
        FileMan_ListFILLByMask(memo_mask.value)
    end
end

local function GetReadOnly()
    if not list_dir.marked then return false end
    local lin = list_dir.marked:sub(2):find("1")
    return (tonumber(list_dir:getcell(lin, 3) or 0) & 1) == 1
end

local function FileManTab_Init(h)
    _Plugins = h
    Favorites_AddFileName = Favorites_AddFileName_l
    Favorites_ListFILL = Favorites_ListFILL_l
    Favorites_Clear = Favorites_Clear_l

    list_dir = iup.matrix{
        numcol = 4, numcol_visible = 2, cursor = "ARROW", alignment = 'ALEFT', heightdef = 6, markmode = 'LIN', flatscrollbar = "YES" ,
        readonly = "NO"  , markmultiple = "NO" , height0 = 4, expand = "YES", framecolor = "255 255 255",
    width0 = 0 , rasterwidth1 = 18, rasterwidth2 = 450, rasterwidth3 = 0, rasterwidth4 = 0}

    list_dir.map_cb = (function(h)
        h.size = "1x1"
    end)
    --list_dir.
    --list_dir.hlcolor = ""

    list_dir:setcell(0, 2, _T"Name")
  	list_dir.click_cb = (function(h, lin, col, status)
        local sel = 0
        if h.marked then sel = h.marked:find('1') - 1 end
        iup.SetAttribute(h, 'MARK'..sel..':0', 0)
        iup.SetAttribute(h, 'MARK'..lin..':0', 1)
        local l = (tonumber(list_dir:getcell(lin, 3) or 0) & 1)
        h.redraw = lin..'*'
        if iup.isdouble(status) and iup.isbutton1(status) then
            if memo_path.value:find('^%w:[\\/]') or memo_path.value:find('^[\\/][\\/]%w+') then
                if list_dir:getcell(1, 2) ~= '..' then
                    current_path = memo_path.value:gsub('[\\/][^\\/]*$', '')..'\\'
                end
                FileMan_OpenItem()
            else
                OnSwitch(false, false)
            end
            return - 1
        elseif iup.isbutton3(status) then
            CORE.ScipHidePannel()
            h.focus_cell = lin..':'..col
            menuhandler:PopUp('MainWindowMenu|_HIDDEN_|Fileman_sidebar')
        end
    end)

    menuhandler:InsertItem('MainWindowMenu', '_HIDDEN_|s1',
        {'Fileman_sidebar', plane = 1,{
            {"Change Dir", action = FileMan_ChangeDir},
            {"Add to Favorites", action = Favorites_AddFile},
            {'s_AddtoFavorites', separator = 1},
            {"", plane = 1, visible = function() local _, d = FileMan_GetSelectedItem(); return d~= 'd' end, {
                {"Delete", action = FileMan_Delete},
                {"Rename", action = FileMan_Rename},
                {'s_OpenwithHildiM', separator = 1},
                {"Open with HildiM", action = FileMan_OpenSelectedItems},
                {"Open in another View", action = function() FileMan_OpenSelectedItems(); CORE.ChangeTab() end},
                {_TM"Open in New HildiM Instance", action = function() CORE.OpenNewInstance(current_path..FileMan_GetSelectedItem()) end},
                {"Execute", action =(function() FileMan_FileExec(nil) end)},
                {'s_ReadOnly', separator = 1},
                {"Read Only", action = FileMan_ChangeReadOnly, check = GetReadOnly},
                {'After File Open', { radio = 1,
                    {"No Tab's switching", action = function() _G.iuprops['sidebarfileman.restoretab'] = 'OFF' end, check = "(_G.iuprops['sidebarfileman.restoretab'] or 'OFF') == 'OFF'"},
                    {"Switch To First Tab", action = function() _G.iuprops['sidebarfileman.restoretab'] = '1' end, check = "(_G.iuprops['sidebarfileman.restoretab'] or 'OFF') == '1'"},
                    {"Switch To Previous Tab", action = function() _G.iuprops['sidebarfileman.restoretab'] = 'ON' end, check = "(_G.iuprops['sidebarfileman.restoretab'] or 'OFF') == 'ON'"},
                }},
            }},
            {"Insert Relative Path", action = function() editor:ReplaceSel(FILEMAN.RelativePath()); iup.PassFocus() end},
    }}, "hildim/ui/fileman.html", _T)

    list_dir.action_cb = (function(h, key, lin, col, edition, value) memoNav(h, key) end)
    list_dir.value_edit_cb = FileMan_DoRename
    list_dir.edition_cb = FileMan_CheckRename
    iup.SetAttribute(list_dir, 'TYPE*:1', 'IMAGE')

    list_favorites = iup.matrix{name = 'filemam.listfavorites',
        numcol = 3, numcol_visible = 3, cursor = "ARROW", alignment = 'ALEFT', heightdef = 6, markmode = 'LIN', flatscrollbar = "YES" ,
        resizematrix = "YES", readonly = "NO"  , markmultiple = "NO" , height0 = 4, expand = "YES", framecolor = "255 255 255",
        width0 = 0 ,
        rasterwidth1 = 18 , rasterwidth2 = _G.iuprops['filemam.listfavorites.rw2'] or 150 ,
    rasterwidth3 = _G.iuprops['filemam.listfavorites.rw3'] or 450, tip = 'jj'}

    list_favorites.colresize_cb = list_favorites.FitColumns(3, true, 1)
    list_favorites.tips_cb = (function(h, x, y)
        local l = iup.TextConvertPosToLinCol(h, iup.ConvertXYToPos(h, x, y))
        if l == 0 then h.tip = _T'Favorites - Files and Folders'
        else h.tip = iup.GetAttributeId2(h, '', l, 3)
        end
    end)
	list_favorites.map_cb = (function(h)
        h.size = "1x1"
    end)
    list_favorites.edition_cb = (function(c, lin, col, mode, update)
        if mode == 1 and (not bRenameFavor or col ~= 2) then return iup.IGNORE; end bRenameFavor = false
    end)
    list_favorites.value_edit_cb = Favorits_DoRename
    iup.SetAttribute(list_favorites, 'TYPE*:1', 'IMAGE')
    list_favorites:setcell(0, 2, _T"Name")
    list_favorites:setcell(0, 3, _T"Path")
  	list_favorites.click_cb = (function(h, lin, col, status)
        if iup.isdouble(status) and iup.isbutton1(status) then
            Favorites_OpenFile()
        elseif iup.isbutton3(status) then
            CORE.ScipHidePannel()
            h.focus_cell = lin..':'..col
            iup.SetAttribute(list_dir, 'MARK'..col..':0', 1)
            menuhandler:PopUp('MainWindowMenu|_HIDDEN_|Favorites_sidebar')
        end
    end)

    menuhandler:InsertItem('MainWindowMenu', '_HIDDEN_|s1',
        {'Favorites_sidebar', plane = 1,{
            {"Add Current File", action = Favorites_AddCurrentBuffer},
            {"Delete from Favorites", action = Favorites_DeleteItem},
            {"Rename", action = Favorites_Rename},
    }}, "hildim/ui/fileman.html", _T)



    split_s = iup.split{iup.backgroundbox{list_dir, bgcolor = iup.GetLayout().txtbgcolor}, iup.backgroundbox{list_favorites, bgcolor = iup.GetLayout().txtbgcolor}, orientation = "HORIZONTAL", name = 'splitFileMan', color = props['layout.splittercolor'], showgrip = 'LINES'}
    memo_path = iup.text{expand = 'YES', tip = _T'Arrow Up/Down, Ctrl+Home/End - movement through the file list'}
    local path_timer = iup.timer{time = 300; action_cb = function(h)
        h.run = 'NO'
        local v = memo_path.value
        if v:find('^%w:[\\/]') or v:find('[\\/][\\/]%w+[\\/]%w%$[\\/]') then
            FileMan_ListFillDir(v)
        end
    end}
    memo_path.action = (function(h, s, new_value)
        path_timer.run = 'NO'
        path_timer.run = 'YES'
    end)
    memo_path.getfocus_cb = (function(h)
        if not list_dir.marked then return end
        local sel = list_dir.marked:find('1')
        if sel ~= nil then iup.SetAttribute(list_dir, 'MARK'..(sel - 1)..':0', 0) end
        sel = 1
        iup.SetAttribute(list_dir, 'MARK'..(sel)..':0', 1)
        list_dir.focus_cell = (sel)..":1"
        list_dir.redraw = "ALL"
    end)

    memo_path.k_any =(function(h, k)
        return memoNav(h, k)
    end)

    memo_mask = iup.text{expand = 'YES', tip = _T'* - any character sequence\nArrow Up/Down, Ctrl+Home/End - movement through the file list'}
    local mask_timer = iup.timer{time = 300; action_cb = function(h)
        h.run = 'NO'
        FileMan_ListFILLByMask(memo_mask.value)
    end}
    memo_mask.action = (function(h, s, new_value)
        mask_timer.run = 'NO'
        mask_timer.run = 'YES'
    end)
    memo_mask.k_any =(function(h, k)
        return memoNav(h, k)
    end)
    chkByTime = iup.hi_toggle{title = _T"Time Sort", value = Iif(sort_by_tyme, "ON", "OFF"), canfocus = "NO", flat_action = FileMan_ToggleSort}
    -- memo_mask.killfocus_cb = (function(h)
    -- FileMan_ListFILLByMask(memo_mask.value)
    -- end)
    AddEventHandler("OnResizeSideBar", function(sciteid)
        if h.fileman.Bar_obj.sciteid == sciteid then
            list_dir.rasterwidth2 = nil
            list_dir.fittosize = 'COLUMNS'
            list_favorites.FitColumns(3, false, 1)()
        end
    end)
    zPath = iup.zbox{
        iup.flatbutton{tip = _T'Fixed', impress = "IMAGE_PinPush", visible = "NO", image = "IMAGE_Pin", canfocus = "NO", flat_action = (function(h) zPath.valuepos = "1" end), },
        iup.flatbutton{tip = _T'Fixed', impress = "IMAGE_Pin", visible = "NO", image = "IMAGE_PinPush", canfocus = "NO", flat_action = (function(h) zPath.valuepos = "0"; OnSwitch(false, true) end), },
    }
    zMemo = iup.zbox{
        iup.flatbutton{tip = _T'Fixed', impress = "IMAGE_PinPush", visible = "NO", image = "IMAGE_Pin", canfocus = "NO", flat_action = (function(h) zMemo.valuepos = "1" end), },
        iup.flatbutton{tip = _T'Fixed', impress = "IMAGE_Pin", visible = "NO", image = "IMAGE_PinPush", canfocus = "NO", flat_action = (function(h) zMemo.valuepos = "0"; memo_mask.value = ''; FileMan_ListFILLByMask(''); zPath.valuepos = p end), },
    }
    local m_bReset = false
    AddEventHandler("OnIdle", function() if m_bReset then OnSwitch(false, true); m_bReset = false end end)
    local res = {

        handle = iup.vbox{
            iup.scrollbox{iup.vbox{iup.hbox{zPath, iup.label{title = _T"Path:", size = "30x"}, memo_path, expand = "HORIZONTAL", alignment = "ACENTER"},
                iup.hbox{zMemo, iup.label{title = _T"Mask:", size = "30x"}, memo_mask, chkByTime, expand = "HORIZONTAL", alignment = "ACENTER"}},
            scrollbar = 'NO', minsize = 'x54', maxsize = 'x54', expand = "HORIZONTAL",};
            split_s
        };
        OnSwitchFile = function() m_bReset = true end;
        OnSave = function() OnSwitch(false, false) end;
        OnOpen = function() m_bReset = true end;
        OnSaveValues = (function() _G.iuprops['FileMan.Dir.restoretab'] = memo_path.value end);
        OpenDir = (function(newPath)
            for i = 1, _Plugins.fileman.Bar_obj.TabCtrl.count do
                if iup.GetAttributeId(_Plugins.fileman.Bar_obj.TabCtrl, 'TABTITLE', i) == _Plugins.fileman.id then
                    _Plugins.fileman.Bar_obj.TabCtrl.valuepos = i
                    break
                end
                print(newPath)

                if newPath:match('[\\/]$') then
                    current_path = newPath
                else
                    current_path = newPath..'\\'
                end
                FileMan_ListFILL()

                for s, tbs in pairs(_Plugins) do
                    if tbs.tabs_OnSelect and _Plugins.fileman.Bar_obj.TabCtrl.value_handle.tabtitle == tbs.id and s ~= 'fileman' then tbs.tabs_OnSelect() end
                end
            end
        end),
        tabs_OnSelchange = function()
            if _Plugins.fileman.Bar_obj.TabCtrl.value_handle.tabtitle ~= _Plugins.fileman.id then
                m_prevSel = _Plugins.fileman.Bar_obj.TabCtrl.valuepos
            end
        end;
        tabs_OnSelect = function(h) scite.RunAsync(function() iup.SetFocus(memo_mask); ensureVisible() end); --[[OnSwitch(false, true)]] end;
    }
    Favorites_OpenList()
    return res
end


return {
    title = 'Files  and Favorites',
    code = 'fileman',
    sidebar = FileManTab_Init,
    tabhotkey = "Alt+Shift+O",
    destroy = function() FILEMAN = nil end,
    description = [[Встроенный файловый менеджер]]
}

