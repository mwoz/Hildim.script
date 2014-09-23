/*
Recode
Version: 1.1
Author: mozers
------------------------------------------------
��������� ���� win1251 � ��������� ���������
��� ����������� ��������� ��������� ����� � win1251
������ �����������:
   command.name.21.*=��������� ���� WIN-1251 � ��������� KOI-8
   command.21.*=WSCRIPT "$(SciteDefaultHome)\tools\Recode.js" koi8 save
   command.mode.21.*=subsystem:windows,savebefore:no,quiet:yes

   command.name.25.*=������������� �������� ���� �� ��������� DOS866 � WIN-1251
   command.25.*=WSCRIPT "$(SciteDefaultHome)\tools\Recode.js" cp866
   command.mode.25.*=subsystem:windows,savebefore:no,quiet:yes

��������� ��� ������ �� ��������� ����������� � ��������� ������� HKEY_CLASSES_ROOT\MIME\Database\Charset
*/

var WshShell = new ActiveXObject("WScript.Shell");
var fso = new ActiveXObject("Scripting.FileSystemObject");
var stream = new ActiveXObject("ADODB.Stream");

try {
	var SciTE=new ActiveXObject("SciTE.Helper");
} catch(e) {
	WScript.Echo("Please install SciTE Helper before!");
	WScript.Quit(1);
}

function Recode(text_in, charset_in, charset_out){
	stream.Open();
	stream.Type = 2;
	stream.Charset = charset_out;
	stream.WriteText(text_in);
	stream.Flush();
	stream.Position = 0;
	stream.Charset = charset_in;
	var text_out = stream.ReadText(-1);
	stream.Close();
	return (text_out);
}

function WriteFile( filename, text){
	var f = fso.OpenTextFile(filename, 2, true);
	f.Write(text);
	f.Close();
	return (true);
}

var Args = WScript.Arguments;
var encode = Args(0);
var all_text = SciTE.GetText;
var filename = SciTE.Props ("FilePath");
var out;
if (Args.length > 1){
	var src_code = SciTE.Props ("code.page.name");
	if (src_code != "WIN-1251") {
		WScript.Echo("�������� ��������� ������ ������� �� windows-1251.\n������������� ����������!");
		WScript.Quit(1);
	}
	out = Recode(all_text, "windows-1251", encode);
	WriteFile(filename, out);
}else{
	out = Recode(all_text, encode, "windows-1251");
	SciTE.Send("menucommand:207"); //IDM_SELECTALL
	SciTE.ReplaceSel(out);
}
