unit uMiddlewareConexao;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - API - Devolucao da conexao ao pool
  ------------------------------------------------------------
  O pool da API tem afinidade por thread: cada requisicao pega a
  conexao da thread e, sem devolver, ela fica reservada ate a thread
  morrer (o que mantem uma transacao aberta entre requisicoes no
  mesmo keep-alive).

  Este middleware envolve a requisicao inteira: depois que a rota
  responde (ou falha), a conexao da thread volta ao pool. O
  TConexao.Destroy faz Rollback de qualquer transacao pendente e
  fecha a conexao, entao a proxima requisicao comeca limpa.
  ============================================================ }

interface

uses
  Horse;

procedure MiddlewareConexao(Req: THorseRequest; Res: THorseResponse;
  Next: TNextProc);

implementation

uses
  uConexao;

procedure MiddlewareConexao(Req: THorseRequest; Res: THorseResponse;
  Next: TNextProc);
begin
  try
    Next;
  finally
    { idempotente: se a rota nao usou o banco, nao ha vaga para devolver }
    TConexao.DevolverAtual;
  end;
end;

end.
