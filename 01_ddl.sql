-- ============================================================================
-- BANCO DE DADOS II - DDL REFEITO COM BASE NO MODELO DO DRAW.IO
-- Arquivo de referência: projeto_bdII(2)(2).drawio
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
