unit uPermissaoUI;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Permissoes aplicadas na interface (T1)
  ------------------------------------------------------------
  Regras:
    - o modulo/tela vem do catalogo canonico (uPermissao.CATALOGO_TELAS),
      resolvido pelo nome da classe do form;
    - a acao negada deixa o controle desabilitado e o botao nao faz
      nada (a tela ainda avisa se o usuario insistir);
    - administrador tem acesso total (herdado de uPermissao).
  ============================================================ }

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, uPermissao;

{ Devolve o modulo e a tela do form a partir do catalogo. Devolve
  False quando a tela nao esta no catalogo (sem protecao). }
function ResolverPermissaoTela(AForm: TForm; out AModulo,
  ATela: string): Boolean;

{ Habilita/desabilita os controles informados conforme a permissao da
  acao ('VISUALIZAR', 'INSERIR', 'EDITAR', 'EXCLUIR', 'IMPRIMIR').
  Devolve True quando o usuario pode a acao. }
function AplicarPermissaoAcao(AForm: TForm; const AAcao: string;
  const AControles: array of string): Boolean;

{ Mesmo que acima, mas com uma mensagem amigavel quando a acao for
  bloqueada (o botao fica desabilitado, mas a mensagem explica). }
function PodeExecutarAcao(AForm: TForm; const AAcao, AMensagem: string;
  const AControles: array of string): Boolean;

implementation

function ResolverPermissaoTela(AForm: TForm; out AModulo,
  ATela: string): Boolean;
begin
  AModulo := '';
  ATela := '';
  if AForm = nil then
    Exit(False);
  Result := PermissaoDaTela(AForm.ClassName, AModulo, ATela);
end;

function AplicarPermissaoAcao(AForm: TForm; const AAcao: string;
  const AControles: array of string): Boolean;
var
  I: Integer;
  LModulo, LTela: string;
  LPermitido: Boolean;
  LControle: TComponent;
begin
  Result := True;
  if not ResolverPermissaoTela(AForm, LModulo, LTela) then
    Exit;

  LPermitido := TemPermissao(LModulo, LTela, AAcao);
  Result := LPermitido;
  for I := Low(AControles) to High(AControles) do
  begin
    LControle := AForm.FindComponent(AControles[I]);
    if (LControle <> nil) and (LControle is TControl) then
      TControl(LControle).Enabled := LPermitido;
  end;
end;

function PodeExecutarAcao(AForm: TForm; const AAcao, AMensagem: string;
  const AControles: array of string): Boolean;
begin
  Result := AplicarPermissaoAcao(AForm, AAcao, AControles);
  if (not Result) and (AMensagem <> '') then
    MessageDlg(AMensagem, mtWarning, [mbOK], 0);
end;

end.
