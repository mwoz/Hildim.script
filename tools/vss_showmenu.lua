require 'shell'
function vss_SetCurrentProject(dir)
    local d = dir or props['FileDir']
    if not shell.fileexists(d..'\\'..'mssccprj.scc') then
        print('"mssccprj.scc" not found in current dir')
        return false
    end
	local fil = io.open(d..'\\'..'mssccprj.scc')
    local strFile = fil:read("*a")
	fil:close()
    local _,_,strProgect = string.find(strFile,'SCC_Project_Name = "([^"]+)')
    local ierr, strerr=shell.exec('"'..props['vsspath']..'\\ss.exe" CP "'..strProgect..'"',nil,true,true)
    if ierr ~= 0 then print(strerr) end
    return ierr == 0
end

local function reset_err(ierr, strerr)
	if ierr==0 then
		scite.MenuCommand(IDM_REVERT)
	else
		print(strerr)
	end
end

local function vss_add()
	if vss_SetCurrentProject() then
		reset_err(shell.exec('"'..props['vsspath']..'\\ss.exe" Add "'..props['FileDir']..'\\'..props['FileNameExt']..'" -C-',nil,true,true))
	end
end

local function vss_getlatest()
	if vss_SetCurrentProject() then
		reset_err(shell.exec('"'..props['vsspath']..'\\ss.exe" Get '..props['FileNameExt'],nil,true,true))
	end
end

local function vss_undocheckout()
	if vss_SetCurrentProject() then
		reset_err(shell.exec('"'..props['vsspath']..'\\ss.exe" Undocheckout '..props['FileNameExt']..' -G-',nil,false,true))
	end
end

local function vss_checkout()
	if vss_SetCurrentProject() then
		local ierr, strerr=shell.exec('"'..props['vsspath']..'\\ss.exe" Diff '..props['FileNameExt'],nil,true,true)
		local stropt = ""
		if ierr == 1 then
			local rez = shell.msgbox("���� ���������� �� ����.\n�������� ������������ ����?","CheckOut",3)
			if rez ~= 2 then
			print(rez)
				if rez == 7 then
					stropt = " -G-"
				end
				ierr = 0
			end
		end
		if ierr == 0 then
			reset_err(shell.exec('"'..props['vsspath']..'\\ss.exe" Checkout '..props['FileNameExt']..stropt,nil,true,true))
		elseif ierr ~= 1 then
			print(strerr)
		end
	end
end

local function vss_diff()
	if vss_SetCurrentProject() then
		local ierr, strerr=shell.exec('"'..props['vsspath']..'\\ss.exe" Diff '..props['FileNameExt'],nil,true,true)
		if ierr==1 then

			local _, tmppath=shell.exec('CMD /c set TEMP',nil,true,true)
			tmppath=string.sub(tmppath,6,string.len(tmppath)-2)
			local cmd='"'..props['vsspath']..'\\ss.exe" Get '..props['FileNameExt']..' -GL"'..tmppath..'"'
			ierr, strerr=shell.exec(cmd,nil,true,true)
			if ierr~=0 then print(strerr) end
			ierr, strerr=shell.exec('CMD /c del /F "'..tmppath..'\\sstmp"',nil,true,true)
			if ierr~=0 then print(strerr) end
			ierr, strerr=shell.exec('CMD /c rename "'..tmppath..'\\'..props['FileNameExt']..'" sstmp',nil,true,true)
			if ierr~=0 then print(strerr) end
			cmd=string.gsub(string.gsub(props['vsscompare'],'%%bname','"'..tmppath..'\\sstmp"'),'%%yname','"'..props['FileDir']..'\\'..props['FileNameExt']..'"')
			shell.exec(cmd)
		else
			print(strerr)
		end
	end
end

local function vss_checkin()
	if vss_SetCurrentProject() then
		reset_err(shell.exec('"'..props['vsspath']..'\\ss.exe" Checkin '..props['FileNameExt']..' -C-',nil,true,true))
	end
end

local function vss_hist()
	if vss_SetCurrentProject() then
		local _, strerr = shell.exec('"'..props['vsspath']..'\\ss.exe" History '..props['FileNameExt'],nil,true,true)
		print(strerr)
	end
end

local function CreateVSSMenu()
    local t = {}

    local VSSContectMenu
    vss_SetCurrentProject()
    local ierr, strerr = shell.exec('"'..props['vsspath']..'\\ss.exe" Status '..props['FileNameExt'],nil,true,true)
    if ierr == 0 then -- �� ����
        t = {
            {'Check Out', action = vss_checkout ,},
            {'Get Latest Version', action = vss_getlatest ,},
            {'Diff', action = vss_diff ,},
            {'History', action = vss_hist ,},
        }
    elseif ierr == 1 then --����
        t = {
            {'Check In', action = vss_checkin ,},
            {'Undo Check Out', action = vss_undocheckout ,},
            {'Get Latest Version', action = vss_getlatest ,},
            {'Diff', action = vss_diff ,},
            {'History', action = vss_hist ,},
        }
    elseif ierr == 100 then --�����
        t = {
            {'Add', action = vss_add ,},
        }
    else
        print(strerr)
    end

    return t
end

menuhandler:InsertItem('TABBAR', '',
    {'VSS', visible=function() return shell.fileexists(props["FileDir"].."\\mssccprj.scc") end, CreateVSSMenu})

