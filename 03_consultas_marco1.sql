-- ================================================================
-- MARCO 1 — 10 CONSULTAS SQL DE COMPLEXIDADE CRESCENTE
-- PostgreSQL
-- ================================================================
SET search_path TO academico, public;

-- Q01 — Junção simples: alunos matriculados em cada turma.
SELECT t.codigo AS turma, a.matricula, a.nome
FROM matricula m
JOIN aluno a ON a.id = m.aluno_id
JOIN turma t ON t.id = m.turma_id
ORDER BY t.codigo, a.nome;

-- Q02 — Junção externa + agregação (REQUISITO DO MARCO 1).
-- O LEFT JOIN preserva inclusive turmas sem matrículas.
SELECT t.codigo AS turma,
       d.codigo AS disciplina,
       t.vagas,
       COUNT(m.id) FILTER (WHERE m.status = 'MATRICULADO') AS matriculados,
       t.vagas - COUNT(m.id) FILTER (WHERE m.status = 'MATRICULADO') AS vagas_restantes
FROM turma t
JOIN disciplina d ON d.id = t.disciplina_id
LEFT JOIN matricula m ON m.turma_id = t.id
GROUP BY t.id, t.codigo, d.codigo, t.vagas
ORDER BY t.codigo;

-- Q03 — Histórico acadêmico com múltiplas junções.
SELECT a.matricula AS ra, a.nome, d.codigo AS disciplina,
       pl.ano, pl.semestre, h.media_final, h.frequencia, h.situacao
FROM historico h
JOIN matricula m ON m.id = h.matricula_id
JOIN aluno a ON a.id = m.aluno_id
JOIN turma t ON t.id = m.turma_id
JOIN disciplina d ON d.id = t.disciplina_id
JOIN periodo_letivo pl ON pl.id = t.periodo_letivo_id
ORDER BY a.matricula, pl.ano, pl.semestre, d.codigo;

-- Q04 — Agregação por curso com HAVING.
SELECT c.codigo AS curso,
       COUNT(DISTINCT a.id) AS alunos,
       ROUND(AVG(h.media_final),2) AS media_curso
FROM curso c
JOIN aluno a ON a.curso_id = c.id
JOIN matricula m ON m.aluno_id = a.id
JOIN historico h ON h.matricula_id = m.id
WHERE h.media_final IS NOT NULL
GROUP BY c.id, c.codigo
HAVING AVG(h.media_final) >= 5
ORDER BY media_curso DESC;

-- Q05 — Subconsulta com NOT EXISTS: alunos que possuem histórico
-- em todas as matrículas não canceladas.
SELECT a.matricula, a.nome
FROM aluno a
WHERE NOT EXISTS (
    SELECT 1
    FROM matricula m
    WHERE m.aluno_id = a.id
      AND m.status <> 'CANCELADO'
      AND NOT EXISTS (SELECT 1 FROM historico h WHERE h.matricula_id = m.id)
)
ORDER BY a.matricula;

-- Q06 — RECURSIVA: árvore completa de pré-requisitos.
WITH RECURSIVE cadeia AS (
    SELECT d.id, d.codigo, d.nome, 0 AS nivel, ARRAY[d.id] AS caminho_ids
    FROM disciplina d
    WHERE d.codigo = 'CCO072'

    UNION ALL

    SELECT req.id, req.codigo, req.nome, c.nivel + 1, c.caminho_ids || req.id
    FROM cadeia c
    JOIN pre_requisito pr ON pr.disciplina_id = c.id
    JOIN disciplina req ON req.id = pr.requisito_id
    WHERE NOT req.id = ANY(c.caminho_ids)
)
SELECT nivel, repeat('  ', nivel) || codigo AS hierarquia, nome
FROM cadeia
ORDER BY caminho_ids;

-- Q07 — RECURSIVA: disciplinas que o aluno 1 já pode cursar.
-- Uma disciplina é liberada quando todos os seus pré-requisitos
-- aparecem no histórico do aluno com situação APROVADO.
WITH RECURSIVE pre AS (
    SELECT pr.disciplina_id, pr.requisito_id
    FROM pre_requisito pr
    UNION ALL
    SELECT p.disciplina_id, pr.requisito_id
    FROM pre p
    JOIN pre_requisito pr ON pr.disciplina_id = p.requisito_id
),
concluidas AS (
    SELECT DISTINCT t.disciplina_id
    FROM matricula m
    JOIN historico h ON h.matricula_id = m.id
    JOIN turma t ON t.id = m.turma_id
    WHERE m.aluno_id = 1 AND h.situacao = 'APROVADO'
),
candidatas AS (
    SELECT d.id, d.codigo, d.nome
    FROM disciplina d
    JOIN curriculo_disciplina cd ON cd.disciplina_id = d.id
    JOIN aluno a ON a.id = 1 AND cd.curriculo_id = a.curriculo_id
    WHERE d.id NOT IN (SELECT disciplina_id FROM concluidas)
),
validas AS (
    SELECT c.*
    FROM candidatas c
    WHERE NOT EXISTS (
        SELECT 1
        FROM pre p
        WHERE p.disciplina_id = c.id
          AND p.requisito_id NOT IN (SELECT disciplina_id FROM concluidas)
    )
)
SELECT id, codigo, nome
FROM validas
ORDER BY codigo;

-- Q08 — FUNÇÃO DE JANELA com RANKING e PERCENTIL (REQUISITO).
WITH desempenho AS (
    SELECT a.id, a.nome, c.codigo AS curso,
           ROUND(AVG(h.media_final),2) AS media
    FROM aluno a
    JOIN curso c ON c.id = a.curso_id
    JOIN matricula m ON m.aluno_id = a.id
    JOIN historico h ON h.matricula_id = m.id
    WHERE h.media_final IS NOT NULL
    GROUP BY a.id, a.nome, c.codigo
)
SELECT curso, nome, media,
       RANK() OVER (PARTITION BY curso ORDER BY media DESC) AS ranking,
       ROUND((PERCENT_RANK() OVER (PARTITION BY curso ORDER BY media DESC))::numeric,4) AS percentil
FROM desempenho
ORDER BY curso, ranking;

-- Q09 — FUNÇÃO DE JANELA LAG para evolução do rendimento.
-- Compara a média do período atual com a média do período anterior
-- de cada aluno.
WITH rendimento AS (
    SELECT a.id, a.nome, pl.ano, pl.semestre,
           ROUND(AVG(h.media_final),2) AS media_periodo
    FROM aluno a
    JOIN matricula m ON m.aluno_id = a.id
    JOIN historico h ON h.matricula_id = m.id
    JOIN turma t ON t.id = m.turma_id
    JOIN periodo_letivo pl ON pl.id = t.periodo_letivo_id
    WHERE h.media_final IS NOT NULL
    GROUP BY a.id, a.nome, pl.ano, pl.semestre
)
SELECT nome, ano, semestre, media_periodo,
       LAG(media_periodo) OVER (PARTITION BY id ORDER BY ano, semestre) AS media_anterior,
       ROUND((media_periodo - LAG(media_periodo) OVER (PARTITION BY id ORDER BY ano, semestre))::numeric,2) AS evolucao
FROM rendimento
ORDER BY nome, ano, semestre;

-- Q10 — Consulta avançada: disciplinas e cadeia de pré-requisitos
-- necessárias para um currículo, removendo duplicidades.
WITH RECURSIVE cadeia AS (
    SELECT cd.disciplina_id AS origem, cd.disciplina_id AS atual
    FROM curriculo_disciplina cd
    WHERE cd.curriculo_id = 1

    UNION

    SELECT c.origem, pr.requisito_id
    FROM cadeia c
    JOIN pre_requisito pr ON pr.disciplina_id = c.atual
),
resultado AS (
    SELECT DISTINCT d.codigo, d.nome
    FROM cadeia c
    JOIN disciplina d ON d.id = c.atual
)
SELECT codigo, nome
FROM resultado
ORDER BY codigo;
