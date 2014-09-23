var scite = "F:\\Program Files (x86)\\Scite\\SciTE.exe";
var WshShell = new ActiveXObject("WScript.Shell");
var filename = WScript.Arguments(0);
var opt = '-check.if.already.open=0 "-loadsession:' + filename.replace(/\\/g,"\\\\") + '"';
var cmd = '"' + scite + '" ' + opt;
WshShell.Run(cmd, 0, false);

