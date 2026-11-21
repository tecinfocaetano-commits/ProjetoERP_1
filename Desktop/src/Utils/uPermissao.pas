unit uPermissao;

{$mode objfpc}{$H+}

{ ============================================================
  ERP 2026 - Permissões por módulo/tela/ação
  ------------------------------------------------------------
  Usa a tabela PERMISSAO (GRUPO_ID, MODULO, TELA, PODE_*), que já
  existia no banco mas não era consultada por nenhuma tela.

  Regras:
    - usuário com USUARIO.ADMINISTRADOR = 'S' tem acesso total;
    - sem registro de permissão para o grupo => acesso negado
      (seguro por padrão);
    - qualquer erro de banco => acesso negado (não libera por falha).
  ============================================================ }

interface

uses
  SysUtils;

type
  EPermissaoNegada = class(Exception);

  { Uma tela do ERP e a permissão que a protege. O catálogo é a fonte
    única: o menu, a guarda de abertura e o seed do banco usam esta
    lista, então nenhuma tela nova pode "escapar" da checagem. }
  TTelaPermissao = record
    FormClass: string;   { nome da classe do form, ex.: 'TfrmPessoas' }
    Modulo: string;
    Tela: string;
    Descricao: string;
  end;

const
  PERM_VISUALIZAR = 'VISUALIZAR';
  PERM_INSERIR    = 'INSERIR';
  PERM_EDITAR     = 'EDITAR';
  PERM_EXCLUIR    = 'EXCLUIR';
  PERM_IMPRIMIR   = 'IMPRIMIR';

{ Módulo/telas do módulo de Produção (espelham o script 012) }
  MODULO_PRODUCAO       = 'PRODUCAO';
  TELA_MAPA_PRODUCAO    = 'MAPA_PRODUCAO';
  TELA_BIPAGEM          = 'BIPAGEM';
  TELA_CONSUMO          = 'CONSUMO';
  TELA_FICHA_TECNICA    = 'FICHA_TECNICA';

{ Módulo/telas das telas de administração abertas pelo menu principal
  (seed em Banco\013_telas_administracao.sql) }
  MODULO_SISTEMA          = 'SISTEMA';
  TELA_CONFIGURACOES      = 'CONFIGURACOES';
  TELA_PERMISSOES         = 'PERMISSOES';
  MODULO_FINANCEIRO       = 'FINANCEIRO';
  TELA_CAIXA              = 'CAIXA';
  MODULO_RELATORIOS       = 'RELATORIOS';
  TELA_CENTRAL_RELATORIOS = 'CENTRAL_RELATORIOS';

{ Módulos dos demais blocos do menu (T1) }
  MODULO_CADASTROS     = 'CADASTROS';
  MODULO_ESTOQUE       = 'ESTOQUE';
  MODULO_VENDAS        = 'VENDAS';
  MODULO_FISCAL        = 'FISCAL';
  MODULO_SUPRIMENTOS   = 'SUPRIMENTOS';
  MODULO_PDV           = 'PDV';
  MODULO_IA            = 'IA';

{ Catálogo canônico: uma linha por tela do menu principal. A ordem
  segue o menu (Suprimentos, Produção, Financeiro, Fiscal, Cadastros,
  Estoque, PDV, Relatórios, IA, Sistema). }
  CATALOGO_TELAS: array[0..32] of TTelaPermissao = (
    (FormClass: 'TfrmMaterial';        Modulo: MODULO_SUPRIMENTOS; Tela: 'MATERIAIS';         Descricao: 'Suprimentos > Materiais'),
    (FormClass: 'TfrmCompras';         Modulo: MODULO_SUPRIMENTOS; Tela: 'COMPRAS';          Descricao: 'Suprimentos > Compras'),
    (FormClass: 'TfrmConsumoMaterial';  Modulo: MODULO_SUPRIMENTOS; Tela: TELA_CONSUMO;      Descricao: 'Suprimentos > Consumo de Materiais'),
    (FormClass: 'TfrmProdutos';         Modulo: MODULO_CADASTROS;   Tela: 'PRODUTOS';         Descricao: 'Produção > Produto Produção'),
    (FormClass: 'TfrmPedidoVenda';      Modulo: MODULO_VENDAS;      Tela: 'PEDIDO_VENDA';      Descricao: 'Produção > Novo Pedido'),
    (FormClass: 'TfrmOrcamento';        Modulo: MODULO_VENDAS;      Tela: 'ORCAMENTO';        Descricao: 'Produção > Novo Orçamento'),
    (FormClass: 'TfrmListaPedidos';     Modulo: MODULO_VENDAS;      Tela: 'LISTA_PEDIDOS';    Descricao: 'Produção > Lista de Pedidos'),
    (FormClass: 'TfrmMapaProducao';     Modulo: MODULO_PRODUCAO;   Tela: TELA_MAPA_PRODUCAO; Descricao: 'Produção > Mapa de Produção'),
    (FormClass: 'TfrmBipagem';          Modulo: MODULO_PRODUCAO;   Tela: TELA_BIPAGEM;      Descricao: 'Produção > Bipagem de Talões'),
    (FormClass: 'TfrmFichaTecnica';     Modulo: MODULO_PRODUCAO;   Tela: TELA_FICHA_TECNICA; Descricao: 'Produção > Ficha Técnica'),
    (FormClass: 'TfrmContasReceber';    Modulo: MODULO_FINANCEIRO;  Tela: 'CONTAS_RECEBER';   Descricao: 'Financeiro > Contas a Receber'),
    (FormClass: 'TfrmContasPagar';      Modulo: MODULO_FINANCEIRO;  Tela: 'CONTAS_PAGAR';     Descricao: 'Financeiro > Contas a Pagar'),
    (FormClass: 'TfrmCaixa';            Modulo: MODULO_FINANCEIRO;  Tela: TELA_CAIXA;        Descricao: 'Financeiro > Caixa'),
    (FormClass: 'TfrmProdutoFiscal';    Modulo: MODULO_FINANCEIRO;  Tela: 'PRODUTO_FISCAL';   Descricao: 'Financeiro > Produto Fiscal'),
    (FormClass: 'TfrmMovimentoFinanceiro'; Modulo: MODULO_FINANCEIRO; Tela: 'MOVIMENTACAO';  Descricao: 'Financeiro > Movimentação Financeira'),
    (FormClass: 'TfrmNotaSaida';        Modulo: MODULO_FISCAL;      Tela: 'NOTA_SAIDA';       Descricao: 'Fiscal > Nota de Saída'),
    (FormClass: 'TfrmNotaEntrada';      Modulo: MODULO_FISCAL;      Tela: 'NOTA_ENTRADA';     Descricao: 'Fiscal > Nota de Entrada'),
    (FormClass: 'TfrmNFe';              Modulo: MODULO_FISCAL;      Tela: 'NFE';             Descricao: 'Fiscal > NF-e / NFC-e'),
    (FormClass: 'TfrmPessoas';          Modulo: MODULO_CADASTROS;   Tela: 'PESSOAS';          Descricao: 'Cadastros > Pessoas'),
    (FormClass: 'TfrmCategorias';       Modulo: MODULO_CADASTROS;   Tela: 'CATEGORIAS';       Descricao: 'Cadastros > Categorias'),
    (FormClass: 'TfrmGrade';            Modulo: MODULO_CADASTROS;   Tela: 'GRADES';           Descricao: 'Cadastros > Grades'),
    (FormClass: 'TfrmPais';             Modulo: MODULO_CADASTROS;   Tela: 'PAISES';           Descricao: 'Cadastros > Países'),
    (FormClass: 'TfrmEstado';           Modulo: MODULO_CADASTROS;   Tela: 'ESTADOS';          Descricao: 'Cadastros > Estados'),
    (FormClass: 'TfrmCidade';           Modulo: MODULO_CADASTROS;   Tela: 'CIDADES';          Descricao: 'Cadastros > Cidades'),
    (FormClass: 'TfrmUsuarios';         Modulo: MODULO_CADASTROS;   Tela: 'USUARIOS';         Descricao: 'Cadastros > Usuários'),
    (FormClass: 'TfrmMovEstoque';       Modulo: MODULO_ESTOQUE;     Tela: 'MOVIMENTACAO';     Descricao: 'Estoque > Movimentação'),
    (FormClass: 'TfrmInventario';       Modulo: MODULO_ESTOQUE;     Tela: 'INVENTARIO';       Descricao: 'Estoque > Inventário'),
    (FormClass: 'TfrmKardex';           Modulo: MODULO_ESTOQUE;     Tela: 'KARDEX';           Descricao: 'Estoque > Kardex'),
    (FormClass: 'TfrmPDV';              Modulo: MODULO_PDV;         Tela: 'PDV';              Descricao: 'PDV > Abrir PDV'),
    (FormClass: 'TfrmCentralRelatorios'; Modulo: MODULO_RELATORIOS; Tela: TELA_CENTRAL_RELATORIOS; Descricao: 'Relatórios > Central'),
    (FormClass: 'TfrmCopiloto';         Modulo: MODULO_IA;          Tela: 'COPILOTO';         Descricao: 'IA Copiloto > Abrir Copiloto'),
    (FormClass: 'TfrmConfiguracoes';    Modulo: MODULO_SISTEMA;     Tela: TELA_CONFIGURACOES; Descricao: 'Sistema > Configurações'),
    (FormClass: 'TfrmPermissoes';       Modulo: MODULO_SISTEMA;     Tela: TELA_PERMISSOES;   Descricao: 'Sistema > Permissões')
  );

{ Verdadeiro quando o usuário logado pode executar a ação. }
function TemPermissao(const AModulo, ATela, AAcao: string): Boolean;

{ Levanta EPermissaoNegada quando não tem permissão, com mensagem
  amigável (e opcional). }
procedure VerificarPermissao(const AModulo, ATela, AAcao: string;
  const AMensagem: string = '');

{ Procura no catálogo a permissão da tela. Devolve False quando a
  classe não está no catálogo (nesse caso o chamador decide). }
function PermissaoDaTela(const AFormClass: string; out AModulo,
  ATela: string): Boolean;

{ Acesso ao catálogo (usado pelo seed do banco e pelos testes). }
function QuantidadeTelasPermissao: Integer;
function TelaPermissaoPorIndice(AIndice: Integer): TTelaPermissao;

implementation

uses
  SQLDB, uConexao, uSessao;

function ColunaDaAcao(const AAcao: string): string;
begin
  if AAcao = PERM_VISUALIZAR then
    Result := 'PODE_VISUALIZAR'
  else if AAcao = PERM_INSERIR then
    Result := 'PODE_INSERIR'
  else if AAcao = PERM_EDITAR then
    Result := 'PODE_EDITAR'
  else if AAcao = PERM_EXCLUIR then
    Result := 'PODE_EXCLUIR'
  else if AAcao = PERM_IMPRIMIR then
    Result := 'PODE_IMPRIMIR'
  else
    Result := '';
end;

function TemPermissao(const AModulo, ATela, AAcao: string): Boolean;
var
  LConexao: TConexao;
  LSessao: TSessao;
  LQuery: TSQLQuery;
  LColuna: string;
begin
  Result := False;

  LSessao := TSessao.GetInstance;
  if LSessao.Administrador then
    Exit(True);

  LColuna := ColunaDaAcao(UpCase(Trim(AAcao)));
  if LColuna = '' then
    Exit(False);

  if LSessao.GrupoId <= 0 then
    Exit(False);

  try
    LConexao := TConexao.GetInstance;
    if (LConexao = nil) or (not LConexao.Conectado) then
      Exit(False);

    LQuery := TSQLQuery.Create(nil);
    try
      LQuery.DataBase := LConexao.Connection;
      LQuery.Transaction := LConexao.Transaction;
      LQuery.SQL.Text :=
        'SELECT ' + LColuna + ' AS PERMITIDO FROM PERMISSAO ' +
        'WHERE GRUPO_ID = :GRP AND UPPER(MODULO) = :MOD AND UPPER(TELA) = :TELA';
      LQuery.ParamByName('GRP').AsLargeInt := LSessao.GrupoId;
      LQuery.ParamByName('MOD').AsString := UpperCase(Trim(AModulo));
      LQuery.ParamByName('TELA').AsString := UpperCase(Trim(ATela));
      LQuery.Open;
      if not LQuery.IsEmpty then
        Result := UpperCase(Trim(LQuery.FieldByName('PERMITIDO').AsString)) = 'S';
    finally
      LQuery.Free;
    end;
  except
    // Falha ao consultar permissão => nega o acesso
    Result := False;
  end;
end;

procedure VerificarPermissao(const AModulo, ATela, AAcao: string;
  const AMensagem: string);
begin
  if TemPermissao(AModulo, ATela, AAcao) then
    Exit;
  if AMensagem <> '' then
    raise EPermissaoNegada.Create(AMensagem);
  raise EPermissaoNegada.CreateFmt(
    'Seu usuário não tem permissão para %s neste módulo (%s/%s).',
    [LowerCase(AAcao), AModulo, ATela]);
end;

function PermissaoDaTela(const AFormClass: string; out AModulo,
  ATela: string): Boolean;
var
  I: Integer;
begin
  AModulo := '';
  ATela := '';
  for I := Low(CATALOGO_TELAS) to High(CATALOGO_TELAS) do
    if UpperCase(CATALOGO_TELAS[I].FormClass) = UpperCase(Trim(AFormClass)) then
    begin
      AModulo := CATALOGO_TELAS[I].Modulo;
      ATela := CATALOGO_TELAS[I].Tela;
      Exit(True);
    end;
  Result := False;
end;

function QuantidadeTelasPermissao: Integer;
begin
  Result := High(CATALOGO_TELAS) - Low(CATALOGO_TELAS) + 1;
end;

function TelaPermissaoPorIndice(AIndice: Integer): TTelaPermissao;
begin
  if (AIndice < Low(CATALOGO_TELAS)) or (AIndice > High(CATALOGO_TELAS)) then
  begin
    Result.FormClass := '';
    Result.Modulo := '';
    Result.Tela := '';
    Result.Descricao := '';
    Exit;
  end;
  Result := CATALOGO_TELAS[AIndice];
end;

end.
