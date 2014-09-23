--[[--------------------------------------------------
ColorSet.lua
Authors: mozers™
version 1.1
------------------------------------------------------
  Connection:
   Set in a file .properties:
     command.name.6.*=Choice Color
     command.6.*=dofile $(SciteDefaultHome)\tools\ColorSet.lua
     command.mode.6.*=subsystem:lua,savebefore:no           #489D5A

  Note: Needed gui.dll <http://scite-ru.googlecode.com/svn/trunk/lualib/gui/>
--]]--------------------------------------------------

local colour = props["CurrentSelection"]
local prefix = false
if colour:match("[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]$") then
	if colour:match("^#") then
		prefix = true
	else
		colour = "#"..colour
	end
else
	prefix = true
	colour = "#FFFFFF"
end
local d = iup.colordlg{showcolortable="YES", showhex="YES"}
d.valuehex = colour
d:popup()
colour = d.valuehex
d:destroy()

if colour ~= nil then
	if not prefix then colour = colour:gsub('^#', '') end
	editor:ReplaceSel(colour)
end

