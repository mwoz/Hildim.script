--[[--------------------------------------------------
auto_backup.lua
Authors: mozers�
Version: 1.5.1
------------------------------------------------------
�������� ��������� ����� ������������ ����� �������������� �����
------------------------------------------------------
�����������:
� ���� SciTEStartup.lua �������� ������:
  dofile (props["SciteDefaultHome"].."\\tools\\auto_backup.lua")
������� � ����� .properties ���-�� ����������� ��������� � ������� ��� ���������� ��������� �����:
  backup.files=1
  backup.path=$(TEMP)\SciTE
----------------------------------------------
Connection:
In file SciTEStartup.lua add a line:
  dofile (props["SciteDefaultHome"].."\\tools\\auto_backup.lua")
Set in a file .properties number saved variants and backup path:
define the number of backup files you want to keep (1-9,0=none)
  backup.files=1
backup.path can contain a absolute or relative (subdir of source-file) path
e.g.
  backup.path=_bak_
  backup.path=$(TEMP)\SciTE
--]]--------------------------------------------------

require 'shell'

local function GetPath()
	local path = shell.from_utf8(props['backup.path'])

-- 	if set relative path
	if string.find(path, '^%a:\\') == nil then
		path = shell.from_utf8(props['FileDir'])..'\\'..path
	end

-- 	if backup folder not exist
	if not shell.fileexists(path) then
		shell.exec('CMD /C MD "'..path..'"', nil, true, true) -- Silent window (only SciTE-Ru)
--~ 		os.execute('CMD /C MD "'..path..'"')
	end
	return path
end

local function BakupFile(filename)
	local sbck = tonumber(props['backup.files'])
	if sbck == nil or sbck == 0 then
		return false
	end
	filename = shell.from_utf8(filename)
	local sfilename = filename
	filename = GetPath().."\\"..string.gsub(filename,'.*\\','')
	local nbck = 1
	while (sbck > nbck ) do
		local fn1 = sbck-nbck
		local fn2 = sbck-nbck+1
		os.remove (filename.."."..fn2..".bak")
		if fn1 == 1 then
			os.rename (filename..".bak", filename.."."..fn2..".bak")
		else
			os.rename (filename.."."..fn1..".bak", filename.."."..fn2..".bak")
		end
		nbck = nbck + 1
	end
	os.remove (filename..".bak")
	if not shell.fileexists(sfilename) then
		io.output(shell.to_utf8(sfilename))
		io.close()
	end
	os.rename (sfilename, filename..".bak")
	if not shell.fileexists(filename..".bak") then
		_ALERT("=>\tERROR CREATE BACKUP FILE: "..filename..".bak".."\t"..sbck)
	end
	return false
end

AddEventHandler("OnBeforeSave", BakupFile)
