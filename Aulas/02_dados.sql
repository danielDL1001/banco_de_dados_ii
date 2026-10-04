-- =====================================================================
-- DADOS DE AULA · BANCO DE DADOS II · CCO072 · IESB · 2026/2
-- Prof. Rodrigo Gonçalves Pinto
--
-- OBJETIVO: enriquecer o banco de matricula com um cenario mais variado,
-- para que as consultas da Aula 2 (e seguintes) tenham dados suficientes
-- para ilustrar cada tecnica: datas espalhadas por varios meses (LAG/LEAD),
-- alunos distribuidos entre os tres cursos (ranking por grupo), matriculas
-- em todas as turmas, e alguns alunos DE PROPOSITO sem matricula (para a
-- demonstracao da armadilha do NOT IN com NULL, na Parte B).
--
-- Rode este script UMA vez, depois do modelo de referencia, e ANTES da
-- Aula 2. Ele nao altera a estrutura do banco, so os dados.
-- Testado em PostgreSQL 17.
-- =====================================================================

SET search_path TO academico, public;

-- Enriquecer o cenário para a aula (sem alterar o modelo):
-- 1) espalhar as matrículas existentes ao longo de vários meses
-- 2) distribuir alunos entre os cursos (CCO, ENGC, ADS)
-- 3) criar matrículas nas demais turmas para haver dados por turma/curso

-- 1) datas de matrícula variadas (fev a nov/2025) para LAG/LEAD fazerem sentido
UPDATE matricula
SET data_matricula = DATE '2025-02-01' + (id % 10) * INTERVAL '32 days';

-- 2) distribuir alunos entre os 3 cursos existentes
UPDATE aluno SET curso_id = CASE (id % 3) WHEN 0 THEN 1 WHEN 1 THEN 2 ELSE 3 END;

-- 3) matricular alunos nas turmas que estão vazias (para dados por turma)
--    turmas 3,4,5,6 estão sem matrícula
INSERT INTO matricula (aluno_id, turma_id, data_matricula)
SELECT a.id, t.id, DATE '2025-02-01' + ((a.id + t.id) % 9) * INTERVAL '30 days'
FROM aluno a
CROSS JOIN turma t
WHERE t.id IN (3,4,5,6)
  AND a.id % 4 = t.id % 4          -- ~1/4 dos alunos em cada turma
  AND a.id <= 110                  -- deixa os alunos 111..120 SEM nenhuma matricula (demo B.4)
  AND NOT EXISTS (SELECT 1 FROM matricula m WHERE m.aluno_id=a.id AND m.turma_id=t.id)
LIMIT 200;

-- 4) gerar histórico para as novas matrículas que ainda não têm
INSERT INTO historico (matricula_id, nota_a1, nota_a2, frequencia, situacao)
SELECT m.id,
       round((random()*6+4)::numeric,1),
       round((random()*6+4)::numeric,1),
       round((random()*30+70)::numeric,1),
       'CURSANDO'
FROM matricula m
WHERE NOT EXISTS (SELECT 1 FROM historico h WHERE h.matricula_id=m.id);

REFRESH MATERIALIZED VIEW mv_indicadores_curso;
ANALYZE;
