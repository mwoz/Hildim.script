
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

props["dwell.period"] = 50

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
local function OnMyClouse()
	props["sidebar.fileman.split.value"]=split_s.value
end

----------------------------------------------------------
-- tab0:list_dir   File Manager
----------------------------------------------------------
function FileMan_ListFILLByMask(strMask)
    file_mask = strMask
    FileMan_ListFILL()
end

function FileMan_ListFILL()
    memo_path.value = current_path
	if current_path == '' then return end
	local folders = gui.files(current_path..'*', true)
	if not folders then return end
	local table_folders = {}
	for i, d in ipairs(folders) do
		table_folders[i] = d:from_utf8(1251)
	end
	table.sort(table_folders, function(a, b) return a:lower() < b:lower() end)
    local name = file_mask..'*'

	local files = gui.files(current_path..name)
	local table_files = {}
	if files then
		for i, filename in ipairs(files) do
			table_files[i] = filename:from_utf8(1251)
		end
	end
	table.sort(table_files, function(a, b) return a:lower() < b:lower() end)

    iup.SetAttribute(list_dir, "DELLIN", "1-"..list_dir.numlin)
    iup.SetAttribute(list_dir, "ADDLIN", "1-"..(#table_folders + #table_files + 1))
	list_dir:setcell(1, 1, '[..]')
	list_dir:setcell(1, 2,'..')
	list_dir:setcell(1, 3, 'd')
	for i = 1, #table_folders do
        list_dir:setcell(i + 1, 1, '['..table_folders[i]..']')
        list_dir:setcell(i + 1, 2, table_folders[i])
        list_dir:setcell(i + 1, 3, 'd')
	end
	for i = 1, #table_files do
        list_dir:setcell(i + #table_folders + 1, 1, table_files[i])
        list_dir:setcell(i + #table_folders + 1, 2, table_files[i])
        list_dir:setcell(i + #table_folders + 1, 3, '')
	end
	list_dir.focus_cell = "1:1"
    iup.SetAttribute(list_dir, 'MARK1:0', 1)
    list_dir.redraw = "ALL"
end

function FileMan_ListFillDir(strPath)
    current_path = strPath:match('(.*\\)')
    if current_path == nil then current_path = '' end
    local folders = gui.files(strPath..'*', true)
    if not folders then return  strPath:len()-(strPath:find('[:%$]') or strPath:len())>0 end
    local table_folders = {}
    for i, d in ipairs(folders) do
        table_folders[i] = d
    end
    table.sort(table_folders, function(a, b) return a:lower() < b:lower() end)

    iup.SetAttribute(list_dir, "DELLIN", "1-"..list_dir.numlin)
    iup.SetAttribute(list_dir, "ADDLIN", "1-"..#table_folders)

    for i = 1, #table_folders do
        list_dir:setcell(i, 1, '['..table_folders[i]..']')
        list_dir:setcell(i, 2, table_folders[i])
        list_dir:setcell(i, 3, 'd')
    end
    iup.SetAttribute(list_dir, 'MARK1:0', 1)
    list_dir.focus_cell = "1:1"
    list_dir.redraw = "ALL"
end

local function FileMan_GetSelectedItem(idx)
    local l = list_getvaluenum(list_dir)
    if idx == nil then idx = l end
	if idx == -1 then return '' end
	return list_dir:getcell(idx, 2), list_dir:getcell(idx, 3)
end

function FileMan_ChangeDir()
    local d = iup.filedlg{dialogtype='DIR',  parentdialog='SCITE'}
    d:popup()
    local newPath = d.value
    d:destroy()
	--local newPath = gui.select_dir_dlg('Please change current directory', current_path)
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

function FileMan_FileExec(params)
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
	if string.match(props['file.patterns.lua'], file_ext) then
		dofile(current_path..filename)
	-- Batch
	elseif string.match(props['file.patterns.batch'], file_ext) then
		FileMan_FileExecWithSciTE(CommandBuild('batch'))
		return
	-- WSH
	elseif string.match(props['file.patterns.wscript']..props['file.patterns.wsh'], file_ext) then
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

function FileMan_FileExecWithParams()
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

local function OpenFile(filename)
	if filename:match(".session$") ~= nil then
		filename = filename:gsub('\\','\\\\')
		scite.Perform ("loadsession:"..filename)
	else
		scite.Open(filename)
	end
	iup.PassFocus()
end

local function FileMan_OpenItem()
	local dir_or_file, attr = FileMan_GetSelectedItem()
	if dir_or_file == '' then return end
	if attr == 'd' then
		gui.chdir(dir_or_file)
		if dir_or_file == '..' then
			local new_path = current_path:gsub('(.*\\).*\\$', '%1')
			if not gui.files(new_path..'*',true) then return end
			current_path = new_path
		else
			current_path = current_path..dir_or_file..'\\'
		end
        memo_mask.value = ''
		FileMan_ListFILLByMask(memo_mask.value)
	else
		OpenFile(current_path..dir_or_file)
	end
end

function FileMan_OpenSelectedItems()
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

local function Favorites_ListFILL()
    local function getName(s)
		local fname = s[1]:gsub('.+\\','')
		if fname == '' then fname = s[1]:gsub('.+\\(.-)\\','[%1]') end
        return fname
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
		local st = ''
        if s[2] then st = 'X' end
        list_favorites:setcell(i, 1, getName(s))
        list_favorites:setcell(i, 2, s[1])
    end
    list_favorites.redraw = "ALL"

end

function Favorites_OpenList()
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
	--Favorites_ListFILL()
end


local function Favorites_SaveList()
	if pcall(io.output, favorites_filename) then
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

function Favorites_AddFile()
	local fname, attr = FileMan_GetSelectedItem()
	if fname == '' then return end
	fname = current_path..fname
	if attr == 'd' then
		fname = fname:gsub('\\\.\.$', '')..'\\'
	end
	list_fav_table[#list_fav_table+1] = {fname, false}
	Favorites_ListFILL()
	Favorites_SaveList()
end

function Favorites_AddCurrentBuffer()
	list_fav_table[#list_fav_table+1] = {props['FilePath'], false}
	Favorites_ListFILL()
    Favorites_SaveList()
end

function Favorites_AddFileName(fName) --дл€ добавлени€ из других библиотек
	if SideBar_obj.Active  ~= true then return end
    list_fav_table[#list_fav_table+1] = {fName, true}
	Favorites_ListFILL()
end

function Favorites_Clear()
    if SideBar_obj.Active  ~= true then return end
    for i = #list_fav_table,1,-1 do
        if list_fav_table[i][2] then table.remove(list_fav_table,i) end
    end
	Favorites_ListFILL()
end

function Favorites_DeleteItem()
	local idx = list_getvaluenum(list_favorites)
	if idx == nil then return end
	iup.SetAttribute(list_favorites, "DELLIN", idx)
	table.remove (list_fav_table, idx)
	Favorites_SaveList()
end

local function Favorites_OpenFile()
	local idx = list_getvaluenum(list_favorites)
	if idx == null then return end
	local fname = list_favorites:getcell(idx,2)
	if fname:match('\\$') then
		gui.chdir(fname)
		current_path = fname
		FileMan_ListFILL()
	else
		OpenFile(fname)
	end
end

local function Favorites_ShowFilePath()
	local sel = list_getvaluenum(list_favorites)
	if sel == nil then return end
	local expansion = list_favorites:getcell(sel,2)
	editor:CallTipCancel()
	editor:CallTipShow(editor.CurrentPos, expansion)
end

local function OnSwitch(bForse)
    if bForse or (SideBar_obj.TabCtrl.value_handle.tabtitle == SideBar_obj.Tabs.fileman.id) then
        local path = props['FileDir']
        if path == '' then return end
		current_path = path:gsub('\\$','')..'\\'
        -- if bClearMask then memo_mask:set_text = "" end
		FileMan_ListFILL()
        Favorites_OpenList()
    end
end

function memoNav(key)
    if key == 65364 then  --down
        local sel = list_dir.marked:find('1')
        if sel == nil then sel = 1 end
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
        current_path = memo_path.value:gsub('[^\\]*$','')
        FileMan_OpenItem()
    elseif key == 65307 then --escape
        iup.PassFocus()
        FileMan_ListFILLByMask(memo_mask.value)
    end
end

local function FileManTab_Init()

    list_dir = iup.matrix{
    numcol=3, numcol_visible=1,  cursor="ARROW", alignment='ALEFT', heightdef=6,markmode='LIN', scrollbar="YES" ,
    resizematrix = "YES"  ,readonly="YES"  ,markmultiple="NO" ,height0 = 4, expand = "YES", framecolor="255 255 255",
    width0 = 0 ,rasterwidth1 = 450,rasterwidth2= 0,rasterwidth3= 0 }

	list_dir:setcell(0, 1, "Name")
  	list_dir.click_cb = (function(h, lin, col, status)
        if iup.isdouble(status) and iup.isbutton1(status) then
            FileMan_OpenItem()
        elseif iup.isbutton3(status) then
            h.focus_cell = lin..':'..col
            iup.SetAttribute(list_dir, 'MARK'..col..':0', 1)
            local mnu = iup.menu
            {
              iup.item{title="Change Dir",action=FileMan_ChangeDir},
              iup.separator{},
              iup.item{title="Open with SciTE",action=FileMan_OpenSelectedItems},
              iup.item{title="Execute",action=FileMan_FileExec},
              iup.item{title="Exec with Params",action=FileMan_FileExecWithParams},
              iup.separator{},
              iup.item{title="Add to Favorites",action=Favorites_AddFile},
            }:popup(iup.MOUSEPOS,iup.MOUSEPOS)
        end
    end)

    list_favorites = iup.matrix{
    numcol=2, numcol_visible=1,  cursor="ARROW", alignment='ALEFT', heightdef=6,markmode='LIN', scrollbar="YES" ,
    resizematrix = "YES"  ,readonly="YES"  ,markmultiple="NO" ,height0 = 4, expand = "YES", framecolor="255 255 255",
    width0 = 0 ,rasterwidth1 = 250 ,rasterwidth2= 450,
    tip= '»збранное - файлы и директории'   }

    list_favorites:setcell(0, 1, "Name")
    list_favorites:setcell(0, 2, "Path")
  	list_favorites.click_cb = (function(h, lin, col, status)
        if iup.isdouble(status) and iup.isbutton1(status) then
            Favorites_OpenFile()
        elseif iup.isbutton1(status) then
            Favorites_ShowFilePath()
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
    split_s = iup.split{list_dir, list_favorites, orientation="HORIZONTAL", value=props["sidebar.fileman.split.value"]}
    memo_path = iup.text{expand='YES'}
    memo_path.action = (function(h,s,new_value)
        FileMan_ListFillDir(new_value)
    end)
    memo_path.getfocus_cb = (function(h)
        iup.SetAttribute(list_dir, 'MARK1:0', 1)
        list_dir.redraw = "1:1"
    end)
    memo_path.killfocus_cb = (function(h)
        FileMan_ListFILLByMask(memo_mask.value)
    end)
    memo_path.killfocus_cb = (function(h)
        FileMan_ListFILLByMask(memo_mask.value)
    end)

    memo_path.k_any=(function(h,k)
        return memoNav(k)
    end)

    memo_mask = iup.text{expand='YES',tip='* - люба€ последовательность...'}
    memo_mask.action = (function(h,s,new_value)
        FileMan_ListFILLByMask(new_value)
    end)
    memo_mask.k_any=(function(h,k)
        return memoNav(k)
    end)
    memo_mask.killfocus_cb = (function(h)
        FileMan_ListFILLByMask(memo_mask.value)
    end)

    SideBar_obj.Tabs.fileman =  {
        handle = iup.vbox{
                   iup.hbox{iup.label{title = "Path:",size="40x"},memo_path,expand="HORIZONTAL", alignment="ACENTER"},
                   iup.hbox{iup.label{title = "File Mask:",size="40x"},memo_mask,expand="HORIZONTAL", alignment="ACENTER"},
                   split_s
                 };
        OnSwitchFile = function()OnSwitch(false) end;
        OnSave = function()OnSwitch(false) end;
        OnOpen = function()OnSwitch(false) end;
        OnFinalise = Favorites_SaveList;
        OnSideBarClouse = OnMyClouse;
        tabs_OnSelect = function()OnSwitch(true) end;
    }
end

FileManTab_Init()
