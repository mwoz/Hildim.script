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
local VSSContectMenuU =
	"||"..
	"VSS|POPUPBEGIN|"..
	"Check Out|9151|"..
	"Get Latest Version|9154|"..
	"Diff|9155|"..
	"History|9157|"..
	"VSS|POPUPEND|"
local VSSContectMenuC =
	"||"..
	"VSS|POPUPBEGIN|"..
	"Check In|9152|"..
	"Undo Check Out|9153|"..
	"Get Latest Version|9154|"..
	"Diff|9155|"..
	"History|9157|"..
	"VSS|POPUPEND|"
local VSSContectMenuN =
	"||"..
	"VSS|POPUPBEGIN|"..
	"Add|9156|"..
	"VSS|POPUPEND|"

local function update_vss_menu()
	local menu = props["user.tabcontext.menu.*"]
    local isVSS = false
    local filedir = props["FileDir"]
	-- test SVN context
	isVSS = shell.fileexists(filedir.."\\mssccprj.scc")
    -- no VSS context
    if string.find(menu,"||VSS|") then
        props["user.tabcontext.menu.*"] = string.gsub(menu, "||VSS|.*", "")
        menu = props["user.tabcontext.menu.*"]
    end
    if isVSS then
        local VSSContectMenu
		vss_SetCurrentProject()
        local ierr, strerr = shell.exec('"'..props['vsspath']..'\\ss.exe" Status '..props['FileNameExt'],nil,true,true)
        if ierr == 0 then -- не взят
            VSSContectMenu = VSSContectMenuU
        elseif ierr == 1 then --взят
            VSSContectMenu = VSSContectMenuC
        elseif ierr == 100 then --новый
            VSSContectMenu = VSSContectMenuN
        else
            print(strerr)
            return
        end
		props["user.tabcontext.menu.*"] = menu..VSSContectMenu
    end
end

local function reset_err(ierr, strerr)
	if ierr==0 then
		scite.MenuCommand(IDM_REVERT)
		update_vss_menu()
	else
		print(strerr)
	end
end

function vss_add()
	if vss_SetCurrentProject() then
		reset_err(shell.exec('"'..props['vsspath']..'\\ss.exe" Add "'..props['FileDir']..'\\'..props['FileNameExt']..'" -C-',nil,true,true))
	end
end

function vss_getlatest()
	if vss_SetCurrentProject() then
		reset_err(shell.exec('"'..props['vsspath']..'\\ss.exe" Get '..props['FileNameExt'],nil,true,true))
	end
end

function vss_undocheckout()
	if vss_SetCurrentProject() then
		reset_err(shell.exec('"'..props['vsspath']..'\\ss.exe" Undocheckout '..props['FileNameExt']..' -G-',nil,false,true))
	end
end

function vss_checkout()
	if vss_SetCurrentProject() then
		local ierr, strerr=shell.exec('"'..props['vsspath']..'\\ss.exe" Diff '..props['FileNameExt'],nil,true,true)
		local stropt = ""
		if ierr == 1 then
			local rez = shell.msgbox("Файл отличается от базы.\nЗаменить существующий файл?","CheckOut",3)
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

function vss_diff()
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

function vss_checkin()
	if vss_SetCurrentProject() then
		reset_err(shell.exec('"'..props['vsspath']..'\\ss.exe" Checkin '..props['FileNameExt']..' -C-',nil,true,true))
	end
end

function vss_hist()
	if vss_SetCurrentProject() then
		local _, strerr = shell.exec('"'..props['vsspath']..'\\ss.exe" History '..props['FileNameExt'],nil,true,true)
		print(strerr)
	end
end

-- Добавляем свой обработчик события OnOpen
AddEventHandler("OnOpen", update_vss_menu)

-- Добавляем свой обработчик события OnSwitchFile
AddEventHandler("OnSwitchFile", update_vss_menu)
