CONNECT 'C:\Users\Charles\Documents\ProjetoERP_1\Banco\dados.fdb' USER 'SYSDBA' PASSWORD 'masterkey';

-- Execute domains
INPUT 'C:\Users\Charles\Documents\ProjetoERP_1\Banco\002_domains.sql';

-- Execute generators
INPUT 'C:\Users\Charles\Documents\ProjetoERP_1\Banco\003_generators.sql';

-- Execute tables
INPUT 'C:\Users\Charles\Documents\ProjetoERP_1\Banco\004_tables.sql';

-- Execute triggers
INPUT 'C:\Users\Charles\Documents\ProjetoERP_1\Banco\005_triggers.sql';

-- Execute indexes
INPUT 'C:\Users\Charles\Documents\ProjetoERP_1\Banco\006_indexes.sql';

-- Execute initial data
INPUT 'C:\Users\Charles\Documents\ProjetoERP_1\Banco\007_initial_data.sql';

-- Execute additional tables
INPUT 'C:\Users\Charles\Documents\ProjetoERP_1\Banco\008_tabelas_adicionais.sql';

COMMIT;
QUIT;
