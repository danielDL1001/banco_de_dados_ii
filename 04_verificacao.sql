-- ================================================================
-- MARCO 1 — VERIFICAÇÃO FINAL
-- Compatível com o novo 01_ddl(1).sql
-- ================================================================
SET search_path TO academico, public;

SELECT 'alunos' AS item, count(*) AS quantidade FROM aluno
UNION ALL
SELECT 'turmas', count(*) FROM turma
UNION ALL
SELECT 'matriculas', count(*) FROM matricula
UNION ALL
SELECT 'historicos', count(*) FROM historico
ORDER BY item;

-- Esperado após a carga: alunos >= 100, turmas >= 6, matriculas >= 300.

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

-- No novo 01_ddl, a estrutura possui 21 tabelas.
-- A quantidade de PKs e FKs é verificada acima diretamente no catálogo.

-- Conferência das categorias obrigatórias das consultas.
-- Q02: LEFT JOIN + agregação
-- Q06: CTE recursiva para árvore de pré-requisitos
-- Q07: CTE recursiva para disciplinas liberadas
-- Q08: RANK + PERCENT_RANK
-- Q09: LAG
