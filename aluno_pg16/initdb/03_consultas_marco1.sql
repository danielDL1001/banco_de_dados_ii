-- ================================================================
-- MARCO 1 — 10 CONSULTAS SQL DE COMPLEXIDADE CRESCENTE
-- Compatível com o novo 01_ddl(1).sql
-- ================================================================
SET search_path TO academico, public;

-- Q01 — Junção simples: alunos matriculados em cada turma.
SELECT t.codigo AS turma,
       a.id_aluno,
       a.nome,
       a.email
FROM matricula m
JOIN aluno a ON a.id_aluno = m.id_aluno
JOIN turma t ON t.id_turma = m.id_turma
ORDER BY t.codigo, a.nome;

-- Q02 — Junção externa + agregação (REQUISITO DO MARCO 1).
-- O LEFT JOIN preserva inclusive turmas sem matrículas.
SELECT t.codigo AS turma,
       d.codigo AS disciplina,
       COUNT(m.id_matricula) AS total_matriculas,
       COUNT(m.id_matricula) FILTER (WHERE m.status = 'MATRICULADO') AS matriculados,
       COUNT(m.id_matricula) FILTER (WHERE m.status = 'CANCELADO') AS cancelados
FROM turma t
JOIN disciplina d ON d.id_disciplina = t.id_disciplina
LEFT JOIN matricula m ON m.id_turma = t.id_turma
GROUP BY t.id_turma, t.codigo, d.codigo
ORDER BY t.codigo;

-- Q03 — Histórico acadêmico com múltiplas junções.
SELECT a.id_aluno,
       a.nome,
       d.codigo AS disciplina,
       pl.ano,
       pl.semestre,
       h.n1,
       h.media_final,
       h.frequencia,
       h.situacao
FROM historico h
JOIN matricula m ON m.id_matricula = h.id_matricula
JOIN aluno a ON a.id_aluno = m.id_aluno
JOIN turma t ON t.id_turma = m.id_turma
JOIN disciplina d ON d.id_disciplina = t.id_disciplina
JOIN periodo_letivo pl ON pl.id_periodo_letivo = t.id_periodo_letivo
ORDER BY a.id_aluno, pl.ano, pl.semestre, d.codigo;

-- Q04 — Agregação por curso com HAVING.
-- O curso é obtido por meio do currículo do aluno.
SELECT c.codigo AS curso,
       COUNT(DISTINCT a.id_aluno) AS alunos,
       ROUND(AVG(h.media_final),2) AS media_curso
FROM curso c
JOIN curriculo cr ON cr.id_curso = c.id_curso
JOIN aluno a ON a.id_curriculo = cr.id_curriculo
JOIN matricula m ON m.id_aluno = a.id_aluno
JOIN historico h ON h.id_matricula = m.id_matricula
WHERE h.media_final IS NOT NULL
GROUP BY c.id_curso, c.codigo
HAVING AVG(h.media_final) >= 5
ORDER BY media_curso DESC;

-- Q05 — Subconsulta com NOT EXISTS: alunos que possuem histórico
-- em todas as matrículas não canceladas.
SELECT a.id_aluno, a.nome
FROM aluno a
WHERE NOT EXISTS (
    SELECT 1
    FROM matricula m
    WHERE m.id_aluno = a.id_aluno
      AND m.status <> 'CANCELADO'
      AND NOT EXISTS (
          SELECT 1
          FROM historico h
          WHERE h.id_matricula = m.id_matricula
      )
)
ORDER BY a.id_aluno;

-- Q06 — RECURSIVA: árvore completa de pré-requisitos de CCO072.
WITH RECURSIVE cadeia AS (
    SELECT d.id_disciplina,
           d.codigo,
           d.nome,
           0 AS nivel,
           ARRAY[d.id_disciplina] AS caminho_ids
    FROM disciplina d
    WHERE d.codigo = 'CCO072'

    UNION ALL

    SELECT req.id_disciplina,
           req.codigo,
           req.nome,
           c.nivel + 1,
           c.caminho_ids || req.id_disciplina
    FROM cadeia c
    JOIN pre_requisito pr ON pr.id_disciplina = c.id_disciplina
    JOIN disciplina req ON req.id_disciplina = pr.id_requisito
    WHERE NOT req.id_disciplina = ANY(c.caminho_ids)
)
SELECT nivel,
       repeat('  ', nivel) || codigo AS hierarquia,
       nome
FROM cadeia
ORDER BY caminho_ids;

-- Q07 — RECURSIVA: disciplinas que o aluno 1 já pode cursar.
-- Uma disciplina é liberada quando todos os pré-requisitos
-- aparecem no histórico do aluno com situação APROVADO.
WITH RECURSIVE pre AS (
    SELECT pr.id_disciplina, pr.id_requisito
    FROM pre_requisito pr

    UNION ALL

    SELECT p.id_disciplina, pr.id_requisito
    FROM pre p
    JOIN pre_requisito pr ON pr.id_disciplina = p.id_requisito
),
concluidas AS (
    SELECT DISTINCT t.id_disciplina
    FROM matricula m
    JOIN historico h ON h.id_matricula = m.id_matricula
    JOIN turma t ON t.id_turma = m.id_turma
    WHERE m.id_aluno = 1
      AND h.situacao = 'APROVADO'
),
candidatas AS (
    SELECT d.id_disciplina,
           d.codigo,
           d.nome
    FROM disciplina d
    JOIN curriculo_disciplina cd ON cd.id_disciplina = d.id_disciplina
    JOIN aluno a ON a.id_aluno = 1
                AND cd.id_curriculo = a.id_curriculo
    WHERE d.id_disciplina NOT IN (
        SELECT id_disciplina FROM concluidas
    )
),
validas AS (
    SELECT c.*
    FROM candidatas c
    WHERE NOT EXISTS (
        SELECT 1
        FROM pre p
        WHERE p.id_disciplina = c.id_disciplina
          AND p.id_requisito NOT IN (
              SELECT id_disciplina FROM concluidas
          )
    )
)
SELECT id_disciplina,
       codigo,
       nome
FROM validas
ORDER BY codigo;

-- Q08 — FUNÇÃO DE JANELA com RANKING e PERCENTIL (REQUISITO).
WITH desempenho AS (
    SELECT a.id_aluno,
           a.nome,
           c.codigo AS curso,
           ROUND(AVG(h.media_final),2) AS media
    FROM aluno a
    JOIN curriculo cr ON cr.id_curriculo = a.id_curriculo
    JOIN curso c ON c.id_curso = cr.id_curso
    JOIN matricula m ON m.id_aluno = a.id_aluno
    JOIN historico h ON h.id_matricula = m.id_matricula
    WHERE h.media_final IS NOT NULL
    GROUP BY a.id_aluno, a.nome, c.codigo
)
SELECT curso,
       nome,
       media,
       RANK() OVER (
           PARTITION BY curso
           ORDER BY media DESC
       ) AS ranking,
       ROUND(
           (PERCENT_RANK() OVER (
               PARTITION BY curso
               ORDER BY media DESC
           ))::numeric,
           4
       ) AS percentil
FROM desempenho
ORDER BY curso, ranking;

-- Q09 — FUNÇÃO DE JANELA LAG para evolução do rendimento.
-- Compara a média do período atual com a média do período anterior
-- de cada aluno.
WITH rendimento AS (
    SELECT a.id_aluno,
           a.nome,
           pl.ano,
           pl.semestre,
           ROUND(AVG(h.media_final),2) AS media_periodo
    FROM aluno a
    JOIN matricula m ON m.id_aluno = a.id_aluno
    JOIN historico h ON h.id_matricula = m.id_matricula
    JOIN turma t ON t.id_turma = m.id_turma
    JOIN periodo_letivo pl ON pl.id_periodo_letivo = t.id_periodo_letivo
    WHERE h.media_final IS NOT NULL
    GROUP BY a.id_aluno, a.nome, pl.ano, pl.semestre
)
SELECT id_aluno,
       nome,
       ano,
       semestre,
       media_periodo,
       LAG(media_periodo) OVER (
           PARTITION BY id_aluno
           ORDER BY ano, semestre
       ) AS media_anterior,
       ROUND(
           (
               media_periodo - LAG(media_periodo) OVER (
                   PARTITION BY id_aluno
                   ORDER BY ano, semestre
               )
           )::numeric,
           2
       ) AS evolucao
FROM rendimento
ORDER BY id_aluno, ano, semestre;

-- Q10 — Consulta avançada: disciplinas e cadeia de pré-requisitos
-- necessárias para o currículo, removendo duplicidades.
WITH RECURSIVE cadeia AS (
    SELECT cd.id_disciplina AS origem,
           cd.id_disciplina AS atual
    FROM curriculo_disciplina cd
    WHERE cd.id_curriculo = 1

    UNION

    SELECT c.origem,
           pr.id_requisito
    FROM cadeia c
    JOIN pre_requisito pr ON pr.id_disciplina = c.atual
),
resultado AS (
    SELECT DISTINCT d.codigo, d.nome
    FROM cadeia c
    JOIN disciplina d ON d.id_disciplina = c.atual
)
SELECT codigo, nome
FROM resultado
ORDER BY codigo;
