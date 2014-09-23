local myId = "Abbrev/Bmk"
local list_abbrev

local list_bookmarks
local tab2
local Abbreviations_USECALLTIPS = tonumber(props['sidebar.abbrev.calltip']) == 1
local isEditor = false

----------------------------------------------------------
-- tab1:list_bookmarks   Bookmarks
----------------------------------------------------------
local table_bookmarks = {}

local function GetBufferNumber()
	local buf = props['BufferNumber']
	if buf == '' then buf = 1 else buf = tonumber(buf) end
	return buf
end


----------------------------------------------------------
-- tab2:list_abbrev   Abbreviations
----------------------------------------------------------
local function Abbreviations_ListFILL()

	iup.SetAttribute(list_abbrev, "DELLIN", "1-"..list_abbrev.numlin)
	local abbrev_filename = props['AbbrevPath']
	local abbr_table = ReadAbbrevFile(abbrev_filename)
	if not abbr_table then return end
    iup.SetAttribute(list_abbrev, "ADDLIN", "1-"..#abbr_table)
	for i,v in ipairs(abbr_table) do
        list_abbrev:setcell(i, 1, v.abbr)         -- ,size="400x400"
        list_abbrev:setcell(i, 2, v.exp:gsub('\t','\\t'))
        list_abbrev:setcell(i, 3, v.exp)
	end
end

--local Abbreviations_HideExpansion
if Abbreviations_USECALLTIPS then
	Abbreviations_HideExpansion = function ()
		editor:CallTipCancel()
	end
else
	Abbreviations_HideExpansion = function ()
		editor:AnnotationClearAll()
	end
end

local scite_InsertAbbreviation = scite_InsertAbbreviation or scite.InsertAbbreviation
local function Abbreviations_InsertExpansion()
	local expansion = iup.GetAttribute(list_abbrev, list_abbrev.focus_cell:gsub(':.*', ':3'))
	scite_InsertAbbreviation(expansion)
    iup.PassFocus()
end

local function Abbreviations_ShowExpansion()
	local expansion = iup.GetAttribute(list_abbrev, list_abbrev.focus_cell:gsub(':.*', ':3'))
    if expansion == nill then return end
	expansion = expansion:gsub('\\\\','\4'):gsub('\\r','\r'):gsub('(\\n','\n'):gsub('\\t','\t'):gsub('\4','\\')
	local cp = editor:codepage()
	if cp ~= 65001 then expansion = expansion:from_utf8(cp) end

	local cur_pos = editor.CurrentPos
	if Abbreviations_USECALLTIPS then
		editor:CallTipCancel()
		editor:CallTipShow(cur_pos, expansion)
	else
		editor:AnnotationClearAll()
		editor.AnnotationVisible = ANNOTATION_BOXED
		local linenr = editor:LineFromPosition(cur_pos)
		editor.AnnotationStyle[linenr] = 255 -- номер стиля, в котором вы задали параметры для аннотаций
		editor:AnnotationSetText(linenr, expansion:gsub('\t', '    '))
	end
end


local function Abbreviations_Init()
    --События списка функций

    list_abbrev = iup.matrix{
    numcol=3, numcol_visible=2,  cursor="ARROW", alignment='ALEFT', heightdef=6,markmode='LIN', scrollbar="YES" ,
    resizematrix = "YES"  ,readonly="YES"  ,markmultiple="NO" ,height0 = 4, expand = "YES", framecolor="255 255 255",
    rasterwidth0 = 0 ,rasterwidth1 = 60 ,rasterwidth2 = 600 ,rasterwidth3 = 0,
    tip='В главном окне введите\nкод из [Abbrev] + (Ctrl+B)'}

	list_abbrev:setcell(0, 1, "Abbrev")         -- ,size="400x400"
	list_abbrev:setcell(0, 2, "Expansion")

	list_abbrev.click_cb = (function(_, lin, col, status)
        if iup.isdouble(status) and iup.isbutton1(status) then
            Abbreviations_InsertExpansion()
        end
    end)

	list_abbrev.enteritem_cb = (function(_, lin, col)
        Abbreviations_ShowExpansion()
    end)

	list_abbrev.keypress_cb = (function(_, key, press)
        if press == 0 then return end
        if key == 13 then  --enter
            Abbreviations_InsertExpansion()
        elseif key == 65307 then
            Abbreviations_HideExpansion()
        end
	end)

    SideBar_obj.Tabs.abbreviations = {
        handle = list_abbrev;
        OnSwitchFile = Abbreviations_ListFILL;
        OnSave = Abbreviations_ListFILL;
        OnOpen = Abbreviations_ListFILL;
        on_SelectMe = (function()  Abbreviations_ListFILL();end)
        }
end

Abbreviations_Init()

