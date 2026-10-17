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
  uMiddlewareCORS,
  uRotasLogin,
  uRotasClientes,
  uRotasProdutos,
  uRotasEstoque,
  uRotasVendas,
  uRotasFinanceiro;

begin
  // Middleware global
  THorse.Use(@MiddlewareCORS);

  // Rotas públicas
  THorse.Post('/api/login', @RotaLogin);

  // Middleware JWT para rotas protegidas
  THorse.Use('/api', @MiddlewareJWT);

  // Registrar rotas
  RegistrarRotasClientes;
  RegistrarRotasProdutos;
  RegistrarRotasEstoque;
  RegistrarRotasVendas;
  RegistrarRotasFinanceiro;

  WriteLn('=== ERP 2026 API REST ===');
  WriteLn('Servidor iniciado na porta 9000');
  WriteLn('Endpoints disponíveis:');
  WriteLn('  POST /api/login');
  WriteLn('  GET/POST /api/clientes');
  WriteLn('  GET/POST /api/produtos');
  WriteLn('  GET/POST /api/estoque');
  WriteLn('  GET/POST /api/vendas');
  WriteLn('  GET/POST /api/financeiro');

  // Conecta ao Firebird uma unica vez para todo o servidor
  try
    TConexao.GetInstance.Conectar;
    WriteLn('Banco conectado: ', TConexao.GetInstance.Database);
  except
    on E: Exception do
      WriteLn('ATENCAO - falha ao conectar no banco: ', E.Message);
  end;

  THorse.Listen(9000);
end.
