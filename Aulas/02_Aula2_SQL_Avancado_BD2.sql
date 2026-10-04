-- #####################################################################
-- ##  AULA 2 · BANCO DE DADOS II · CCO072 · IESB · 2026/2            ##
-- ##  Prof. Rodrigo Goncalves Pinto                                  ##
-- ##                                                                 ##
-- ##  SQL AVANCADO (DQL) sobre o banco do Projeto Academico IESB     ##
-- ##  Juncoes · Subconsultas · CTEs (recursivas) · Funcoes de        ##
-- ##  janela · Views e Materialized Views                            ##
-- #####################################################################
--
-- COMO LER ESTE ARQUIVO
--   * Cada PARTE (A a E) comeca com uma explicacao do conceito:
--     o que e, como funciona e quando usar.
--   * As linhas marcadas com ">> MySQL:" apontam onde o PostgreSQL e
--     DIFERENTE do MySQL que voces usaram em Banco de Dados I. Preste
--     atencao especial nelas.
--   * Rode bloco a bloco, de cima para baixo, apertando F5 no pgAdmin.
--
-- =====================================================================
-- ANTES DE TUDO: SCHEMA (a maior diferenca em relacao ao MySQL)
-- =====================================================================
-- No MySQL, "banco de dados" e "schema" sao a MESMA coisa (sinonimos),
-- e voce escolhe com:   USE nome_do_banco;
--
-- No PostgreSQL e diferente e mais organizado. A hierarquia tem TRES
-- niveis:   Servidor  ->  Banco de dados  ->  Schema  ->  Tabelas
-- Um unico banco pode ter VARIOS schemas (como se fossem pastas), e cada
-- schema guarda suas tabelas. As nossas tabelas nao estao no schema
-- padrao ("public"); estao num schema chamado "academico".
--
-- >> MySQL: nao existe "USE" no PostgreSQL. Para dizer em qual schema
--    procurar as tabelas, usamos o comando abaixo (uma vez por sessao).
--    Sem ele, o banco procura no schema "public" (vazio) e da erro
--    "relation ... does not exist".
SET search_path TO academico, public;


-- #####################################################################
-- PARTE A — JUNCOES (JOINS)
-- #####################################################################
--
-- O QUE E: juntar linhas de duas ou mais tabelas relacionadas, seguindo
--   as chaves (uma matricula aponta para um aluno e para uma turma; a
--   turma aponta para uma disciplina; e assim por diante).
-- COMO FUNCIONA: o JOIN casa cada linha de uma tabela com as linhas
--   correspondentes da outra, conforme a condicao do ON.
-- QUANDO USAR: sempre que a informacao que voce precisa esta espalhada
--   em varias tabelas (que e o normal num banco relacional).
--
-- >> MySQL: a sintaxe de JOIN e praticamente IGUAL a do MySQL. O que
--    muda aqui e o dialeto de algumas FUNCOES (veremos em A.4).


-- ---------------------------------------------------------------------
-- A.1  JUNCAO EM CADEIA: navegar por 5 tabelas numa consulta so.
--
--   Para responder "quem cursa o que", precisamos partir da matricula e
--   ir "puxando" as tabelas ligadas a ela, uma a uma, pelas chaves
--   estrangeiras. Cada JOIN acrescenta uma tabela a cadeia.
-- ---------------------------------------------------------------------
SELECT a.nome        AS aluno,        -- coluna "nome" da tabela aluno (apelido a)
       d.nome        AS disciplina,   -- coluna "nome" da tabela disciplina (apelido d)
       t.codigo      AS turma,        -- codigo da turma (ex.: CCODM2B)
       pl.ano || '/' || pl.semestre AS periodo,  -- monta o texto "2026/2" juntando ano e semestre
       -- >> MySQL: o operador de juntar textos e "||". No MySQL, "||"
       --    normalmente significa OU logico! No MySQL voce escreveria:
       --    CONCAT(pl.ano, '/', pl.semestre)
       m.status                       -- situacao da matricula (um tipo ENUM; ver nota em A.3)
FROM matricula m                                  -- tabela central: 1 linha por vinculo aluno-turma
JOIN aluno a           ON a.id = m.aluno_id        -- puxa o aluno daquela matricula
JOIN turma t           ON t.id = m.turma_id        -- puxa a turma daquela matricula
JOIN disciplina d      ON d.id = t.disciplina_id   -- da turma, chega-se a disciplina
JOIN periodo_letivo pl ON pl.id = t.periodo_letivo_id  -- e ao periodo letivo
WHERE m.status = 'MATRICULADO'                     -- filtra so vinculos ativos
ORDER BY a.nome, d.nome                            -- ordena por aluno e, dentro, por disciplina
LIMIT 10;                                          -- traz so as 10 primeiras linhas
-- >> MySQL: o "LIMIT" e IGUAL ao do MySQL (bom, uma coisa que nao muda!).
--    (No SQL Server seria "TOP 10"; aqui e LIMIT, como voces ja conhecem.)


-- ---------------------------------------------------------------------
-- A.2  INNER JOIN x LEFT JOIN: a pergunta muda com o tipo de juncao.
--
--   INNER JOIN (o "JOIN" puro) so mostra linhas que casam dos DOIS lados.
--   LEFT JOIN mantem TODAS as linhas da tabela da esquerda, mesmo as que
--   nao tem par na direita (preenchendo com NULO o que faltar).
--   Aqui: queremos TODAS as turmas, INCLUSIVE as que estao sem alunos.
-- ---------------------------------------------------------------------
SELECT t.codigo        AS turma,      -- codigo da turma
       d.nome          AS disciplina, -- disciplina da turma (so para leitura)
       count(m.id)     AS matriculas  -- conta as matriculas de cada turma
       -- ATENCAO: usamos count(m.id), e NAO count(*). Numa turma sem
       -- matricula, o LEFT JOIN cria uma linha com m.id = NULO.
       -- count(*) contaria essa linha fantasma como 1; count(m.id)
       -- ignora nulos e conta 0, que e o certo.
       -- >> MySQL: essa regra do count(coluna) x count(*) e IGUAL no
       --    MySQL. O conceito de LEFT JOIN tambem e o mesmo.
FROM turma t                          -- comeca pela turma: queremos todas
JOIN disciplina d ON d.id = t.disciplina_id            -- nome da disciplina
LEFT JOIN matricula m ON m.turma_id = t.id             -- LEFT: preserva turmas vazias
GROUP BY t.codigo, d.nome             -- agrupa por turma (para o count funcionar por turma)
ORDER BY matriculas DESC, t.codigo;   -- mais cheias primeiro; desempata pelo codigo


-- ---------------------------------------------------------------------
-- A.3  AUTO-JUNCAO: juntar uma tabela com ela mesma.
--
--   As vezes uma tabela se relaciona com ela propria. Aqui, uma
--   disciplina tem outra disciplina como pre-requisito. Para mostrar os
--   NOMES dos dois lados, a tabela "disciplina" precisa entrar DUAS
--   vezes na consulta, com apelidos diferentes (d e r), como se fossem
--   duas tabelas separadas.
-- ---------------------------------------------------------------------
SELECT d.codigo AS disciplina,     -- codigo da disciplina que TEM o pre-requisito
       d.nome   AS nome_disciplina,-- nome dela
       r.codigo AS requisito,      -- codigo da disciplina exigida como pre-requisito
       r.nome   AS nome_requisito  -- nome dela
FROM pre_requisito pr              -- tabela que liga disciplina <-> requisito
JOIN disciplina d ON d.id = pr.disciplina_id   -- 1a entrada da tabela: o lado "disciplina"
JOIN disciplina r ON r.id = pr.requisito_id    -- 2a entrada da MESMA tabela: o lado "requisito"
ORDER BY d.codigo;
-- >> MySQL: auto-juncao funciona igual no MySQL. Sem novidade de dialeto
--    aqui; o que costuma confundir e apenas a IDEIA de usar a mesma
--    tabela duas vezes com apelidos.


-- ---------------------------------------------------------------------
-- A.4  JUNCAO N:N COM AGREGACAO DE TEXTO: alunos de cada turma na
--      mesma celula.
--
--   Um aluno esta em varias turmas; uma turma tem varios alunos. Essa
--   relacao "muitos-para-muitos" e resolvida pela tabela matricula no
--   meio. Aqui, juntamos os NOMES dos alunos de cada turma numa unica
--   celula de texto, separados por ";".
-- ---------------------------------------------------------------------
SELECT t.codigo AS turma,          -- codigo da turma
       count(*) AS qtd_alunos,     -- quantos alunos ela tem
       string_agg(a.nome, '; ' ORDER BY a.nome) AS alunos  -- junta os nomes numa celula so
       -- >> MySQL: aqui esta uma diferenca IMPORTANTE de dialeto.
       --    No MySQL essa funcao se chama GROUP_CONCAT e a ordenacao
       --    fica DENTRO dela:
       --       GROUP_CONCAT(a.nome ORDER BY a.nome SEPARATOR '; ')
       --    No PostgreSQL o nome e string_agg(expr, separador),
       --    e o ORDER BY vai dentro dos parenteses, como acima.
FROM turma t                       -- turma...
JOIN matricula m ON m.turma_id = t.id          -- ...suas matriculas...
JOIN aluno a     ON a.id = m.aluno_id           -- ...e os alunos correspondentes
GROUP BY t.id, t.codigo            -- agrupa por turma
ORDER BY qtd_alunos DESC, t.codigo;-- turmas maiores primeiro


-- #####################################################################
-- PARTE B — SUBCONSULTAS (SUBQUERIES)
-- #####################################################################
--
-- O QUE E: uma consulta DENTRO de outra consulta. A de dentro produz um
--   valor (ou uma lista, ou uma tabela) que a de fora utiliza.
-- COMO FUNCIONA: existem dois tipos que voce precisa distinguir:
--   1) NAO-CORRELACIONADA: a subconsulta nao depende da consulta de fora.
--      Roda UMA vez, produz um resultado, e pronto.
--   2) CORRELACIONADA: a subconsulta usa uma coluna da consulta de fora.
--      Por isso, ela e reexecutada UMA VEZ POR LINHA da consulta externa.
-- QUANDO USAR: quando a resposta depende de um calculo intermediario
--   (uma media, um maximo, "existe algo que...?", etc.).
--
-- >> MySQL: subconsultas existem no MySQL e a sintaxe e a mesma. As
--    diferencas neste bloco aparecem em funcoes pontuais e no LATERAL.


-- ---------------------------------------------------------------------
-- B.1  SUBCONSULTA NAO-CORRELACIONADA: roda uma vez so.
--
--   A subconsulta calcula a carga horaria MEDIA de todas as disciplinas
--   (um unico numero). A consulta de fora usa esse numero para achar as
--   disciplinas acima da media. Como a subconsulta nao olha para a linha
--   de fora, ela e calculada uma unica vez.
-- ---------------------------------------------------------------------
SELECT codigo, nome, ch_total                -- codigo, nome e carga horaria total
FROM disciplina
WHERE ch_total > (                           -- compara a carga de cada disciplina com...
        SELECT avg(ch_total)                 -- ...a carga MEDIA de todas (um numero so)
        FROM disciplina                      -- subconsulta independente da linha de fora
      )
ORDER BY ch_total DESC;                       -- maiores cargas primeiro
-- >> MySQL: identico ao MySQL. avg() existe nos dois.


-- ---------------------------------------------------------------------
-- B.2  SUBCONSULTA CORRELACIONADA: roda uma vez por linha.
--
--   Repare no "a.id" LA DENTRO da subconsulta: ele vem da consulta de
--   fora. Por isso, para cada aluno, a subconsulta e reexecutada usando
--   o id daquele aluno. Aqui: para cada aluno, contamos suas matriculas
--   e achamos a data da mais recente.
-- ---------------------------------------------------------------------
SELECT a.matricula, a.nome,
       (SELECT count(*)              FROM matricula m WHERE m.aluno_id = a.id) AS total_matriculas,
       -- ^ conta as matriculas DESTE aluno (a.id vem de fora = correlacionada)
       (SELECT max(m.data_matricula) FROM matricula m WHERE m.aluno_id = a.id)::date AS ultima
       -- ^ data da matricula mais recente DESTE aluno
       -- >> MySQL: o "::date" no fim e um CAST (conversao de tipo) do
       --    PostgreSQL. max(data_matricula) devolve data COM hora
       --    (timestamp); "::date" corta a hora e deixa so a data.
       --    No MySQL nao existe "::"; escreve-se CAST(... AS DATE)
       --    ou DATE(...). O atalho "valor::tipo" e exclusivo do Postgres.
FROM aluno a
WHERE EXISTS (                      -- so alunos que TEM ao menos uma matricula
        SELECT 1 FROM matricula m WHERE m.aluno_id = a.id
        -- EXISTS pergunta apenas "ha alguma linha?"; o "1" e simbolico,
        -- nao importa o que se coloca ali.
      )
ORDER BY total_matriculas DESC, a.matricula
LIMIT 10;


-- ---------------------------------------------------------------------
-- B.3  TRES CAMINHOS PARA A MESMA PERGUNTA: IN, EXISTS e JOIN.
--
--   "Quantos alunos ja se matricularam em Banco de Dados II (CCO072)?"
--   As tres formas abaixo dao o MESMO numero. Mudam a legibilidade e,
--   as vezes, o desempenho (assunto da aula 5, com EXPLAIN).
-- ---------------------------------------------------------------------
--   (a) via IN: a subconsulta gera uma LISTA de ids; o WHERE testa se o
--       id do aluno esta nessa lista.
SELECT count(*) AS via_in
FROM aluno a
WHERE a.id IN (                                   -- o id do aluno esta na lista?
        SELECT m.aluno_id
        FROM matricula m
        JOIN turma t      ON t.id = m.turma_id
        JOIN disciplina d ON d.id = t.disciplina_id
        WHERE d.codigo = 'CCO072'                 -- ...de quem cursa CCO072
      );

--   (b) via EXISTS: para cada aluno, "existe" ao menos uma matricula
--       dele em CCO072? (correlacionada)
SELECT count(*) AS via_exists
FROM aluno a
WHERE EXISTS (
        SELECT 1
        FROM matricula m
        JOIN turma t      ON t.id = m.turma_id
        JOIN disciplina d ON d.id = t.disciplina_id
        WHERE m.aluno_id = a.id                   -- correlacao com a linha de fora
          AND d.codigo = 'CCO072'
      );

--   (c) via JOIN + DISTINCT: junta tudo e conta alunos distintos.
SELECT count(DISTINCT a.id) AS via_join           -- DISTINCT: o JOIN pode repetir o aluno
FROM aluno a
JOIN matricula m  ON m.aluno_id = a.id
JOIN turma t      ON t.id = m.turma_id
JOIN disciplina d ON d.id = t.disciplina_id
WHERE d.codigo = 'CCO072';
-- >> MySQL: IN, EXISTS, JOIN e DISTINCT funcionam igual no MySQL.


-- ---------------------------------------------------------------------
-- B.4  A ARMADILHA DO "NOT IN" COM NULO.
--
--   Este e um dos erros mais traicoeiros de SQL, e acontece TAMBEM no
--   MySQL. Se a lista do NOT IN contiver um unico valor NULO, o
--   resultado inteiro vira VAZIO, silenciosamente e sem dar erro.
--   Motivo: em SQL, comparar qualquer coisa com NULO nao da "verdadeiro"
--   nem "falso", da "desconhecido" — e isso contamina o NOT IN.
--   A forma segura, imune a nulos, e usar NOT EXISTS.
-- ---------------------------------------------------------------------
-- (i) versao que funciona (a coluna aluno_id nunca e nula):
SELECT count(*) AS sem_matricula_not_in
FROM aluno
WHERE id NOT IN (SELECT aluno_id FROM matricula);   -- seguro: sem nulos na lista

-- (ii) a MESMA ideia, mas com um NULO injetado de proposito na lista:
SELECT count(*) AS armadilha_not_in
FROM aluno
WHERE id NOT IN (
        SELECT aluno_id FROM matricula
        UNION ALL
        SELECT NULL                                 -- este NULO "envenena" o NOT IN
      );
-- Resultado: cai para 0, mesmo havendo alunos sem matricula.

-- (iii) a forma segura, que ignora o problema do nulo:
SELECT count(*) AS forma_segura
FROM aluno a
WHERE NOT EXISTS (                                  -- NOT EXISTS trata nulos corretamente
        SELECT 1 FROM matricula m WHERE m.aluno_id = a.id
      );
-- >> MySQL: a armadilha do NOT IN com NULO e IDENTICA no MySQL. A licao
--    vale para os dois bancos: prefira NOT EXISTS a NOT IN quando a
--    lista puder conter nulos.


-- ---------------------------------------------------------------------
-- B.5  SUBCONSULTA NO "FROM" E O "LATERAL".
--
--   Uma subconsulta comum no FROM nao pode "enxergar" as outras tabelas
--   da mesma clausula FROM. O LATERAL quebra essa regra: ele permite que
--   a subconsulta use a linha atual da tabela de fora. Aqui: para cada
--   aluno, buscamos a sua matricula mais recente.
-- ---------------------------------------------------------------------
SELECT a.matricula, a.nome,
       ult.data_matricula::date AS ultima_matricula,  -- data vinda da subconsulta lateral
       ult.status                                     -- status vindo da subconsulta lateral
FROM aluno a
JOIN LATERAL (                       -- LATERAL: a subconsulta pode usar "a" (a linha de fora)
        SELECT m.data_matricula, m.status
        FROM matricula m
        WHERE m.aluno_id = a.id      -- <- so e permitido por causa do LATERAL
        ORDER BY m.data_matricula DESC
        LIMIT 1                       -- pega apenas a mais recente
     ) ult ON true                    -- "ON true": aceita sempre que a subconsulta trouxer linha
ORDER BY ult.data_matricula DESC
LIMIT 10;
-- >> MySQL: o MySQL so passou a ter LATERAL na versao 8.0.14, e e pouco
--    usado la. Muito provavelmente voces nunca viram isso no MySQL.
--    No dia a dia, LATERAL brilha para pegar "o mais recente de cada".


-- #####################################################################
-- PARTE C — CTEs (COMMON TABLE EXPRESSIONS / "WITH")
-- #####################################################################
--
-- O QUE SAO: uma CTE e uma "tabela temporaria em memoria", com nome, que
--   existe SOMENTE durante a execucao daquela consulta. Voce calcula um
--   resultado, da um nome a ele (com WITH ... AS (...)) e usa esse nome
--   mais adiante como se fosse uma tabela de verdade.
--
-- COMO FUNCIONAM: diferente de uma tabela temporaria de verdade
--   (CREATE TEMPORARY TABLE), a CTE NAO e gravada em lugar nenhum e NAO
--   precisa ser apagada depois. Ela nasce e morre dentro do mesmo
--   comando SELECT. Uma CTE pode ate se apoiar em outra definida antes
--   dela, encadeando etapas.
--
-- QUANDO USAR: quando uma consulta ficaria confusa com varias
--   subconsultas aninhadas. A CTE quebra o problema em etapas nomeadas,
--   lidas de cima para baixo, como os passos de uma receita. Ganha-se
--   MUITA legibilidade. Use tambem quando precisar reaproveitar o mesmo
--   resultado intermediario mais de uma vez.
--
-- >> MySQL: CTEs (WITH) so existem no MySQL a partir da versao 8.0. Se
--    voces usaram uma versao mais antiga em BD I, nunca viram isso — por
--    isso pode parecer novidade. Onde existe (8.0+), a sintaxe e a mesma.
--    Uma diferenca conceitual: no MySQL a alternativa antiga era criar
--    CREATE TEMPORARY TABLE, rodar varias vezes e depois DROPar. A CTE
--    dispensa tudo isso: e temporaria, automatica e local a consulta.


-- ---------------------------------------------------------------------
-- C.1  CTE SIMPLES: nomear etapas e encadea-las.
--
--   Etapa 1: total de matriculas por curso.
--   Etapa 2: a media desses totais (que LE a etapa 1).
--   Consulta final: mostra cada curso ao lado da media e o desvio.
--   Escrito com subconsultas aninhadas, ficaria bem menos legivel.
-- ---------------------------------------------------------------------
WITH matriculas_por_curso AS (       -- 1a tabela temporaria em memoria
    SELECT c.codigo AS curso, count(*) AS qtd   -- total de matriculas por curso
    FROM matricula m
    JOIN aluno a ON a.id = m.aluno_id
    JOIN curso c ON c.id = a.curso_id
    GROUP BY c.codigo
),
media AS (                           -- 2a tabela temporaria, que LE a primeira
    SELECT avg(qtd) AS media_geral   -- media dos totais calculados acima
    FROM matriculas_por_curso        -- <- usa o resultado da CTE anterior
)
-- Consulta final: combina as duas CTEs criadas acima
SELECT mc.curso, mc.qtd,                                  -- curso e seu total (da CTE 1)
       round(m.media_geral, 2)          AS media_geral,   -- a media (da CTE 2), 2 casas decimais
       round(mc.qtd - m.media_geral, 2) AS desvio         -- quanto o curso desvia da media
FROM matriculas_por_curso mc
CROSS JOIN media m                    -- CROSS JOIN: cola a UNICA linha da media em cada curso
-- >> MySQL: CROSS JOIN existe no MySQL igual. Aqui ele e seguro (e util)
--    porque "media" tem uma linha so: cruzar N cursos x 1 media = N linhas.
ORDER BY mc.qtd DESC;


-- ---------------------------------------------------------------------
-- C.2  CTE RECURSIVA: percorrer uma estrutura em ARVORE.
--
--   Uma CTE recursiva se repete, alimentando-se do proprio resultado, ate
--   nao encontrar mais nada. Serve para hierarquias: organogramas, pastas
--   dentro de pastas e — no nosso caso — a cadeia de pre-requisitos.
--
--   Estrutura OBRIGATORIA, sempre em 3 partes:
--     1) ANCORA: o ponto de partida (roda uma vez).
--     2) UNION ALL: o "cola" entre a ancora e a parte que se repete.
--     3) TERMO RECURSIVO: a parte que se refere a propria CTE e se repete.
--
--   Aqui: descer toda a cadeia de pre-requisitos de CCO072 (BD II).
-- ---------------------------------------------------------------------
WITH RECURSIVE cadeia AS (
    -- (1) ANCORA: a disciplina de partida, no nivel 0
    SELECT d.id, d.codigo, d.nome, 0 AS nivel,
           d.codigo::text AS caminho          -- caminho percorrido, em texto
    FROM disciplina d
    WHERE d.codigo = 'CCO072'                  -- <- ponto de partida da arvore

    UNION ALL                                   -- (2) cola a ancora ao termo recursivo

    -- (3) TERMO RECURSIVO: os pre-requisitos das disciplinas ja achadas
    SELECT req.id, req.codigo, req.nome, c.nivel + 1,   -- desce um nivel a cada salto
           c.caminho || ' -> ' || req.codigo            -- acumula o caminho
    FROM cadeia c                                        -- <- a CTE se referencia (por isso "recursiva")
    JOIN pre_requisito pr ON pr.disciplina_id = c.id     -- pre-requisitos daquela disciplina
    JOIN disciplina req   ON req.id = pr.requisito_id    -- dados da disciplina exigida
)
SELECT nivel,
       repeat('    ', nivel) || codigo AS hierarquia,    -- indenta conforme a profundidade
       nome, caminho
FROM cadeia
ORDER BY caminho;
-- >> MySQL: "WITH RECURSIVE" tambem existe no MySQL 8.0+ e a estrutura
--    (ancora + UNION ALL + termo recursivo) e a MESMA. Em MySQL antigo
--    (5.x), recursao NAO existia — tinha que se virar com procedimentos.


-- ---------------------------------------------------------------------
-- C.3  CTE RECURSIVA NO SENTIDO INVERSO: subir a arvore.
--
--   Mesmo mecanismo, direcao contraria: partimos de uma disciplina-base
--   e subimos para as que DEPENDEM dela. A unica diferenca em relacao a
--   C.2 e QUAL coluna usamos na juncao (trocamos disciplina_id por
--   requisito_id). Aqui: tudo que depende de MDC118.
-- ---------------------------------------------------------------------
WITH RECURSIVE dependentes AS (
    SELECT d.id, d.codigo, d.nome, 0 AS nivel           -- ancora: a disciplina-base
    FROM disciplina d
    WHERE d.codigo = 'MDC118'
    UNION ALL
    SELECT dep.id, dep.codigo, dep.nome, dp.nivel + 1   -- sobe um nivel
    FROM dependentes dp
    JOIN pre_requisito pr ON pr.requisito_id = dp.id     -- quem tem ESTA como requisito...
    JOIN disciplina dep   ON dep.id = pr.disciplina_id   -- ...e a disciplina que depende
)
SELECT nivel, codigo, nome
FROM dependentes
ORDER BY nivel, codigo;


-- ---------------------------------------------------------------------
-- C.4  PROTECAO CONTRA RECURSAO INFINITA.
--
--   Se os dados tiverem um ciclo (A exige B e B exige A), a CTE recursiva
--   NAO para sozinha e roda para sempre. Duas protecoes que TODA CTE
--   recursiva sobre dados reais deveria ter:
--     (1) guardar num array o caminho ja visitado e cortar se um no se
--         repetir;
--     (2) limitar a profundidade maxima.
-- ---------------------------------------------------------------------
WITH RECURSIVE seguro AS (
    SELECT d.id, d.codigo, 0 AS nivel,
           ARRAY[d.id] AS visitados            -- inicia a lista de nos ja visitados
           -- >> MySQL: ARRAY e um tipo NATIVO do PostgreSQL. O MySQL nao
           --    tem array de verdade; la, essa protecao seria feita de
           --    outro jeito (concatenando ids num texto, por exemplo).
    FROM disciplina d
    WHERE d.codigo = 'CCO072'
    UNION ALL
    SELECT req.id, req.codigo, s.nivel + 1,
           s.visitados || req.id                -- acrescenta o novo no ao caminho
    FROM seguro s
    JOIN pre_requisito pr ON pr.disciplina_id = s.id
    JOIN disciplina req   ON req.id = pr.requisito_id
    WHERE NOT req.id = ANY(s.visitados)         -- PROTECAO 1: corta se o no ja foi visitado
      AND s.nivel < 10                          -- PROTECAO 2: corta na profundidade 10
)
SELECT codigo, nivel, visitados
FROM seguro
ORDER BY nivel, codigo;


-- #####################################################################
-- PARTE D — FUNCOES DE JANELA (WINDOW FUNCTIONS)
-- #####################################################################
--
-- O QUE SAO: funcoes que fazem um calculo sobre um CONJUNTO de linhas
--   relacionadas a linha atual (a "janela"), MAS sem juntar as linhas
--   num resultado so.
--
-- COMO FUNCIONAM — a diferenca-chave em relacao ao GROUP BY:
--   * GROUP BY COLAPSA: varias linhas viram uma (voce perde o detalhe).
--   * OVER (janela) PRESERVA: todas as linhas continuam aparecendo, e o
--     calculo e anexado como uma coluna a mais em cada uma.
--   A "janela" e definida pela clausula OVER(...), que pode ter
--   PARTITION BY (divide em grupos) e ORDER BY (ordena dentro do grupo).
--
-- QUANDO USAR: rankings, comparar uma linha com a anterior/seguinte,
--   somas acumuladas, medias moveis, percentis. Tudo isso mantendo o
--   detalhe linha a linha.
--
-- >> MySQL: funcoes de janela (OVER, RANK, LAG, etc.) so existem no MySQL
--    a partir da versao 8.0. Se voces usaram MySQL 5.x em BD I, isto e
--    TOTALMENTE novo. Onde existe (8.0+), a sintaxe e basicamente igual.


-- ---------------------------------------------------------------------
-- D.1  A DIFERENCA FUNDAMENTAL: GROUP BY colapsa; OVER preserva.
--
--   As duas consultas usam count. A 1a (GROUP BY) devolve 1 linha por
--   curso. A 2a (OVER) mantem TODAS as matriculas e escreve, em cada
--   linha, o total do curso e o total geral — sem colapsar nada.
-- ---------------------------------------------------------------------
-- (i) com GROUP BY: uma linha por curso (perde o detalhe dos alunos)
SELECT c.codigo AS curso, count(*) AS matriculas
FROM matricula m
JOIN aluno a ON a.id = m.aluno_id
JOIN curso c ON c.id = a.curso_id
GROUP BY c.codigo;

-- (ii) com OVER: cada matricula continua aparecendo, "carregando" os totais
SELECT a.nome AS aluno, c.codigo AS curso,
       count(*) OVER (PARTITION BY c.codigo) AS matriculas_no_curso, -- total do curso da linha
       count(*) OVER ()                      AS matriculas_no_total  -- total geral (janela sem particao)
FROM matricula m
JOIN aluno a ON a.id = m.aluno_id
JOIN curso c ON c.id = a.curso_id
ORDER BY c.codigo, a.nome
LIMIT 12;


-- ---------------------------------------------------------------------
-- D.2  RANKING: ROW_NUMBER x RANK x DENSE_RANK x NTILE.
--
--   As quatro numeram/ordenam, mas tratam EMPATES de formas diferentes:
--     row_number : posicao unica sempre (1,2,3,4...) — ignora empate
--     rank       : empate divide a posicao e PULA a seguinte (1,1,3...)
--     dense_rank : empate divide a posicao e NAO pula (1,1,2...)
--     ntile(n)   : divide as linhas em n faixas de tamanho parecido
-- ---------------------------------------------------------------------
WITH desempenho AS (                 -- media de cada aluno (media das medias de suas matriculas)
    SELECT a.nome, round(avg(h.media_final), 2) AS media
    FROM aluno a
    JOIN matricula m ON m.aluno_id = a.id
    JOIN historico h ON h.matricula_id = m.id
    WHERE h.media_final IS NOT NULL
    GROUP BY a.id, a.nome
)
SELECT nome, media,
       row_number() OVER (ORDER BY media DESC) AS row_number,  -- sequencial unico
       rank()       OVER (ORDER BY media DESC) AS rank,        -- com "buracos" no empate
       dense_rank() OVER (ORDER BY media DESC) AS dense_rank,  -- sem buracos
       ntile(4)     OVER (ORDER BY media DESC) AS quartil      -- divide a turma em 4 faixas
FROM desempenho
ORDER BY media DESC
LIMIT 12;


-- ---------------------------------------------------------------------
-- D.3  RANKING DENTRO DE CADA GRUPO: PARTITION BY.
--
--   "O aluno de melhor media EM CADA curso." O PARTITION BY faz o ranking
--   REINICIAR a cada curso. Depois filtramos so a posicao 1.
--   Observacao: nao da para filtrar uma funcao de janela direto no WHERE;
--   por isso envolvemos tudo numa subconsulta e filtramos por fora.
-- ---------------------------------------------------------------------
SELECT * FROM (
    SELECT c.codigo AS curso, a.nome,
           round(avg(h.media_final), 2) AS media,
           rank() OVER (PARTITION BY c.codigo ORDER BY avg(h.media_final) DESC) AS posicao
           -- ^ ranking que reinicia a cada curso (PARTITION BY c.codigo)
    FROM aluno a
    JOIN curso c     ON c.id = a.curso_id
    JOIN matricula m ON m.aluno_id = a.id
    JOIN historico h ON h.matricula_id = m.id
    WHERE h.media_final IS NOT NULL
    GROUP BY c.codigo, a.id, a.nome
) r
WHERE posicao = 1                    -- so o primeiro colocado de cada curso
ORDER BY curso;


-- ---------------------------------------------------------------------
-- D.4  LAG e LEAD: comparar a linha atual com a anterior/seguinte.
--
--   lag()  olha para a linha ANTERIOR na ordem definida.
--   lead() olha para a linha SEGUINTE.
--   Aqui: evolucao mensal de matriculas, com a variacao mes a mes.
-- ---------------------------------------------------------------------
WITH por_mes AS (                    -- total de matriculas por mes
    SELECT date_trunc('month', data_matricula)::date AS mes, count(*) AS qtd
    -- >> MySQL: date_trunc e uma funcao do PostgreSQL que "arredonda"
    --    uma data para o inicio do mes. No MySQL o equivalente seria
    --    DATE_FORMAT(data, '%Y-%m-01') ou usar EXTRACT(YEAR/MONTH).
    FROM matricula
    GROUP BY 1                        -- agrupa pela 1a coluna do SELECT (o mes)
    -- >> MySQL: "GROUP BY 1" (agrupar pela posicao) funciona nos dois.
)
SELECT mes, qtd,
       lag(qtd)  OVER (ORDER BY mes) AS mes_anterior,   -- qtd do mes anterior
       qtd - lag(qtd) OVER (ORDER BY mes) AS variacao,  -- diferenca para o mes anterior
       lead(qtd) OVER (ORDER BY mes) AS mes_seguinte    -- qtd do proximo mes
FROM por_mes
ORDER BY mes;


-- ---------------------------------------------------------------------
-- D.5  ACUMULADOS E MEDIA MOVEL: a "moldura" da janela (frame).
--
--   Uma janela ordenada pode olhar um INTERVALO de linhas ao redor da
--   atual. "ROWS BETWEEN ... AND ..." define esse intervalo (a moldura):
--     UNBOUNDED PRECEDING = desde a primeira linha
--     CURRENT ROW         = ate a linha atual  -> isso da um ACUMULADO
--     1 PRECEDING/FOLLOWING = a vizinha de tras/frente -> MEDIA MOVEL
-- ---------------------------------------------------------------------
WITH por_mes AS (
    SELECT date_trunc('month', data_matricula)::date AS mes, count(*) AS qtd
    FROM matricula
    GROUP BY 1
)
SELECT mes, qtd,
       sum(qtd) OVER (ORDER BY mes
                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS acumulado,
       -- ^ soma tudo do inicio ate a linha atual (total que so cresce)
       round(avg(qtd) OVER (ORDER BY mes
                      ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING), 2)     AS media_movel_3
       -- ^ media do mes anterior, do atual e do seguinte (suaviza a curva)
FROM por_mes
ORDER BY mes;
-- >> MySQL: a clausula de moldura (ROWS BETWEEN) tambem existe no MySQL
--    8.0. Em MySQL antigo, nada disso era possivel.


-- ---------------------------------------------------------------------
-- D.6  NOMEAR A JANELA: a clausula WINDOW.
--
--   Quando varias funcoes usam a MESMA janela, da para defini-la uma vez
--   com um nome (na clausula WINDOW) e reutilizar. Evita repetir e evita
--   erro de digitar a janela diferente em cada funcao.
-- ---------------------------------------------------------------------
WITH desempenho AS (
    SELECT c.codigo AS curso, a.nome, round(avg(h.media_final), 2) AS media
    FROM aluno a
    JOIN curso c     ON c.id = a.curso_id
    JOIN matricula m ON m.aluno_id = a.id
    JOIN historico h ON h.matricula_id = m.id
    WHERE h.media_final IS NOT NULL
    GROUP BY c.codigo, a.id, a.nome
)
SELECT curso, nome, media,
       rank()           OVER w AS posicao,         -- usa a janela chamada "w"
       round(avg(media) OVER w, 2) AS media_curso  -- mesma janela "w", outra funcao
FROM desempenho
WINDOW w AS (PARTITION BY curso ORDER BY media DESC)  -- define "w" uma unica vez
ORDER BY curso, posicao
LIMIT 15;
-- >> MySQL: a clausula WINDOW nomeada existe no MySQL 8.0. Pouca gente
--    usa, mas deixa a consulta bem mais limpa quando a janela se repete.


-- #####################################################################
-- PARTE E — VIEWS E MATERIALIZED VIEWS
-- #####################################################################
--
-- O QUE SAO:
--   VIEW ("visao"): uma consulta guardada com um nome. Ela NAO armazena
--     dados; toda vez que voce a consulta, a consulta por tras roda de
--     novo e traz dados sempre atualizados. E como um "atalho" para uma
--     consulta que voce usa muito.
--   MATERIALIZED VIEW ("visao materializada"): parecida, mas o resultado
--     FICA GRAVADO em disco. A leitura e rapida (nao recalcula), porem o
--     dado fica "congelado" no momento em que foi gravado, ate voce
--     mandar atualizar com REFRESH.
--
-- QUANDO USAR:
--   VIEW: quando voce quer simplificar/reaproveitar uma consulta e
--     precisa sempre do dado atual. (custo: recalcula a cada uso)
--   MATERIALIZED VIEW: quando a consulta e pesada e voce tolera um dado
--     um pouco defasado (ex.: um painel de indicadores atualizado 1x/dia).
--
-- >> MySQL: a VIEW comum existe no MySQL, igual. Mas a MATERIALIZED VIEW
--    NAO EXISTE no MySQL! La, quem precisa disso cria uma tabela normal e
--    a atualiza na mao (ou por evento agendado). No PostgreSQL e um
--    recurso nativo, com o comando REFRESH. Esta e uma diferenca grande.


-- ---------------------------------------------------------------------
-- E.1  VIEW: uma consulta batizada, sempre atualizada.
--
--   "Ocupacao de cada turma": vagas, matriculados e vagas restantes.
--   Depois de criada, consulta-se como se fosse uma tabela.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_ocupacao AS
SELECT t.id AS turma_id, t.codigo AS turma, d.nome AS disciplina,
       t.vagas,                                                          -- vagas ofertadas
       count(m.id) FILTER (WHERE m.status = 'MATRICULADO') AS ocupadas,  -- so matriculas ativas
       -- >> MySQL: "FILTER (WHERE ...)" e um recurso do PostgreSQL para
       --    contar/somar so as linhas que satisfazem uma condicao. No
       --    MySQL nao existe FILTER; faz-se com CASE dentro do agregado:
       --    SUM(CASE WHEN m.status='MATRICULADO' THEN 1 ELSE 0 END)
       t.vagas - count(m.id) FILTER (WHERE m.status = 'MATRICULADO') AS restantes
FROM turma t
JOIN disciplina d ON d.id = t.disciplina_id
LEFT JOIN matricula m ON m.turma_id = t.id                             -- LEFT: turma vazia tambem aparece
GROUP BY t.id, t.codigo, d.nome, t.vagas;

-- consulta a view como se fosse uma tabela normal:
SELECT turma, disciplina, vagas, ocupadas, restantes
FROM vw_ocupacao
ORDER BY restantes, turma;


-- ---------------------------------------------------------------------
-- E.2  VIEW SOBRE VIEW: uma view pode se apoiar em outra.
--
--   Aqui, filtramos a view anterior para mostrar so as turmas lotadas.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_turmas_lotadas AS
SELECT * FROM vw_ocupacao WHERE restantes <= 0;   -- reaproveita a vw_ocupacao

SELECT turma, disciplina, vagas, ocupadas
FROM vw_turmas_lotadas
ORDER BY turma;


-- ---------------------------------------------------------------------
-- E.3  VIEW COM REGRA DE NEGOCIO: encapsular um criterio num nome.
--
--   A regra "reprovado por falta = frequencia < 75%" fica guardada na
--   view. Os relatorios usam a view e nao repetem (nem divergem) a regra.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_risco_frequencia AS
SELECT a.matricula, a.nome, d.codigo AS disciplina, h.frequencia
FROM historico h
JOIN matricula m  ON m.id = h.matricula_id
JOIN aluno a      ON a.id = m.aluno_id
JOIN turma t      ON t.id = m.turma_id
JOIN disciplina d ON d.id = t.disciplina_id
WHERE h.frequencia < 75;              -- a regra de negocio, encapsulada

SELECT * FROM vw_risco_frequencia
ORDER BY frequencia
LIMIT 10;


-- ---------------------------------------------------------------------
-- E.4  MATERIALIZED VIEW: aqui o resultado E gravado em disco.
--
--   Indicadores por curso. Como fica materializada, a leitura e rapida,
--   mas o dado so muda quando dermos REFRESH (ver E.5).
-- ---------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS mv_indicadores_aula;   -- recomeca limpo se ja existir
CREATE MATERIALIZED VIEW mv_indicadores_aula AS
SELECT c.id AS curso_id, c.codigo AS curso,
       count(*)                     AS registros,    -- total de registros de historico do curso
       count(DISTINCT a.id)         AS alunos,       -- alunos distintos do curso
       round(avg(h.media_final), 2) AS media_geral,  -- media das medias
       count(*) FILTER (WHERE h.situacao = 'APROVADO') AS aprovados
FROM curso c
JOIN aluno a     ON a.curso_id = c.id
JOIN matricula m ON m.aluno_id = a.id
JOIN historico h ON h.matricula_id = m.id
GROUP BY c.id, c.codigo;

-- indice UNICO: exigido para poder usar REFRESH ... CONCURRENTLY (E.5)
CREATE UNIQUE INDEX uq_mv_indicadores_aula ON mv_indicadores_aula (curso_id);

SELECT curso, registros, alunos, media_geral, aprovados
FROM mv_indicadores_aula
ORDER BY media_geral DESC;


-- ---------------------------------------------------------------------
-- E.5  A PROVA DE QUE A MATERIALIZED VIEW FICA "CONGELADA".
--
--   Inserimos uma matricula nova e comparamos a contagem na TABELA (que
--   ja ve o novo dado) com a da MATERIALIZED VIEW (que ainda nao ve, ate
--   o REFRESH). Depois damos REFRESH e as duas convergem.
-- ---------------------------------------------------------------------
-- cria uma matricula nova para o curso de id = 1
INSERT INTO matricula (aluno_id, turma_id, status)
SELECT a.id, t.id, 'MATRICULADO'
FROM aluno a
JOIN curso c ON c.id = a.curso_id AND c.id = 1
JOIN turma t ON t.id = 1
WHERE NOT EXISTS (SELECT 1 FROM matricula m WHERE m.aluno_id = a.id AND m.turma_id = t.id)
LIMIT 1;

-- gera o historico dessa nova matricula (para entrar na contagem)
INSERT INTO historico (matricula_id, nota_a1, nota_a2, frequencia, situacao)
SELECT m.id, 8.0, 7.0, 90, 'APROVADO'
FROM matricula m
WHERE NOT EXISTS (SELECT 1 FROM historico h WHERE h.matricula_id = m.id);

-- ANTES do refresh: a tabela ja conta o novo registro; a mv ainda nao
SELECT (SELECT count(*) FROM historico h
          JOIN matricula m ON m.id = h.matricula_id
          JOIN aluno a     ON a.id = m.aluno_id
         WHERE a.curso_id = 1)                                        AS registros_na_tabela,
       (SELECT registros FROM mv_indicadores_aula WHERE curso_id = 1) AS registros_na_mv;
-- Os dois numeros vao DIVERGIR aqui: a tabela ja subiu, a mv esta congelada.

-- atualiza a materialized view (CONCURRENTLY nao trava leituras, mas
-- EXIGE o indice unico criado em E.4)
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_indicadores_aula;
-- >> MySQL: nada disso existe no MySQL. Este comando REFRESH e a razao
--    de a materialized view ser tao pratica no PostgreSQL.

-- DEPOIS do refresh: as duas fontes convergem
SELECT (SELECT count(*) FROM historico h
          JOIN matricula m ON m.id = h.matricula_id
          JOIN aluno a     ON a.id = m.aluno_id
         WHERE a.curso_id = 1)                                        AS registros_na_tabela,
       (SELECT registros FROM mv_indicadores_aula WHERE curso_id = 1) AS registros_na_mv;
-- Agora sao IGUAIS: o REFRESH regravou o resultado da mv.

-- #####################################################################
-- FIM DA AULA 2
-- #####################################################################
