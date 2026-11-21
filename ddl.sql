-- ============================================================================
-- BANCO DE DADOS II - MODELO FÍSICO (DDL ÚNICO)
-- Arquivo de referência: projeto_bdII.drawio (modelo lógico)
-- Base: PostgreSQL 16/17
--
-- Observações:
-- Aluno: Daniel, Alexandre, Kalel
-- ============================================================================

DROP SCHEMA IF EXISTS academico CASCADE;
CREATE SCHEMA academico;
SET search_path TO academico, public;

-- ============================================================================
-- 1. TIPOS PERSONALIZADOS
-- ============================================================================

CREATE TYPE vinculo_t AS ENUM (
    'PRE_REQUISITO',
    'CO_REQUISITO'
);

-- ============================================================================
-- 2. ESTRUTURA GEOGRÁFICA
-- ============================================================================

CREATE TABLE pais (
    id_pais       integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome_pais     varchar(100) NOT NULL,
    codigo_pais   integer
);

CREATE TABLE estado (
    id_estado    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pais      integer NOT NULL,
    nome_estado  varchar(100) NOT NULL,
    municipio    varchar(100),

    CONSTRAINT fk_estado_pais
        FOREIGN KEY (id_pais)
        REFERENCES pais (id_pais)
);

CREATE TABLE cidade (
    id_cidade      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_estado      integer NOT NULL,
    nome           varchar(100) NOT NULL,
    codigo_cidade  integer,

    CONSTRAINT fk_cidade_estado
        FOREIGN KEY (id_estado)
        REFERENCES estado (id_estado)
);

-- ============================================================================
-- 3. ESTRUTURA FÍSICA DA INSTITUIÇÃO
-- ============================================================================

CREATE TABLE campus (
    id_campus      smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_cidade      integer NOT NULL,
    nome_campus    varchar(60) NOT NULL,
    endereco       varchar(100),
    telefone       varchar(15),
    cep            varchar(9),
    complementos   varchar(100),
    qtd_blocos     smallint,
    salas          smallint,

    CONSTRAINT fk_campus_cidade
        FOREIGN KEY (id_cidade)
        REFERENCES cidade (id_cidade)
);

CREATE TABLE predio (
    id_predio    smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_campus    smallint NOT NULL,
    qtd_predios  integer,

    CONSTRAINT fk_predio_campus
        FOREIGN KEY (id_campus)
        REFERENCES campus (id_campus)
);

CREATE TABLE bloco (
    id_bloco    smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_predio   smallint NOT NULL,

    CONSTRAINT fk_bloco_predio
        FOREIGN KEY (id_predio)
        REFERENCES predio (id_predio)
);

CREATE TABLE sala (
    id_sala      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_bloco     smallint NOT NULL,
    codigo       varchar(10) NOT NULL,
    tipo         varchar(30),
    capacidade   smallint,

    CONSTRAINT fk_sala_bloco
        FOREIGN KEY (id_bloco)
        REFERENCES bloco (id_bloco),

    CONSTRAINT ck_sala_capacidade
        CHECK (capacidade IS NULL OR capacidade > 0)
);

-- ============================================================================
-- 4. ESTRUTURA ACADÊMICA
-- ============================================================================

CREATE TABLE curso (
    id_curso    smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_campus   smallint,
    codigo      varchar(10) NOT NULL,
    nome        varchar(120) NOT NULL,
    grau        varchar(120),
    ch_total    smallint,

    CONSTRAINT fk_curso_campus
        FOREIGN KEY (id_campus)
        REFERENCES campus (id_campus),

    CONSTRAINT ck_curso_ch_total
        CHECK (ch_total IS NULL OR ch_total > 0)
);

CREATE TABLE campus_curso (
    fk_id_campus  smallint,
    fk_id_curso   smallint,

    CONSTRAINT pk_campus_curso
        PRIMARY KEY (fk_id_campus, fk_id_curso),

    CONSTRAINT fk_campus_curso_campus
        FOREIGN KEY (fk_id_campus)
        REFERENCES campus (id_campus),

    CONSTRAINT fk_campus_curso_curso
        FOREIGN KEY (fk_id_curso)
        REFERENCES curso (id_curso)
);

CREATE TABLE curriculo (
    id_curriculo  smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_curso      smallint NOT NULL,
    ano_vigencia  smallint,
    ativo         boolean,

    CONSTRAINT fk_curriculo_curso
        FOREIGN KEY (id_curso)
        REFERENCES curso (id_curso)
);

CREATE TABLE disciplina (
    id_disciplina  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo         varchar(10) NOT NULL,
    nome           varchar(120) NOT NULL,
    ch_teorica     smallint,
    ch_pratica     smallint,
    ch_total       smallint,
    ementa         text,

    CONSTRAINT ck_disciplina_ch
        CHECK (
            COALESCE(ch_teorica, 0) >= 0
            AND COALESCE(ch_pratica, 0) >= 0
            AND COALESCE(ch_total, 0) >= 0
        )
);

CREATE TABLE curriculo_disciplina (
    id_curriculo   smallint,
    id_disciplina  integer,
    tipo           varchar(20),
    periodo        smallint,

    CONSTRAINT pk_curriculo_disciplina
        PRIMARY KEY (id_curriculo, id_disciplina),

    CONSTRAINT fk_curriculo_disciplina_curriculo
        FOREIGN KEY (id_curriculo)
        REFERENCES curriculo (id_curriculo),

    CONSTRAINT fk_curriculo_disciplina_disciplina
        FOREIGN KEY (id_disciplina)
        REFERENCES disciplina (id_disciplina)
);

CREATE TABLE pre_requisito (
    id_disciplina  integer,
    id_requisito   integer,
    vinculo        academico.vinculo_t,

    CONSTRAINT pk_pre_requisito
        PRIMARY KEY (id_disciplina, id_requisito),

    CONSTRAINT fk_pre_requisito_disciplina
        FOREIGN KEY (id_disciplina)
        REFERENCES disciplina (id_disciplina),

    CONSTRAINT fk_pre_requisito_requisito
        FOREIGN KEY (id_requisito)
        REFERENCES disciplina (id_disciplina),

    CONSTRAINT ck_pre_requisito_distintas
        CHECK (id_disciplina <> id_requisito)
);

CREATE TABLE professor (
    id_professor  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    matricula     varchar(12) NOT NULL UNIQUE,
    nome          varchar(120) NOT NULL,
    email         varchar(120),
    titulacao     varchar(20)
);

-- ============================================================================
-- 5. OFERTA DE DISCIPLINAS
-- ============================================================================

CREATE TABLE periodo_letivo (
    id_periodo_letivo  smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ano                smallint NOT NULL,
    semestre           smallint NOT NULL,
    data_inicio        date,
    data_fim           date,

    CONSTRAINT ck_periodo_semestre
        CHECK (semestre BETWEEN 1 AND 2),

    CONSTRAINT ck_periodo_datas
        CHECK (data_fim IS NULL OR data_inicio IS NULL OR data_fim >= data_inicio)
);

CREATE TABLE turma (
    id_turma           integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_disciplina      integer NOT NULL,
    id_professor       integer,
    id_periodo_letivo  smallint NOT NULL,
    turno              varchar(10),
    codigo             varchar(15) NOT NULL,

    CONSTRAINT fk_turma_disciplina
        FOREIGN KEY (id_disciplina)
        REFERENCES disciplina (id_disciplina),

    CONSTRAINT fk_turma_professor
        FOREIGN KEY (id_professor)
        REFERENCES professor (id_professor),

    CONSTRAINT fk_turma_periodo
        FOREIGN KEY (id_periodo_letivo)
        REFERENCES periodo_letivo (id_periodo_letivo)
);

-- ============================================================================
-- 6. VIDA ACADÊMICA
-- ============================================================================

CREATE TABLE aluno (
    id_aluno         integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome             varchar(100) NOT NULL,
    email            varchar(100),
    cpf              char(11) NOT NULL UNIQUE,
    telefone_aluno   char(11)
);

CREATE TABLE matricula (
    id_matricula    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_aluno        integer NOT NULL,
    id_turma        integer NOT NULL,
    status          varchar(15),
    data_matricula  date,

    CONSTRAINT uq_matricula_aluno_turma
        UNIQUE (id_aluno, id_turma),

    CONSTRAINT fk_matricula_aluno
        FOREIGN KEY (id_aluno)
        REFERENCES aluno (id_aluno),

    CONSTRAINT fk_matricula_turma
        FOREIGN KEY (id_turma)
        REFERENCES turma (id_turma)
);

-- historico é 1:1 com matricula (ERone no Draw.io)
CREATE TABLE historico (
    id_historico  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_matricula  integer NOT NULL UNIQUE,
    situacao      varchar(15),
    n1            numeric(4,2),
    n2            numeric(4,2),
    n3            numeric(4,2),
    media_final   numeric(4,2),
    frequencia    numeric(5,2),

    CONSTRAINT fk_historico_matricula
        FOREIGN KEY (id_matricula)
        REFERENCES matricula (id_matricula),

    CONSTRAINT ck_historico_notas
        CHECK (
            (n1 IS NULL OR n1 BETWEEN 0 AND 10)
            AND (n2 IS NULL OR n2 BETWEEN 0 AND 10)
            AND (n3 IS NULL OR n3 BETWEEN 0 AND 10)
            AND (media_final IS NULL OR media_final BETWEEN 0 AND 10)
        ),

    CONSTRAINT ck_historico_frequencia
        CHECK (frequencia IS NULL OR frequencia BETWEEN 0 AND 100)
);

-- ============================================================================
-- 7. FERIADOS
-- ============================================================================

CREATE TABLE feriado (
    id_feriado  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    descricao   varchar(120) NOT NULL,
    data        date NOT NULL
);

CREATE TABLE pais_feriado (
    fk_id_pais     integer,
    fk_id_feriado  integer,

    CONSTRAINT pk_pais_feriado
        PRIMARY KEY (fk_id_pais, fk_id_feriado),

    CONSTRAINT fk_pais_feriado_pais
        FOREIGN KEY (fk_id_pais)
        REFERENCES pais (id_pais),

    CONSTRAINT fk_pais_feriado_feriado
        FOREIGN KEY (fk_id_feriado)
        REFERENCES feriado (id_feriado)
);

-- ============================================================================
-- 8. AUDITORIA
-- ============================================================================

CREATE TABLE log_matricula (
    id_log        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_matricula  integer NOT NULL,
    acao          varchar(20),
    usuario       varchar(60),
    detalhe       text,
    ocorrido_em   timestamp,

    CONSTRAINT fk_log_matricula_matricula
        FOREIGN KEY (id_matricula)
        REFERENCES matricula (id_matricula)
);

-- ============================================================================
-- 9. ÍNDICES DE APOIO (colunas de chave estrangeira usadas em junções)
-- ============================================================================

CREATE INDEX ix_estado_pais              ON estado (id_pais);
CREATE INDEX ix_cidade_estado            ON cidade (id_estado);
CREATE INDEX ix_campus_cidade            ON campus (id_cidade);
CREATE INDEX ix_predio_campus            ON predio (id_campus);
CREATE INDEX ix_bloco_predio             ON bloco (id_predio);
CREATE INDEX ix_sala_bloco               ON sala (id_bloco);
CREATE INDEX ix_curso_campus             ON curso (id_campus);
CREATE INDEX ix_campus_curso_curso       ON campus_curso (fk_id_curso);
CREATE INDEX ix_curriculo_curso          ON curriculo (id_curso);
CREATE INDEX ix_curriculo_disc_disciplina ON curriculo_disciplina (id_disciplina);
CREATE INDEX ix_pre_requisito_requisito  ON pre_requisito (id_requisito);
CREATE INDEX ix_turma_disciplina         ON turma (id_disciplina);
CREATE INDEX ix_turma_professor          ON turma (id_professor);
CREATE INDEX ix_turma_periodo            ON turma (id_periodo_letivo);
CREATE INDEX ix_matricula_turma          ON matricula (id_turma);
CREATE INDEX ix_pais_feriado_feriado     ON pais_feriado (fk_id_feriado);
CREATE INDEX ix_log_matricula_matricula  ON log_matricula (id_matricula);

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- ----------------------------------------------------------------------------
-- 0. TABELAS TEMPORÁRIAS DE APOIO (somem sozinhas no COMMIT)
-- ----------------------------------------------------------------------------

-- 0.1 Matriz curricular de Ciência da Computação (conforme o PDF)
-- periodo = semestre do curso (1A=1, 1B=2, 2A=3, 2B=4, ... 4B=8)
-- eixo    = classificação pelas cores da legenda do PDF
-- Disciplinas DIGITAIS: 3h/45 dias = 51T/9P ; 3h/20 dias = 42T/18P
--   (valores obtidos fechando os totais de teórica/prática de cada módulo do PDF).
-- Projeto Integrador 2A: PDF não detalha a divisão; assumido 10T/50P.

BEGIN;

SET search_path TO academico, public;

CREATE TEMP TABLE tmp_matriz (
    periodo  smallint,
    eixo     varchar(20),
    nome     varchar(120),
    ch_t     smallint,
    ch_p     smallint
) ON COMMIT DROP;

INSERT INTO tmp_matriz (periodo, eixo, nome, ch_t, ch_p)
SELECT * FROM (VALUES
 -- 1º ciclo - módulo 1A
 (1,'FLUTUANTE','Tópicos de Matemática',45,15),
 (1,'FLUTUANTE','Algoritmos e Programação de Computadores I',30,30),
 (1,'PROFISSIONALIZANTE','Fundamentos de Lógica',45,15),
 (1,'PROFISSIONALIZANTE','Geometria Analítica e Vetores',45,15),
 (1,'PROFISSIONALIZANTE','Matemática Discreta',45,15),
 (1,'PROFISSIONALIZANTE','Laboratório Práticas I',0,30),
 (1,'PROFISSIONALIZANTE','Leitura e Produção de Textos',51,9),
 -- 1º ciclo - módulo 1B
 (2,'FLUTUANTE','Cálculo I',45,15),
 (2,'FLUTUANTE','Algoritmos e Programação de Computadores II',30,30),
 (2,'PROFISSIONALIZANTE','Álgebra Linear',45,15),
 (2,'PROFISSIONALIZANTE','Banco de Dados I',30,30),
 (2,'PROFISSIONALIZANTE','Sistemas Digitais',30,30),
 (2,'PROFISSIONALIZANTE','Laboratório Práticas II',0,30),
 (2,'PROFISSIONALIZANTE','Inglês Instrumental',51,9),
 -- 2º ciclo - módulo 2A
 (3,'PROFISSIONALIZANTE','Cálculo II',45,15),
 (3,'FUNDAMENTOS','Estrutura de Dados',15,45),
 (3,'FUNDAMENTOS','Organização de Computadores',45,15),
 (3,'FUNDAMENTOS','Teoria da Computação',60,0),
 (3,'FUNDAMENTOS','Projeto Integrador 2A',10,50),
 (3,'FUNDAMENTOS','Arquitetura de Computadores',42,18),
 (3,'FUNDAMENTOS','Metodologia da Pesquisa',51,9),
 -- 2º ciclo - módulo 2B
 (4,'FUNDAMENTOS','Engenharia de Software',45,15),
 (4,'FUNDAMENTOS','Banco de Dados II',30,30),
 (4,'FUNDAMENTOS','Inteligência Artificial',30,30),
 (4,'FUNDAMENTOS','Programação Orientada a Objetos',15,45),
 (4,'FUNDAMENTOS','Sistemas Operacionais',45,15),
 (4,'FUNDAMENTOS','Governança de TI e Mapeamento de Processos',42,18),
 (4,'FUNDAMENTOS','Ética',51,9),
 -- 3º ciclo - módulo 3A
 (5,'FUNDAMENTOS','Cálculo Numérico',30,30),
 (5,'PROFISSIONALIZANTE','Computação Gráfica',15,45),
 (5,'PROFISSIONALIZANTE','Paradigmas de Linguagem de Programação',15,45),
 (5,'PROFISSIONALIZANTE','Processamento de Imagens',30,30),
 (5,'PROFISSIONALIZANTE','Programação para Dispositivos Móveis',15,45),
 (5,'PROFISSIONALIZANTE','Projeto Integrador 3A',10,50),
 -- 3º ciclo - módulo 3B
 (6,'PROFISSIONALIZANTE','Linguagens Formais e Autômatos',45,15),
 (6,'PROFISSIONALIZANTE','Programação Paralela',15,45),
 (6,'PROFISSIONALIZANTE','Redes de Computadores I',30,30),
 (6,'PROFISSIONALIZANTE','Teoria dos Grafos',15,45),
 (6,'PROFISSIONALIZANTE','Projeto Integrador 3B',60,0),
 (6,'FUNDAMENTOS','Probabilidade e Estatística',42,18),
 -- 4º ciclo - módulo 4A
 (7,'PROFISSIONALIZANTE','Análise de Algoritmos',30,30),
 (7,'PRATICA_CARREIRA','Estágio Supervisionado I',0,100),
 (7,'PROFISSIONALIZANTE','Inteligência Artificial II',15,45),
 (7,'PROFISSIONALIZANTE','Sistemas Distribuídos',30,30),
 (7,'PROFISSIONALIZANTE','Tópicos em Banco de Dados',30,30),
 (7,'PROFISSIONALIZANTE','Administração de Serviços da Internet',42,18),
 (7,'PRATICA_CARREIRA','Trabalho de Conclusão de Curso I',0,60),
 -- 4º ciclo - módulo 4B
 (8,'PROFISSIONALIZANTE','Compiladores',45,15),
 (8,'PROFISSIONALIZANTE','Sistemas de Comunicação',45,15),
 (8,'PRATICA_CARREIRA','Estágio Supervisionado II',0,100),
 (8,'PROFISSIONALIZANTE','Sistemas de Tempo Real',30,30),
 (8,'PROFISSIONALIZANTE','Tecnologias Web',30,30),
 (8,'PROFISSIONALIZANTE','Tópicos em Computação',30,30),
 (8,'PROFISSIONALIZANTE','Criptografia: Algoritmo e Certificação Digital',42,18),
 (8,'PRATICA_CARREIRA','Trabalho de Conclusão de Curso II',0,60),
 -- Disciplinas eletivas (60h cada; cursadas no 4A no lugar de "Eletiva")
 (7,'ELETIVA','Interface Homem-Computador',60,0),
 (7,'ELETIVA','Libras',60,0)
) AS v(periodo, eixo, nome, ch_t, ch_p);

-- 0.2 Listas de nomes para gerar professores e alunos
CREATE TEMP TABLE tmp_nome ON COMMIT DROP AS
SELECT t.nome, t.rn::int AS rn
FROM unnest(ARRAY[
  'Ana','Bruno','Carla','Daniel','Eduarda','Felipe','Gabriela','Henrique',
  'Isabela','João','Karina','Lucas','Mariana','Nicolas','Olívia','Pedro',
  'Quitéria','Rafael','Sofia','Thiago','Úrsula','Vitor','Wanessa','Yuri'
]) WITH ORDINALITY AS t(nome, rn);

CREATE TEMP TABLE tmp_sobrenome ON COMMIT DROP AS
SELECT t.sobrenome, t.rn::int AS rn
FROM unnest(ARRAY[
  'Silva','Santos','Oliveira','Souza','Rodrigues','Ferreira','Alves','Pereira',
  'Lima','Gomes','Costa','Ribeiro','Martins','Carvalho','Almeida','Lopes',
  'Soares','Fernandes','Vieira','Barbosa','Rocha','Dias','Nascimento','Andrade','Moreira'
]) WITH ORDINALITY AS t(sobrenome, rn);

-- 0.3 Feriados: (país, descrição, mês, dia)
CREATE TEMP TABLE tmp_feriado (
    pais       varchar(100),
    descricao  varchar(120),
    mes        integer,
    dia        integer
) ON COMMIT DROP;

INSERT INTO tmp_feriado (pais, descricao, mes, dia)
SELECT * FROM (VALUES
 ('Brasil','Confraternização Universal',1,1),
 ('Brasil','Tiradentes',4,21),
 ('Brasil','Aniversário de Brasília',4,21),
 ('Brasil','Dia do Trabalho',5,1),
 ('Brasil','Independência do Brasil',9,7),
 ('Brasil','Nossa Senhora Aparecida',10,12),
 ('Brasil','Finados',11,2),
 ('Brasil','Proclamação da República',11,15),
 ('Brasil','Consciência Negra',11,20),
 ('Brasil','Dia do Evangélico (DF)',11,30),
 ('Brasil','Natal',12,25),
 ('Argentina','Día de la Independencia',7,9),
 ('Argentina','Navidad',12,25),
 ('Portugal','Dia da Liberdade',4,25),
 ('Portugal','Dia de Portugal',6,10),
 ('Portugal','Natal (Portugal)',12,25),
 ('Uruguai','Declaratoria de la Independencia',8,25)
) AS v(pais, descricao, mes, dia);

-- ----------------------------------------------------------------------------
-- 1. PAÍS, ESTADO, CIDADE
-- ----------------------------------------------------------------------------

INSERT INTO pais (nome_pais, codigo_pais)
SELECT * FROM (VALUES
  ('Brasil',55),('Argentina',54),('Portugal',351),('Estados Unidos',1),
  ('Uruguai',598),('Paraguai',595),('Chile',56),('Colômbia',57)
) AS v(nome_pais, codigo_pais);

-- Técnica: INNER JOIN - o nome do país da lista é ligado à PK de "pais".
-- Como ler: "para cada estado brasileiro da lista, grave o id do Brasil".
INSERT INTO estado (id_pais, nome_estado, municipio)
SELECT p.id_pais, v.nome_estado, v.capital
FROM (VALUES
  ('Acre','Rio Branco'),('Alagoas','Maceió'),('Amapá','Macapá'),('Amazonas','Manaus'),
  ('Bahia','Salvador'),('Ceará','Fortaleza'),('Distrito Federal','Brasília'),
  ('Espírito Santo','Vitória'),('Goiás','Goiânia'),('Maranhão','São Luís'),
  ('Mato Grosso','Cuiabá'),('Mato Grosso do Sul','Campo Grande'),
  ('Minas Gerais','Belo Horizonte'),('Pará','Belém'),('Paraíba','João Pessoa'),
  ('Paraná','Curitiba'),('Pernambuco','Recife'),('Piauí','Teresina'),
  ('Rio de Janeiro','Rio de Janeiro'),('Rio Grande do Norte','Natal'),
  ('Rio Grande do Sul','Porto Alegre'),('Rondônia','Porto Velho'),
  ('Roraima','Boa Vista'),('Santa Catarina','Florianópolis'),
  ('São Paulo','São Paulo'),('Sergipe','Aracaju'),('Tocantins','Palmas')
) AS v(nome_estado, capital)
JOIN pais p ON p.nome_pais = 'Brasil';

INSERT INTO estado (id_pais, nome_estado, municipio)
SELECT p.id_pais, v.nome_estado, v.capital
FROM (VALUES
  ('Argentina','Buenos Aires','La Plata'),
  ('Portugal','Lisboa','Lisboa'),
  ('Portugal','Porto','Porto'),
  ('Estados Unidos','Califórnia','Sacramento'),
  ('Uruguai','Montevidéu','Montevidéu')
) AS v(pais, nome_estado, capital)
JOIN pais p ON p.nome_pais = v.pais;

-- Uma cidade (a sede/capital) para cada estado
INSERT INTO cidade (id_estado, nome, codigo_cidade)
SELECT e.id_estado, e.municipio, 1000 + e.id_estado
FROM estado e
WHERE e.municipio IS NOT NULL;

-- Cidades do DF e do entorno
INSERT INTO cidade (id_estado, nome, codigo_cidade)
SELECT e.id_estado, v.cidade, 5300000 + row_number() OVER (ORDER BY v.cidade)
FROM (VALUES
  ('Distrito Federal','Taguatinga'),('Distrito Federal','Ceilândia'),
  ('Distrito Federal','Águas Claras'),('Distrito Federal','Gama'),
  ('Distrito Federal','Sobradinho'),('Distrito Federal','Planaltina'),
  ('Distrito Federal','Samambaia'),('Distrito Federal','Guará'),
  ('Goiás','Anápolis'),('Goiás','Luziânia'),('Goiás','Formosa'),
  ('Goiás','Valparaíso de Goiás'),('Goiás','Águas Lindas de Goiás')
) AS v(uf, cidade)
JOIN estado e ON e.nome_estado = v.uf;

-- ----------------------------------------------------------------------------
-- 2. ESTRUTURA FÍSICA: campus -> prédio -> bloco -> sala
-- ----------------------------------------------------------------------------

-- INNER JOIN em dois níveis: cidade (pelo nome) e estado (para desambiguar).
INSERT INTO campus (id_cidade, nome_campus, endereco, telefone, cep, complementos)
SELECT ci.id_cidade, v.nome_campus, v.endereco, v.telefone, v.cep, v.complementos
FROM (VALUES
  ('Campus Asa Sul',      'Brasília',     'Distrito Federal','SGAS Quadra 613/614, Lote 97',   '(61) 3000-0001','70200-730','Campus fictício - sede'),
  ('Campus Asa Norte',    'Brasília',     'Distrito Federal','SGAN Quadra 612, Módulo D',       '(61) 3000-0002','70830-010','Campus fictício'),
  ('Campus Taguatinga',   'Taguatinga',   'Distrito Federal','QNA 40, Área Especial',           '(61) 3000-0003','72110-400','Campus fictício'),
  ('Campus Águas Claras', 'Águas Claras', 'Distrito Federal','Av. das Araucárias, Lote 1000',   '(61) 3000-0004','71936-250','Campus fictício')
) AS v(nome_campus, cidade, uf, endereco, telefone, cep, complementos)
JOIN cidade ci ON ci.nome = v.cidade
JOIN estado e  ON e.id_estado = ci.id_estado AND e.nome_estado = v.uf;

-- CROSS JOIN com generate_series: 3 prédios por campus  (4 x 3 = 12)
INSERT INTO predio (id_campus, qtd_predios)
SELECT c.id_campus, 3
FROM campus c
CROSS JOIN generate_series(1, 3) AS g(n)
ORDER BY c.id_campus, g.n;

-- 4 blocos por prédio  (12 x 4 = 48)
INSERT INTO bloco (id_predio)
SELECT p.id_predio
FROM predio p
CROSS JOIN generate_series(1, 4) AS g(n)
ORDER BY p.id_predio, g.n;

-- 25 salas por bloco  (48 x 25 = 1.200 salas)
-- O tipo e a capacidade dependem do número da sala (CASE).
INSERT INTO sala (id_bloco, codigo, tipo, capacidade)
SELECT b.id_bloco,
       'B' || lpad(b.id_bloco::text, 2, '0') || '-' || lpad(g.n::text, 3, '0'),
       CASE WHEN g.n = 25     THEN 'Auditório'
            WHEN g.n % 5 = 0  THEN 'Laboratório'
            WHEN g.n % 7 = 0  THEN 'Sala de Estudo'
            ELSE                   'Sala de Aula' END,
       CASE WHEN g.n = 25     THEN 120
            WHEN g.n % 5 = 0  THEN 30
            WHEN g.n % 7 = 0  THEN 20
            ELSE                   40 + (g.n % 3) * 5 END
FROM bloco b
CROSS JOIN generate_series(1, 25) AS g(n)
ORDER BY b.id_bloco, g.n;

-- UPDATE ... FROM com JOIN: recalcula qtd_blocos e salas de cada campus
-- a partir do que realmente foi inserido (campus -> predio -> bloco -> sala).
UPDATE campus c
SET qtd_blocos = x.blocos,
    salas      = x.salas
FROM (SELECT p.id_campus,
             COUNT(DISTINCT b.id_bloco) AS blocos,
             COUNT(s.id_sala)           AS salas
      FROM predio p
      JOIN bloco b ON b.id_predio = p.id_predio
      JOIN sala  s ON s.id_bloco  = b.id_bloco
      GROUP BY p.id_campus) x
WHERE x.id_campus = c.id_campus;

-- ----------------------------------------------------------------------------
-- 3. ESTRUTURA ACADÊMICA
-- ----------------------------------------------------------------------------

INSERT INTO curso (id_campus, codigo, nome, grau, ch_total)
SELECT c.id_campus, v.codigo, v.nome, v.grau, v.ch_total
FROM (VALUES
  ('2130','Ciência da Computação',                  'Bacharelado',3580,'Campus Asa Sul'),
  ('2140','Engenharia de Software',                 'Bacharelado',3600,'Campus Asa Sul'),
  ('2150','Sistemas de Informação',                 'Bacharelado',3200,'Campus Asa Norte'),
  ('2160','Análise e Desenvolvimento de Sistemas',  'Tecnólogo',  2000,'Campus Taguatinga'),
  ('2170','Engenharia da Computação',               'Bacharelado',3600,'Campus Águas Claras')
) AS v(codigo, nome, grau, ch_total, campus)
JOIN campus c ON c.nome_campus = v.campus;

-- UNION entre "campus de origem do curso" e "cursos ofertados em todos os campi"
INSERT INTO campus_curso (fk_id_campus, fk_id_curso)
SELECT cu.id_campus, cu.id_curso
FROM curso cu
WHERE cu.id_campus IS NOT NULL
UNION
SELECT c.id_campus, cu.id_curso
FROM campus c
CROSS JOIN curso cu
WHERE cu.codigo IN ('2130','2150');

-- Cada curso ganha 2 currículos: 2016 (inativo) e 2020 (ativo)
INSERT INTO curriculo (id_curso, ano_vigencia, ativo)
SELECT cu.id_curso, v.ano, v.ativo
FROM curso cu
CROSS JOIN (VALUES (2016, false), (2020, true)) AS v(ano, ativo)
ORDER BY cu.id_curso, v.ano;

-- Disciplinas (código CC001, CC002... em ordem de semestre e nome)
INSERT INTO disciplina (codigo, nome, ch_teorica, ch_pratica, ch_total, ementa)
SELECT 'CC' || lpad((row_number() OVER (ORDER BY m.periodo, m.nome))::text, 3, '0'),
       m.nome,
       m.ch_t,
       m.ch_p,
       m.ch_t + m.ch_p,
       'Ementa da disciplina ' || m.nome || ': conteúdo programático do ' || m.periodo || 'º semestre, '
         || m.ch_t || 'h teóricas e ' || m.ch_p || 'h práticas.'
FROM tmp_matriz m
ORDER BY m.periodo, m.nome;

-- Currículo x disciplina
--  * Ciência da Computação (2130): matriz completa (8 semestres) nos 2 currículos.
--  * Demais cursos: só os 4 primeiros semestres (núcleo comum).
-- O JOIN com tmp_matriz tem condição composta (OR) em vez de igualdade simples.
INSERT INTO curriculo_disciplina (id_curriculo, id_disciplina, tipo, periodo)
SELECT cu.id_curriculo, d.id_disciplina, m.eixo, m.periodo
FROM curriculo cu
JOIN curso c       ON c.id_curso = cu.id_curso
JOIN tmp_matriz m  ON (c.codigo = '2130' OR m.periodo <= 4)
JOIN disciplina d  ON d.nome = m.nome
ORDER BY cu.id_curriculo, m.periodo, d.codigo;

-- Pré/co-requisitos: dois JOINs na MESMA tabela (auto-relacionamento),
-- um para a disciplina e outro para o requisito.
INSERT INTO pre_requisito (id_disciplina, id_requisito, vinculo)
SELECT d.id_disciplina, r.id_disciplina, v.vinculo::vinculo_t
FROM (VALUES
  ('Algoritmos e Programação de Computadores II','Algoritmos e Programação de Computadores I','PRE_REQUISITO'),
  ('Laboratório Práticas I','Algoritmos e Programação de Computadores I','CO_REQUISITO'),
  ('Laboratório Práticas II','Laboratório Práticas I','PRE_REQUISITO'),
  ('Álgebra Linear','Geometria Analítica e Vetores','CO_REQUISITO'),
  ('Cálculo II','Cálculo I','PRE_REQUISITO'),
  ('Banco de Dados II','Banco de Dados I','PRE_REQUISITO'),
  ('Estrutura de Dados','Algoritmos e Programação de Computadores II','PRE_REQUISITO'),
  ('Programação Orientada a Objetos','Algoritmos e Programação de Computadores II','PRE_REQUISITO'),
  ('Organização de Computadores','Sistemas Digitais','PRE_REQUISITO'),
  ('Arquitetura de Computadores','Organização de Computadores','PRE_REQUISITO'),
  ('Sistemas Operacionais','Organização de Computadores','PRE_REQUISITO'),
  ('Teoria da Computação','Matemática Discreta','PRE_REQUISITO'),
  ('Inteligência Artificial','Estrutura de Dados','PRE_REQUISITO'),
  ('Inteligência Artificial II','Inteligência Artificial','PRE_REQUISITO'),
  ('Engenharia de Software','Programação Orientada a Objetos','CO_REQUISITO'),
  ('Cálculo Numérico','Cálculo II','PRE_REQUISITO'),
  ('Cálculo Numérico','Álgebra Linear','PRE_REQUISITO'),
  ('Computação Gráfica','Álgebra Linear','PRE_REQUISITO'),
  ('Processamento de Imagens','Computação Gráfica','CO_REQUISITO'),
  ('Paradigmas de Linguagem de Programação','Programação Orientada a Objetos','PRE_REQUISITO'),
  ('Programação para Dispositivos Móveis','Programação Orientada a Objetos','PRE_REQUISITO'),
  ('Linguagens Formais e Autômatos','Teoria da Computação','PRE_REQUISITO'),
  ('Compiladores','Linguagens Formais e Autômatos','PRE_REQUISITO'),
  ('Programação Paralela','Sistemas Operacionais','PRE_REQUISITO'),
  ('Redes de Computadores I','Sistemas Operacionais','CO_REQUISITO'),
  ('Teoria dos Grafos','Matemática Discreta','PRE_REQUISITO'),
  ('Sistemas Distribuídos','Redes de Computadores I','PRE_REQUISITO'),
  ('Sistemas de Comunicação','Redes de Computadores I','PRE_REQUISITO'),
  ('Sistemas de Tempo Real','Sistemas Operacionais','PRE_REQUISITO'),
  ('Tecnologias Web','Banco de Dados I','PRE_REQUISITO'),
  ('Tópicos em Banco de Dados','Banco de Dados II','PRE_REQUISITO'),
  ('Análise de Algoritmos','Estrutura de Dados','PRE_REQUISITO'),
  ('Criptografia: Algoritmo e Certificação Digital','Redes de Computadores I','PRE_REQUISITO'),
  ('Administração de Serviços da Internet','Redes de Computadores I','PRE_REQUISITO'),
  ('Projeto Integrador 3A','Projeto Integrador 2A','PRE_REQUISITO'),
  ('Projeto Integrador 3B','Projeto Integrador 3A','PRE_REQUISITO'),
  ('Trabalho de Conclusão de Curso I','Metodologia da Pesquisa','PRE_REQUISITO'),
  ('Trabalho de Conclusão de Curso II','Trabalho de Conclusão de Curso I','PRE_REQUISITO'),
  ('Estágio Supervisionado II','Estágio Supervisionado I','PRE_REQUISITO')
) AS v(disciplina, requisito, vinculo)
JOIN disciplina d ON d.nome = v.disciplina
JOIN disciplina r ON r.nome = v.requisito;

-- ----------------------------------------------------------------------------
-- 4. PROFESSORES (80) - nomes combinados por JOIN com as listas temporárias
-- ----------------------------------------------------------------------------
-- Cada nome é escolhido por "número de ordem" (rn) calculado com resto (%) e
-- divisão inteira (/) do contador g.n -> combinações sem repetição.
WITH dim AS (
    SELECT (SELECT COUNT(*) FROM tmp_nome)      AS qn,
           (SELECT COUNT(*) FROM tmp_sobrenome) AS qs
)
INSERT INTO professor (matricula, nome, email, titulacao)
SELECT 'P' || lpad(g.n::text, 6, '0'),
       n.nome || ' ' || s1.sobrenome || ' ' || s2.sobrenome,
       'professor' || g.n || '@exemplo.edu.br',
       (ARRAY['Especialista','Mestre','Doutor','Pós-Doutor'])[1 + g.n % 4]
FROM generate_series(1, 80) AS g(n)
CROSS JOIN dim
JOIN tmp_nome      n  ON n.rn  = 1 + g.n % dim.qn
JOIN tmp_sobrenome s1 ON s1.rn = 1 + (g.n / dim.qn) % dim.qs
JOIN tmp_sobrenome s2 ON s2.rn = 1 + (g.n + g.n / (dim.qn * dim.qs)) % dim.qs
ORDER BY g.n;

-- ----------------------------------------------------------------------------
-- 5. PERÍODOS LETIVOS (2023/1 a 2026/2) E TURMAS
-- ----------------------------------------------------------------------------

INSERT INTO periodo_letivo (ano, semestre, data_inicio, data_fim)
SELECT a.ano, s.semestre,
       make_date(a.ano, CASE s.semestre WHEN 1 THEN 2 ELSE 8  END, 1),
       make_date(a.ano, CASE s.semestre WHEN 1 THEN 6 ELSE 12 END,
                        CASE s.semestre WHEN 1 THEN 30 ELSE 15 END)
FROM generate_series(2023, 2026) AS a(ano)
CROSS JOIN generate_series(1, 2) AS s(semestre)
ORDER BY a.ano, s.semestre;

-- Turmas: em cada período letivo são ofertadas as disciplinas do currículo ATIVO
-- de Ciência da Computação cujo semestre tem a mesma paridade do período
-- (semestre 1 -> disciplinas ímpares: 1A,2A,3A,4A; semestre 2 -> pares).
-- Cada disciplina tem uma turma Matutino e uma Noturno.
-- O professor é distribuído em rodízio (row_number) entre todos os professores.
WITH prof AS (
    SELECT id_professor, row_number() OVER (ORDER BY id_professor) AS rn
    FROM professor
),
qtd AS (SELECT COUNT(*) AS q FROM professor),
base AS (
    SELECT d.id_disciplina, d.codigo AS cod_disc,
           pl.id_periodo_letivo, pl.ano, pl.semestre, t.turno,
           row_number() OVER (ORDER BY pl.ano, pl.semestre, d.codigo, t.turno) AS rn
    FROM periodo_letivo pl
    JOIN curriculo_disciplina cd ON cd.periodo % 2 = pl.semestre % 2
    JOIN curriculo cu            ON cu.id_curriculo = cd.id_curriculo AND cu.ativo
    JOIN curso c                 ON c.id_curso = cu.id_curso AND c.codigo = '2130'
    JOIN disciplina d            ON d.id_disciplina = cd.id_disciplina
    CROSS JOIN (VALUES ('Matutino'), ('Noturno')) AS t(turno)
)
INSERT INTO turma (id_disciplina, id_professor, id_periodo_letivo, turno, codigo)
SELECT b.id_disciplina, p.id_professor, b.id_periodo_letivo, b.turno,
       b.cod_disc || '-' || b.ano || '.' || b.semestre || '-' || left(b.turno, 1)
FROM base b
CROSS JOIN qtd
JOIN prof p ON p.rn = 1 + (b.rn - 1) % qtd.q
ORDER BY b.rn;

-- ----------------------------------------------------------------------------
-- 6. ALUNOS (1.200)
-- ----------------------------------------------------------------------------
-- CPF e telefone FICTÍCIOS: o CPF é (n * número primo) mod 10^11, o que garante
-- valores diferentes para cada n (a coluna cpf é UNIQUE). Não são CPFs válidos.
WITH dim AS (
    SELECT (SELECT COUNT(*) FROM tmp_nome)      AS qn,
           (SELECT COUNT(*) FROM tmp_sobrenome) AS qs
)
INSERT INTO aluno (nome, email, cpf, telefone_aluno)
SELECT n.nome || ' ' || s1.sobrenome || ' ' || s2.sobrenome,
       'aluno' || lpad(g.n::text, 5, '0') || '@aluno.exemplo.edu.br',
       lpad(((g.n::bigint * 982451653) % 100000000000)::text, 11, '0'),
       '619' || lpad(((g.n::bigint * 7654321) % 100000000)::text, 8, '0')
FROM generate_series(1, 1200) AS g(n)
CROSS JOIN dim
JOIN tmp_nome      n  ON n.rn  = 1 + g.n % dim.qn
JOIN tmp_sobrenome s1 ON s1.rn = 1 + (g.n / dim.qn) % dim.qs
JOIN tmp_sobrenome s2 ON s2.rn = 1 + (g.n + g.n / (dim.qn * dim.qs)) % dim.qs
ORDER BY g.n;

-- ----------------------------------------------------------------------------
-- 7. MATRÍCULAS
-- ----------------------------------------------------------------------------
-- Cada aluno ingressa em um período letivo (rk_inicio) e em um semestre do curso
-- (periodo_inicio) e cursa até 3 semestres seguidos (j = 0,1,2). Em cada semestre
-- ele se matricula em TODAS as turmas do seu turno daquele semestre do currículo.
--
-- Cadeia de JOINs:  plano (aluno+j) -> pl (período letivo) -> oferta (turma + semestre
-- da disciplina no currículo ativo de Ciência da Computação).
-- Status: período 2026/2 = ATIVA; ~1 em 40 = TRANCADA; demais = CONCLUIDA.
WITH pl AS (
    SELECT id_periodo_letivo, semestre, data_inicio,
           row_number() OVER (ORDER BY ano, semestre) AS rk
    FROM periodo_letivo
),
al AS (
    SELECT id_aluno, row_number() OVER (ORDER BY id_aluno) AS rn
    FROM aluno
),
oferta AS (
    SELECT t.id_turma, t.id_periodo_letivo, t.turno, cd.periodo
    FROM turma t
    JOIN curriculo_disciplina cd ON cd.id_disciplina = t.id_disciplina
    JOIN curriculo cu            ON cu.id_curriculo  = cd.id_curriculo AND cu.ativo
    JOIN curso c                 ON c.id_curso       = cu.id_curso AND c.codigo = '2130'
),
plano AS (
    SELECT al.id_aluno, al.rn,
           (al.rn % 8) + 1 AS rk_inicio,
           ((al.rn / 8) % 3) * 2 + CASE WHEN (al.rn % 8) % 2 = 0 THEN 1 ELSE 2 END AS periodo_inicio,
           j.j
    FROM al
    CROSS JOIN generate_series(0, 2) AS j(j)
)
INSERT INTO matricula (id_aluno, id_turma, status, data_matricula)
SELECT pn.id_aluno,
       o.id_turma,
       CASE WHEN pl.rk = 8                          THEN 'ATIVA'
            WHEN (pn.rn + o.id_turma) % 40 = 0      THEN 'TRANCADA'
            ELSE                                         'CONCLUIDA' END,
       pl.data_inicio - ((pn.rn + o.id_turma) % 20)::int
FROM plano pn
JOIN pl      ON pl.rk = pn.rk_inicio + pn.j
JOIN oferta o ON o.id_periodo_letivo = pl.id_periodo_letivo
             AND o.periodo = pn.periodo_inicio + pn.j
             AND o.turno   = CASE WHEN (pn.rn / 2) % 2 = 0 THEN 'Matutino' ELSE 'Noturno' END
ORDER BY pn.id_aluno, pl.rk, o.id_turma;

-- ----------------------------------------------------------------------------
-- 8. HISTÓRICO (1:1 com matrícula)
-- ----------------------------------------------------------------------------
-- Notas e frequência aleatórias (random()); a situação é DERIVADA delas:
--   frequência < 75         -> REP_FREQUENCIA
--   média >= 6              -> APROVADO ; senão REPROVADO
--   matrícula ATIVA         -> CURSANDO (só n1 lançada) ; TRANCADA -> TRANCADO (sem notas)
WITH base AS MATERIALIZED (
    SELECT m.id_matricula, m.status,
           round((2 + random() * 8)::numeric, 2)  AS n1,
           round((2 + random() * 8)::numeric, 2)  AS n2,
           round((2 + random() * 8)::numeric, 2)  AS n3,
           round((55 + random() * 45)::numeric, 2) AS freq
    FROM matricula m
),
calc AS (
    SELECT b.*, round((b.n1 + b.n2 + b.n3) / 3, 2) AS media
    FROM base b
)
INSERT INTO historico (id_matricula, situacao, n1, n2, n3, media_final, frequencia)
SELECT c.id_matricula,
       CASE WHEN c.status = 'ATIVA'    THEN 'CURSANDO'
            WHEN c.status = 'TRANCADA' THEN 'TRANCADO'
            WHEN c.freq < 75           THEN 'REP_FREQUENCIA'
            WHEN c.media >= 6          THEN 'APROVADO'
            ELSE                            'REPROVADO' END,
       CASE WHEN c.status = 'TRANCADA' THEN NULL ELSE c.n1 END,
       CASE WHEN c.status IN ('ATIVA','TRANCADA') THEN NULL ELSE c.n2 END,
       CASE WHEN c.status IN ('ATIVA','TRANCADA') THEN NULL ELSE c.n3 END,
       CASE WHEN c.status IN ('ATIVA','TRANCADA') THEN NULL ELSE c.media END,
       CASE WHEN c.status = 'TRANCADA' THEN NULL ELSE c.freq END
FROM calc c
ORDER BY c.id_matricula;

-- ----------------------------------------------------------------------------
-- 9. FERIADOS
-- ----------------------------------------------------------------------------

-- CROSS JOIN: cada feriado fixo x cada ano de 2023 a 2026
INSERT INTO feriado (descricao, data)
SELECT f.descricao, make_date(a.ano, f.mes, f.dia)
FROM tmp_feriado f
CROSS JOIN generate_series(2023, 2026) AS a(ano)
ORDER BY 2, 1;

-- JOIN triplo: lista temporária -> país (pelo nome) -> feriado (por descrição+data)
INSERT INTO pais_feriado (fk_id_pais, fk_id_feriado)
SELECT p.id_pais, fe.id_feriado
FROM tmp_feriado f
JOIN pais p      ON p.nome_pais = f.pais
JOIN feriado fe  ON fe.descricao = f.descricao
                AND EXTRACT(MONTH FROM fe.data) = f.mes
                AND EXTRACT(DAY   FROM fe.data) = f.dia;

-- ----------------------------------------------------------------------------
-- 10. AUDITORIA (log_matricula)
-- ----------------------------------------------------------------------------

-- 10.1 Um log de INSERT para cada matrícula (matrícula -> aluno -> turma)
INSERT INTO log_matricula (id_matricula, acao, usuario, detalhe, ocorrido_em)
SELECT m.id_matricula,
       'INSERT',
       'secretaria' || (m.id_matricula % 5 + 1),
       'Matrícula de ' || a.nome || ' na turma ' || t.codigo,
       m.data_matricula + time '08:00' + (m.id_matricula % 480) * interval '1 minute'
FROM matricula m
JOIN aluno a ON a.id_aluno = m.id_aluno
JOIN turma t ON t.id_turma = m.id_turma
ORDER BY m.id_matricula;

-- 10.2 Lançamento de notas no fim do período (histórico -> matrícula -> turma -> professor -> período)
INSERT INTO log_matricula (id_matricula, acao, usuario, detalhe, ocorrido_em)
SELECT m.id_matricula,
       'LANCAMENTO_NOTAS',
       'prof.' || p.matricula,
       'Situação final: ' || h.situacao || ' | média: ' || COALESCE(h.media_final::text, '-')
         || ' | freq.: ' || COALESCE(h.frequencia::text, '-') || '%',
       pl.data_fim + time '18:00' + (m.id_matricula % 300) * interval '1 minute'
FROM historico h
JOIN matricula m       ON m.id_matricula = h.id_matricula
JOIN turma t           ON t.id_turma = m.id_turma
JOIN professor p       ON p.id_professor = t.id_professor
JOIN periodo_letivo pl ON pl.id_periodo_letivo = t.id_periodo_letivo
WHERE m.status = 'CONCLUIDA'
ORDER BY m.id_matricula;

-- 10.3 Trancamentos
INSERT INTO log_matricula (id_matricula, acao, usuario, detalhe, ocorrido_em)
SELECT m.id_matricula,
       'TRANCAMENTO',
       'secretaria' || (m.id_matricula % 5 + 1),
       'Trancamento solicitado pelo aluno ' || a.nome || ' (turma ' || t.codigo || ')',
       pl.data_inicio + 30 + time '10:00'
FROM matricula m
JOIN aluno a           ON a.id_aluno = m.id_aluno
JOIN turma t           ON t.id_turma = m.id_turma
JOIN periodo_letivo pl ON pl.id_periodo_letivo = t.id_periodo_letivo
WHERE m.status = 'TRANCADA'
ORDER BY m.id_matricula;

COMMIT;

-- Atualiza as estatísticas do otimizador para as consultas do próximo arquivo
ANALYZE;

-- ----------------------------------------------------------------------------
-- 11. CONFERÊNCIA: quantidade de linhas por tabela
-- ----------------------------------------------------------------------------
SELECT tabela, linhas
FROM (
    SELECT 'pais' AS tabela, COUNT(*) AS linhas FROM pais
    UNION ALL SELECT 'estado',               COUNT(*) FROM estado
    UNION ALL SELECT 'cidade',               COUNT(*) FROM cidade
    UNION ALL SELECT 'campus',               COUNT(*) FROM campus
    UNION ALL SELECT 'predio',               COUNT(*) FROM predio
    UNION ALL SELECT 'bloco',                COUNT(*) FROM bloco
    UNION ALL SELECT 'sala',                 COUNT(*) FROM sala
    UNION ALL SELECT 'curso',                COUNT(*) FROM curso
    UNION ALL SELECT 'campus_curso',         COUNT(*) FROM campus_curso
    UNION ALL SELECT 'curriculo',            COUNT(*) FROM curriculo
    UNION ALL SELECT 'disciplina',           COUNT(*) FROM disciplina
    UNION ALL SELECT 'curriculo_disciplina', COUNT(*) FROM curriculo_disciplina
    UNION ALL SELECT 'pre_requisito',        COUNT(*) FROM pre_requisito
    UNION ALL SELECT 'professor',            COUNT(*) FROM professor
    UNION ALL SELECT 'periodo_letivo',       COUNT(*) FROM periodo_letivo
    UNION ALL SELECT 'turma',                COUNT(*) FROM turma
    UNION ALL SELECT 'aluno',                COUNT(*) FROM aluno
    UNION ALL SELECT 'matricula',            COUNT(*) FROM matricula
    UNION ALL SELECT 'historico',            COUNT(*) FROM historico
    UNION ALL SELECT 'feriado',              COUNT(*) FROM feriado
    UNION ALL SELECT 'pais_feriado',         COUNT(*) FROM pais_feriado
    UNION ALL SELECT 'log_matricula',        COUNT(*) FROM log_matricula
) t
ORDER BY linhas DESC;



-- ============================================================================
-- BANCO DE DADOS II - CONSULTAS DEMONSTRATIVAS (SELECT + JOIN)
-- Execute DEPOIS de 1_ddl.sql e 2_dml_inserts.sql.
-- No pgAdmin, selecione UMA consulta por vez (marque o texto) e aperte F5.
-- ============================================================================

SET search_path TO academico, public;

-- =====================================================================
-- C1. Grade de turmas do último período letivo
-- Técnica: JOIN interno (INNER JOIN). Cada JOIN liga uma chave estrangeira à
-- chave primária da tabela pai. Só aparecem linhas que têm par em
-- TODAS as tabelas.
-- Detalhe: (ARRAY[...])[n] usa um número como posição no vetor.
-- Como ler: "para cada turma do último período, mostre código, disciplina,
-- professor, turno e o semestre do curso em que a disciplina está".
-- =====================================================================
SELECT t.codigo                       AS turma,
       d.nome                         AS disciplina,
       p.nome                         AS professor,
       t.turno,
       cd.periodo                     AS semestre_do_curso,
       pl.ano || '/' || pl.semestre   AS periodo_letivo
FROM turma t
JOIN periodo_letivo pl        ON pl.id_periodo_letivo = t.id_periodo_letivo
JOIN disciplina d             ON d.id_disciplina      = t.id_disciplina
JOIN professor p              ON p.id_professor       = t.id_professor
JOIN curriculo_disciplina cd  ON cd.id_disciplina     = d.id_disciplina
JOIN curriculo cu             ON cu.id_curriculo      = cd.id_curriculo AND cu.ativo
JOIN curso c                  ON c.id_curso           = cu.id_curso AND c.codigo = '2130'
WHERE pl.id_periodo_letivo = (SELECT id_periodo_letivo FROM periodo_letivo
                              ORDER BY data_inicio DESC LIMIT 1)   -- último período cadastrado
ORDER BY cd.periodo, d.nome, t.turno;

-- =====================================================================
-- C2. Histórico escolar de um aluno
-- Técnica: cadeia de INNER JOIN aluno -> matricula -> turma -> disciplina
-- -> periodo_letivo, mais historico (1:1 com matricula).
-- Como ler: "para o aluno de id 1, liste cada disciplina cursada com notas,
-- média, frequência e situação, na ordem cronológica".
-- =====================================================================
SELECT a.nome                         AS aluno,
       pl.ano || '/' || pl.semestre   AS periodo,
       d.nome                         AS disciplina,
       h.n1, h.n2, h.n3, h.media_final, h.frequencia,
       h.situacao
FROM aluno a
JOIN matricula m       ON m.id_aluno = a.id_aluno
JOIN turma t           ON t.id_turma = m.id_turma
JOIN disciplina d      ON d.id_disciplina = t.id_disciplina
JOIN periodo_letivo pl ON pl.id_periodo_letivo = t.id_periodo_letivo
JOIN historico h       ON h.id_matricula = m.id_matricula
WHERE a.id_aluno = 1
ORDER BY pl.ano, pl.semestre, d.nome;

-- =====================================================================
-- C3. Localização completa de cada sala (hierarquia física + geográfica)
-- Técnica: 7 INNER JOINs seguindo a hierarquia
-- sala -> bloco -> prédio -> campus -> cidade -> estado -> país.
-- Como ler: "mostre, por sala, onde ela fica no mundo".
-- =====================================================================
SELECT pa.nome_pais, e.nome_estado, ci.nome AS cidade, ca.nome_campus,
       pr.id_predio AS predio, b.id_bloco AS bloco,
       s.codigo AS sala, s.tipo, s.capacidade
FROM sala s
JOIN bloco b    ON b.id_bloco   = s.id_bloco
JOIN predio pr  ON pr.id_predio = b.id_predio
JOIN campus ca  ON ca.id_campus = pr.id_campus
JOIN cidade ci  ON ci.id_cidade = ca.id_cidade
JOIN estado e   ON e.id_estado  = ci.id_estado
JOIN pais pa    ON pa.id_pais   = e.id_pais
WHERE s.tipo = 'Laboratório'
ORDER BY ca.nome_campus, s.codigo
LIMIT 50;

-- =====================================================================
-- C4. Pré-requisitos de cada disciplina (auto-junção)
-- Técnica: a tabela "disciplina" aparece DUAS vezes com apelidos diferentes
-- (d = a disciplina, r = o requisito). pre_requisito faz a ponte.
-- Como ler: "para cada disciplina, quais outras precisam vir antes (ou junto)".
-- =====================================================================
SELECT d.codigo  AS cod_disciplina,
       d.nome    AS disciplina,
       pr.vinculo,
       r.codigo  AS cod_requisito,
       r.nome    AS requisito
FROM pre_requisito pr
JOIN disciplina d ON d.id_disciplina = pr.id_disciplina
JOIN disciplina r ON r.id_disciplina = pr.id_requisito
ORDER BY d.codigo, pr.vinculo, r.codigo;

-- =====================================================================
-- C5. Disciplinas SEM nenhum pré/co-requisito
-- Técnica: LEFT JOIN + "IS NULL" (anti-junção). O LEFT JOIN mantém todas as
-- disciplinas; as que não acharam par em pre_requisito ficam com NULL.
-- Como ler: "quais disciplinas podem ser cursadas sem depender de outra".
-- =====================================================================
SELECT d.codigo, d.nome, d.ch_total
FROM disciplina d
LEFT JOIN pre_requisito pr ON pr.id_disciplina = d.id_disciplina
WHERE pr.id_disciplina IS NULL
ORDER BY d.codigo;

-- =====================================================================
-- C6. Matriz curricular de Ciência da Computação agrupada por semestre
-- Técnica: JOIN + GROUP BY com string_agg() e SUM().
-- Como ler: "por semestre do currículo ativo, liste as disciplinas e some a CH".
-- =====================================================================
SELECT cd.periodo                                   AS semestre,
       COUNT(*)                                     AS qtd_disciplinas,
       SUM(d.ch_total)                              AS ch_semestre,
       string_agg(d.nome, ' | ' ORDER BY d.nome)    AS disciplinas
FROM curso c
JOIN curriculo cu             ON cu.id_curso = c.id_curso AND cu.ativo
JOIN curriculo_disciplina cd  ON cd.id_curriculo = cu.id_curriculo
JOIN disciplina d             ON d.id_disciplina = cd.id_disciplina
WHERE c.codigo = '2130'
GROUP BY cd.periodo
ORDER BY cd.periodo;

-- =====================================================================
-- C7. Taxa de aprovação por disciplina
-- Técnica: JOIN + GROUP BY + COUNT(*) FILTER (WHERE ...) + HAVING.
-- Só entram matrículas com resultado final (exclui CURSANDO e TRANCADO).
-- Como ler: "das matrículas encerradas, qual % foi aprovada em cada disciplina".
-- =====================================================================
SELECT d.nome                                                   AS disciplina,
       COUNT(*)                                                 AS matriculas,
       COUNT(*) FILTER (WHERE h.situacao = 'APROVADO')          AS aprovados,
       COUNT(*) FILTER (WHERE h.situacao = 'REPROVADO')         AS reprovados,
       COUNT(*) FILTER (WHERE h.situacao = 'REP_FREQUENCIA')    AS rep_frequencia,
       ROUND(100.0 * COUNT(*) FILTER (WHERE h.situacao = 'APROVADO') / COUNT(*), 1) AS pct_aprovacao,
       ROUND(AVG(h.media_final), 2)                             AS media_geral
FROM historico h
JOIN matricula m  ON m.id_matricula = h.id_matricula
JOIN turma t      ON t.id_turma = m.id_turma
JOIN disciplina d ON d.id_disciplina = t.id_disciplina
WHERE h.situacao IN ('APROVADO','REPROVADO','REP_FREQUENCIA')
GROUP BY d.nome
HAVING COUNT(*) >= 30
ORDER BY pct_aprovacao ASC, d.nome;

-- =====================================================================
-- C8. Carga de trabalho dos professores (LEFT JOIN + agregação)
-- Técnica: LEFT JOIN para incluir também professores sem turma (contam 0).
-- Como ler: "quantas turmas e quantos alunos distintos cada professor atendeu".
-- =====================================================================
SELECT p.matricula, p.nome, p.titulacao,
       COUNT(DISTINCT t.id_turma) AS turmas,
       COUNT(m.id_matricula)      AS matriculas,
       COUNT(DISTINCT m.id_aluno) AS alunos_distintos
FROM professor p
LEFT JOIN turma t     ON t.id_professor = p.id_professor
LEFT JOIN matricula m ON m.id_turma = t.id_turma
GROUP BY p.id_professor, p.matricula, p.nome, p.titulacao
ORDER BY matriculas DESC, p.nome
LIMIT 20;

-- =====================================================================
-- C9. Feriados por país com o nome do dia da semana
-- Técnica: JOIN em tabela associativa N:N (pais <-> pais_feriado <-> feriado).
-- Detalhe: (ARRAY[...])[EXTRACT(DOW ...) + 1] -> DOW vai de 0 (domingo) a 6 (sábado),
-- por isso soma 1 para virar posição de vetor (que começa em 1).
-- Como ler: "para cada país, datas de feriado em 2026 e em que dia caem".
-- =====================================================================
SELECT pa.nome_pais,
       f.descricao,
       f.data,
       (ARRAY['dom','seg','ter','qua','qui','sex','sab'])[EXTRACT(DOW FROM f.data)::int + 1] AS dia
FROM pais pa
JOIN pais_feriado pf ON pf.fk_id_pais    = pa.id_pais
JOIN feriado f       ON f.id_feriado     = pf.fk_id_feriado
WHERE EXTRACT(YEAR FROM f.data) = 2026
ORDER BY pa.nome_pais, f.data;

-- =====================================================================
-- C10. Turmas do último período que caem em feriado nacional? (JOIN por data)
-- Técnica: JOIN sem chave estrangeira - condição por intervalo (BETWEEN).
-- Como ler: "quais feriados do Brasil ocorrem dentro de cada período letivo".
-- =====================================================================
SELECT pl.ano || '/' || pl.semestre AS periodo,
       COUNT(*)                     AS feriados_no_periodo,
       string_agg(to_char(f.data, 'DD/MM'), ', ' ORDER BY f.data) AS datas
FROM periodo_letivo pl
JOIN feriado f       ON f.data BETWEEN pl.data_inicio AND pl.data_fim
JOIN pais_feriado pf ON pf.fk_id_feriado = f.id_feriado
JOIN pais pa         ON pa.id_pais = pf.fk_id_pais AND pa.nome_pais = 'Brasil'
GROUP BY pl.id_periodo_letivo, pl.ano, pl.semestre
ORDER BY pl.ano, pl.semestre;

-- =====================================================================
-- C11. Auditoria de uma matrícula (todas as ações registradas)
-- Técnica: JOIN de 5 tabelas, ligando o log ao aluno e à disciplina.
-- Como ler: "linha do tempo de tudo que aconteceu com cada matrícula do aluno 1".
-- =====================================================================
SELECT l.ocorrido_em, l.acao, l.usuario, a.nome AS aluno, d.nome AS disciplina, l.detalhe
FROM log_matricula l
JOIN matricula m  ON m.id_matricula = l.id_matricula
JOIN aluno a      ON a.id_aluno = m.id_aluno
JOIN turma t      ON t.id_turma = m.id_turma
JOIN disciplina d ON d.id_disciplina = t.id_disciplina
WHERE a.id_aluno = 1
ORDER BY l.ocorrido_em, l.id_log;

-- =====================================================================
-- C12. Ranking dos 10 melhores alunos (média das médias finais)
-- Técnica: JOIN + GROUP BY + HAVING + função de janela RANK().
-- Como ler: "alunos com pelo menos 10 disciplinas aprovadas, ordenados pela média".
-- =====================================================================
SELECT RANK() OVER (ORDER BY AVG(h.media_final) DESC) AS posicao,
       a.nome,
       COUNT(*)                     AS disciplinas_aprovadas,
       ROUND(AVG(h.media_final), 2) AS media_geral
FROM aluno a
JOIN matricula m ON m.id_aluno = a.id_aluno
JOIN historico h ON h.id_matricula = m.id_matricula
WHERE h.situacao = 'APROVADO'
GROUP BY a.id_aluno, a.nome
HAVING COUNT(*) >= 10
ORDER BY posicao, a.nome
LIMIT 10;
