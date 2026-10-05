-- ================================================================
-- MARCO 1 — VERIFICAÇÃO FINAL
-- ================================================================
SET search_path TO academico, public;

SELECT 'alunos' AS item, count(*) AS quantidade FROM aluno
UNION ALL
SELECT 'turmas', count(*) FROM turma
UNION ALL
SELECT 'matriculas', count(*) FROM matricula
UNION ALL
SELECT 'historicos', count(*) FROM historico;

-- Esperado: alunos >= 100, turmas >= 6, matriculas >= 300.

SELECT
  (SELECT count(*) FROM information_schema.tables
   WHERE table_schema='academico' AND table_type='BASE TABLE') AS tabelas,
  (SELECT count(*) FROM pg_constraint c
   JOIN pg_namespace n ON n.oid=c.connamespace
   WHERE n.nspname='academico' AND c.contype='p') AS pks,
  (SELECT count(*) FROM pg_constraint c
   JOIN pg_namespace n ON n.oid=c.connamespace
   WHERE n.nspname='academico' AND c.contype='f') AS fks,
  (SELECT count(*) FROM pg_constraint c
   JOIN pg_namespace n ON n.oid=c.connamespace
   WHERE n.nspname='academico' AND c.contype='u') AS uniques;

-- Conferência das 5 categorias obrigatórias das consultas.
-- Q02: LEFT JOIN + agregação
-- Q06: CTE recursiva para árvore de pré-requisitos
-- Q07: CTE recursiva para disciplinas liberadas
-- Q08: RANK + PERCENT_RANK
-- Q09: LAG
