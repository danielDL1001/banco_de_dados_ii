/*-------------------------------------------------------------------------------------------------------------------------
Disciplina: Banco de Dados I
Autor....: Prof. Rodrigo Gonçalves Pinto
Objetivo..: Carga do banco db_biblioteca. Substitui o banco sakila que usávamos no MySQL.
Objeto....: 02_carga_db_biblioteca.sql

RODAR DEPOIS de ter criado o banco db_biblioteca (script 01_cria_bancos.sql).

ANTES DE EXECUTAR: conecte-se ao banco db_biblioteca.
   No DBeaver e no pgAdmin: troque o banco no seletor do topo da janela de SQL.
   No psql:                 \c db_biblioteca
Se você rodar este script conectado ao banco postgres, as tabelas vão nascer no lugar errado.
Para conferir onde você está, rode antes:  SELECT current_database();
--------------------------------------------------------------------------------------------------------------------------
De onde veio cada tabela (equivalência com o sakila do MySQL):

   sakila                db_biblioteca
   ------                -------------
   film              --> obra
   category          --> area
   film_category     --> obra_area
   actor             --> autor
   film_actor        --> obra_autor
   language          --> idioma
   city              --> cidade
   country           --> pais
   customer          --> leitor
   payment           --> emprestimo

A carga é DETERMINÍSTICA: não usa random(). Todo aluno que subir o container
vai ter exatamente os mesmos dados, os mesmos IDs e os mesmos totais que aparecem
nos comentários dos scripts de aula.

IMPORTANTE) este script é para RODAR INTEIRO, de uma vez. Você NÃO precisa entender
como os dados são gerados: os comandos usados aqui (unnest, LATERAL, generate_series)
são mais avançados que a disciplina. O que interessa é a PARTE DE CIMA, a criação das
tabelas, e a CONFERÊNCIA lá no fim. Leia as duas com calma.
--------------------------------------------------------------------------------------------------------------------------
Versão 1.0
*/

-- confirme o banco antes de continuar. Tem que responder db_biblioteca.
SELECT current_database();


/*------------------------------------------------------
CRIAÇÃO DAS TABELAS
--------------------------------------------------------*/
-- OBS) no PostgreSQL, o equivalente do AUTO_INCREMENT do MySQL é
-- GENERATED ALWAYS AS IDENTITY (padrão SQL) ou o tipo serial (herança do PostgreSQL antigo).
-- Vamos usar GENERATED ALWAYS AS IDENTITY, que é o padrão da linguagem.

-- COMO LER UMA TABELA (pegue a tabela obra lá embaixo como exemplo):
--   id_obra   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY
--   ^nome     ^tipo  ^o banco numera sozinho       ^chave primária: identifica cada linha
--
--   id_idioma INT REFERENCES idioma (id_idioma)
--                 ^chave estrangeira: só aceita um id_idioma que EXISTA na tabela idioma.
--
-- O DROP TABLE da primeira linha apaga as tabelas, se já existirem, para o script poder
-- ser rodado de novo sem erro. Se for a primeira vez, aparecem avisos (NOTICE) dizendo
-- que a tabela não existe. Isso NÃO é erro, pode ignorar.

DROP TABLE IF EXISTS emprestimo, leitor, cidade, pais, obra_autor, autor, obra_area, obra, area, idioma CASCADE;

CREATE TABLE idioma (
    id_idioma   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome        VARCHAR(50) NOT NULL
);

CREATE TABLE area (
    id_area     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome        VARCHAR(50) NOT NULL
);

CREATE TABLE obra (
    id_obra          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    titulo           VARCHAR(120) NOT NULL,
    descricao        TEXT,
    ano_lancamento   INT,
    id_idioma        INT REFERENCES idioma (id_idioma),
    dias_emprestimo  INT,
    valor_locacao    NUMERIC(5,2),
    duracao_minutos  INT,
    custo_reposicao  NUMERIC(6,2),
    classificacao    VARCHAR(5)
);

CREATE TABLE obra_area (
    id_obra  INT REFERENCES obra (id_obra),
    id_area  INT REFERENCES area (id_area),
    PRIMARY KEY (id_obra, id_area)
);

CREATE TABLE autor (
    id_autor        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    primeiro_nome   VARCHAR(50) NOT NULL,
    ultimo_nome     VARCHAR(50) NOT NULL
);

CREATE TABLE obra_autor (
    id_obra  INT REFERENCES obra (id_obra),
    id_autor INT REFERENCES autor (id_autor),
    PRIMARY KEY (id_obra, id_autor)
);

CREATE TABLE pais (
    id_pais    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome_pais  VARCHAR(60) NOT NULL
);

CREATE TABLE cidade (
    id_cidade   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cidade      VARCHAR(60) NOT NULL,
    id_pais     INT REFERENCES pais (id_pais)
);

CREATE TABLE leitor (
    id_leitor      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    primeiro_nome  VARCHAR(50) NOT NULL,
    ultimo_nome    VARCHAR(50) NOT NULL,
    id_cidade      INT REFERENCES cidade (id_cidade),
    ativo          BOOLEAN DEFAULT TRUE
);

CREATE TABLE emprestimo (
    id_emprestimo   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_leitor       INT REFERENCES leitor (id_leitor),
    valor           NUMERIC(6,2),
    data_emprestimo TIMESTAMP
);


/*------------------------------------------------------
CARGA DE DADOS
--------------------------------------------------------*/

-- IDIOMAS (6 registros)
INSERT INTO idioma (nome) VALUES
 ('Português'), ('Inglês'), ('Espanhol'), ('Francês'), ('Alemão'), ('Italiano');


-- ÁREAS DO CONHECIMENTO (16 registros, mesmo número de categorias do sakila)
INSERT INTO area (nome) VALUES
 ('Computação'), ('Matemática'), ('Física'), ('Química'),
 ('Biologia'), ('História'), ('Geografia'), ('Filosofia'),
 ('Literatura'), ('Direito'), ('Medicina'), ('Engenharia'),
 ('Economia'), ('Psicologia'), ('Sociologia'), ('Artes');


-- PAÍSES (12 registros)
INSERT INTO pais (nome_pais) VALUES
 ('Brasil'), ('Portugal'), ('Reino Unido'), ('Canadá'),
 ('Estados Unidos'), ('Argentina'), ('Espanha'), ('França'),
 ('Alemanha'), ('Itália'), ('México'), ('Japão');


-- OBRAS (1000 registros)
-- os títulos são gerados pela combinação de 40 palavras x 25 palavras = 1000 títulos únicos.
INSERT INTO obra (titulo, descricao, ano_lancamento, id_idioma,
                  dias_emprestimo, valor_locacao, duracao_minutos,
                  custo_reposicao, classificacao)
SELECT
    p1.palavra || ' ' || p2.palavra                                      AS titulo,
    'Obra pertencente ao acervo geral da biblioteca do IESB.'            AS descricao,
    1996 + ((n * 3) % 29)                                                AS ano_lancamento,
    1 + (n % 6)                                                          AS id_idioma,
    3 + (n % 5)                                                          AS dias_emprestimo,
    (ARRAY[0.99, 2.99, 4.99])[1 + (n % 3)]                               AS valor_locacao,
    46 + ((n * 13) % 140)                                                AS duracao_minutos,
    9.99 + ((n * 11) % 21)                                               AS custo_reposicao,
    (ARRAY['L','10','12','14','16','18'])[1 + ((n * 5) % 6)]             AS classificacao
FROM (
    SELECT palavra, row_number() OVER () AS i
      FROM unnest(ARRAY[
        'ACADEMIA','ALGORITMO','ANATOMIA','ARQUITETURA','ATLAS','AURORA','AVENTURA','BALADA',
        'BUSSOLA','CAMINHO','CANTATA','CAVERNA','CIDADELA','CODIGO','COMPASSO','CRONICA',
        'DESERTO','DIARIO','ECLIPSE','ENIGMA','ESTRELA','FABULA','FAROL','FRONTEIRA',
        'GALERIA','HORIZONTE','JORNADA','LABIRINTO','LEGADO','MEMORIA','MOSAICO','ORACULO',
        'PANORAMA','PRELUDIO','RETRATO','SINFONIA','TAPECARIA','TRATADO','UNIVERSO','VERTICE'
      ]) AS palavra
) p1
CROSS JOIN (
    SELECT palavra, row_number() OVER () AS j
      FROM unnest(ARRAY[
        'ANTIGO','AZUL','BRANCO','CELESTE','DIGITAL','DOURADO','ETERNO','FERIDO',
        'GELADO','INFINITO','LUNAR','MARINHO','NOTURNO','OCULTO','PERDIDO','PROFUNDO',
        'QUEBRADO','SAGRADO','SELVAGEM','SILENCIOSO','SOLAR','SOMBRIO','VAZIO','VELOZ','VERMELHO'
      ]) AS palavra
) p2
CROSS JOIN LATERAL (SELECT ((p1.i - 1) * 25 + p2.j)::int AS n) calc
ORDER BY n;

-- a obra 1 tem duração fixa em 86 minutos: ela é usada na Aula 08,
-- no exemplo de IF / ELSIF dentro de procedure.
UPDATE obra SET duracao_minutos = 86 WHERE id_obra = 1;


-- OBRA x ÁREA (cada obra pertence a exatamente uma área)
INSERT INTO obra_area (id_obra, id_area)
SELECT id_obra, 1 + ((id_obra * 11) % 16) FROM obra;

-- o custo de reposição passa a depender da ÁREA da obra: área técnica repõe mais caro.
-- é isso que faz a pergunta "qual área custa mais caro para repor?" ter resposta na Aula 07.
UPDATE obra o
   SET custo_reposicao = 6.99 + (oa.id_area * 1.1) + ((o.id_obra * 7) % 6)
  FROM obra_area oa
 WHERE oa.id_obra = o.id_obra;


-- AUTORES (200 registros)
-- a lista abaixo tem 138 primeiros nomes, mas a conta (n * 37) % 128 só alcança os 128 primeiros.
-- resultado: 128 primeiros nomes distintos, distribuídos sobre 200 autores.
INSERT INTO autor (primeiro_nome, ultimo_nome)
SELECT
    nomes.primeiro[1 + ((n * 37) % 128)],
    sobrenomes.ultimo[1 + ((n * 17) % 40)]
FROM generate_series(1, 200) AS n,
LATERAL (SELECT ARRAY[
 'ADRIANA','AFONSO','AGATHA','ALBERTO','ALICE','ALINE','ALVARO','AMANDA','ANA','ANDRE',
 'ANGELA','ANTONIO','ARTHUR','AUGUSTO','AURORA','BEATRIZ','BERNARDO','BIANCA','BRENO','BRUNA',
 'BRUNO','CAIO','CAMILA','CARLA','CARLOS','CAROLINA','CASSIA','CECILIA','CELIA','CESAR',
 'CLARA','CLAUDIA','CLOVIS','CRISTINA','DANIEL','DANIELA','DAVI','DEBORA','DIEGO','DIOGO',
 'EDUARDA','EDUARDO','ELAINE','ELIAS','ELISA','EMANUEL','ERIKA','ESTELA','EVANDRO','FABIANA',
 'FABIO','FELIPE','FERNANDA','FERNANDO','FLAVIA','FRANCISCO','GABRIEL','GABRIELA','GERALDO','GILBERTO',
 'GISELE','GUILHERME','GUSTAVO','HELENA','HELIO','HENRIQUE','HUGO','IARA','IGOR','INES',
 'ISABEL','ISADORA','IVAN','JAQUELINE','JOANA','JOAO','JORGE','JOSE','JULIA','JULIANA',
 'JULIO','KARINA','LARISSA','LAURA','LEANDRO','LEONARDO','LETICIA','LIVIA','LORENA','LUCAS',
 'LUCIA','LUCIANA','LUIS','LUIZA','MANUELA','MARCELO','MARCIA','MARCO','MARCOS','MARIA',
 'MARIANA','MARINA','MARTA','MATEUS','MAURICIO','MIGUEL','MILENA','MONICA','MURILO','NATALIA',
 'NELSON','NICOLE','OLIVIA','OSCAR','OTAVIO','PATRICIA','PAULA','PAULO','PEDRO','PENELOPE',
 'PRISCILA','RAFAEL','RAQUEL','RENATA','RENATO','RICARDO','ROBERTA','ROBERTO','RODRIGO','ROSANA',
 'SAMUEL','SANDRA','SERGIO','SILVIA','SOFIA','TATIANA','THIAGO','VITOR'
 ] AS primeiro) AS nomes,
LATERAL (SELECT ARRAY[
 'ALMEIDA','ALVES','ANDRADE','ARAUJO','AZEVEDO','BARBOSA','BARROS','BATISTA',
 'BORGES','BRAGA','CAMPOS','CARDOSO','CARVALHO','CASTRO','CORREIA','COSTA',
 'CUNHA','DIAS','DUARTE','FARIAS','FERNANDES','FERREIRA','FONSECA','FREITAS',
 'GOMES','GONCALVES','LIMA','LOPES','MACHADO','MARTINS','MELO','MENDES',
 'MONTEIRO','MOREIRA','NASCIMENTO','NUNES','OLIVEIRA','PEREIRA','PINTO','RAMOS'
 ] AS ultimo) AS sobrenomes;

-- PENELOPE recebe registros extras. Ela é usada na Aula 07 como exemplo de
-- primeiro nome repetido, no tópico DISTINCT.
UPDATE autor SET primeiro_nome = 'PENELOPE' WHERE id_autor IN (3, 47, 155);


-- OBRA x AUTOR (2985 vínculos)
INSERT INTO obra_autor (id_obra, id_autor)
SELECT DISTINCT o.id_obra, 1 + ((o.id_obra * k + k * 7) % 200)
  FROM obra o, generate_series(1, 3) AS k;


-- CIDADES (130 registros)
-- 120 nomes distintos; 10 desses nomes aparecem DUAS vezes, em países diferentes.
-- Esses 10 nomes repetidos são o exemplo de "encontrar registros duplicados" com HAVING, na Aula 07.
INSERT INTO cidade (cidade, id_pais)
SELECT nomes.c[n], 1 + (n % 12)
FROM generate_series(1, 120) AS n,
LATERAL (SELECT ARRAY[
 'Londres','Porto','Lisboa','Madri','Barcelona','Paris','Lyon','Berlim','Munique','Roma',
 'Milao','Napoles','Toronto','Vancouver','Montreal','Chicago','Boston','Seattle','Denver','Austin',
 'Miami','Atlanta','Dallas','Houston','Phoenix','Portland','Detroit','Baltimore','Orlando','Nashville',
 'Brasilia','Salvador','Recife','Fortaleza','Curitiba','Manaus','Belem','Goiania','Vitoria','Natal',
 'Maceio','Teresina','Palmas','Macapa','Cuiaba','Aracaju','Florianopolis','Londrina','Maringa','Santos',
 'Campinas','Sorocaba','Uberlandia','Ribeirao','Niteroi','Petropolis','Caxias','Pelotas','Bauru','Marilia',
 'Buenos','Cordoba','Rosario','Mendoza','Tucuman','Salta','Neuquen','Parana','Corrientes','Formosa',
 'Guadalajara','Monterrey','Puebla','Tijuana','Merida','Cancun','Toluca','Leon','Queretaro','Durango',
 'Toquio','Osaka','Kyoto','Nagoya','Sapporo','Fukuoka','Kobe','Sendai','Hiroshima','Niigata',
 'Hamburgo','Colonia','Frankfurt','Stuttgart','Dresden','Leipzig','Bremen','Hannover','Nuremberg','Essen',
 'Turim','Bolonha','Florenca','Veneza','Genova','Palermo','Verona','Catania','Bari','Trieste',
 'Coimbra','Braga','Faro','Aveiro','Evora','Sintra','Setubal','Guimaraes','Funchal','Viseu'
 ] AS c) AS nomes;

-- as 10 cidades repetidas: mesmo nome, país diferente.
INSERT INTO cidade (cidade, id_pais)
SELECT c.cidade, 1 + ((c.id_pais + 4) % 12)
  FROM cidade c
 WHERE c.id_cidade IN (1, 5, 13, 21, 31, 45, 61, 73, 81, 91);


-- LEITORES (599 registros)
INSERT INTO leitor (primeiro_nome, ultimo_nome, id_cidade)
SELECT
    a.primeiro_nome,
    b.ultimo_nome,
    1 + (n % 130)
FROM generate_series(1, 599) AS n
JOIN autor a ON a.id_autor = 1 + (n % 200)
JOIN autor b ON b.id_autor = 1 + ((n * 3) % 200);


-- EMPRÉSTIMOS (16044 registros)
INSERT INTO emprestimo (id_leitor, valor, data_emprestimo)
SELECT
    1 + (n % 599),
    (ARRAY[0.99, 2.99, 4.99, 5.99, 7.99, 9.99, 11.99])[1 + (n % 7)],
    TIMESTAMP '2025-02-01 08:00:00' + ((n % 300) || ' days')::interval
                                    + ((n % 11) || ' hours')::interval
FROM generate_series(1, 16044) AS n;


/*------------------------------------------------------
CONFERÊNCIA DA CARGA
--------------------------------------------------------*/
-- se algum número aqui não bater com a lista abaixo, a carga falhou.
-- resultado esperado:
--      area ........ 16        idioma ...... 6
--      autor ....... 200       leitor ...... 599
--      cidade ...... 130       obra ........ 1000
--      emprestimo .. 16044     obra_area ... 1000
--      obra_autor .. 2985      pais ........ 12
-- se apareceu "relation does not exist", você rodou o script no banco errado.
-- volte ao topo, troque para db_biblioteca e rode de novo: o DROP TABLE do início limpa tudo.
SELECT 'idioma'     AS tabela, COUNT(*) FROM idioma
UNION ALL SELECT 'area',        COUNT(*) FROM area
UNION ALL SELECT 'pais',        COUNT(*) FROM pais
UNION ALL SELECT 'obra',        COUNT(*) FROM obra
UNION ALL SELECT 'obra_area',   COUNT(*) FROM obra_area
UNION ALL SELECT 'autor',       COUNT(*) FROM autor
UNION ALL SELECT 'obra_autor',  COUNT(*) FROM obra_autor
UNION ALL SELECT 'cidade',      COUNT(*) FROM cidade
UNION ALL SELECT 'leitor',      COUNT(*) FROM leitor
UNION ALL SELECT 'emprestimo',  COUNT(*) FROM emprestimo
ORDER BY 1;
