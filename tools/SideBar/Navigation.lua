local currentItem = 0
local list_navigation
local blockUpdate = false

local function OnNavigate(item)
	if blockUpdate then return  end

	while currentItem > 1 do
		list_navigation.dellin = 0
		currentItem = currentItem - 1
	end
	local path_ = props['FilePath']

    if path_=='' then return end
	local line_ = editor:LineFromPosition((editor.CurrentPos))

	local _,_,fName = path_:find('([^\\]*)$')
    fName = fName:from_utf8(1251)

    if tonumber(list_navigation.numlin) > 1 then
		if path_:lower() == list_navigation:getcell(1,5):lower() and math.abs(line_ - tonumber(list_navigation:getcell(1,4) - 1)) < 1 then return end  -- то есть не вносим метки с одинаковыми позициями
	end

	local line_text = editor:GetLine(line_)
	if line_text == nil then line_text = '' end
	line_text = line_text:gsub('^%s+', ''):gsub('%s+', ' ')
	if line_text == '' then
		line_text = ' - empty line - '
	end

    list_navigation.addlin = 0
    list_navigation:setcell(1,1,line_text)
    list_navigation:setcell(1,2,fName)
    list_navigation:setcell(1,3,item)
    list_navigation:setcell(1,4,(line_+1))
    list_navigation:setcell(1,5, path_)

	while tonumber(list_navigation.numlin) > 100 do
		list_navigation.dellin = tonumber(list_navigation.numlin) - 1
	end

	list_navigation.marked = nil
	--iup.SetAttributeId2(list_navigation, "MARK",1,0, "1")
	--iup.SetAttributeId2(list_navigation, "BGCOLOR",1, -1, "195 192 192")
    iup.SetAttribute(list_navigation, "BGCOLOR"..(currentItem + 1)..":*", "255 255 255")
    iup.SetAttribute(list_navigation, "BGCOLOR1:*", "192 192 192")
    list_navigation.redraw = "L1-100"
	currentItem = 1
end

local function Navigation_Go(item)
	local path = list_navigation:getcell(item,5)
    if not path then return end
    local lin = tonumber(list_navigation:getcell(item,4))

	blockUpdate = true
	if props['FilePath'] ~= path then scite.Open(path) end

	editor:SetSel(editor:PositionFromLine(lin-1),editor:PositionFromLine(lin))
	iup.PassFocus()
	blockUpdate = false

    iup.SetAttribute(list_navigation, "BGCOLOR"..(currentItem)..":*", "255 255 255")
    iup.SetAttribute(list_navigation, "BGCOLOR"..item..":*", "192 192 192")
    list_navigation.redraw = "L1-100"
	currentItem = item
end

local function Navigation_OnKey(key, shift, ctrl, alt, char)
	if editor.Focus and alt then
        local newItem
		if key == 188 or key == 37 then -- '<'
			if currentItem >= tonumber(list_navigation.numlin) then return end
			newItem = currentItem + 1
		elseif key == 190 or key == 39 then -- '>'
			if currentItem == 1 then return end
			newItem = currentItem - 1
		else
			return
		end
		Navigation_Go(newItem)
	end
end
--++++++++++++++++++++++

local function FuncBmkTab_Init()
    --События списка функций


	local list_func_height = tonumber(props['sidebar.list_navigation.height']) or 200
	--if list_func_height <= 0 then list_func_height = 200 end

    list_navigation = iup.matrix{
    numcol=5, numcol_visible=4,  cursor="ARROW", alignment='ALEFT', heightdef=6,markmode='LIN', scrollbar="YES" ,
    resizematrix = "YES"  ,readonly="YES"  ,markmultiple="NO" ,height0 = 4, expand = "YES", framecolor="255 255 255",
    width0 = 0 ,rasterwidth1 = 250 ,rasterwidth2 = 70 ,rasterwidth3 = 50 ,rasterwidth4 = 40 ,rasterwidth5 = 0,
    tip='История\n(Alt+<)/(Alt+>) - Назад/Вперед'}

	list_navigation:setcell(0, 1, "Text")         -- ,size="400x400"
	list_navigation:setcell(0, 2, "File")
	list_navigation:setcell(0, 3, "Item")
	list_navigation:setcell(0, 4, "Line")
	list_navigation.click_cb = (function(_, lin, col, status)
        if iup.isdouble(status) and iup.isbutton1(status) then
            Navigation_Go(lin)
        end
    end)

    SideBar_obj.Tabs.navigation = {
        handle = list_navigation;
        id = myId;
        tab = tab1;
        OnKey = Navigation_OnKey;
       OnMenuCommand=(function(msg) if msg==2316 then OnNavigation("Home") elseif msg==2318 then OnNavigation("End") end end);
		OnNavigation = OnNavigate;
        }
end

FuncBmkTab_Init()
