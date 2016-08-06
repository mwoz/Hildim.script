
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

function FILEMAN.FullPath()
    local lin = list_dir.marked:sub(2):find("1")
    return current_path..list_dir:getcell(lin, 2)
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

FileMan_ListFILL = function()
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
        if (not table_dir[i].isdirectory) and (not table_dir[i].name:lower():find(maskVal) or shell.bit_and(table_dir[i].attributes,2) == 2) then
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
            local n,a = table_dir[i].name, table_dir[i].attributes
            if n ~= "." and n ~= ".." and not n:find('^%$') and shell.bit_and(a,2) == 0 and shell.bit_and(a,4) == 0 then
                list_dir:setcell(j, 1, 'IMAGE_Folder')
                list_dir:setcell(j, 2, n)
                list_dir:setcell(j, 3, a)
                list_dir:setcell(j, 4, 'd')
                j = j + 1
            end
        else
            if table_dir[i].name:lower():find(maskVal) and shell.bit_and(table_dir[i].attributes,2) ~= 2 then
                list_dir:setcell(j, 1,  GetExtImage(table_dir[i].name))
                list_dir:setcell(j, 2, table_dir[i].name)
                list_dir:setcell(j, 3, table_dir[i].attributes)
                list_dir:setcell(j, 4, '')
                if shell.bit_and(table_dir[i].attributes,1) == 1 then
                    iup.SetAttributeId2(list_dir, 'FGCOLOR', j, 2, '100 100 100')
                end
                j = j + 1
            end
        end
	end
    if j<prevL+1 then iup.SetAttribute(list_dir, 'DELLIN', (j)..'-'..prevL) end
    local d = Iif(file_mask == '', 1, dc)
	list_dir.focus_cell = d..":1"
    iup.SetAttributeId2(list_dir, 'MARK', d, 0, '1')
    list_dir.redraw = "ALL"
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
        if table_folders[i].isdirectory and shell.bit_and(a,2)==0 and shell.bit_and(a,4)==0 and not table_folders[i].name:find('^%$')  then
            list_dir:setcell(j, 1, 'IMAGE_Folder')
            list_dir:setcell(j, 2, table_folders[i].name)
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
	return list_dir:getcell(idx, 2), list_dir:getcell(idx, 4), tonumber(list_dir:getcell(idx, 3))
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
    SideBar_Plugins.fileman.Bar_obj.TabCtrl.valuepos = n -1
    for _,tbs in pairs(SideBar_Plugins) do
        if tbs.tabs_OnSelect and SideBar_Plugins.fileman.Bar_obj.TabCtrl.value_handle.tabtitle == tbs.id then tbs.tabs_OnSelect() end
    end
end

local function OpenFile(filename)
	if filename:match(".session$") ~= nil then
		filename = filename:gsub('\\','\\\\')
		scite.Perform ("loadsession:"..filename)
	else
		scite.Open(filename:to_utf8(1251))
	end
    if (_G.iuprops['sidebarfileman.restoretab'] or 'OFF')=='ON' then mybar_Switch(m_prevSel+1)
    elseif (_G.iuprops['sidebarfileman.restoretab'] or 'OFF')=='1' then mybar_Switch(1)
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
        memo_mask.value = ''
		FileMan_ListFILLByMask(memo_mask.value)
	else
        local _,_,ext = dir_or_file:find('%.([^%.]*)$')
        ext = (ext or ''):lower()
        if string.find('.exe.lnk.doc.xsl.pdf.chm.', '%.'..ext..'%.') then
            FileMan_FileExec()
            return
        end
        prev_filename = current_path..dir_or_file
		OpenFile(prev_filename)
	end
end

local function FileMan_OpenSelectedItems()
	local si = list_getvaluenum(list_favorites)
    local dir_or_file, attr = FileMan_GetSelectedItem(si)
    if attr ~= 'd' then
        OpenFile(current_path..dir_or_file)
    end
end
----------------------------------------------------------
-- tab0:list_favorites   Favorites
----------------------------------------------------------
local favorites_filename = props['SciteUserHome']..'\\favorites.lst'
local list_fav_table = {}

local function Favorites_ListFILL_l()
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
        list_favorites:setcell(i, 2, getName(s))
        list_favorites:setcell(i, 3, s[1])
    end
    list_favorites.redraw = "ALL"
end

local function Favorites_OpenList()
	local favorites_file = io.open(favorites_filename)
    list_fav_table = {}
	if favorites_file then
		for line in favorites_file:lines() do
			if line ~= '' then
				line = ReplaceWithoutCase(line, '$(SciteDefaultHome)', props['SciteDefaultHome'])
				list_fav_table[#list_fav_table+1] = {line, false}
			end
		end
		favorites_file:close()
	end
    bListOpened = true
end


local function Favorites_SaveList()
	if bListOpened and pcall(io.output, favorites_filename) then
        local tbl = {}
        for i = 1, #list_fav_table do
            if not list_fav_table[i][2] then table.insert(tbl,list_fav_table[i][1]) end
        end
		local list_string = table.concat(tbl,'\n')
		list_string = ReplaceWithoutCase(list_string, props['SciteDefaultHome'], '$(SciteDefaultHome)')
		io.write(list_string)
		io.close()
	end
end

local function Favorites_AddFile()
	local fname, attr = FileMan_GetSelectedItem()
	if fname == '' then return end
	fname = current_path..fname
	if attr == 'd' then
		fname = fname:gsub('\\\.\.$', '')..'\\'
	end
	list_fav_table[#list_fav_table+1] = {fname, false}
	Favorites_ListFILL_l()
	Favorites_SaveList()
end

local function FileMan_ChangeReadOnly()
    local fname, d, attr = FileMan_GetSelectedItem()
	if fname == '' then return end
	fname = current_path..fname
    l = list_getvaluenum(list_dir)
    if shell.bit_and(attr, 1) == 1 then
        attr = attr - 1
    else
        attr = attr + 1
    end
    shell.setfileattr(fname, attr)
    attr = shell.getfileattr(fname)
    list_dir:setcell(l, 3, attr)
    if shell.bit_and(attr, 1) == 1 then
        iup.SetAttributeId2(list_dir, 'FGCOLOR', l, 2, '100 100 100')
    else
        iup.SetAttributeId2(list_dir, 'FGCOLOR', l, 2, '0 0 0')
    end
end

local function FileMan_Delete()
    local fname, d, attr = FileMan_GetSelectedItem()
	if fname == '' or d == 'd' then return end
	fname = current_path..fname
    local msb = iup.messagedlg{buttons='YESNO', value='Delete file\n'..fname..'\n?'}
    msb.popup(msb)
    if msb.buttonresponse == '1' then
        local lRes = shell.delete_file(fname)
        --local lRes = shell.rename_file(fname, current_path..'aa')
        if lRes == 0 then
            FileMan_ListFILL()
        else
            print('File '..fname..' not deleted!')
        end
    end
    msb:destroy(msb)
end

local prevName
local function FileMan_CheckRename(c,lin, col, mode, update)
    if mode == 1 then
        if prevName == nil then return -1 end
    end
end
local function FileMan_DoRename(c, lin, col)
    local fname, d, attr = FileMan_GetSelectedItem()
    if fname ~= prevName then
        local lRes = shell.rename_file(current_path..prevName, current_path..fname)
        if lRes ~= 0 then
            FileMan_ListFILL()
            print('File '..prevName..' not renamed!')
        end
    end
    prevName = nil
end

local function FileMan_Rename()
    local fname, d, attr = FileMan_GetSelectedItem()
    prevName = fname
    local l = list_getvaluenum(list_dir)
	if fname == '' or d == 'd' then return end

    list_dir.focus_cell = l..":2"
    iup.SetAttribute(list_dir, 'READONLY', 'NO')
    iup.SetAttribute(list_dir, 'EDIT_MODE', 'YES')
end

local function Favorites_AddCurrentBuffer()
	list_fav_table[#list_fav_table+1] = {props['FilePath'], false}
	Favorites_ListFILL_l()
    Favorites_SaveList()
end

local function Favorites_AddFileName_l(fName) --для добавления из других библиотек
    list_fav_table[#list_fav_table+1] = {fName, true}
end

local function Favorites_Clear_l()
    if SideBar_Plugins.fileman.Bar_obj.Active  ~= true then return end
    for i = #list_fav_table,1,-1 do
        if list_fav_table[i][2] then table.remove(list_fav_table,i) end
    end
	Favorites_ListFILL_l()
end

local function Favorites_DeleteItem()
	local idx = list_getvaluenum(list_favorites)
	if idx == nil then return end
	iup.SetAttribute(list_favorites, "DELLIN", idx)
	table.remove (list_fav_table, idx)
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

local function OnSwitch(bForse, bRelist)
    if prev_filename:upper() == props['FilePath']:upper() then return end
    prev_filename = ''
    if bForse or (SideBar_Plugins.fileman.Bar_obj.TabCtrl.value_handle.tabtitle == SideBar_Plugins.fileman.id) then
        if bForse then iup.SetFocus(memo_mask) end
        local path = props['FileDir']
        if path == '' then path = _G.iuprops['sidebarfileman.restoretab'] end
        if path ~= '' then
            current_path = path:gsub('\\$','')..'\\'
            -- if bClearMask then memo_mask:set_text = "" end
            FileMan_ListFILL()
            for i = 0, list_dir.count - 1 do
                if list_dir:getcell(i,2) ~= nil and list_dir:getcell(i,2):upper() == props['FileNameExt']:upper() then
                    iup.SetAttributeId2(list_dir, 'MARK',1,0, 0)
                    iup.SetAttributeId2(list_dir, 'MARK',i,0, 1)
                    list_dir.focus_cell = i..":1"
                    list_dir.redraw = "ALL"
                    iup.SetAttribute(list_dir, 'SHOW', i..":1")
                end
            end
        end
    end
    if bRelist then
        Favorites_OpenList()
        Favorites_ListFILL_l()
    end
end

local function memoNav(key)
    if key == 65364 then  --down
        local sel = 1
        if list_dir.marked then sel = list_dir.marked:find('1') end
        sel = sel - 1
        if sel < list_dir.count - 1 then
            iup.SetAttribute(list_dir, 'MARK'..(sel)..':0', 0)
            iup.SetAttribute(list_dir, 'MARK'..(sel+1)..':0', 1)
            list_dir.focus_cell = (sel+1)..":1"
            list_dir.redraw = "ALL"
        end
        return -1
    elseif key == 65362 then  --up
        local sel = list_dir.marked:find('1')
        if sel == nil then sel = list_dir.count + 2 end
        sel = sel - 1
        if sel > 1 then
            iup.SetAttribute(list_dir, 'MARK'..(sel)..':0', 0)
            iup.SetAttribute(list_dir, 'MARK'..(sel-1)..':0', 1)
            list_dir.focus_cell = (sel-1)..":1"
            list_dir.redraw = "ALL"
        end
        return -1
    elseif key == 13 then
        if memo_path.value:find('^%w:[\\/]') or memo_path.value:find('[\\/][\\/]%w+[\\/]%w%$[\\/]') then
            current_path = memo_path.value:gsub('[\\/][^\\/]*$','')..'\\'
            FileMan_OpenItem()
            memo_path.caretpos = memo_path.count
        end
    elseif key == 65307 then --escape
        iup.PassFocus()
        FileMan_ListFILLByMask(memo_mask.value)
    end
end

local function GetReadOnly()
    local lin = list_dir.marked:sub(2):find("1")
    return shell.bit_and(tonumber(list_dir:getcell(lin, 3) or 0), 1) == 1
end

local function FileManTab_Init()
    Favorites_AddFileName = Favorites_AddFileName_l
    Favorites_ListFILL = Favorites_ListFILL_l
    Favorites_Clear = Favorites_Clear_l

    list_dir = iup.matrix{
    numcol=4, numcol_visible=2,  cursor="ARROW", alignment='ALEFT', heightdef=6,markmode='LIN', scrollbar="YES" ,
    resizematrix = "YES"  ,readonly="NO"  ,markmultiple="NO" ,height0 = 4, expand = "YES", framecolor="255 255 255",
    width0 = 0 ,rasterwidth1 = 18,rasterwidth2= 450,rasterwidth3= 0, rasterwidth4= 0 }

    list_dir.map_cb = (function(h)
        h.size="1x1"
    end)

    list_dir:setcell(0, 2, "Name")
  	list_dir.click_cb = (function(h, lin, col, status)
        local sel = 0
        if h.marked then sel = h.marked:find('1') - 1 end
        iup.SetAttribute(h,  'MARK'..sel..':0', 0)
        iup.SetAttribute(h, 'MARK'..lin..':0', 1)
        local l = shell.bit_and(tonumber(list_dir:getcell(lin, 3) or 0), 1)
        h.redraw = lin..'*'
        if iup.isdouble(status) and iup.isbutton1(status) then
            if memo_path.value:find('^%w:[\\/]') or memo_path.value:find('[\\/][\\/]%w+[\\/]%w%$[\\/]') then
                if list_dir:getcell(1, 2) ~= '..' then
                    current_path = memo_path.value:gsub('[\\/][^\\/]*$','')..'\\'
                end
                FileMan_OpenItem()
            else
                OnSwitch(false,false)
            end
            return -1
        elseif iup.isbutton3(status) then
            h.focus_cell = lin..':'..col
            menuhandler:PopUp('MainWindowMenu¦_HIDDEN_¦Fileman_sidebar')
        end
    end)

    menuhandler:InsertItem('MainWindowMenu', '_HIDDEN_¦s1',   --TODO переместить в SideBar\FindRepl.lua вместе с функциями
        {'Fileman_sidebar', plane = 1,{
            {"Change Dir", ru = "Изменить Директорию", action = FileMan_ChangeDir},
            {"Read Only", ru = "Только чтение", action = FileMan_ChangeReadOnly, check = GetReadOnly},
            {"Delete", ru = "Удалить", action = FileMan_Delete},
            {"Rename", ru = "Переименовать", action = FileMan_Rename},
            {'s_OpenwithHildiM', separator = 1},
            {"Open with HildiM", action = FileMan_OpenSelectedItems},
            {"Execute", ru = "Выполнить", action =(function() FileMan_FileExec(nil) end)},
            {"Exec with Params", ru = "Выполнить с параметрами", action = FileMan_FileExecWithParams},
            {'s_AddtoFavorites', separator = 1},
            {"Add to Favorites", ru = "Добавить в избранное", action = Favorites_AddFile},
            {'When open file', ru = "После выбора файла",{
                {"Stay Here", action = function() _G.iuprops['sidebarfileman.restoretab'] = 'OFF' end, value = Iif((_G.iuprops['sidebarfileman.restoretab'] or 'OFF') == 'OFF', 'ON', 'OFF')},
                {"Restore First Tab", action = function() _G.iuprops['sidebarfileman.restoretab'] = '1' end, value = Iif((_G.iuprops['sidebarfileman.restoretab'] or 'OFF') == '1', 'ON', 'OFF')},
                {"Restore Prev. Tab", action = function() _G.iuprops['sidebarfileman.restoretab'] = 'ON' end, value = Iif((_G.iuprops['sidebarfileman.restoretab'] or 'OFF') == 'ON', 'ON', 'OFF')},
            }},
            {"Insert Relative Path", ru = "Вставить относительный путь", action = function() editor:ReplaceSel(FILEMAN.RelativePath()); iup.PassFocus() end},
    }})

    list_dir.action_cb = (function(h, key, lin, col, edition, value) memoNav(key) end)
    list_dir.value_edit_cb = FileMan_DoRename
    list_dir.edition_cb = FileMan_CheckRename
    iup.SetAttribute(list_dir, 'TYPE*:1', 'IMAGE')

    list_favorites = iup.matrix{
    numcol=3, numcol_visible=3,  cursor="ARROW", alignment='ALEFT', heightdef=6,markmode='LIN', scrollbar="YES" ,
    resizematrix = "YES"  ,readonly="YES"  ,markmultiple="NO" ,height0 = 4, expand = "YES", framecolor="255 255 255",
    width0 = 0 ,rasterwidth1 = 18 ,rasterwidth2 = 80 ,rasterwidth3= 450, tip ='jj'}

    list_favorites.tips_cb = (function(h, x, y)
        local l = iup.TextConvertPosToLinCol(h, iup.ConvertXYToPos(h, x, y))
        if l == 0 then h.tip = 'Избранное - файлы и директории'
        else h.tip = iup.GetAttributeId2(h, '', l, 3)
        end
    end)
	list_favorites.map_cb = (function(h)
        h.size="1x1"
    end)
    iup.SetAttribute(list_favorites, 'TYPE*:1', 'IMAGE')
    list_favorites:setcell(0, 2, "Name")
    list_favorites:setcell(0, 3, "Path")
  	list_favorites.click_cb = (function(h, lin, col, status)
        if iup.isdouble(status) and iup.isbutton1(status) then
            Favorites_OpenFile()
        elseif iup.isbutton3(status) then
            h.focus_cell = lin..':'..col
            iup.SetAttribute(list_dir, 'MARK'..col..':0', 1)
            local mnu = iup.menu
            {
              iup.item{title="Add active buffer",action=Favorites_AddCurrentBuffer},
              iup.item{title="Delete item",action=Favorites_DeleteItem}
            }:popup(iup.MOUSEPOS,iup.MOUSEPOS)
        end
    end)
    split_s = iup.split{list_dir, list_favorites, orientation="HORIZONTAL", name='splitFileMan',layoutdrag = 'NO'}
    memo_path = iup.text{expand='YES'}
    memo_path.action = (function(h,s,new_value)
        if new_value:find('^%w:[\\/]') or new_value:find('[\\/][\\/]%w+[\\/]%w%$[\\/]') then
            FileMan_ListFillDir(new_value)
        end
    end)
    memo_path.getfocus_cb = (function(h)
        iup.SetAttribute(list_dir, 'MARK1:0', 1)
        list_dir.redraw = "1:1"
    end)

    memo_path.k_any=(function(h,k)
        return memoNav(k)
    end)

    memo_mask = iup.text{expand='YES',tip='* - любая последовательность...'}
    memo_mask.action = (function(h,s,new_value)
        FileMan_ListFILLByMask(new_value)
    end)
    memo_mask.k_any=(function(h,k)
        return memoNav(k)
    end)
    chkByTime = iup.toggle{title="Time Sort", value=Iif(sort_by_tyme, "ON", "OFF"),action=FileMan_ToggleSort}
    -- memo_mask.killfocus_cb = (function(h)
        -- FileMan_ListFILLByMask(memo_mask.value)
    -- end)


    SideBar_Plugins.fileman =  {
        handle = iup.vbox{
                   iup.scrollbox{iup.vbox{iup.hbox{iup.label{title = "Path:",size="40x"},memo_path,expand="HORIZONTAL", alignment="ACENTER"},
                   iup.hbox{iup.label{title = "File Mask:",size="40x"},memo_mask,chkByTime,expand="HORIZONTAL", alignment="ACENTER"}},
                   scrollbar='NO', minsize='x54', maxsize='x54', expand="HORIZONTAL",};
                   split_s
                 };
        OnSwitchFile = function()OnSwitch(false,true) end;
        OnSave = function()OnSwitch(false,false) end;
        OnOpen = function()OnSwitch(false,true) end;
        OnSaveValues = (function() Favorites_SaveList();_G.iuprops['FileMan.Dir.restoretab']=memo_path.value end);
        OpenDir = (function(newPath)
            for i=1, SideBar_Plugins.fileman.Bar_obj.TabCtrl.count do
                if iup.GetAttributeId(SideBar_Plugins.fileman.Bar_obj.TabCtrl,'TABTITLE',i) == SideBar_Plugins.fileman.id then
                    SideBar_Plugins.fileman.Bar_obj.TabCtrl.valuepos = i
                    break
                end
                print(newPath)

                if newPath:match('[\\/]$') then
                    current_path = newPath
                else
                    current_path = newPath..'\\'
                end
                FileMan_ListFILL()

                for s,tbs in pairs(SideBar_Plugins) do
                    if tbs.tabs_OnSelect and SideBar_Plugins.fileman.Bar_obj.TabCtrl.value_handle.tabtitle == tbs.id and s ~= 'fileman' then tbs.tabs_OnSelect() end
                end
            end
        end),
        tabs_OnSelect = function()
            if SideBar_Plugins.fileman.Bar_obj.TabCtrl.value_handle.tabtitle ~= SideBar_Plugins.fileman.id then
                m_prevSel = SideBar_Plugins.fileman.Bar_obj.TabCtrl.valuepos
            end
            OnSwitch(true,false)
        end;
    }
    Favorites_OpenList()
end


return {
    title = 'Files  and Favorites',
    code = 'fileman',
    sidebar = FileManTab_Init,
    description = [[Встроенный файловый менеджер]]
}

