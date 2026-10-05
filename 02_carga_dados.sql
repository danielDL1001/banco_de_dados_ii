-- ================================================================
-- MARCO 1 — CARGA DE DADOS
-- PostgreSQL 16/17
-- ================================================================
SET search_path TO academico, public;

-- Dados institucionais
INSERT INTO campus (nome, cidade) VALUES
 ('Asa Sul','Brasília'), ('Ceilândia','Brasília');

INSERT INTO curso (codigo, nome, grau, ch_total, campus_id) VALUES
 ('CCO','Ciência da Computação','BACHARELADO',3200,1),
 ('ENGC','Engenharia de Computação','BACHARELADO',3600,1),
 ('ADS','Análise e Desenvolvimento de Sistemas','TECNOLOGO',2000,1);

INSERT INTO curriculo (curso_id, ano_vigencia, ativo) VALUES
 (1,2026,true), (1,2023,false), (2,2026,true), (3,2026,true);

INSERT INTO disciplina (codigo, nome, ch_teorica, ch_pratica, ementa) VALUES
 ('HMDC253','Banco de Dados I',30,30,'Modelagem relacional, normalização e SQL.'),
 ('CCO072','Banco de Dados II',30,30,'Transações, concorrência, recuperação e otimização.'),
 ('CCO085','Programação Paralela',45,15,'Concorrência, paralelismo e memória.'),
 ('MDC050','Inteligência Artificial',45,15,'Busca, representação do conhecimento e aprendizado.'),
 ('ADS033','Aprendizagem de Máquina',30,30,'Aprendizado supervisionado e não supervisionado.'),
 ('MDC118','Algoritmos e Programação I',30,30,'Lógica de programação e estruturas básicas.'),
 ('MDC122','Sistemas Operacionais',45,15,'Processos, memória e sistemas de arquivos.');

INSERT INTO curriculo_disciplina (curriculo_id, disciplina_id, periodo, tipo) VALUES
 (1,1,2,'OBRIGATORIA'), (1,2,4,'OBRIGATORIA'), (1,3,6,'OBRIGATORIA'),
 (1,4,4,'OBRIGATORIA'), (1,6,1,'OBRIGATORIA'), (1,7,4,'OBRIGATORIA'),
 (4,5,5,'OBRIGATORIA');

INSERT INTO pre_requisito (disciplina_id, requisito_id, vinculo) VALUES
 (1,6,'PRE_REQUISITO'),
 (2,1,'PRE_REQUISITO'),
 (3,6,'PRE_REQUISITO'),
 (3,7,'PRE_REQUISITO'),
 (4,6,'PRE_REQUISITO');

INSERT INTO professor (matricula, nome, email, titulacao) VALUES
 ('201680','Rodrigo Gonçalves Pinto','rodrigo.pinto@iesb.edu.br','MESTRE'),
 ('201455','Marcelo Paiva','marcelo.paiva@iesb.edu.br','DOUTOR'),
 ('201322','Roger Santos','roger.santos@iesb.edu.br','MESTRE');

INSERT INTO sala (campus_id, codigo, capacidade, tipo) VALUES
 (1,'JB1',55,'LABORATORIO'), (1,'JB2/4',36,'LABORATORIO'),
 (1,'JB5',44,'LABORATORIO'), (1,'IA2',24,'LABORATORIO'),
 (1,'IA3',30,'LABORATORIO'), (1,'JA2',32,'TEORICA');

INSERT INTO periodo_letivo (ano, semestre, data_inicio, data_fim) VALUES
 (2026,2,'2026-08-03','2026-12-12'), (2026,1,'2026-02-02','2026-06-20');

INSERT INTO feriado (data, descricao, campus_id) VALUES
 ('2026-09-07','Independência do Brasil',NULL),
 ('2026-10-12','Nossa Senhora Aparecida',NULL),
 ('2026-11-02','Finados',NULL),
 ('2026-11-15','Proclamação da República',NULL),
 ('2026-11-20','Dia da Consciência Negra',NULL);

-- 6 turmas do período atual + 2 turmas históricas para permitir
-- consultas de pré-requisito com aproveitamento já realizado.
INSERT INTO turma (codigo, disciplina_id, periodo_letivo_id, professor_id, turno, vagas) VALUES
 ('CCODM2B',2,1,1,'MATUTINO',40),
 ('CCONM2B',2,1,1,'NOTURNO',24),
 ('CCODM3B',3,1,2,'MATUTINO',30),
 ('CCONM3B',3,1,2,'NOTURNO',30),
 ('ENGCDM2B',4,1,3,'MATUTINO',36),
 ('ADSDM2C',5,1,3,'MATUTINO',36),
 ('CCODM1B',1,2,1,'MATUTINO',40),
 ('MDC118B',6,2,2,'MATUTINO',40);

INSERT INTO turma_horario (turma_id, sala_id, dia_semana, faixa) VALUES
 (1,1,2,'[08:15,11:00)'), (2,4,2,'[19:15,22:00)'),
 (3,5,5,'[08:15,11:00)'), (4,5,5,'[19:15,22:00)'),
 (5,2,4,'[08:15,11:00)'), (6,2,6,'[08:15,11:00)'),
 (7,3,3,'[08:15,11:00)'), (8,6,3,'[13:30,16:15)');

-- 100 alunos (requisito mínimo do Marco 1).
INSERT INTO aluno (matricula, nome, cpf, email, nascimento, curso_id, curriculo_id, ingresso)
SELECT lpad(g::text,8,'0'),
       'Aluno ' || g,
       lpad(g::text,11,'0'),
       'aluno' || g || '@iesb.edu.br',
       DATE '2000-01-01' + (g % 1800),
       CASE WHEN g % 3 = 1 THEN 1 WHEN g % 3 = 2 THEN 2 ELSE 3 END,
       CASE WHEN g % 3 = 1 THEN 1 WHEN g % 3 = 2 THEN 3 ELSE 4 END,
       DATE '2024-02-01'
FROM generate_series(1,100) AS g;

-- 300 matrículas: cada aluno recebe 3 turmas diferentes.
-- A primeira matrícula de cada aluno é ativa; as outras duas são
-- históricas/canceladas, mantendo o conjunto de dados consistente
-- com as vagas das turmas.
-- Aluno 1 é preparado com BD I (turma histórica 7) para que a
-- consulta Q07 consiga demonstrar uma disciplina liberada por pré-requisito.
INSERT INTO matricula (aluno_id, turma_id, data_matricula, status)
VALUES
 (1,7,'2026-02-03 08:00:00-03','MATRICULADO'),
 (1,3,'2026-02-04 08:00:00-03','CANCELADO'),
 (1,5,'2026-02-05 08:00:00-03','CANCELADO');

-- Os outros 99 alunos recebem mais 297 matrículas.
INSERT INTO matricula (aluno_id, turma_id, data_matricula, status)
SELECT g AS aluno_id,
       t.turma_id,
       CASE WHEN t.ord = 1 THEN timestamptz '2026-08-03 08:00:00-03'
            ELSE timestamptz '2026-02-03 08:00:00-03' END
            + ((g + t.ord) % 20) * interval '1 day',
       CASE WHEN t.ord = 1 THEN 'MATRICULADO'::status_mat_t
            ELSE 'CANCELADO'::status_mat_t END
FROM generate_series(2,100) AS g
CROSS JOIN LATERAL (
    VALUES
      (((g - 1) % 8) + 1, 1),
      (((g + 1) % 8) + 1, 2),
      (((g + 3) % 8) + 1, 3)
) AS t(turma_id, ord);

-- Histórico para as 300 matrículas.
-- O aluno 1 recebe nota alta em BD I (turma histórica 7),
-- tornando possível demonstrar a consulta recursiva de disciplinas liberadas.
INSERT INTO historico (matricula_id, nota_a1, nota_a2, frequencia, situacao)
SELECT m.id,
       CASE WHEN m.aluno_id = 1 AND m.turma_id = 7 THEN 9.0 ELSE round((5 + random()*5)::numeric,2) END,
       CASE WHEN m.aluno_id = 1 AND m.turma_id = 7 THEN 9.0 ELSE round((5 + random()*5)::numeric,2) END,
       CASE WHEN m.aluno_id = 1 AND m.turma_id = 7 THEN 95 ELSE round((75 + random()*25)::numeric,2) END,
       CASE WHEN m.aluno_id = 1 AND m.turma_id = 7 THEN 'APROVADO'::situacao_t
            WHEN m.status = 'CANCELADO' THEN 'REPROVADO_NOTA'::situacao_t
            ELSE 'APROVADO'::situacao_t END
FROM matricula m;

-- Garantia de consistência mínima do dataset.
DO $$
DECLARE
    v_alunos integer; v_turmas integer; v_matriculas integer;
BEGIN
    SELECT count(*) INTO v_alunos FROM aluno;
    SELECT count(*) INTO v_turmas FROM turma;
    SELECT count(*) INTO v_matriculas FROM matricula;
    IF v_alunos < 100 OR v_turmas < 6 OR v_matriculas < 300 THEN
        RAISE EXCEPTION 'Carga do Marco 1 insuficiente: alunos=%, turmas=%, matriculas=%', v_alunos, v_turmas, v_matriculas;
    END IF;
END $$;

ANALYZE;
