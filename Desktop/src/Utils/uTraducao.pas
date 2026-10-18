unit uTraducao;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Idioma dos diálogos do LCL (português)
  ------------------------------------------------------------
  Os MessageDlg do LCL mostram botões e títulos em inglês
  ("Yes"/"No", "Confirmation", "Error") porque os
  resourcestrings do LCLStrConsts são em inglês por padrão.

  O mecanismo oficial do LCL é o LCLTranslator: um arquivo
  .po (aqui: lclstrconsts.pt_BR.po, o mesmo que vem com o
  Lazarus) traduz os resourcestrings por msgid na inicialização.

    SetDefaultLang('pt_BR', '', 'lclstrconsts')
      -> procura lclstrconsts.pt_BR.po ao lado do exe e
         aplica "&Yes" -> "&Sim", "Confirmation" -> "Confirmação" ...

  O arquivo .po é copiado para Desktop\bin\ pelo build_desktop.bat.
  Se o arquivo faltar, o sistema continua em inglês (sem erro).
  ============================================================ }

interface

{ Aplica o idioma português (diálogos do LCL). Retorna True se o
  arquivo de tradução foi encontrado e aplicado. }
function AplicarIdiomaPortugues: Boolean;

implementation

uses
  SysUtils, LCLTranslator;

function AplicarIdiomaPortugues: Boolean;
var
  LArquivo: string;
begin
  { 'lclstrconsts' = nome do arquivo de tradução (sem idioma/extensão);
    a pasta é a do próprio exe. ForceUpdate=False porque na prática
    nenhum form ainda foi criado quando isto roda. }
  LArquivo := SetDefaultLang('pt_BR', '', 'lclstrconsts', False);
  Result := LArquivo <> '';
end;

end.
