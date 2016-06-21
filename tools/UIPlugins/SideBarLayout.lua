tbArgLeft = function()
return nil
        --return {
           --Pane{Pane{'functions', 'navigation', orientation="HORIZONTAL", name="splitFuncNav",  type='SPLIT'},  Pane{type="FIND"}, tabtitle = "Func/Nav", type='VBOX'},
            --Pane{'abbreviations', 'bookmark', orientation="HORIZONTAL", name="splitAbbrev", tabtitle = "Abbrev/Bmk", type="SPLIT"},
           -- Pane{'fileman', tabtitle = "FileMan"},
           -- Pane{'atrium', tabtitle = "Atrium", type= "VBOX"},"Atrium type= "VBOX"}, "Atrium type= "VBOX"}, "Atrium type= "VBOX"}, "Atrium
            --Pane{'bookmark', tabtitle = "Atrium", type= "VBOX"},type= "VBOX"},"Atriumtype= "VBOX"},"Atriumtype= "VBOX"},"Atrium
      -- }
end
tbArgRight = function()
        return {
            Pane{'functions', Pane{ type="FIND"}, tabtitle = "Func/Find", type='VBOX'},
            Pane{'abbreviations', Pane{'bookmark','navigation', orientation="HORIZONTAL", name="splitFuncNav",  type='SPLIT'}, orientation="HORIZONTAL", name="splitAbbrev", tabtitle = "Abbrev/Bmk/Nav", type="SPLIT"},
            Pane{'fileman', tabtitle = "FileMan"},
            Pane{'atrium', tabtitle = "Atrium", type= "VBOX"},
        }
end
