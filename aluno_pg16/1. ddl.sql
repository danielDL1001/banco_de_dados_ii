-- ============================================================================
-- BANCO DE DADOS II - MODELO FÍSICO (DDL ÚNICO)
-- Arquivo de referência: projeto_bdII.drawio (modelo lógico)
-- Base: PostgreSQL 16/17
--
-- Observações:
-- - A estrutura segue nomes, campos, tipos e relacionamentos do Draw.io
--   (22 tabelas).
-- - Diferenças em relação ao DDL anterior, conforme o Draw.io:
--     * aluno não possui id_curriculo nem nascimento; possui telefone_aluno;
--     * campus possui id_cidade; predio não possui id_cidade;
--     * existe a tabela associativa campus_curso (campus N:N curso);
--     * historico possui n1, n2, n3 e é 1:1 com matricula;
--     * cpf de aluno é UNIQUE; email de aluno não é UNIQUE.
-- - campus.cep está como nvarchar(9) no Draw.io; PostgreSQL não possui
--   nvarchar, portanto foi usado varchar(9).
-- - curso.id_campus está marcado como FK no Draw.io e foi mantido, embora a
--   ligação campus-curso também seja feita por campus_curso.
-- - vinculo_t é um tipo ENUM personalizado.
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


