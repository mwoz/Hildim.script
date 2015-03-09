require"lpeg"

local function Show()


    local btn_tst = iup.button  {title="Test"}
    iup.SetHandle("EDIT_BTN_TEST",btn_tst)

    local txt_exp = iup.text{multiline='YES',wordwrap='YES', expand='YES', fontsize='12'}

    local vbox = iup.vbox{
        iup.hbox{iup.vbox{txt_exp}};

        iup.hbox{btn_tst},
        expandchildren ='YES',gap=2,margin="4x4"}
    local dlg = iup.scitedialog{vbox; title="lpegTester",defaultenter="MOVE_BTN_OK",defaultesc="MOVE_BTN_ESC",tabsize=editor.TabWidth,
        maxbox="NO",minbox ="NO",resize ="YES",shrink ="YES",sciteparent="SCITE", sciteid="abbreveditor", minsize='600x300'}

    dlg.show_cb=(function(h,state)
        if state == 4 then
            dlg:postdestroy()
        end
    end)

    function btn_tst:action()
        local s = 'local P, V, Cg, Ct, Cc, S, R, C, Carg, Cf, Cb, Cp, Cmt = lpeg.P, lpeg.V, lpeg.Cg, lpeg.Ct, lpeg.Cc, lpeg.S, lpeg.R, lpeg.C, lpeg.Carg, lpeg.Cf, lpeg.Cb, lpeg.Cp, lpeg.Cmt\n'
        s = s..txt_exp.value
        local patt = dostring(s)
        --print(editor:GetText())
        debug_prnArgs(patt:match(editor:GetText(),1))
    end

end

Show()
