tbArg = function()
        return {
            Pane{'functions', Pane{ type="FIND"}, tabtitle = "Func/Find", type='VBOX'},
            Pane{'abbreviations', Pane{'bookmark','navigation', orientation="HORIZONTAL", name="splitFuncNav",  type='SPLIT'}, orientation="HORIZONTAL", name="splitAbbrev", tabtitle = "Abbrev/Bmk/Nav", type="SPLIT"},
            Pane{'fileman', tabtitle = "FileMan"},
            Pane{'atrium', tabtitle = "Atrium", type= "VBOX"},
        }
end
