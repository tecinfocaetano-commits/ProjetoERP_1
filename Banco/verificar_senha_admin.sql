CONNECT 'C:\Users\Charles\Documents\ProjetoERP_1\Banco\dados.fdb' USER 'SYSDBA' PASSWORD 'masterkey';

SELECT ID, NOME, LOGIN, SENHA, ATIVO FROM USUARIO WHERE LOGIN = 'admin';
QUIT;
