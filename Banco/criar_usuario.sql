CONNECT 'C:\Users\Charles\Documents\ProjetoERP_1\Banco\dados.fdb' USER 'SYSDBA' PASSWORD 'masterkey';

-- Tentar criar um novo usuário
CREATE USER ERP_USER PASSWORD 'erp2026' GRANT ADMIN ROLE;
COMMIT;
QUIT;
