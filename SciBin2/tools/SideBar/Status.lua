local txtCol, txtSel, lblSel, txtLine
local isColor = false
local needCoding = false
local function ShowCurrentColour(pos, word)
	if pos ~= 0 then
		if word:match('%x%x%x%x%x%x') then
            local _,_,r,g,b= word:find('(%x%x)(%x%x)(%x%x)')
            lblSel.bgcolor = (('0x'..r)+0)..' '..(('0x'..g)+0)..' ' ..(('0x'..b)+0);isColor=true
		elseif word == 'RGB' then
            local le = editor:GetLine(editor:LineFromPosition(pos))     --[, ]+%)
            local f,_,r,g,b= le:find('RGB%( *([0-9]+)[, ]+([0-9]+)[, ]+([0-9]+)')
            if f then
                 lblSel.bgcolor = r..' '..g..' '..b ;isColor=true
            else
                f,_,r,g,b= le:find('RGB%( *&H(%x%x)[, ]+&H(%x%x)[, ]+&H(%x%x)')
                if f then
                    lblSel.bgcolor = (('0x'..r)+0)..' '..(('0x'..g)+0)..' ' ..(('0x'..b)+0) ;isColor=true
                end
            end
		elseif isColor then
            lblSel.bgcolor = iup.GetGlobal('DLGBGCOLOR') ;isColor=false
		end
    elseif isColor then
        lblSel.bgcolor = iup.GetGlobal('DLGBGCOLOR') ;isColor=false
	end
end

local function OnSwitch()
    local t = 1000000
    if editor.Lexer == SCLEX_FORMENJINE then
        t = 200
    end
    iup.GetGlobal('DLGBGCOLOR')
    scite.SendEditor(SCI_SETMOUSEDWELLTIME, t)
    needCoding = (scite.SendEditor(SCI_GETCODEPAGE) ~= 0)
end

local function _OnUpdateUI()
    if not editor.Focus then return end

    txtCol.value = scite.SendEditor(SCI_GETCOLUMN, editor.CurrentPos) + scite.SendEditor(SCI_GETSELECTIONNANCHORVIRTUALSPACE, 0) + 1
    txtSel.value = editor.SelectionEnd - editor.SelectionStart
    txtLine.value = editor:LineFromPosition(editor.CurrentPos) + 1
end
local zbox_s;
local function FindTab_Init()
    txtCol = iup.text{size='25x'; readonly='YES', bgcolor=iup.GetGlobal('DLGBGCOLOR')}
    txtSel = iup.text{size='25x'; readonly='YES', bgcolor=iup.GetGlobal('DLGBGCOLOR')}
    txtLine = iup.text{size='25x'; readonly='YES', bgcolor=iup.GetGlobal('DLGBGCOLOR')}
    lblSel = iup.text{size = '200x0'; readonly='YES', bgcolor=iup.GetGlobal('DLGBGCOLOR')}
    local function onSpellContext(_,but, pressed, x, y, status)
        if but == 51 and pressed == 0 then --right

            local mnu = iup.menu
            {
              iup.item{title="Проверить выделенный фрагмент",action=spell_Selected},
              iup.item{title="Проверить фрагмент с учетом подсветки",action=spell_ByLex},
              iup.item{title="Показать список ошибок",action=spell_ErrorList},
            }:popup(iup.MOUSEPOS,iup.MOUSEPOS)
        end
    end
    local sTip='Режим автоматической проверки\nорфографии(Ctrl+Alt+F12)'
    zbox_s = iup.zbox{
        iup.button{image='IMAGE_CheckSpelling2';impress='IMAGE_CheckSpelling'; tip=sTip;
            map_cb=(function(_) if props["spell.autospell"] == "1" then zbox_s.valuepos=1 else zbox_s.valuepos=0 end end);
            action=(function(_) props["spell.autospell"] = "1"; zbox_s.valuepos=1 end);
            button_cb=onSpellContext;
        };
        iup.button{image='IMAGE_CheckSpelling';impress='IMAGE_CheckSpelling2'; tip=sTip;
            action=(function(_) props["spell.autospell"] = "0"; zbox_s.valuepos=0 end);
            button_cb=onSpellContext;
        };
    }
    StatusBar_obj.Tabs.statusbar = {
        handle = iup.hbox{
            iup.label{title='Line: '; fontstyle='Bold'};   --sdfds esvdf
            txtLine;
            iup.label{title='Colimn: '; fontstyle='Bold'};   --sdfds esvdf
            txtCol;
            iup.label{title='Selection: '; fontstyle='Bold'};
            txtSel;
            lblSel;
            zbox_s;
            expand='HORIZONTAL', minsize='200x', alignment='ACENTER',gap='8',margin='3x0'
        };
        OnUpdateUI = _OnUpdateUI;
        OnDwellStart = ShowCurrentColour;
        OnOpen=OnSwitch;
        OnSwitchFile=OnSwitch;
        SetFindRes = (function(what,count)
                            if count > 0 then
                                if needCoding then what = what:from_utf8(1251) end
                                lblSel.value=what..'   :'..count..' entry'
                            else lblSel.value=''
                    end end)
        }

end

FindTab_Init()


