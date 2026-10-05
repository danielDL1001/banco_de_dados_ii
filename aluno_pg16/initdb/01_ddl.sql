-- ============================================================================
-- BANCO DE DADOS II - DDL REFEITO COM BASE NO MODELO DO DRAW.IO
-- Arquivo de referência: projeto_bdII.drawio
-- Base: PostgreSQL
--
-- Observação:
-- - A estrutura abaixo segue nomes, campos, tipos e relacionamentos mostrados
--   no Draw.io.
-- - pais_feriado.fk_id_feriado aparece sem tipo no Draw.io; o tipo integer foi
--   inferido para compatibilizar com feriado.id_feriado (integer).
-- - vinculo_t é mantido como tipo personalizado já presente no DDL original.
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
    codigo_pais   integer,
    nome_pais     varchar(100)
);

CREATE TABLE estado (
    id_estado    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pais      integer,
    nome_estado  varchar(100),
    municipio    varchar(100),

    CONSTRAINT fk_estado_pais
        FOREIGN KEY (id_pais)
        REFERENCES pais (id_pais)
);

CREATE TABLE cidade (
    id_cidade      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome           varchar(100),
    codigo_cidade  integer,
    id_estado      integer,

    CONSTRAINT fk_cidade_estado
        FOREIGN KEY (id_estado)
        REFERENCES estado (id_estado)
);

CREATE TABLE campus (
    id_campus      smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome_campus    varchar(60),
    cep            varchar(9),
    endereco       varchar(100),
    telefone       varchar(15),
    complementos   varchar(100),
    qtd_blocos     smallint,
    salas          smallint
);

CREATE TABLE predio (
    id_predio    smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_cidade    integer,
    qtd_predios  integer,
    id_campus    smallint,

    CONSTRAINT fk_predio_cidade
        FOREIGN KEY (id_cidade)
        REFERENCES cidade (id_cidade),

    CONSTRAINT fk_predio_campus
        FOREIGN KEY (id_campus)
        REFERENCES campus (id_campus)
);

CREATE TABLE bloco (
    id_bloco    smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_predio   smallint,

    CONSTRAINT fk_bloco_predio
        FOREIGN KEY (id_predio)
        REFERENCES predio (id_predio)
);

-- ============================================================================
-- 3. ESTRUTURA ACADÊMICA
-- ============================================================================

CREATE TABLE curso (
    id_curso    smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_campus   smallint,
    codigo      varchar(10),
    nome        varchar(120),
    grau        varchar(120),
    ch_total    smallint,

    CONSTRAINT fk_curso_campus
        FOREIGN KEY (id_campus)
        REFERENCES campus (id_campus)
);

CREATE TABLE curriculo (
    id_curriculo  smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ano_vigencia  smallint,
    ativo         boolean,
    id_curso      smallint,

    CONSTRAINT fk_curriculo_curso
        FOREIGN KEY (id_curso)
        REFERENCES curso (id_curso)
);

CREATE TABLE disciplina (
    id_disciplina  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo         varchar(10),
    nome           varchar(120),
    ch_teorica     smallint,
    ch_pratica     smallint,
    ch_total       smallint,
    ementa         text
);

CREATE TABLE curriculo_disciplina (
    id_curriculo   smallint,
    id_disciplina  integer,
    periodo        smallint,
    tipo           varchar(20),

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
    vinculo        vinculo_t,

    CONSTRAINT pk_pre_requisito
        PRIMARY KEY (id_disciplina, id_requisito),

    CONSTRAINT fk_pre_requisito_disciplina
        FOREIGN KEY (id_disciplina)
        REFERENCES disciplina (id_disciplina),

    CONSTRAINT fk_pre_requisito_requisito
        FOREIGN KEY (id_requisito)
        REFERENCES disciplina (id_disciplina)
);

CREATE TABLE professor (
    id_professor  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    matricula     varchar(12) UNIQUE,
    nome          varchar(120),
    email         varchar(120),
    titulacao     varchar(20)
);

-- ============================================================================
-- 4. OFERTA DE DISCIPLINAS
-- ============================================================================

CREATE TABLE periodo_letivo (
    id_periodo_letivo  smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ano                smallint,
    semestre           smallint,
    data_inicio        date,
    data_fim           date
);

CREATE TABLE turma (
    id_turma          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_disciplina     integer,
    id_professor      integer,
    id_periodo_letivo smallint,
    turno             varchar(10),
    codigo            varchar(15),

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

CREATE TABLE sala (
    id_sala      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo       varchar(10),
    capacidade   smallint,
    tipo         varchar(30),
    id_bloco     smallint,

    CONSTRAINT fk_sala_bloco
        FOREIGN KEY (id_bloco)
        REFERENCES bloco (id_bloco)
);

-- ============================================================================
-- 5. VIDA ACADÊMICA
-- ============================================================================

CREATE TABLE aluno (
    id_aluno      integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_curriculo  smallint,
    nome          varchar(120),
    cpf           char(11),
    email         varchar(120) UNIQUE,
    nascimento    date,

    CONSTRAINT fk_aluno_curriculo
        FOREIGN KEY (id_curriculo)
        REFERENCES curriculo (id_curriculo)
);

CREATE TABLE matricula (
    id_matricula   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_aluno       integer,
    id_turma       integer,
    data_matricula date,
    status         varchar(15),

    CONSTRAINT uq_matricula_aluno_turma
        UNIQUE (id_aluno, id_turma),

    CONSTRAINT fk_matricula_aluno
        FOREIGN KEY (id_aluno)
        REFERENCES aluno (id_aluno),

    CONSTRAINT fk_matricula_turma
        FOREIGN KEY (id_turma)
        REFERENCES turma (id_turma)
);

CREATE TABLE historico (
    id_historico  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_matricula  integer,
    n1             numeric,
    media_final    numeric,
    frequencia     numeric,
    situacao       varchar(15),

    CONSTRAINT fk_historico_matricula
        FOREIGN KEY (id_matricula)
        REFERENCES matricula (id_matricula)
);

-- ============================================================================
-- 6. FERIADOS
-- ============================================================================

CREATE TABLE feriado (
    id_feriado  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    data        date,
    descricao   varchar(120)
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
-- 7. AUDITORIA
-- ============================================================================

CREATE TABLE log_matricula (
    id_log        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_matricula  integer,
    acao          varchar(20),
    ocorrido_em   timestamp,
    usuario       varchar(60),
    detalhe       text,

    CONSTRAINT fk_log_matricula_matricula
        FOREIGN KEY (id_matricula)
        REFERENCES matricula (id_matricula)
);

-- ================================================================
-- MARCO 1 — CARGA DE DADOS
-- Compatível com o novo 01_ddl(1).sql
-- PostgreSQL 16/17
-- ================================================================
SET search_path TO academico, public;

-- ----------------------------------------------------------------
-- 1. ESTRUTURA GEOGRÁFICA
-- ----------------------------------------------------------------
INSERT INTO pais (codigo_pais, nome_pais) VALUES
 (55, 'Brasil');

INSERT INTO estado (id_pais, nome_estado, municipio) VALUES
 (1, 'Distrito Federal', 'Brasília');

INSERT INTO cidade (nome, codigo_cidade, id_estado) VALUES
 ('Brasília', 5300108, 1);

-- ----------------------------------------------------------------
-- 2. DADOS INSTITUCIONAIS
-- ----------------------------------------------------------------
INSERT INTO campus
    (nome_campus, cep, endereco, telefone, complementos, qtd_blocos, salas)
VALUES
    ('Asa Sul',  '70200-000', 'SGAS 613, Conjunto E', '(61)3966-1200', NULL, 2, 6),
    ('Ceilândia','72200-000', 'QNN 26, Área Especial', '(61)3966-1300', NULL, 1, 2);

INSERT INTO predio (id_cidade, qtd_predios, id_campus) VALUES
 (1, 2, 1),
 (1, 1, 2);

INSERT INTO bloco (id_predio) VALUES
 (1), (1), (2);

INSERT INTO curso (id_campus, codigo, nome, grau, ch_total) VALUES
 (1, 'CCO',  'Ciência da Computação',                  'BACHARELADO', 3200),
 (1, 'ENGC', 'Engenharia de Computação',               'BACHARELADO', 3600),
 (1, 'ADS',  'Análise e Desenvolvimento de Sistemas',   'TECNOLOGO',   2000);

INSERT INTO curriculo (ano_vigencia, ativo, id_curso) VALUES
 (2026, true,  1),
 (2023, false, 1),
 (2026, true,  2),
 (2026, true,  3);

INSERT INTO disciplina
    (codigo, nome, ch_teorica, ch_pratica, ch_total, ementa)
VALUES
 ('HMDC253','Banco de Dados I',                 30,30,60,'Modelagem relacional, normalização e SQL.'),
 ('CCO072','Banco de Dados II',                30,30,60,'Transações, concorrência, recuperação e otimização.'),
 ('CCO085','Programação Paralela',             45,15,60,'Concorrência, paralelismo e memória.'),
 ('MDC050','Inteligência Artificial',           45,15,60,'Busca, representação do conhecimento e aprendizado.'),
 ('ADS033','Aprendizagem de Máquina',           30,30,60,'Aprendizado supervisionado e não supervisionado.'),
 ('MDC118','Algoritmos e Programação I',       30,30,60,'Lógica de programação e estruturas básicas.'),
 ('MDC122','Sistemas Operacionais',             45,15,60,'Processos, memória e sistemas de arquivos.');

INSERT INTO curriculo_disciplina (id_curriculo, id_disciplina, periodo, tipo) VALUES
 (1,1,2,'OBRIGATORIA'), (1,2,4,'OBRIGATORIA'), (1,3,6,'OBRIGATORIA'),
 (1,4,4,'OBRIGATORIA'), (1,6,1,'OBRIGATORIA'), (1,7,4,'OBRIGATORIA'),
 (4,5,5,'OBRIGATORIA');

INSERT INTO pre_requisito (id_disciplina, id_requisito, vinculo) VALUES
 (1,6,'PRE_REQUISITO'),
 (2,1,'PRE_REQUISITO'),
 (3,6,'PRE_REQUISITO'),
 (3,7,'PRE_REQUISITO'),
 (4,6,'PRE_REQUISITO');

INSERT INTO professor (matricula, nome, email, titulacao) VALUES
 ('201680','Rodrigo Gonçalves Pinto','rodrigo.pinto@iesb.edu.br','MESTRE'),
 ('201455','Marcelo Paiva','marcelo.paiva@iesb.edu.br','DOUTOR'),
 ('201322','Roger Santos','roger.santos@iesb.edu.br','MESTRE');

-- ----------------------------------------------------------------
-- 3. OFERTA
-- ----------------------------------------------------------------
INSERT INTO periodo_letivo (ano, semestre, data_inicio, data_fim) VALUES
 (2026,2,'2026-08-03','2026-12-12'),
 (2026,1,'2026-02-02','2026-06-20');

INSERT INTO sala (codigo, capacidade, tipo, id_bloco) VALUES
 ('JB1',   55,'LABORATORIO',1),
 ('JB2/4', 36,'LABORATORIO',1),
 ('JB5',   44,'LABORATORIO',2),
 ('IA2',   24,'LABORATORIO',2),
 ('IA3',   30,'LABORATORIO',2),
 ('JA2',   32,'TEORICA',1);

INSERT INTO turma
    (id_disciplina, id_professor, id_periodo_letivo, turno, codigo)
VALUES
 (2,1,1,'MATUTINO','CCODM2B'),
 (2,1,1,'NOTURNO','CCONM2B'),
 (3,2,1,'MATUTINO','CCONM3B'),
 (3,2,1,'NOTURNO','CCONM3B-N'),
 (4,3,1,'MATUTINO','ENGCDM2B'),
 (5,3,1,'MATUTINO','ADSDM2C'),
 (1,1,2,'MATUTINO','CCODM1B'),
 (6,2,2,'MATUTINO','MDC118B');

INSERT INTO feriado (data, descricao) VALUES
 ('2026-09-07','Independência do Brasil'),
 ('2026-10-12','Nossa Senhora Aparecida'),
 ('2026-11-02','Finados'),
 ('2026-11-15','Proclamação da República'),
 ('2026-11-20','Dia da Consciência Negra');

INSERT INTO pais_feriado (fk_id_pais, fk_id_feriado)
SELECT 1, id_feriado
FROM feriado
ORDER BY id_feriado;

-- ----------------------------------------------------------------
-- 4. VIDA ACADÊMICA
-- ----------------------------------------------------------------
INSERT INTO aluno (id_curriculo, nome, cpf, email, nascimento)
SELECT CASE
         WHEN g % 3 = 1 THEN 1
         WHEN g % 3 = 2 THEN 3
         ELSE 4
       END,
       'Aluno ' || g,
       lpad(g::text,11,'0'),
       'aluno' || g || '@iesb.edu.br',
       DATE '2000-01-01' + (g % 1800)
FROM generate_series(1,100) AS g;

-- 300 matrículas: 3 por aluno.
-- A primeira matrícula do aluno 1 é a disciplina histórica BD I;
-- as demais matrículas permitem demonstrar as consultas do Marco 1.
INSERT INTO matricula (id_aluno, id_turma, data_matricula, status)
VALUES
 (1,7,'2026-02-03','MATRICULADO'),
 (1,3,'2026-02-04','CANCELADO'),
 (1,5,'2026-02-05','CANCELADO');

INSERT INTO matricula (id_aluno, id_turma, data_matricula, status)
SELECT g,
       t.id_turma,
       CASE WHEN t.ord = 1 THEN DATE '2026-08-03'
            ELSE DATE '2026-02-03' END
         + ((g + t.ord) % 20),
       CASE WHEN t.ord = 1 THEN 'MATRICULADO' ELSE 'CANCELADO' END
FROM generate_series(2,100) AS g
CROSS JOIN LATERAL (
    VALUES
      ((((g - 1) % 8) + 1), 1),
      ((((g + 1) % 8) + 1), 2),
      ((((g + 3) % 8) + 1), 3)
) AS x(id_turma, ord)
JOIN turma t ON t.id_turma = x.id_turma;

-- Histórico para as 300 matrículas.
INSERT INTO historico
    (id_matricula, n1, media_final, frequencia, situacao)
SELECT m.id_matricula,
       CASE
         WHEN m.id_aluno = 1 AND m.id_turma = 7 THEN 9.0
         ELSE round((5 + random()*5)::numeric,2)
       END,
       CASE
         WHEN m.id_aluno = 1 AND m.id_turma = 7 THEN 9.0
         ELSE round((5 + random()*5)::numeric,2)
       END,
       CASE
         WHEN m.id_aluno = 1 AND m.id_turma = 7 THEN 95
         ELSE round((75 + random()*25)::numeric,2)
       END,
       CASE
         WHEN m.id_aluno = 1 AND m.id_turma = 7 THEN 'APROVADO'
         WHEN m.status = 'CANCELADO' THEN 'REPROVADO_NOTA'
         ELSE 'APROVADO'
       END
FROM matricula m;

-- ----------------------------------------------------------------
-- 5. AUDITORIA
-- ----------------------------------------------------------------
INSERT INTO log_matricula (id_matricula, acao, ocorrido_em, usuario, detalhe)
SELECT m.id_matricula,
       'CARGA_INICIAL',
       now(),
       CURRENT_USER::varchar(60),
       'Registro criado pela carga do Marco 1'::text
FROM matricula m
WHERE m.id_matricula <= 10;

-- ----------------------------------------------------------------
-- 6. GARANTIA DE CONSISTÊNCIA MÍNIMA
-- ----------------------------------------------------------------
DO $$
DECLARE
    v_alunos integer;
    v_turmas integer;
    v_matriculas integer;
BEGIN
    SELECT count(*) INTO v_alunos FROM aluno;
    SELECT count(*) INTO v_turmas FROM turma;
    SELECT count(*) INTO v_matriculas FROM matricula;

    IF v_alunos < 100 OR v_turmas < 6 OR v_matriculas < 300 THEN
        RAISE EXCEPTION
            'Carga do Marco 1 insuficiente: alunos=%, turmas=%, matriculas=%',
            v_alunos, v_turmas, v_matriculas;
    END IF;
END $$;

ANALYZE;
