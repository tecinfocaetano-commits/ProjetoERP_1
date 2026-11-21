program ERP2026API;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - FASE 7 - API REST com Horse Framework
  Descrição: Servidor de API REST para integração
  Porta padrão: 9000
  ============================================================ }

uses
  SysUtils,
  Horse,
  uConexao,
  uMiddlewareJWT,
  uMiddlewareSessao,
  uMiddlewareCORS,
  uMiddlewareConexao,
  uRotasLogin,
  uRotasClientes,
  uRotasProdutos,
  uRotasEstoque,
  uRotasVendas,
  uRotasOrcamentos,
  uRotasFinanceiro,
  uRotasProducao,
  uRotasPDV;

function JsonTexto(const ATexto: string): string;
begin
  Result := StringReplace(ATexto, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
  Result := StringReplace(Result, #13, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
end;

procedure RotaHealth(Req: THorseRequest; Res: THorseResponse);
var
  LMensagem: string;
  LBancoOk: Boolean;
begin
  LMensagem := '';
  LBancoOk := False;
  try
    { GetInstance ja pinga o banco e renova a conexao se ela estiver morta.
      Antes o health so lia Connection.Connected e podia dizer "ok" com o
      banco inacessivel. }
    TConexao.GetInstance;
    LBancoOk := True;
  except
    on E: Exception do LMensagem := E.Message;
  end;

  if LBancoOk then
    Res.Send('{"status":"ok","servico":"ERP2026API","banco":"ok","pool":"' +
      TConexao.PoolDescricao + '"}').Status(THTTPStatus.OK)
  else
    Res.Send('{"status":"erro","servico":"ERP2026API","banco":"' +
      JsonTexto(LMensagem) + '","pool":"' + TConexao.PoolDescricao + '"}')
      .Status(THTTPStatus.ServiceUnavailable);
end;

var
  LBanco: string;

begin
  // Em producao, recusa subir com o segredo JWT padrao de desenvolvimento.
  try
    ValidarConfiguracaoJWT;
  except
    on E: Exception do
    begin
      WriteLn(ErrOutput, 'ERRO de configuracao: ', E.Message);
      Halt(2);
    end;
  end;

  // Middleware global
  THorse.Use(@MiddlewareCORS);
  // Devolve a conexao da thread ao pool ao fim de cada requisicao
  THorse.Use(@MiddlewareConexao);

  // Rotas publicas
  THorse.Get('/api/health', @RotaHealth);
  THorse.Post('/api/login', @RotaLogin);

  // Middleware JWT para rotas protegidas
  THorse.Use('/api', @MiddlewareJWT);
  // D3: contexto da sessao por thread para os Services reutilizados
  THorse.Use('/api', @MiddlewareSessao);

  // Registrar rotas
  RegistrarRotasClientes;
  RegistrarRotasProdutos;
  RegistrarRotasEstoque;
  RegistrarRotasVendas;
  RegistrarRotasOrcamentos;
  RegistrarRotasFinanceiro;
  RegistrarRotasProducao;
  RegistrarRotasPDV;

  WriteLn('=== ERP 2026 API REST ===');
  WriteLn('Servidor iniciado na porta 9000');
  WriteLn('Endpoints disponíveis:');
  WriteLn('  GET  /api/health');
  WriteLn('  POST /api/login');
  WriteLn('  GET/POST/PUT/DELETE /api/clientes');
  WriteLn('  GET/POST /api/produtos, PUT/DELETE /api/produtos/:id');
  WriteLn('  GET/POST /api/estoque');
  WriteLn('  GET/POST /api/vendas');
  WriteLn('  GET/POST /api/orcamentos, PUT/DELETE /api/orcamentos/:id');
  WriteLn('  POST /api/orcamentos/:id/converter');
  WriteLn('  GET/POST /api/financeiro');
  WriteLn('  POST /api/producao/bipar');
  WriteLn('  GET/POST /api/pdv (status, caixa, produtos, vendas)');

  // Primeira conexao (do thread principal) sinaliza que o banco esta no ar;
  // as requisicoes usam cada uma a sua conexao tirada do pool
  try
    TConexao.GetInstance.Conectar;
    LBanco := TConexao.GetInstance.Database;
    WriteLn('Banco conectado: ', LBanco);
    // cada thread de requisicao recebe a propria conexao (pool com afinidade
    // por thread; tamanho via variavel de ambiente ERP_API_POOL)
    WriteLn('Pool de conexoes: ', TConexao.PoolDescricao);
    // libera a vaga do thread principal: quem usa o banco sao as requisicoes
    TConexao.DevolverAtual;
  except
    on E: Exception do
      WriteLn('ATENCAO - falha ao conectar no banco: ', E.Message);
  end;

  THorse.Listen(9000);
end.
