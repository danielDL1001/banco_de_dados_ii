/*-------------------------------------------------------------------------------------------------------------------------
Disciplina: Banco de Dados I
Autor....: Prof. Rodrigo Gonçalves Pinto
Objetivo..: Data manipulation samples. (Exemplos de DML manipulação de dados)
Bimestre.: 2 Bimestre
Objeto....: Aula07_consultas.sql

Data Criação...................: 15/05/2023
Data Alteração................. : versão PostgreSQL 16
Alteração Feita: conversão do script de MySQL para PostgreSQL 16, mantendo a mesma sequência de aula.
                 O banco sakila foi substituído pelo banco db_biblioteca.
--------------------------------------------------------------------------------------------------------------------------
ESTE SCRIPT PASSA POR TRÊS BANCOS DE DADOS:

   PARTE 1 --> db_universidade   ALTER TABLE e DROP TABLE
   PARTE 2 --> db_iesb           cópia de registros, IN, e funções agregadas
   PARTE 3 --> db_biblioteca     GROUP BY, HAVING, DISTINCT, JOINs e COALESCE

COMO RODAR ESTE SCRIPT:
 - rode UMA PARTE de cada vez, nunca o script inteiro de uma vez.
 - antes de cada parte, troque de banco no seletor do topo da janela (DBeaver ou pgAdmin).
 - logo depois da troca tem um SELECT current_database(). Rode e confira a resposta.
   Se não for o banco da parte, PARE: tudo que você rodar vai cair no banco errado.
 - a linha "-- \c nome_do_banco" está comentada de propósito. Ela só funciona no psql.
   Quem usa psql pode apagar os dois tracinhos da frente.
--------------------------------------------------------------------------------------------------------------------------
Versão 1.0
*/


/*=========================================================================================================================
  PARTE 1 - db_universidade
=========================================================================================================================*/
-- >>> TROQUE PARA O BANCO db_universidade <<<
-- \c db_universidade

SELECT current_database();
-- tem que responder: db_universidade

-- ANTES DE COMEÇAR) esta parte ALTERA as tabelas criadas na Aula 06.
-- Se você já rodou a Aula 07 alguma vez, rode o Aula06_CRUD.sql de novo primeiro:
-- ele derruba e recria as tabelas do zero, e a Aula 07 volta a funcionar do começo.
-- Sem isso, o ALTER vai reclamar que a coluna já existe ou que já foi renomeada.

/*------------------------------------------------------
OUTROS COMANDOS IMPORTANTES
COMANDO ALTER
vamos adicionar uma nova coluna
--------------------------------------------------------*/

-- visualizando a tabela alunos
SELECT
    *
FROM
    tb_alunos;

-- visualizando os tipos de dados.
-- (lembre: no PostgreSQL não existe DESCRIBE. No psql é \d tb_alunos; em qualquer ferramenta é a consulta abaixo.)
SELECT column_name AS campo, data_type AS tipo, is_nullable AS aceita_nulo
  FROM information_schema.columns
 WHERE table_name = 'tb_alunos'
 ORDER BY ordinal_position;

-- comando alter é utilizado para realizar alterações em uma tabela.
-- Utilizar com cautela.
-- utilizamos o comando alter para adicionar um campo (atributo) na tabela alunos.
-- Observe que: o campo é adicionado no final da tabela.
-- OBS) veja que aqui não se utiliza parênteses ()

ALTER TABLE tb_alunos
    ADD COLUMN IF NOT EXISTS instagram VARCHAR(50);


-- alterando o TIPO DE DADOS de uma coluna
-- no MySQL era:      ALTER TABLE tabela MODIFY coluna novo_tipo;
-- no PostgreSQL é:   ALTER TABLE tabela ALTER COLUMN coluna TYPE novo_tipo;
ALTER TABLE tb_alunos
   ALTER COLUMN email_aluno TYPE CHAR(255);

-- visualizando novamente a estrutura de dados
SELECT column_name AS campo, data_type AS tipo
  FROM information_schema.columns
 WHERE table_name = 'tb_alunos'
 ORDER BY ordinal_position;


-- alterando o NOME de uma coluna
-- no MySQL era:      ALTER TABLE tabela CHANGE nome_antigo nome_novo tipo;
-- no PostgreSQL é:   ALTER TABLE tabela RENAME COLUMN nome_antigo TO nome_novo;
-- repare na vantagem: aqui você NÃO precisa repetir o tipo de dados. No MySQL, se você esquecesse
-- de repetir o tipo certo, renomeava e mudava o tipo da coluna sem perceber.
ALTER TABLE tb_alunos
   RENAME COLUMN data_cadastro TO dt_cadastro;

SELECT column_name AS campo, data_type AS tipo
  FROM information_schema.columns
 WHERE table_name = 'tb_alunos'
 ORDER BY ordinal_position;


-- adicionando uma restrição NOT NULL em uma coluna específica
-- no MySQL era:      ALTER TABLE tabela MODIFY coluna tipo NOT NULL;
-- no PostgreSQL é:   ALTER TABLE tabela ALTER COLUMN coluna SET NOT NULL;
-- perceba que o campo nome_aluno permite valores null. Vamos alterar para não permitir.
ALTER TABLE tb_alunos
    ALTER COLUMN nome_aluno SET NOT NULL;

-- e para VOLTAR atrás, permitindo nulo de novo:
-- ALTER TABLE tb_alunos ALTER COLUMN nome_aluno DROP NOT NULL;

-- alterando o TAMANHO da coluna
ALTER TABLE tb_alunos
    ALTER COLUMN nome_aluno TYPE VARCHAR(300);


/*-------------------------------------------------------------------------------------------------------------------------
COMANDO DROP
variação DROP TABLE IF EXISTS
-------------------------------------------------------------------------------------------------------------------------*/
-- utiliza-se o comando DROP para eliminar, apagar estruturas como banco de dados e tabelas.
-- no exemplo abaixo, utiliza-se o comando DROP para excluir a tabela tb_alunos.
-- CUIDADO! ao apagar, você apaga todos os objetos associados à tabela.

-- OBS) no PostgreSQL, se a tabela tiver alguém apontando para ela por chave estrangeira,
-- o DROP simples é RECUSADO. Para derrubar junto tudo que depende dela, acrescenta-se CASCADE.
-- É por isso que nos nossos scripts aparece DROP TABLE ... CASCADE.

-- DROP TABLE IF EXISTS tb_alunos;           -- recusado: tb_matriculas depende dela
-- DROP TABLE IF EXISTS tb_alunos CASCADE;   -- aceito, e leva junto a chave estrangeira da tb_matriculas


/*=========================================================================================================================
  PARTE 2 - db_iesb
=========================================================================================================================*/
-- >>> TROQUE PARA O BANCO db_iesb <<<
-- \c db_iesb

SELECT current_database();
-- tem que responder: db_iesb

/*-------------------------------------------------------------------------------------------------------------------------
-- Função importante:
 COPIANDO registros de uma tabela para outra tabela de um mesmo banco de dados
-------------------------------------------------------------------------------------------------------------------------*/
-- para demonstrar a cópia de uma tabela para a outra tabela de um mesmo banco de dados,
-- vamos criar duas tabelas.
-- 1) tabela chamada tb_pessoas
-- 2) tabela chamada tb_funcionarios
-- ambas as tabelas pertencentes ao banco de dados chamado db_iesb.
-- Objetivo) copiar os dados da tabela tb_pessoas para a tabela tb_funcionarios

DROP TABLE IF EXISTS tb_funcionarios, tb_pessoas, tb_departamentos CASCADE;
DROP TYPE  IF EXISTS tp_sexo;

CREATE TYPE tp_sexo AS ENUM ('M', 'F');

CREATE TABLE IF NOT EXISTS tb_pessoas (
    id_pessoa   INT GENERATED BY DEFAULT AS IDENTITY,
    nome_pessoa VARCHAR(250) NOT NULL,
    sexo        tp_sexo,

 PRIMARY KEY (id_pessoa)
);

CREATE TABLE IF NOT EXISTS tb_funcionarios (
    id_funcionario           INT GENERATED BY DEFAULT AS IDENTITY,
    nome_funcionario         VARCHAR(255),
    salario_funcionario      NUMERIC(10,2),
    dta_admissao_funcionario TIMESTAMP,
    sexo_funcionario         tp_sexo,
    dta_cadastro_funcionario TIMESTAMP,

    PRIMARY KEY (id_funcionario)
);

-- 1º) adicionar dados na tabela pessoas, para poder ter registros a copiar

INSERT INTO tb_pessoas (nome_pessoa, sexo) VALUES ('Charlize Theron'  , 'F'),
                                                  ('Jeniffer Aniston' , 'F'),
                                                  ('Scarlet Johansson', 'M'),
                                                  ('Brad Pitt'        , 'M'),
                                                  ('Tom Cruise'       , 'M'),
                                                  ('Will Smith'       , 'M');

-- Verifico se os registros foram adicionados na tabela tb_pessoas
SELECT * FROM tb_pessoas;


-- 2º) adicionar dados na tabela tb_funcionarios

INSERT INTO tb_funcionarios (nome_funcionario, salario_funcionario, dta_admissao_funcionario, sexo_funcionario, dta_cadastro_funcionario)
VALUES
    ('Isaac Newton'         , 100000.00, '2023-04-01 08:00:00', 'M', now()),
    ('Carl Friedrich Gauss' , 120000.00, '2023-04-01 08:00:00', 'M', now()),
    ('Ada Lovelace'         , 110000.00, '2023-04-01 08:00:00', 'F', now());


-- 3º INICIAR O PROCESSO DA CÓPIA
-- utilizamos em conjunto as instruções insert e select

-- [PASSO 1] verificar os campos de cada tabela. Perceba que os campos são diferentes
SELECT * FROM tb_pessoas;
-- campos: id_pessoa, nome_pessoa, sexo

SELECT * FROM tb_funcionarios;
-- campos: id_funcionario, nome_funcionario, salario_funcionario, dta_admissao_funcionario, sexo_funcionario, dta_cadastro_funcionario

-- [PASSO 2] Utilizo os comandos em conjunto INSERT / SELECT
-- para copiar dados da tabela pessoas para a tabela funcionários
-- estamos dando salários iniciais iguais a 10 para os registros recém adicionados.
-- quem gerencia o ID é a IDENTITY da tb_funcionarios.
-- OBS) repare que NÃO tem a palavra VALUES. O SELECT é que fornece as linhas.

INSERT INTO tb_funcionarios (nome_funcionario,
                salario_funcionario,
                dta_admissao_funcionario,
                sexo_funcionario,
                dta_cadastro_funcionario)
     SELECT nome_pessoa, 10, '2023-05-17', sexo, CURRENT_DATE AS dta_cadastro_funcionario FROM tb_pessoas;

-- visualizando a cópia
SELECT * FROM tb_funcionarios;


/*-------------------------------------------------------------------------------------------------------------------------

 Comando SELECT
 IN --> compara valores para encontrá-los na cláusula where

-------------------------------------------------------------------------------------------------------------------------*/
-- comando utilizado para comparar um valor igual aos campos dentro dos parênteses
-- vamos criar uma tabela chamada departamentos

-- Criando a tabela departamentos
DROP TABLE IF EXISTS tb_funcionarios CASCADE;
DROP TABLE IF EXISTS tb_departamentos CASCADE;

CREATE TABLE tb_departamentos(
    id_departamento        INT GENERATED BY DEFAULT AS IDENTITY,
    nome_departamento      VARCHAR(50),
    descricao_departamento TEXT,
    dta_criacao            DATE,
    localizacao            VARCHAR(100),

    PRIMARY KEY (id_departamento)
);

-- adicionando departamentos à tabela tb_departamentos.
INSERT INTO tb_departamentos (nome_departamento, descricao_departamento, dta_criacao, localizacao)
    VALUES
            ('Vendas',      'Departamento responsável pela venda de produtos',   '2023-01-10', 'São Paulo'),
            ('RH',          'Departamento responsável pelo gerenciamento de recursos humanos', '2023-03-15', 'Rio de Janeiro'),
            ('TI',          'Departamento responsável pela infraestrutura tecnológica', '2023-02-20', 'Belo Horizonte'),
            ('Marketing',   'Departamento responsável pela estratégia de marketing', '2023-04-05', 'Curitiba'),
            ('Financeiro',  'Departamento responsável pela gestão financeira', '2023-05-01', 'Porto Alegre'),
            ('Produção',    'Departamento responsável pela fabricação dos produtos', '2023-06-10', 'Recife'),
            ('Logística',   'Departamento responsável pelo gerenciamento de estoques e distribuição', '2023-07-15', 'Salvador'),
            ('Qualidade',   'Departamento responsável pelo controle de qualidade dos produtos', '2023-08-20', 'Fortaleza'),
            ('Jurídico',    'Departamento responsável por assuntos jurídicos e contratos', '2023-09-25', 'Brasília'),
            ('Pesquisa e Desenvolvimento', 'Departamento responsável pela pesquisa e desenvolvimento de novos produtos', '2023-10-30', 'Manaus');

-- visualizar os registros adicionados.
SELECT * FROM tb_departamentos;


-- criar a tabela funcionarios, referenciando a tabela departamentos.
CREATE TABLE tb_funcionarios(
    id_funcionario          INT GENERATED BY DEFAULT AS IDENTITY,
    id_departamento         INT,
    nome_funcionario        VARCHAR(200),
    salario_funcionario     NUMERIC(10,2),
    dt_admissao_funcionario DATE,
    sexo_funcionario        tp_sexo,
    dt_cadastro_funcionario TIMESTAMP,

PRIMARY KEY (id_funcionario),
FOREIGN KEY (id_departamento) REFERENCES tb_departamentos(id_departamento)
);

-- visualizando a tabela recém criada.
SELECT column_name AS campo, data_type AS tipo
  FROM information_schema.columns
 WHERE table_name = 'tb_funcionarios'
 ORDER BY ordinal_position;

SELECT * FROM tb_departamentos;

 -- adicionando dados na tabela funcionários com seus respectivos departamentos.
 INSERT INTO tb_funcionarios ( id_departamento,
                              nome_funcionario,
                              salario_funcionario,
                              dt_admissao_funcionario,
                              sexo_funcionario,
                              dt_cadastro_funcionario)
                        VALUES  (1, 'Charlize Theron',      10000,      CURRENT_DATE, 'F', now()),
                                (2, 'Jeniffer Aniston',      5000,      CURRENT_DATE, 'F', now()),
                                (3, 'Scarlet Johansson',     3000,      CURRENT_DATE, 'F', now()),
                                (4, 'Brad Pitt',            25000,      CURRENT_DATE, 'M', now()),
                                (5, 'Tom Cruise',           15258.12,   CURRENT_DATE, 'M', now()),
                                (6, 'Will Smith',             150.78,   CURRENT_DATE, 'M', now()),
                                (7, 'Júlia Roberts',          160.30,   CURRENT_DATE, 'F', now()),
                                (8, 'Nicole Kidman',         1560.25,   CURRENT_DATE, 'F', now()),
                                (9, 'Tom Hanks',             1200.37,   CURRENT_DATE, 'M', now()),
                                (9, 'Denzel Washington',  1000000.00,   CURRENT_DATE, 'M', now());


-- selecionando todos os funcionários
SELECT * FROM tb_funcionarios;

-- selecionando apenas os funcionários do departamento 9 = jurídico.
 SELECT *
   FROM tb_funcionarios
 WHERE id_departamento = 9;

-- selecione todos os funcionários que estão no departamento 2, 7 e 9.
 SELECT *
   FROM tb_funcionarios
WHERE id_departamento IN (2,7,9);


/*-------------------------------------------------------------------------------------------------------------------------

 Comando SELECT
 UPPER() e LOWER() --> passando strings (texto) para maiúsculo e minúsculo.

-------------------------------------------------------------------------------------------------------------------------*/
-- UPPER() Maiúsculo
-- LOWER() Minúsculo
-- selecione todos os nomes de departamentos e coloque-os em letra maiúscula.
SELECT UPPER(nome_departamento) FROM tb_departamentos;

-- selecione todos os nomes de departamentos e coloque-os em letra minúscula
SELECT LOWER(nome_departamento) FROM tb_departamentos;

-- OBS) o PostgreSQL tem ainda a função INITCAP, que não existia no MySQL:
-- coloca a primeira letra de cada palavra em maiúscula. Útil para arrumar cadastro mal digitado.
SELECT INITCAP('pesquisa e desenvolvimento') AS arrumado;


/*-------------------------------------------------------------------------------------------------------------------------

 Comando SELECT
Funções Agregadas --> COUNT(*)

-------------------------------------------------------------------------------------------------------------------------*/
-- COUNT(*)
-- Contar a quantidade de linhas da tabela departamentos

SELECT COUNT(*) FROM tb_departamentos;
-- perceba que o nome da coluna ficou igual a "count"
-- para alterar o nome da coluna em tempo de execução, utilizamos um (ALIAS) ou apelido com a palavra reservada AS. Veja
SELECT COUNT(*) AS quantidade FROM tb_departamentos;

-- contar a quantidade de linhas da tabela de funcionários com a coluna id_departamento preenchida.
SELECT COUNT(id_departamento) AS quantidade_departamento_funcionarios FROM tb_funcionarios;

-- OBS) a função COUNT retornará zero quando nenhuma linha atender ao critério utilizado.
-- OBS) COUNT(coluna) NÃO conta as linhas em que a coluna está NULL. COUNT(*) conta a linha inteira,
-- mesmo cheia de nulos. É por isso que os dois números podem ser diferentes na mesma tabela.


/*-------------------------------------------------------------------------------------------------------------------------

 Comando SELECT
Funções Agregadas --> SUM()

-------------------------------------------------------------------------------------------------------------------------*/
-- SUM(). soma valores de uma coluna

-- soma todos os registros de salários dos funcionários.
SELECT SUM(salario_funcionario) AS salario FROM tb_funcionarios;
-- perceba que o valor gerado pela soma não está formatado no padrão brasileiro.

-- resultado esperado: 1061329.82

-- no MySQL usávamos FORMAT(valor, 2, 'pt-br'). No PostgreSQL essa função não existe.
-- aqui usamos to_char() para formatar, e translate() para trocar ponto por vírgula e vírgula por ponto.
-- vamos montar em DOIS PASSOS, para ficar fácil de entender.

-- [PASSO 1] to_char coloca os separadores, mas no padrão AMERICANO: vírgula no milhar, ponto no decimal.
SELECT to_char(SUM(salario_funcionario), 'FM999,999,990.00') AS salario_americano
  FROM tb_funcionarios;
-- resultado: 1,061,329.82

-- [PASSO 2] translate troca os dois símbolos de lugar, e vira o padrão BRASILEIRO.
SELECT translate(to_char(SUM(salario_funcionario), 'FM999,999,990.00'), ',.', '.,') AS salario
  FROM tb_funcionarios;
-- resultado: 1.061.329,82
-- onde: 'FM999,999,990.00' é a máscara de saída.
--       FM  = remove os espaços em branco que o PostgreSQL colocaria à esquerda.
--       9   = posição de dígito que some quando é zero à esquerda.
--       0   = posição de dígito que aparece sempre. Por isso o último é 0, para nunca sumir o zero das casas.
--       translate(texto, ',.', '.,') = troca toda vírgula por ponto e todo ponto por vírgula, de uma vez.

-- E SE EU SÓ QUISER ARREDONDAR? Na maioria das vezes, o ROUND basta. Ele não põe ponto de milhar,
-- mas é simples e o resultado continua sendo NÚMERO (o to_char devolve TEXTO, que não dá para somar depois).
SELECT ROUND(AVG(salario_funcionario), 2) AS media_arredondada
  FROM tb_funcionarios;
-- resultado: 106132.98


/*-------------------------------------------------------------------------------------------------------------------------

 Comando SELECT
Funções Agregadas --> AVG()
avg() = média aritmética

-------------------------------------------------------------------------------------------------------------------------*/
-- AVG(). realiza a média aritmética de uma coluna

-- fazer a média de todos os registros de salários dos funcionários.
SELECT AVG(salario_funcionario) AS media_salarios FROM tb_funcionarios;

-- fazer a média de salários de todos os registros da tabela funcionários formatando a saída para
-- moeda em português Brasil.
SELECT translate(to_char(AVG(salario_funcionario), 'FM999,999,990.00'), ',.', '.,') AS media_salarios
  FROM tb_funcionarios;

-- obs) a função AVG() retorna null se nenhuma linha atender o critério da consulta.
SELECT AVG(salario_funcionario) AS media_salarios
  FROM tb_funcionarios
 WHERE id_departamento = 99;   -- departamento que não existe


/*-------------------------------------------------------------------------------------------------------------------------

 Comando SELECT
Funções Agregadas --> MAX()
MAX() = valor máximo

-------------------------------------------------------------------------------------------------------------------------*/
-- MAX. encontra o maior valor de uma coluna na tabela.

-- selecionar o maior salário da tabela funcionários
SELECT MAX(salario_funcionario)
    FROM tb_funcionarios;
-- resultado esperado: 1000000.00 (o Denzel Washington)
-- repare que um único salário enorme puxa a MÉDIA lá para cima: a média deu 106 mil,
-- mas 9 dos 10 funcionários ganham menos de 26 mil. Média sozinha engana.

-- Qual é o maior salário da tabela funcionários, quando o nome do funcionário termina com a letra "s" ?
SELECT MAX(salario_funcionario)
  FROM tb_funcionarios
WHERE nome_funcionario LIKE '%s';
-- resultado esperado: 1200.37 (o Tom Hanks). O WHERE filtra PRIMEIRO, e o MAX olha só quem sobrou.


/*-------------------------------------------------------------------------------------------------------------------------

 Comando SELECT
Funções Agregadas --> MIN()
MIN() = valor mínimo

-------------------------------------------------------------------------------------------------------------------------*/
-- MIN. encontra o menor valor de uma coluna na tabela.

SELECT MIN(salario_funcionario)
    FROM tb_funcionarios;

-- será que MIN() e MAX() funcionam também para strings (textos)?
  -- seleciona o menor nome alfabeticamente na tabela funcionarios.
  -- a função min() e max() retorna o menor / maior nome da tabela de acordo com a ordem lexicográfica.
  -- (classificação de ordem das letras / palavras)
SELECT MIN(nome_funcionario) AS menor_nome
    FROM tb_funcionarios;
-- resultado esperado: Brad Pitt. Não é o salário: é o primeiro nome em ordem alfabética.

 -- Verifica se as funções retornam os mesmos valores
SELECT * FROM tb_funcionarios
  ORDER BY nome_funcionario DESC;

  SELECT nome_funcionario, salario_funcionario FROM tb_funcionarios
    ORDER BY salario_funcionario DESC;


/*-------------------------------------------------------------------------------------------------------------------------

 Comando SELECT
Funções Agregadas --> STDDEV_POP() e STDDEV_SAMP()
STDDEV_POP()  = desvio padrão populacional
STDDEV_SAMP() = desvio padrão amostral

-------------------------------------------------------------------------------------------------------------------------*/
-- sintaxe: SELECT STDDEV_POP(coluna_numerica) AS desvio_padrao FROM tabela;
-- onde: coluna numérica é a coluna que deseja calcular
-- mostre o desvio padrão populacional do salário do funcionario da tabela funcionários
SELECT STDDEV_POP(salario_funcionario)
    FROM tb_funcionarios;

-- desvio padrão amostral
-- no MySQL o amostral se escrevia só STDDEV(). No PostgreSQL STDDEV() também funciona e é sinônimo de
-- STDDEV_SAMP(), mas escreva o nome completo: em consulta que outra pessoa vai ler, o nome completo diz qual dos dois é.
-- selecione o desvio padrão amostral do atributo salario_funcionario, onde id_funcionario contém 2, 7 e 9.
SELECT STDDEV_SAMP(salario_funcionario)
    FROM tb_funcionarios
WHERE id_funcionario IN (2, 7, 9);


/*-------------------------------------------------------------------------------------------------------------------------

 Comando SELECT
Funções Agregadas --> VAR_POP() e VAR_SAMP()
VAR_POP()  = variância calculada como o quadrado de STDDEV_POP, ou seja, variância populacional
VAR_SAMP() = variância calculada como o quadrado de STDDEV_SAMP, ou seja, variância amostral
-------------------------------------------------------------------------------------------------------------------------*/
-- sintaxe: SELECT VAR_POP(coluna_numerica) AS variancia_populacao FROM tabela;
-- onde: coluna numérica é a coluna que deseja calcular a variância
-- variância populacional
SELECT VAR_POP(salario_funcionario)
    FROM tb_funcionarios;

-- variância amostral
-- selecione a variância amostral do salário dos funcionários onde id_funcionario sejam iguais a 2, 7 ou 9.
SELECT VAR_SAMP(salario_funcionario)
    FROM tb_funcionarios
  WHERE id_funcionario IN (2,7,9);

-- conferindo a relação entre as duas: a variância é o desvio padrão ao quadrado.
SELECT VAR_POP(salario_funcionario)                    AS variancia,
       POWER(STDDEV_POP(salario_funcionario), 2)       AS desvio_ao_quadrado
  FROM tb_funcionarios;


/*=========================================================================================================================
  PARTE 3 - db_biblioteca

  Este é o banco que substitui o sakila que usávamos no MySQL. Em vez de locadora de filmes,
  é o acervo de uma biblioteca. A equivalência é direta:
        film --> obra     category --> area     actor --> autor     city --> cidade
=========================================================================================================================*/
-- >>> TROQUE PARA O BANCO db_biblioteca <<<
-- \c db_biblioteca

SELECT current_database();
-- tem que responder: db_biblioteca

/*-------------------------------------------------------------------------------------------------------------------------

 Cláusula GROUP BY
 GROUP BY = Agrupar os registros por?

-------------------------------------------------------------------------------------------------------------------------*/

-- Calcular a quantidade de obras por valor de locação
-- usar a tabela obra
-- agrupar por valor_locacao.
SELECT valor_locacao, COUNT(*) AS quantidade_obras_por_locacao
   FROM obra
GROUP BY valor_locacao
ORDER BY valor_locacao;
-- resultado esperado: 0.99 = 333 obras | 2.99 = 334 obras | 4.99 = 334 obras

-- COMO PENSAR O GROUP BY: imagine que o banco separa as obras em MONTINHOS, um para cada valor_locacao.
-- Depois ele aplica o COUNT em cada montinho. Uma linha de resultado para cada montinho.
--
-- REGRA QUE MAIS DERRUBA GENTE: toda coluna do SELECT que NÃO está dentro de uma função
-- (COUNT, SUM, AVG...) tem que aparecer no GROUP BY. Se esquecer, o PostgreSQL acusa:
--      ERROR: column "obra.titulo" must appear in the GROUP BY clause or be used in an aggregate function


-- Qual a média do custo de reposição, caso a obra seja perdida ou danificada (custo_reposicao), por área?
-- Será que obras de Medicina custam mais caro em média para repor caso sejam perdidas, roubadas ou danificadas?
-- vejamos as tabelas envolvidas (obra, obra e area, area)
SELECT * FROM obra   LIMIT 5;
SELECT * FROM obra_area LIMIT 5;
SELECT * FROM area;

-- Select que responde a pergunta
SELECT AVG(O.custo_reposicao) AS custo_reposicao_media,
        A.nome AS area_do_conhecimento
            FROM obra O
     INNER JOIN obra_area OA
     ON O.id_obra = OA.id_obra
        INNER JOIN area A
        ON OA.id_area = A.id_area
            GROUP BY area_do_conhecimento
              ORDER BY custo_reposicao_media DESC;
-- resultado esperado: 16 áreas. Artes é a mais cara (27,59) e Computação a mais barata (10,12).
-- Medicina fica no meio, em 6º lugar.

-- COMO LER O JOIN ACIMA: a tabela obra não sabe o nome da área. Ela só se liga à área pela tabela
-- do meio, obra_area. Então o caminho é:   obra  --(id_obra)-->  obra_area  --(id_area)-->  area
-- As letras O, OA e A são APELIDOS das tabelas, só para não escrever o nome inteiro toda hora.

-- OBS) repare que no GROUP BY usamos o APELIDO area_do_conhecimento. O PostgreSQL aceita isso,
-- mas é um favor que ele faz. O padrão SQL manda repetir a coluna: GROUP BY A.nome. Prefira a forma padrão.


/*-------------------------------------------------------------------------------------------------------------------------

 Cláusula HAVING
 HAVING = tendo..

 A cláusula HAVING é semelhante à cláusula WHERE.

 A cláusula WHERE não pode ser usada em agregações, pois geralmente o filtro é aplicado quando as linhas são recuperadas
 no banco de dados, fazendo com que estas nem cheguem a ser consideradas quando da realização de agrupamentos ou na execução
 da função de agregação.

 A cláusula HAVING será aplicada somente após a recuperação das linhas do banco de dados, da montagem dos grupos e da
 execução das funções agregadas.

-------------------------------------------------------------------------------------------------------------------------*/

 -- PRIMEIRO, UM EXEMPLO BEM SIMPLES, com uma tabela só:
 -- quais valores de empréstimo movimentaram MAIS DE 15 MIL REAIS no total?
 -- passo 1) agrupa os empréstimos por valor.   passo 2) soma cada grupo.   passo 3) HAVING fica com os grupos acima de 15 mil.
SELECT valor,
       COUNT(*)   AS quantidade,
       SUM(valor) AS total_movimentado
  FROM emprestimo
 GROUP BY valor
HAVING SUM(valor) > 15000
 ORDER BY valor;
-- resultado esperado: 3 linhas --> 7.99, 9.99 e 11.99
-- tente trocar o HAVING por WHERE e rode: dá erro. O WHERE não enxerga o SUM, porque o SUM
-- só existe DEPOIS que os grupos foram montados. Para filtrar resultado de função agregada, é HAVING.
--
-- ORDEM EM QUE O BANCO EXECUTA (não é a ordem em que a gente escreve!):
--      FROM  -->  WHERE  -->  GROUP BY  -->  HAVING  -->  SELECT  -->  ORDER BY
--      WHERE filtra LINHAS, antes de agrupar.   HAVING filtra GRUPOS, depois de agrupar.


 -- quais os títulos cujo o custo médio de reposição seja menor que 10 reais?
 -- OBS) aqui cada título forma um grupo de uma obra só, então a "média" é o próprio custo.
 -- O exemplo serve para mostrar o HAVING junto com JOIN e GROUP BY de duas colunas.
SELECT  O.titulo,
        A.nome AS area_do_conhecimento
            FROM obra O
     INNER JOIN obra_area OA
     ON O.id_obra = OA.id_obra
        INNER JOIN area A
        ON OA.id_area = A.id_area
            GROUP BY A.nome,
                     O.titulo
                     HAVING AVG(O.custo_reposicao) < 10
            ORDER BY O.titulo;
-- resultado esperado: 20 obras, todas da área Computação (a área de custo mais baixo).


SELECT * FROM cidade;

-- Quais são as cidades que possuem mais de um registro?
-- Em outras palavras: encontre para mim registros duplicados.
SELECT cidade, COUNT(*) AS quantidade_registros
    FROM cidade
      GROUP BY
        cidade
          HAVING COUNT(*) > 1
      ORDER BY cidade;
-- resultado esperado: 10 cidades, cada uma com 2 registros (Barcelona, Brasilia, Buenos, Cuiaba,
-- Hamburgo, Londres, Miami, Puebla, Toquio e Toronto).
-- ESTA É A CONSULTA CLÁSSICA PARA ACHAR DUPLICADOS. Guarde o modelo:
--      SELECT coluna, COUNT(*) FROM tabela GROUP BY coluna HAVING COUNT(*) > 1;

-- Veja que a cidade Londres possui 2 registros, e que cada registro possui países diferentes.
-- veja que o id_pais mostra isso.
SELECT *
      FROM cidade
        WHERE cidade = 'Londres';

-- OBS) e se eu escrever 'londres' com L minúsculo? No MySQL vinha igual. No PostgreSQL vem VAZIO.
SELECT * FROM cidade WHERE cidade = 'londres';   -- 0 linhas
SELECT * FROM cidade WHERE cidade ILIKE 'londres';  -- agora sim


-- Usando o mesmo comando, contudo adicionando a cláusula WHERE
-- eliminando valores NULL caso existam antes de aplicar agregação
SELECT cidade, COUNT(*) AS quantidade_registros
    FROM cidade
      WHERE cidade IS NOT NULL -- ELIMINANDO VALORES NULL CASO EXISTAM!
      GROUP BY cidade
          HAVING COUNT(*) > 1
      ORDER BY cidade;


/*-------------------------------------------------------------------------------------------------------------------------

 CONSTANTES E CONCATENAÇÃO

-------------------------------------------------------------------------------------------------------------------------*/

-- usando uma string (texto) antes de selecionar uma coluna da tabela obra
-- perceba que colocamos outro nome para titulo.
-- resultado: duas colunas
-- ATENÇÃO) a constante vai entre ASPAS SIMPLES. O apelido da coluna vai entre ASPAS DUPLAS.
-- se você trocar os dois, o PostgreSQL acusa erro. No MySQL passava.
SELECT 'OBRA....:' AS "OBRAS PARA EMPRESTAR",
      titulo AS "Título da obra"
      FROM obra
      LIMIT 10;

-- USANDO A FUNÇÃO CONCAT
SELECT CONCAT(titulo, '........: ', id_obra) AS "Títulos para emprestar"
        FROM obra
        LIMIT 10;

-- o PostgreSQL tem também o operador || para concatenar, que é o padrão SQL.
-- CUIDADO com a diferença: se algum pedaço for NULL, o || devolve NULL e some a linha inteira.
-- O CONCAT ignora o nulo e continua. Quando houver coluna que aceita nulo, prefira CONCAT.
SELECT titulo || '........: ' || id_obra AS "Títulos para emprestar"
        FROM obra
        LIMIT 10;

-- demonstrando a diferença na prática
SELECT CONCAT('Obra: ', NULL, ' fim') AS com_concat,
       'Obra: ' || NULL || ' fim'     AS com_pipes;


/*-------------------------------------------------------------------------------------------------------------------------

 FUNÇÕES TRIM E LENGTH

-------------------------------------------------------------------------------------------------------------------------*/

-- A função trim retira os espaços contidos nas margens da cadeia de caracteres.
-- veja o select sem a função TRIM
SELECT CONCAT('Obras.............:            ',  titulo)
    FROM obra
    LIMIT 5;

-- Agora aplicando a função TRIM
SELECT CONCAT(TRIM('Obras.............:            '),  titulo)
    FROM obra
    LIMIT 5;


 -- usando a função LENGTH
 -- retorna a quantidade de caracteres de uma string
 SELECT LENGTH(titulo) AS quantidade_caracteres_no_titulo,
        titulo,
        id_obra
    FROM
      obra
       ORDER BY quantidade_caracteres_no_titulo
       LIMIT 10;


/*-------------------------------------------------------------------------------------------------------------------------

 OPERAÇÕES MATEMÁTICAS

 SQRT  = RAIZ QUADRADA DE UM NÚMERO
 EXP   = RETORNA O VALOR EXPONENCIAL DO PARÂMETRO PASSADO
 LN    = RETORNA O LOGARITMO NATURAL DO VALOR PASSADO
 MOD   = ACEITA DOIS PARÂMETROS, RETORNA O RESTO DA DIVISÃO INTEIRA DO PRIMEIRO PARÂMETRO PELO SEGUNDO
 POWER = ACEITA DOIS PARÂMETROS. RETORNA O VALOR DA POTÊNCIA DO PRIMEIRO PARÂMETRO PELO SEGUNDO PARÂMETRO
 TAN   = RETORNA A TANGENTE DE UM ARCO CUJO O VALOR FOI PASSADO COMO PARÂMETRO
-------------------------------------------------------------------------------------------------------------------------*/
-- UTILIZANDO VARIÁVEIS
-- ATENÇÃO) o PostgreSQL NÃO tem as variáveis de sessão @variavel do MySQL.
-- No MySQL escrevíamos:  SET @VALOR = 25;  SELECT SQRT(@VALOR);
-- Aqui existem três substitutos. Vamos ver os três.

-- [SUBSTITUTO 1] o mais simples: não usar variável nenhuma.
SELECT SQRT(25);

-- [SUBSTITUTO 2] a cláusula WITH. É SQL padrão, funciona em qualquer ferramenta,
-- e é a forma que vocês vão usar na prova.
-- COMO LER: o WITH cria uma "tabelinha temporária" chamada parametros, com uma coluna valor = 25.
-- O SELECT de baixo usa essa tabelinha como se fosse uma tabela de verdade.
WITH parametros AS (SELECT 25 AS valor)
SELECT SQRT(valor)  AS raiz_quadrada,
       EXP(valor)   AS exponencial,
       LN(valor)    AS logaritmo_natural
  FROM parametros;

-- [SUBSTITUTO 3] (OPCIONAL, só para curiosidade: pode pular)
-- variável de sessão de verdade, com set_config e current_setting.
-- serve quando o valor precisa sobreviver a vários comandos seguidos.
-- o prefixo "aula." é obrigatório: o PostgreSQL exige um ponto no nome para não confundir
-- com os parâmetros internos dele.
SELECT set_config('aula.valor', '25', false);
SELECT current_setting('aula.valor')::numeric AS valor_guardado;
SELECT SQRT(current_setting('aula.valor')::numeric) AS raiz_quadrada;

-- TESTANDO A FUNÇÃO MOD
-- RESTO 0, POIS 10 / 2 = 5 RESTO ZERO.
SELECT MOD(10, 2) AS resto;

-- TESTANDO A FUNÇÃO POWER
SELECT POWER(10, 2) AS potencia;

-- TESTANDO A FUNÇÃO TAN
SELECT TAN(10) AS tangente;

-- os três juntos, usando WITH, do jeito que se escreve de verdade
WITH parametros AS (SELECT 10 AS a, 2 AS b)
SELECT MOD(a,b)   AS resto,
       POWER(a,b) AS potencia,
       TAN(a)     AS tangente
  FROM parametros;


/*-------------------------------------------------------------------------------------------------------------------------

 ELIMINANDO REPETIÇÕES

 DISTINCT
-------------------------------------------------------------------------------------------------------------------------*/

-- VERIFICANDO QUANTOS REGISTROS TEMOS NA TABELA autor
SELECT COUNT(*) FROM autor;  -- 200 REGISTROS

-- VERIFICANDO SE HÁ PRIMEIROS NOMES REPETIDOS NA TABELA AUTORES
SELECT primeiro_nome, COUNT(*)
  FROM autor
    GROUP BY primeiro_nome
    ORDER BY COUNT(*) DESC, primeiro_nome;

-- resultado esperado: PENELOPE aparece em primeiro, com 4. Depois vêm vários nomes com 2.
-- PERCEBA QUE A AUTORA PENELOPE POSSUI 4 REGISTROS IGUAIS PARA O PRIMEIRO NOME. VAMOS VERIFICAR
-- O ÚLTIMO NOME PARA DISTINGUIR
SELECT primeiro_nome, ultimo_nome
  FROM autor
    WHERE primeiro_nome = 'PENELOPE';

-- VAMOS SELECIONAR APENAS PRIMEIROS NOMES DOS AUTORES QUE SEJAM DISTINTOS, E MANDAMOS CONTAR.
SELECT COUNT(DISTINCT primeiro_nome) FROM autor;  -- 128 REGISTROS.

-- e o DISTINCT sozinho, sem COUNT: mostra a lista, cada primeiro nome UMA vez só.
SELECT DISTINCT primeiro_nome
  FROM autor
 ORDER BY primeiro_nome;
-- resultado esperado: 128 linhas. 200 autores, mas só 128 primeiros nomes diferentes.

-- (OPCIONAL, pode pular) o PostgreSQL tem ainda o DISTINCT ON, que não existe no MySQL:
-- traz UMA linha inteira por valor repetido, e você escolhe QUAL linha com o ORDER BY.
-- aqui: um autor por primeiro nome, escolhendo o de sobrenome alfabeticamente menor.
SELECT DISTINCT ON (primeiro_nome) primeiro_nome, ultimo_nome, id_autor
  FROM autor
 ORDER BY primeiro_nome, ultimo_nome
 LIMIT 10;


/*-------------------------------------------------------------------------------------------------------------------------

JOINS possíveis no PostgreSQL


INNER JOIN: Retorna apenas as linhas que têm correspondência em ambas as tabelas sendo unidas.

LEFT JOIN (também conhecido como LEFT OUTER JOIN): Retorna todas as linhas da tabela à esquerda (a primeira tabela mencionada na consulta) e as correspondentes da tabela à direita, se houver alguma.

RIGHT JOIN (também conhecido como RIGHT OUTER JOIN): Retorna todas as linhas da tabela à direita (a segunda tabela mencionada na consulta) e as correspondentes da tabela à esquerda, se houver alguma.

FULL JOIN (ou FULL OUTER JOIN): Retorna todas as linhas de ambas as tabelas sendo unidas, incluindo aquelas que não têm correspondência.

CROSS JOIN: Retorna o produto cartesiano de duas tabelas, ou seja, todas as combinações possíveis entre as linhas das tabelas.

SELF JOIN: Quando uma tabela é unida a si mesma, geralmente usando aliases de tabela diferentes.

NATURAL JOIN: Realiza uma junção com base em colunas com o mesmo nome em ambas as tabelas, sem exigir uma cláusula ON explícita. No entanto, esse tipo de join não é amplamente recomendado, pois pode levar a resultados inesperados.

OBS IMPORTANTE) o FULL JOIN não existe no MySQL. No MySQL a gente simulava com UNION de dois LEFT JOIN.
No PostgreSQL ele existe de verdade, e hoje vamos usá-lo.
----------------------------------------------------------------------------------------------------------------------*/

-- PREPARAÇÃO DA DEMONSTRAÇÃO
-- ATENÇÃO) esta preparação é usada também nos exercícios da Aula 07 (itens 4.4 a 4.6). Não pule.
-- para enxergar a diferença entre os JOINs, precisamos de linhas SEM par dos dois lados.
-- vamos criar:
--   1) uma obra que NÃO tem área
--   2) uma área que NÃO tem obra
DELETE FROM obra_area WHERE id_obra IN (SELECT id_obra FROM obra WHERE titulo = 'MANUSCRITO SOLITARIO');
DELETE FROM obra  WHERE titulo = 'MANUSCRITO SOLITARIO';
DELETE FROM area  WHERE nome   = 'Acervo Raro';

INSERT INTO obra (titulo, ano_lancamento, valor_locacao, duracao_minutos, custo_reposicao, classificacao)
VALUES ('MANUSCRITO SOLITARIO', 2024, 4.99, 120, 29.99, 'L');   -- obra sem área

INSERT INTO area (nome) VALUES ('Acervo Raro');                  -- área sem obra


-- INNER JOIN = INTERSECÇÃO
-- só quem tem par dos dois lados.
SELECT COUNT(*) AS linhas_inner_join
        FROM obra O
     INNER JOIN obra_area OA ON O.id_obra = OA.id_obra
     INNER JOIN area A       ON OA.id_area = A.id_area;
-- resultado esperado: 1000. São 1001 obras, mas o MANUSCRITO SOLITARIO não tem área e fica de fora.
-- E o Acervo Raro também fica de fora, porque não tem obra.

-- OBS) a palavra INNER é opcional. Escrever só JOIN é a mesma coisa que INNER JOIN.

-- LEFT JOIN = TUDO DA ESQUERDA, MAIS O QUE CASAR DA DIREITA
-- entra o MANUSCRITO SOLITARIO, com a área vindo NULL.
SELECT O.id_obra, O.titulo, A.nome AS area_do_conhecimento
        FROM obra O
      LEFT JOIN obra_area OA ON O.id_obra = OA.id_obra
      LEFT JOIN area A       ON OA.id_area = A.id_area
     WHERE A.nome IS NULL;
-- resultado esperado: 1 linha, o MANUSCRITO SOLITARIO, com a área vazia (NULL).
-- O TRUQUE: LEFT JOIN + WHERE ... IS NULL = "quem da esquerda NÃO tem par na direita".
-- ATENÇÃO) para testar nulo é IS NULL. Escrever  = NULL  não dá erro, mas nunca traz nada.

-- RIGHT JOIN = TUDO DA DIREITA, MAIS O QUE CASAR DA ESQUERDA
-- entra o Acervo Raro, com a obra vindo NULL.
SELECT O.id_obra, O.titulo, A.nome AS area_do_conhecimento
        FROM obra_area OA
      RIGHT JOIN area A ON OA.id_area = A.id_area
      LEFT  JOIN obra O ON O.id_obra  = OA.id_obra
     WHERE O.id_obra IS NULL;
-- resultado esperado: 1 linha, o Acervo Raro, com a obra vazia (NULL).
-- OBS) todo RIGHT JOIN pode ser escrito como LEFT JOIN, só invertendo a ordem das tabelas.
-- Por isso, no mercado, quase todo mundo usa só LEFT JOIN.

-- FULL JOIN = TUDO DOS DOIS LADOS
-- aparecem os DOIS casos sem par, na mesma consulta.
SELECT O.id_obra, O.titulo, A.nome AS area_do_conhecimento
        FROM obra O
      FULL JOIN obra_area OA ON O.id_obra = OA.id_obra
      FULL JOIN area A       ON OA.id_area = A.id_area
     WHERE O.id_obra IS NULL OR A.id_area IS NULL;
-- resultado esperado: 2 linhas, o MANUSCRITO SOLITARIO (sem área) e o Acervo Raro (sem obra).
--
-- RESUMO DOS JOINS, pensando em duas listas: obras e áreas
--      INNER JOIN --> só quem tem par          (obra COM área)
--      LEFT  JOIN --> tudo da esquerda         (todas as obras, com ou sem área)
--      RIGHT JOIN --> tudo da direita          (todas as áreas, com ou sem obra)
--      FULL  JOIN --> tudo dos dois lados      (todas as obras e todas as áreas)


-- CROSS JOIN = TODAS AS COMBINAÇÕES POSSÍVEIS
-- VAMOS UTILIZAR OUTRO EXEMPLO PARA MOSTRAR AS COMBINAÇÕES.

DROP TABLE IF EXISTS grupo_a, grupo_b;

 -- Criação da tabela Grupo A
CREATE TABLE grupo_a (
  id_grupo_a INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  nome VARCHAR(50)
);

-- Inserção dos dados na tabela Grupo A
INSERT INTO grupo_a (nome) VALUES
('Brasil'),
('Holanda'),
('México'),
('EUA');

-- Criação da tabela Grupo B
CREATE TABLE grupo_b (
  id_grupo_b INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  nome VARCHAR(50)
);

-- Inserção dos dados na tabela Grupo B
INSERT INTO grupo_b (nome) VALUES
('Itália'),
('Argentina'),
('Japão'),
('França');

 -- CRIAMOS A ESTRUTURA, AGORA VAMOS UTILIZAR O CROSS JOIN ENTRE OS GRUPOS A E B.
 -- VEJA O RESULTADO COM TODAS AS COMBINAÇÕES POSSÍVEIS: 4 x 4 = 16 LINHAS.

 SELECT A.id_grupo_a,
        A.nome AS selecao_a,
        B.id_grupo_b,
        B.nome AS selecao_b
    FROM grupo_a A
    CROSS JOIN grupo_b B;

-- OBS) o CROSS JOIN é o único JOIN que NÃO tem ON. Ele não compara nada, combina tudo.
-- É também o erro mais caro que existe: um CROSS JOIN acidental entre duas tabelas de 1000 linhas
-- gera 1 milhão de linhas. Quando uma consulta "travar o banco", desconfie de um ON esquecido.


-- SELF JOIN = TABELA UNIDA A SI MESMA
-- autores que dividem o mesmo sobrenome. O alias diferente é o que permite tratar a mesma
-- tabela como se fossem duas.
SELECT  a.id_autor,
        a.primeiro_nome,
        a.ultimo_nome,
        b.id_autor       AS id_colega,
        b.primeiro_nome  AS primeiro_nome_colega
    FROM autor a
     JOIN autor b ON a.ultimo_nome = b.ultimo_nome
                 AND a.id_autor    <> b.id_autor   -- sem esta linha, cada autor casa consigo mesmo
   ORDER BY a.ultimo_nome, a.id_autor
   LIMIT 20;


-- NATURAL JOIN
/*
O exemplo retornará os IDs dos autores, seus primeiros nomes,
sobrenomes e os IDs das obras que eles escreveram.
O NATURAL JOIN combina automaticamente as colunas com o mesmo nome ("id_autor" e "id_obra")
nas tabelas "autor", "obra_autor" e "obra".
*/
SELECT  autor.id_autor,
        autor.primeiro_nome,
        autor.ultimo_nome,
        obra.id_obra
FROM autor
NATURAL JOIN obra_autor
NATURAL JOIN obra
LIMIT 10;

-- POR QUE NÃO USAR NATURAL JOIN: ele junta por TODA coluna de mesmo nome.
-- No dia em que alguém criar uma coluna "nome" nas duas tabelas, a consulta muda de resultado
-- sozinha, sem ninguém ter mexido nela. Escreva o ON. É mais longo e é seguro.
SELECT  autor.id_autor,
        autor.primeiro_nome,
        autor.ultimo_nome,
        obra.id_obra
FROM autor
JOIN obra_autor ON autor.id_autor = obra_autor.id_autor
JOIN obra       ON obra_autor.id_obra = obra.id_obra
LIMIT 10;


/*-------------------------------------------------------------------------------------------------------------------------
 FUNÇÃO COALESCE
 SUBSTITUI VALORES NULL POR OUTRO VALOR.
 ----------------------------------------------------------------------------------------------------------------------*/

-- PARA DEMONSTRAR A FUNÇÃO COALESCE, VAMOS CRIAR UMA NOVA TABELA COM ALGUNS VALORES NULL.

-- CRIAÇÃO DA TABELA DETALHES DA OBRA
-- ATENÇÃO) esta tabela é usada também nos exercícios da Aula 07 (itens 2.5 e 5.2). Não pule.
DROP TABLE IF EXISTS detalhes_obra;

CREATE TABLE detalhes_obra (
  id_detalhes_obra                  INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  id_obra                           INT,
  editora_detalhes                  VARCHAR(100),
  genero_detalhes                   VARCHAR(50),
  paginas_detalhes                  INT,
  ano_edicao_detalhes               INT,
  classificacao_indicativa_detalhes VARCHAR(10),

  FOREIGN KEY (id_obra) REFERENCES obra(id_obra)
);

-- INSERÇÃO DE DADOS NA TABELA DETALHES_OBRA
INSERT INTO detalhes_obra (id_obra,
                            editora_detalhes,
                            genero_detalhes,
                            paginas_detalhes,
                            ano_edicao_detalhes,
                            classificacao_indicativa_detalhes)
                        VALUES
                            (1, 'Bookman',  'Técnico',  420,  2020, '16 anos'),
                            (2, 'Atlas',    'Didático', 190,  2018, 'Livre'),
                            (3, NULL,       'Ensaio',   305,  NULL, '14 anos'),
                            (4, 'Campus',   'Manual',   NULL, 2019, '18 anos'),
                            (5, 'Saraiva',  NULL,       295,  2021, '12 anos'),
                            (6, NULL,       NULL,       NULL, NULL, NULL);

-- olhando o problema antes de resolver: seis linhas, cheias de buraco.
SELECT * FROM detalhes_obra;

-- UTILIZANDO A FUNÇÃO COALESCE
-- Utilizando o comando COALESCE para tratar valores nulos
SELECT id_obra,
        COALESCE(editora_detalhes, 'Editora não informada')  AS editora,
        COALESCE(genero_detalhes,  'Gênero não informado')   AS genero,
        COALESCE(paginas_detalhes,               0)          AS paginas,
        COALESCE(ano_edicao_detalhes,            0)          AS ano_da_edicao,
        COALESCE(classificacao_indicativa_detalhes, 'Classificação não informada') AS "CLASSIFICAÇÃO INDICATIVA NO BRASIL"
FROM detalhes_obra;

-- OBS) o COALESCE aceita quantos argumentos você quiser, e devolve o PRIMEIRO que não for nulo.
-- Ele é a tradução em SQL de "tente isto; se não tiver, tente aquilo; se não tiver, use este texto".
SELECT id_obra,
       COALESCE(editora_detalhes, genero_detalhes, 'Nada preenchido') AS primeiro_que_existir
  FROM detalhes_obra;

-- CUIDADO) COALESCE só enxerga NULL. String vazia '' NÃO é nulo, e passa direto.
SELECT COALESCE('', 'valor substituto') AS vazio_nao_e_nulo,
       COALESCE(NULL, 'valor substituto') AS nulo_e_substituido;


/*
FIM AULA 7
*/
