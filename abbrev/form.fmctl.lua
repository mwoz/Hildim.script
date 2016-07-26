local function frmControlPos(findSt, findEnd, s, dInd, replAbbr)
    --показываем диалог позиционировани€ контролов
    local dlg2 = _G.dialogs["ctrlgreator"]
    if dlg2 ~= nil then return end --один экземпл€р уже показан
    local tX, tW, tCpt, tA = {},{},{},{}
    local tX1, tW1, tCpt1, tA1 = {},{},{}, {}
    --создаем контролы
    local txtX2 = iup.list{size='60x0',dropdown="YES",editbox="YES",mask="/d+",visibleitems="15"}
    local txtY2 = iup.text{size='60x0',mask="/d+"}
    local txtH2 = iup.text{size='60x0',mask="/d+"}
    local txtW2 = iup.list{size='60x0',dropdown="YES",editbox="YES",mask="/d+",visibleitems="15"}

    local _,_, ctype = s:find('type="(%l+)"')
    local txtCp = iup.list{size='60x0',dropdown="YES",editbox="YES",mask="/d+",visibleitems="15"}
    local function onCmbAll(h)
        if tA1 == nil then return end
        if #tA1 == 0 then return end
        txtX2.value = tA1[tonumber(h.value)][2][1]
        txtW2.value = tA1[tonumber(h.value)][2][2]
        txtCp.value = tA1[tonumber(h.value)][2][3]
    end
    local cmbAll = iup.list{size='60x0',dropdown="YES",visibleitems="15",valuechanged_cb = onCmbAll}
    local function onTxtX2(h,text, item, state)
            local n = tonumber(text)
            for i, s in pairs(tA1) do if tonumber(s[2][1]) >= n then cmbAll.value=i;break;end end
        end
    txtX2.action = onTxtX2
    local txtDx = iup.text{size='35x0',mask="/d+"}
    local bDdx = s:find('tag="ddx_Enabled=Y"')
    local cmbDdx = iup.list{dropdown="YES",visibleitems="5",active=Iif(bDdx, 'YES', 'NO'), value=Iif(bDdx, _G.iuprops['abbrev.ctrldlg.ddx'] or 0, 0)}
    iup.SetAttribute(cmbDdx, 1, '')
    iup.SetAttribute(cmbDdx, 2, 'ddx_Enabled')
    iup.SetAttribute(cmbDdx, 3, 'ddx_MetaBind')
    --найдем в тексте все контролы и извлечем из них все горизонтальные координаты - дл€ выбора
    local b,e = 0,-1
    local body
    while true do
        b,e,body = editor:findtext('<control \\(.+?\\)>', SCFIND_REGEXP, e + 1)
        if not b then break end
        body = editor:textrange(b,e)
        local xI, wI, cI = 0,0,0
        --сначала пишем в имена - дл€ избежани€ дублировани€
        body:gsub('position="(%d+);%d+;(%d+);%d+"', function(x,w) xI=x; wI=w; tX[x] = tonumber(x); tW[w] = tonumber(w) end)
        body:gsub('captionwidth="(%d+)"', function(cp)
            cI = cp
            tCpt[cp] = tonumber(cp)
            local l = tonumber(cp) + tonumber(xI)
            tX[''..l] = l
            l = tonumber(wI) - tonumber(cp)
            tW[''..l] = l
        end)
        if tonumber(xI) > 0 and tonumber(wI) > 0 then tA[xI..','..wI..','..cI] = {xI, wI, cI} end
    end
    --перепишем все таблицы по индексам и отсортируем
    for s, i in pairs(tX) do table.insert(tX1,i) end
    for s, i in pairs(tW) do table.insert(tW1,i) end
    for s, i in pairs(tCpt) do table.insert(tCpt1,i) end
    for i, t in pairs(tA) do table.insert(tA1,{i,t}) end

    table.sort(tX1)
    table.sort(tW1)
    table.sort(tCpt1)
    table.sort(tA1,function(a,b)
        local ta,tb = a[2], b[2]
        if ta[1] == tb[1] then
            if ta[2] == tb[2] then
                return tonumber(ta[3])<tonumber(tb[3])
            else
                return tonumber(ta[2])<tonumber(tb[2])
            end
        else
            return tonumber(ta[1])<tonumber(tb[1])
        end
    end)

    --заполним списки комбобоксов
    local l = 1
    for i, s in pairs(tX1) do if tonumber(s) > 0 then iup.SetAttribute(txtX2, l, s);l=l+1 end end
    l = 1
    for i, s in pairs(tW1) do if tonumber(s) > 0 then iup.SetAttribute(txtW2, l, s);l=l+1 end end
    l = 1
    for i, s in pairs(tCpt1) do if tonumber(s) > 0 then iup.SetAttribute(txtCp, l, s);l=l+1 end end
    for i, s in pairs(tA1) do iup.SetAttribute(cmbAll, i, s[1]) end
    txtX2.value=1;txtW2.value=1;txtCp.value=1;cmbAll.value=1


    local i,str
    txtH2.value = _G.iuprops['abbrev.ctrldlg.h'] or '11'
    txtDx.value = _G.iuprops['abbrev.ctrldlg.dh'] or '1'
    i,i,txtX2.value,txtY2.value,txtW2.value=s:find('position="(%d+);(%d+);(%d+);%d+"')
    i,i,str=s:find('captionwidth="(%d+)"')
    local bIsRef = (nil ~= s:find('name="btn1"'))
    if i == nil and not bIsRef then
        txtCp.value=''
        txtCp.active='NO'
    else
        txtCp.active='YES'
        txtCp.value=str
    end

    --найдем предыдущий контрол и по нему выставим координаты в нашем
    local icL = editor:LineFromPosition(editor.CurrentPos)

    local onSameLine = true
    local iDepth = 0
    for i = icL - 1, 1, -1 do
        local x,y,w
        local sl = editor:GetLine(i)
        if sl:find('^%s+$') then
            onSameLine = false --считаем, что если предыдуща€ строка пуста, то контрол на новой строке
        elseif sl:find('<frame ') then
            break
        elseif sl:find('</control>') then
            iDepth = iDepth + 1
        elseif sl:find('<control ') then
            if not sl:find('/>') then iDepth = iDepth - 1 end
            if iDepth == 0 then
                local _,_,x,y,w,h = sl:find('position="(%d+);(%d+);(%d+);(%d+)"')
                if onSameLine then
                    txtY2.value = y
                    txtX2.value = ''..(tonumber(x or 0) + tonumber(w or 0))
                else
                    txtY2.value = '' ..(tonumber(y or 0) + tonumber(h or 0) + tonumber(txtDx.value or 0))
                end
                break
            end
        end
    end
    onTxtX2(txtX2,txtX2.value, nil, nil)
    onCmbAll(cmbAll)
    ---

    local btn_ok = iup.button  {title="OK"}
    iup.SetHandle("CREATE_BTN_OK",btn_ok)
    local btn_esc = iup.button  {title="Cancel"}
    iup.SetHandle("CREATE_BTN_ESC",btn_esc)
    local btn_clear = iup.button  {title="Clear"}
    iup.SetHandle("CREATE_BTN_CLEAR",btn_clear)

    local vbox = iup.vbox{
        iup.hbox{iup.label{size='60x0'},cmbAll,iup.label{title='dH'},txtDx,iup.fill{}, cmbDdx,gap=20};
        iup.hbox{gap=20, alignment='ACENTER',
            iup.label{title="Left",size='60x0'},
            iup.label{title="Top",size='60x0'},
            iup.label{title="Width",size='60x0'},
            iup.label{title="Height",size='60x0'},
            iup.label{title="CptWidth",size='60x0'}
        };
        iup.hbox{txtX2,txtY2,txtW2,txtH2,txtCp,gap=20, alignment='ACENTER'};
        iup.hbox{btn_ok,iup.fill{},btn_clear,btn_esc},gap=2,margin="4x4" }

    dlg2 = iup.scitedialog{vbox; title=" онтрол √ритер",defaultenter="CREATE_BTN_OK",defaultesc="CREATE_BTN_ESC",maxbox="NO",minbox ="NO",resize ="NO",
    sciteparent="SCITE", sciteid="ctrlgreator"}
    dlg2.show_cb=(function(h,state)
        if state == 4 then
            dlg2:postdestroy()
        end
    end)
    function btn_clear:action()
            txtX2.value = ''
            txtY2.value = ''
            txtH2.value = ''
            txtW2.value = ''
            txtCp.value = ''
    end

    function btn_ok:action()

        s = s:gsub('position="%d+;%d+;%d+;%d+"', 'position="'..txtX2.value..';'..txtY2.value..';'..txtW2.value..';'..txtH2.value ..'"', 1):gsub('ЛFMCTLЫ', '')
        local bNoCapt = false
        if txtCp.active=='YES' then s = s:gsub('captionwidth="%d+"',
        function()
            if txtCp.value == '0' then
                txtCp.value = true
                return ''
            end
            return 'captionwidth="'..txtCp.value..'"'
        end) end
        if tonumber(txtCp.value) == 0 and (ctype ~= 'button' and ctype ~= 'label' and ctype ~= 'link' and ctype ~= 'checkbox') then
            s = s:gsub(' caption=".-"', ''):gsub(' caption_ru=".-"', '')
        end
        if bDdx then
            if cmbDdx.value == '1' then s = s:gsub('tag="ddx_Enabled=Y"', '') end
            if cmbDdx.value == '3' then s = s:gsub('"ddx_Enabled=', '"ddx_MetaBind=') end
            if cmbDdx.value ~= '3' then s = s:gsub(' style="F"', '') end
            _G.iuprops['abbrev.ctrldlg.ddx'] = cmbDdx.value
        end
        _G.iuprops['abbrev.ctrldlg.h'] = txtH2.value
        _G.iuprops['abbrev.ctrldlg.dh'] = txtDx.value

        replAbbr(findSt, findEnd, s, dInd)
        dlg2:postdestroy()
    end

    function btn_esc:action()
        dlg2:postdestroy()
    end
end

return frmControlPos
