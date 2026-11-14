/*-------------------------------------------------------------------------------------------------------------------------
Disciplina: Banco de Dados I
Autor....: Prof. Rodrigo Gonçalves Pinto
Objetivo..: Criação dos bancos de dados e entendimento de SCHEMA no PostgreSQL.
Objeto....: 01_cria_bancos.sql

ESTE É O PRIMEIRO SCRIPT DA DISCIPLINA. Rodamos ele juntos, em aula, comando por comando.
O container sobe apenas com o PostgreSQL e o banco padrão "postgres". Tudo o mais nós criamos.

Conecte-se ao banco postgres antes de começar.
--------------------------------------------------------------------------------------------------------------------------
Versão 1.0
*/


/*------------------------------------------------------
ONDE ESTAMOS: A HIERARQUIA DO POSTGRESQL
--------------------------------------------------------*/
-- No PostgreSQL existem QUATRO níveis, um dentro do outro:
--
--      SERVIDOR (cluster)
--        └── BANCO DE DADOS      db_universidade, db_iesb, db_biblioteca
--              └── SCHEMA        public, e outros que criarmos
--                    └── TABELA  tb_alunos, obra, autor...
--
-- ATENÇÃO, AQUI MORA A MAIOR CONFUSÃO DE QUEM VEM DO MYSQL:
-- no MySQL, as palavras DATABASE e SCHEMA são SINÔNIMOS. CREATE DATABASE e CREATE SCHEMA
-- fazem exatamente a mesma coisa.
-- no PostgreSQL são coisas DIFERENTES, em níveis diferentes. O schema é uma gaveta DENTRO
-- do banco. Um banco pode ter vários schemas, e cada schema tem as suas tabelas.
--
-- CONSEQUÊNCIA PRÁTICA: no PostgreSQL uma consulta enxerga UM banco só. Não dá para fazer
-- JOIN entre dois bancos, como fazíamos no MySQL escrevendo banco1.tabela e banco2.tabela.
-- Mas dá para fazer JOIN entre quantos SCHEMAS você quiser, dentro do mesmo banco.
-- É por isso que, no mundo PostgreSQL, o que no MySQL seriam vários "databases" costuma
-- virar vários SCHEMAS dentro de um banco só.

-- vendo onde estamos agora
SELECT current_database() AS banco_atual,
       current_schema()   AS schema_atual,
       current_user       AS usuario;
-- resposta esperada: postgres | public | postgres

-- listando os bancos que existem no servidor
SELECT datname AS banco
  FROM pg_database
 ORDER BY datname;
-- neste momento só existem postgres, template0 e template1.
-- os template são os moldes que o PostgreSQL usa para fabricar banco novo. Não se mexe neles.


/*------------------------------------------------------
CRIANDO OS BANCOS DE DADOS
--------------------------------------------------------*/
-- ATENÇÃO) o CREATE DATABASE NÃO pode rodar dentro de uma transação.
-- No DBeaver, confira no alto da janela se está em "Auto" (autocommit) e não em "Manual".
-- Se estiver em Manual, o comando falha com:
--      ERROR: CREATE DATABASE cannot run inside a transaction block
-- No pgAdmin a Query Tool já roda em autocommit e funciona direto.

-- OBS) o CREATE DATABASE também NÃO aceita IF NOT EXISTS, diferente do MySQL.
-- Se o banco já existir, dá erro. Não é problema: é só pular o comando.
--      ERROR: database "db_universidade" already exists   --> o banco já está lá. Siga em frente.

-- OBS) por que "db_" na frente do nome? É só convenção, para bater o olho e saber que é um banco.
-- Do mesmo jeito que vamos usar "tb_" para tabela, "vw_" para view e "fn_" para função.

-- banco de dados da Aula 06 (CRUD)
CREATE DATABASE db_universidade;

-- banco de dados da Aula 07 (cópia de tabelas, IN, funções agregadas)
CREATE DATABASE db_iesb;

-- banco de dados das Aulas 07 e 08 (GROUP BY, HAVING, JOINs, Views, Triggers, Procedures)
-- este é o banco que vai receber a carga de dados, e substitui o antigo sakila do MySQL.
CREATE DATABASE db_biblioteca;

-- conferindo: agora são seis
SELECT datname AS banco
  FROM pg_database
 ORDER BY datname;
-- resultado esperado: db_biblioteca, db_iesb, db_universidade, postgres, template0, template1

-- o comentário serve para documentar o banco. Aparece nas ferramentas e no \l do psql.
COMMENT ON DATABASE db_universidade IS 'Aula 06 - CRUD';
COMMENT ON DATABASE db_iesb         IS 'Aula 07 - cópia de tabelas e funções agregadas';
COMMENT ON DATABASE db_biblioteca   IS 'Aulas 07 e 08 - acervo de biblioteca com carga';

-- lendo os comentários de volta.
-- ATENÇÃO) a função é shobj_description, com "sh" na frente, e não obj_description.
-- O "sh" é de SHARED: banco de dados, usuário e tablespace são objetos compartilhados
-- pelo servidor inteiro, e os comentários deles ficam em um catálogo separado.
-- Com obj_description a consulta roda, não dá erro, e devolve a coluna VAZIA.
-- É um bom exemplo de erro silencioso: o pior tipo, porque não avisa.
SELECT d.datname AS banco,
       shobj_description(d.oid, 'pg_database') AS descricao
  FROM pg_database d
 WHERE d.datname LIKE 'db%'
 ORDER BY d.datname;


/*------------------------------------------------------
TROCANDO DE BANCO
--------------------------------------------------------*/
-- Não existe o comando USE do MySQL. Trocar de banco é ABRIR OUTRA CONEXÃO.
--
--   DBeaver  --> seletor de banco no alto da janela de SQL
--                (ou duplo clique no banco, na árvore da esquerda)
--   pgAdmin  --> clique no banco na árvore e abra uma nova Query Tool
--   psql     --> \c db_biblioteca
--
-- >>> AGORA: conecte-se ao banco db_biblioteca antes de seguir. <<<
-- Se o banco novo não aparecer na árvore do DBeaver, clique com o botão direito na
-- conexão e escolha Invalidate/Reconnect. Ele só relê a lista de bancos ao reconectar.

-- confirmando que a troca funcionou
SELECT current_database() AS banco_atual;
-- tem que responder: db_biblioteca


/*------------------------------------------------------
CRIANDO UM SCHEMA
--------------------------------------------------------*/
-- Todo banco nasce com um schema chamado public. É nele que as tabelas caem quando
-- você não diz nada. Vamos ver os schemas que existem no db_biblioteca.

SELECT schema_name
  FROM information_schema.schemata
 ORDER BY schema_name;
-- public é o nosso. Os que começam com pg_ são do próprio PostgreSQL.

-- criando um schema novo, para separar o rascunho da turma do acervo oficial
CREATE SCHEMA IF NOT EXISTS laboratorio;

COMMENT ON SCHEMA laboratorio IS 'área de testes da turma; o acervo fica no schema public';

-- criando uma tabela DENTRO do schema novo. Repare no nome em duas partes: schema.tabela
CREATE TABLE IF NOT EXISTS laboratorio.tb_teste (
    id    INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    texto VARCHAR(100)
);

INSERT INTO laboratorio.tb_teste (texto) VALUES ('primeira linha da turma');

SELECT * FROM laboratorio.tb_teste;

-- e agora o ponto da demonstração: SEM dizer o schema, o PostgreSQL procura no public e não acha.
-- A linha abaixo DÁ ERRO DE PROPÓSITO:
SELECT * FROM tb_teste;
--      ERROR:  relation "tb_teste" does not exist

-- POR QUE: existe uma lista de schemas onde o banco procura, e na ordem. Chama-se search_path.
SHOW search_path;
-- o padrão é "$user", public. O schema laboratorio não está na lista, então não é procurado.

-- podemos acrescentar o laboratorio à lista, só para esta conexão:
SET search_path TO laboratorio, public;

-- agora funciona sem escrever o schema na frente
SELECT * FROM tb_teste;

-- voltando ao normal. O search_path volta sozinho quando a conexão fecha.
SET search_path TO public;

-- limpando o laboratório. Descomente quando quiser desfazer a demonstração.
-- DROP SCHEMA laboratorio CASCADE;


/*------------------------------------------------------
PRÓXIMO PASSO
--------------------------------------------------------*/
-- Com os três bancos criados, abra o script 02_carga_db_biblioteca.sql,
-- CONECTADO AO BANCO db_biblioteca, e execute-o inteiro.
-- Ele cria as tabelas do acervo e carrega os dados das Aulas 07 e 08.
-- É o único script que rodamos de uma vez só, sem olhar comando por comando:
-- são 16 mil linhas de empréstimos, e digitar isso na mão não ensina nada.

/*
FIM
*/
