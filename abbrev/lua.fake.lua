local function frmControlPos(findSt, findEnd, s, dInd, func_replAbbr)
    --���������� ������ ���������������� ���������
    --findSt - ������� ������ ���������� � ������
    --findEnd - ������� ����� ���������� � ������
    --s - ����� �������.
    --dInd ������� ������ ���������� � ������
    --func_replAbbr - �������, ������� �� ������ ������� � ����������� �����������, ��������� ������ ������� � ������������ � �������������
    local dlg2 = _G.dialogs["ctrlgreator"]
    if dlg2 ~= nil then return end --���� ��������� ��� �������

    local txtY2 = iup.text{size='60x0'}

    local btn_ok = iup.button  {title="OK"}
    iup.SetHandle("CREATE_BTN_OK", btn_ok)
    local btn_esc = iup.button  {title="Cancel"}
    iup.SetHandle("CREATE_BTN_ESC",btn_esc)


    local vbox = iup.vbox{
        iup.hbox{txtY2,gap=20, alignment='ACENTER'};
        iup.hbox{btn_ok,iup.fill{},btn_esc},gap=2,margin="4x4" }

    dlg2 = iup.scitedialog{vbox; title = "������ ����������� �����������", maxbox = "NO", minbox = "NO",resize ="NO",
    sciteparent = "SCITE", sciteid = "fake_test"}
    dlg2.show_cb=(function(h,state)
        if state == 4 then
            dlg2:postdestroy()
        end
    end)

    function btn_ok:action()
        s = s:gsub('==INPUT==', txtY2.value)
        func_replAbbr(findSt, findEnd, s, dInd)
        dlg2:postdestroy()
    end

    function btn_esc:action()
        dlg2:postdestroy()
    end
end

return frmControlPos
