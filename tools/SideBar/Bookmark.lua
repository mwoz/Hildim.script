
local list_bookmarks
local tab2
local Abbreviations_USECALLTIPS = tonumber(props['sidebar.abbrev.calltip']) == 1
local isEditor = false
local m_lastLin = -2

----------------------------------------------------------
-- tab1:list_bookmarks   Bookmarks
----------------------------------------------------------
local table_bookmarks = {}

local function GetBufferNumber()
	local buf = props['BufferNumber']
	if buf == '' then buf = 1 else buf = tonumber(buf) end
	return buf
end

local function Bookmark_Add(line_number)
	local line_text = editor:GetLine(line_number)
	if line_text == nil then line_text = '' end
	line_text = line_text:gsub('^%s+', ''):gsub('%s+', ' ')
	if line_text == '' then
		line_text = ' - empty line - ('..(line_number+1)..')'
	end
	for _, a in ipairs(table_bookmarks) do
		if a.FilePath == props['FilePath'] and a.LineNumber == line_number then
		return end
	end
	local bmk = {}
	bmk.FilePath = props['FilePath']
	bmk.BufferNumber = GetBufferNumber()
	bmk.LineNumber = line_number

	bmk.LineText = line_text
	table_bookmarks[#table_bookmarks+1] = bmk
end

local function Bookmark_Delete(line_number)
	for i = #table_bookmarks, 1, -1 do
		if table_bookmarks[i].FilePath == props['FilePath'] then
			if line_number == nil then
				table.remove(table_bookmarks, i)
			elseif table_bookmarks[i].LineNumber == line_number then
				table.remove(table_bookmarks, i)
				break
			end
		end
	end
end

local function Bookmarks_ListFILL()
	table.sort(table_bookmarks, function(a, b)
									return a.BufferNumber < b.BufferNumber or
											a.BufferNumber == b.BufferNumber and
											a.LineNumber < b.LineNumber
								end)
	iup.SetAttribute(list_bookmarks, "DELLIN", "1-"..list_bookmarks.numlin)
    iup.SetAttribute(list_bookmarks, "ADDLIN", "1-"..#table_bookmarks)
	for i, bmk in ipairs(table_bookmarks) do
        list_bookmarks:setcell(i, 1, bmk.BufferNumber)         -- ,size="400x400"
        list_bookmarks:setcell(i, 2, bmk.LineText)
        list_bookmarks:setcell(i, 3, bmk.FilePath)
        list_bookmarks:setcell(i, 4, bmk.LineNumber)
	end
    m_lastLin = -2
    list_bookmarks.redraw = "L1-100"
end

local function Bookmarks_RefreshTable()
	Bookmark_Delete()
	for i = 0, editor.LineCount do
		if editor:MarkerGet(i) == 2 then
			Bookmark_Add(i)
		end
	end
	Bookmarks_ListFILL()
end

local function Bookmarks_GotoLine(item)
	local path = list_bookmarks:getcell(item,3)
    local lin = tonumber(list_bookmarks:getcell(item,4))

	--if pos then
		OnNavigation("Bkmk")
		scite.Open(path) -- FilePath
		ShowCompactedLine(lin) -- LineNumber
		editor:GotoLine(lin)
		iup.PassFocus()
		OnNavigation("Bkmk-")
	--end
end
local function  _OnUpdateUI()
    if SideBar_Plugins.bookmark.Bar_obj.ActiveTab == myId then
        if (editor.Focus) then
            local line_count_new = editor.LineCount
            local def_line_count = line_count_new - line_count
            if def_line_count ~= 0 then
                if tab2:bounds() then -- visible Funk/Bmk
                    Bookmarks_RefreshTable()
                end
                line_count = line_count_new
            end
        end
    end
end

local function _OnSendEditor(id_msg, wp, lp)
	if id_msg == SCI_MARKERADD then
		if lp == 1 then Bookmark_Add(wp) Bookmarks_ListFILL() end
	elseif id_msg == SCI_MARKERDELETE then
		if lp == 1 then Bookmark_Delete(wp) Bookmarks_ListFILL() end
	elseif id_msg == SCI_MARKERDELETEALL then
		if wp == 1 then Bookmark_Delete() Bookmarks_ListFILL() end
	end
end
local function _OnClose(file)
	for i = #table_bookmarks, 1, -1 do
		if table_bookmarks[i].FilePath == file then
			table.remove(table_bookmarks, i)
		end
	end
	Bookmarks_ListFILL()
end
----------------------------------------------------------
-- tab2:list_abbrev   Abbreviations
----------------------------------------------------------

local function OnSwitch()
    isEditor = true
    if SideBar_Plugins.bookmark.Bar_obj.ActiveTab == myId then
        Abbreviations_ListFILL()
        Bookmarks_ListFILL()
    end
end

local function AbbreviationsTab_Init()

    list_bookmarks = iup.matrix{
    numcol=4, numcol_visible=2,  cursor="ARROW", alignment='ALEFT', heightdef=6,markmode='LIN', scrollbar="YES" ,
    resizematrix = "YES"  ,readonly="YES"  ,markmultiple="NO" ,height0 = 4, expand = "YES", framecolor="255 255 255",
    width0 = 0 ,width1 = 25 ,width2 = 600 ,width3 = 0 ,width4 = 0 }

	list_bookmarks:setcell(0, 1, "@")         -- ,size="400x400"
	list_bookmarks:setcell(0, 2, "Bookmarks")
	list_bookmarks.click_cb = (function(_, lin, col, status)
        if iup.isdouble(status) and iup.isbutton1(status) then
            Bookmarks_GotoLine(lin)
        end
    end)
	list_bookmarks.map_cb = (function(h)
        h.size="1x1"
    end)
    list_bookmarks.mousemove_cb = (function(_,lin, col)
        if m_lastLin ~= lin then
            m_lastLin = lin
            if list_bookmarks:getcell(lin,4) then
                list_bookmarks.tip = list_bookmarks:getcell(lin,2)..'\n\n File: '..list_bookmarks:getcell(lin,3)..'\nLine:  '..(tonumber(list_bookmarks:getcell(lin,4)) + 1)
            else
                list_bookmarks.tip = 'Список букмарков'
            end
        end
    end)

	list_bookmarks.keypress_cb = (function(_, key, press)
        if press == 0 then return end
        if key == 13 then  --enter
            Bookmarks_GotoLine()
        end
	end)

    SideBar_Plugins.bookmark = {
        handle = list_bookmarks;
        OnSendEditor = _OnSendEditor;
        OnClose = _OnClose;
        On_SelectMe = function() Bookmarks_ListFILL() end
        }

end

AbbreviationsTab_Init()

