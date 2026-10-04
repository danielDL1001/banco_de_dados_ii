/* =============================================================================
   1. CABEÇALHO E OBJETIVO DO EXPERIMENTO
   =============================================================================
   Arquivo ........: marco02_transacoes_concorrencia.sql
   Objetivo .......: demonstrar, em DUAS SESSÕES REAIS do PostgreSQL, a condição de
                     corrida na disputa pela ÚLTIMA VAGA de uma turma e comparar duas
                     correções: (1) bloqueio explícito SELECT ... FOR UPDATE e
                     (2) isolamento SERIALIZABLE (SSI), com tratamento de 40001/40P01.
   Referência .....: marco01.sql  (= modelo_fisico_postgresql.sql, entregue na etapa
                     anterior; seções 1-9 = DDL). NÃO é modificado nem recriado aqui.
                     Este arquivo opera sobre o banco já criado por ele.

   ESTRUTURAS DO marco01 UTILIZADAS (verificadas no DDL, nenhum nome presumido):
     turma(id_turma PK, id_disciplina, id_professor, id_periodo_letivo, turno, codigo)
     matricula(id_matricula PK, id_aluno FK, id_turma FK, data_matricula, status,
               UNIQUE (id_aluno, id_turma) = uq_matricula_aluno_turma)
     aluno, disciplina, professor, periodo_letivo (apenas para linhas de teste)
     idx_matricula_turma_aluno (id_turma, id_aluno): atende a contagem por turma.

   LIMITAÇÃO DO MODELO (identificada ANTES de qualquer SQL):
     O marco01 NÃO possui atributo de capacidade nem contador de vagas em turma.
     sala.capacidade existe, mas não há relacionamento turma <-> sala, então a capacidade
     da turma não é derivável. Sem capacidade não existe regra a violar.
     SOLUÇÃO MÍNIMA: uma única tabela auxiliar ISOLADA, sem alterar nenhuma tabela do modelo:
         turma_capacidade (id_turma PK/FK -> turma, capacidade smallint NOT NULL CHECK > 0)
     Ocupação NÃO é armazenada: é calculada por count(*) em matricula (evita contador
     redundante que poderia divergir). Todo o experimento é válido também sem contador.
     Nenhuma restrição do marco01 é removida ou alterada.

   DECISÕES ASSUMIDAS (registradas):
     D1 "Matrículas confirmadas" = TODAS as linhas de matricula da turma. O modelo não
        define os valores de matricula.status; filtrar por um valor seria inventar regra.
        Linhas de teste usam status 'CONFIRMADA' (dado de teste, não regra do modelo).
     D2 Capacidade de teste N = 3 (2 matrículas = N-1, 1 vaga), turmas CONC-*.
     D3 Dados de teste identificados por marcador ('CONC-...' / 'conc_...@conc.invalid');
        preparação e limpeza só tocam esses marcadores.
     D4 A regra de capacidade é imposta pelo PROTOCOLO transacional (lock ou SERIALIZABLE),
        não por constraint. Uma garantia estrutural exigiria TRIGGER em matricula (alteração
        do modelo) e não foi implementada sem autorização. Ver seção 13, item "limitações".

   SOBRE EVIDÊNCIAS: os blocos "RESULTADO OBSERVADO" são saída REAL de execução com duas
   sessões independentes (conexões/PIDs distintos) em PostgreSQL 16.15 (Ubuntu), 1 vCPU,
   4 GB RAM, default_transaction_isolation=read committed, deadlock_timeout=1s, tabelas
   com poucas linhas. Foram gerados por um script Python/psycopg2 auxiliar (driver) que
   executa EXATAMENTE os comandos numerados deste arquivo, alternando as sessões na ordem
   indicada. "Esperado" = previsão da documentação. Tempos absolutos dependem do ambiente.
   NENHUMA medição de desempenho (throughput/latência) foi feita ou é afirmada.

   ESTRUTURA DESTE ARQUIVO (seções do pedido original -> aqui):
     1 Cabeçalho | 2 Pré-requisitos | 3 Preparação | 4 Estado inicial | 5 Anomalia |
     6 Instruções das duas sessões | 7 Correção 1 (FOR UPDATE) | 8 Teste concorrente 1 |
     9 Correção 2 (SERIALIZABLE) | 10 Teste concorrente 2 | 11 Verificação de integridade |
     12 Erros e retentativas | 13 Comparação técnica | 14 Limpeza
   ============================================================================= */


/* =============================================================================
   2. PRÉ-REQUISITOS
   =============================================================================
   * Banco criado pela execução prévia das seções 1-9 do marco01.sql (21 tabelas).
     (A seção 10 do marco01 é benchmark e NÃO deve ser carregada neste banco.)
   * PostgreSQL >= 10; psql. Usuário com permissão de CREATE TABLE e DML.
   * Nível de isolamento padrão do banco = READ COMMITTED (não alterado).
   * Executáveis com "psql -f": seções 3, 4, 11 e 14. As demais contêm roteiros para
     serem colados manualmente, passo a passo, em DUAS janelas (comentários "--").
   * NÃO execute este arquivo inteiro numa única sessão esperando concorrência: isso
     seria execução sequencial, não concorrente.
   ============================================================================= */
\set ON_ERROR_STOP on
SET client_min_messages = warning;


/* =============================================================================
   3. PREPARAÇÃO CONTROLADA DO CENÁRIO DE TESTE   (executável: psql -f ou colar)
   =============================================================================
   Idempotente. Só INSERE linhas marcadas 'CONC'/'conc_' e cria turma_capacidade.
   Nenhum dado preexistente é lido, alterado ou removido.
   ============================================================================= */
-- 3.1 Estrutura auxiliar (ÚNICA adição ao modelo; isolada; ver justificativa no cabeçalho)
CREATE TABLE IF NOT EXISTS turma_capacidade (
    id_turma    integer  PRIMARY KEY REFERENCES turma (id_turma),
    capacidade  smallint NOT NULL CHECK (capacidade > 0)
);

-- 3.2 Dados de teste, todos com marcador 'CONC' (idempotente: pode reexecutar)
INSERT INTO periodo_letivo (ano, semestre, data_inicio, data_fim)
SELECT 9999, 1, DATE '9999-01-01', DATE '9999-06-30'
 WHERE NOT EXISTS (SELECT 1 FROM periodo_letivo WHERE ano = 9999 AND semestre = 1);

INSERT INTO disciplina (codigo, nome)
SELECT 'CONC-DISC', 'Disciplina de teste de concorrencia'
 WHERE NOT EXISTS (SELECT 1 FROM disciplina WHERE codigo = 'CONC-DISC');

INSERT INTO professor (matricula, nome, email)
SELECT 'CONC-PROF', 'Professor de teste', 'conc_prof@conc.invalid'
 WHERE NOT EXISTS (SELECT 1 FROM professor WHERE matricula = 'CONC-PROF');

-- alunos: f1,f2 (já matriculados), a,b (candidatos), s01..s08 (contenção em massa)
INSERT INTO aluno (nome, cpf, email)
SELECT 'CONC aluno ' || k, '99999' || lpad(n::text, 6, '0'), 'conc_' || k || '@conc.invalid'
  FROM (VALUES ('f1',1),('f2',2),('a',3),('b',4),('s01',11),('s02',12),('s03',13),('s04',14),
               ('s05',15),('s06',16),('s07',17),('s08',18)) v(k, n)
 WHERE NOT EXISTS (SELECT 1 FROM aluno x WHERE x.email = 'conc_' || v.k || '@conc.invalid');

-- turmas de teste (uma por experimento, para não misturar os cenários)
INSERT INTO turma (id_disciplina, id_professor, id_periodo_letivo, turno, codigo)
SELECT (SELECT id_disciplina FROM disciplina WHERE codigo = 'CONC-DISC'),
       (SELECT id_professor  FROM professor  WHERE matricula = 'CONC-PROF'),
       (SELECT id_periodo_letivo FROM periodo_letivo WHERE ano = 9999 AND semestre = 1),
       'teste', c
  FROM (VALUES ('CONC-ANOM'),('CONC-LOCK'),('CONC-SER'),('CONC-DL1'),('CONC-DL2')) v(c)
 WHERE NOT EXISTS (SELECT 1 FROM turma t WHERE t.codigo = v.c);

-- capacidade N = 3 em todas
INSERT INTO turma_capacidade (id_turma, capacidade)
SELECT id_turma, 3 FROM turma WHERE codigo LIKE 'CONC-%'
ON CONFLICT (id_turma) DO NOTHING;

-- N-1 = 2 matrículas confirmadas (f1, f2) nas turmas dos experimentos 1-3
INSERT INTO matricula (id_aluno, id_turma, data_matricula, status)
SELECT a.id_aluno, t.id_turma, CURRENT_DATE, 'CONFIRMADA'
  FROM aluno a CROSS JOIN turma t
 WHERE a.email IN ('conc_f1@conc.invalid', 'conc_f2@conc.invalid')
   AND t.codigo IN ('CONC-ANOM', 'CONC-LOCK', 'CONC-SER')
   AND NOT EXISTS (SELECT 1 FROM matricula m WHERE m.id_aluno = a.id_aluno AND m.id_turma = t.id_turma);


/* =============================================================================
   4. ESTADO INICIAL DA TURMA   (executável)
   =============================================================================
   Esperado: 3 turmas (ANOM, LOCK, SER) com capacidade 3 e 2 matriculados (N-1);
   DL1/DL2 com 0 (usadas só no teste de deadlock).
   Resultado observado após a preparação:
       CONC-ANOM | 3 | 2     CONC-LOCK | 3 | 2     CONC-SER | 3 | 2
       CONC-DL1  | 3 | 0     CONC-DL2  | 3 | 0
   ============================================================================= */
SELECT t.codigo, c.capacidade, count(m.id_matricula) AS matriculados,
       c.capacidade - count(m.id_matricula) AS vagas
  FROM turma t JOIN turma_capacidade c ON c.id_turma = t.id_turma
  LEFT JOIN matricula m ON m.id_turma = t.id_turma
 WHERE t.codigo LIKE 'CONC-%'
 GROUP BY t.codigo, c.capacidade ORDER BY t.codigo;


/* =============================================================================
   5. REPRODUÇÃO DA ANOMALIA — READ COMMITTED (padrão), SEM controle
   =============================================================================
   Turma CONC-ANOM: capacidade 3, matriculados 2 (N-1), 1 vaga. Candidatos: A e B
   (alunos 'conc_a' e 'conc_b', DIFERENTES).

   Padrão leitura-modificação-escrita: (1) lê vagas = capacidade - count(matricula);
   (2) a aplicação decide "vagas > 0"; (3) INSERT da matrícula.

   POR QUE A ANOMALIA É POSSÍVEL (e por que as constraints existentes não a impedem):
   * READ COMMITTED: cada comando enxerga só o que já foi confirmado. A leitura de B
     não vê o INSERT não confirmado de A, então as duas leituras retornam vagas = 1.
   * UNIQUE (id_aluno,id_turma) de matricula impede o MESMO aluno duas vezes; aqui os
     alunos são diferentes -> chaves diferentes -> o INSERT de B NÃO espera nem falha.
   * FKs e PK não limitam a quantidade de linhas por turma. Não existe CHECK/UNIQUE no
     modelo que expresse a capacidade (turma_capacidade.capacidade é só um valor).
   * Nenhuma restrição foi removida para a demonstração.

   Distinção exigida:
   * Execução SEQUENCIAL (A termina, depois B): B lê vagas = 0 e não insere -> correto.
   * Execução CONCORRENTE (A e B lêem antes de qualquer COMMIT): ambos decidem inserir.
   * O PostgreSQL GARANTE em READ COMMITTED apenas que não há leitura suja e que cada
     comando vê um snapshot consistente; NÃO garante que a decisão tomada com base numa
     leitura continue válida no momento da escrita.

   ORDEM DE EXECUÇÃO (abrir DOIS terminais psql no MESMO banco; os passos numerados
   devem ser executados na ordem, alternando entre as janelas):
   (remova o prefixo "--     " ao colar)

--   [0] Sessão A ou qualquer: reiniciar o cenário (só linhas de teste):
--     DELETE FROM matricula WHERE id_turma = (SELECT id_turma FROM turma WHERE codigo = 'CONC-ANOM')
--        AND id_aluno NOT IN (SELECT id_aluno FROM aluno WHERE email LIKE 'conc\_f%@conc.invalid');
--   [1] Sessão A:
--     BEGIN;
--   [2] Sessão B:
--     BEGIN;
--   [3] Sessão A:   esperado: (3, 2, 1)
--     SELECT c.capacidade, count(m.id_matricula) AS matriculados,
--            c.capacidade - count(m.id_matricula) AS vagas
--       FROM turma_capacidade c JOIN turma t ON t.id_turma = c.id_turma
--       LEFT JOIN matricula m ON m.id_turma = c.id_turma
--      WHERE t.codigo = 'CONC-ANOM' GROUP BY c.capacidade;
--   [4] Sessão B:   esperado: (3, 2, 1)   <-- PONTO DE SINCRONIZAÇÃO: as duas já leram vaga=1
--     SELECT c.capacidade, count(m.id_matricula) AS matriculados,
--            c.capacidade - count(m.id_matricula) AS vagas
--       FROM turma_capacidade c JOIN turma t ON t.id_turma = c.id_turma
--       LEFT JOIN matricula m ON m.id_turma = c.id_turma
--      WHERE t.codigo = 'CONC-ANOM' GROUP BY c.capacidade;
--   [5] Sessão A:   esperado: INSERT 0 1
--     INSERT INTO matricula (id_aluno, id_turma, data_matricula, status)
--     SELECT a.id_aluno, t.id_turma, CURRENT_DATE, 'CONFIRMADA'
--       FROM aluno a, turma t WHERE a.email = 'conc_a@conc.invalid' AND t.codigo = 'CONC-ANOM';
--   [6] Sessão B:   esperado: INSERT 0 1 IMEDIATO (não espera: chave diferente)
--     INSERT INTO matricula (id_aluno, id_turma, data_matricula, status)
--     SELECT a.id_aluno, t.id_turma, CURRENT_DATE, 'CONFIRMADA'
--       FROM aluno a, turma t WHERE a.email = 'conc_b@conc.invalid' AND t.codigo = 'CONC-ANOM';
--   [7] Sessão A:
--     COMMIT;
--   [8] Sessão B:
--     COMMIT;
--   [9] qualquer sessão:   esperado: matriculados = 4 > capacidade 3, excedeu = t
--     SELECT t.codigo, c.capacidade, count(m.id_matricula) AS matriculados,
--            count(m.id_matricula) > c.capacidade AS excedeu
--       FROM turma t JOIN turma_capacidade c ON c.id_turma = t.id_turma
--       LEFT JOIN matricula m ON m.id_turma = t.id_turma
--      WHERE t.codigo = 'CONC-ANOM' GROUP BY t.codigo, c.capacidade;

   RESULTADO ESPERADO: 4 matrículas em turma de capacidade 3 (violação da regra).
-- RESULTADO OBSERVADO (execução real; saída resumida do driver, PostgreSQL 16.15):
--   t= 0.005s  === EXP 1: ANOMALIA (READ COMMITTED, sem controle) ===
--   t= 0.006s  Sessão OBS(pid 1727)  SELECT estado -> (codigo, capacidade, matriculados, excedeu)  =>  [('CONC-ANOM', 3, 2, False)]
--   t= 0.010s  Sessão A (pid 1728)  BEGIN  =>  OK
--   t= 0.010s  Sessão B (pid 1729)  BEGIN  =>  OK
--   t= 0.012s  Sessão A (pid 1728)  SELECT vagas  -> (capacidade, matriculados, vagas)  =>  [(3, 2, 1)]
--   t= 0.013s  Sessão B (pid 1729)  SELECT vagas  -> (capacidade, matriculados, vagas)  =>  [(3, 2, 1)]
--   t= 0.014s  Sessão A (pid 1728)  INSERT matricula [aluno a, CONC-ANOM]  =>  OK
--   t= 0.015s  Sessão B (pid 1729)  INSERT matricula [aluno b, CONC-ANOM]  =>  OK
--   t= 0.015s  Sessão B: INSERT bloqueou? NAO (concluiu em 0.001s sem esperar)
--   t= 0.016s  Sessão A (pid 1728)  COMMIT  =>  OK
--   t= 0.016s  Sessão B (pid 1729)  COMMIT  =>  OK
--   t= 0.016s  Sessão OBS(pid 1727)  SELECT estado -> (codigo, capacidade, matriculados, excedeu)  =>  [('CONC-ANOM', 3, 4, True)]
   Interpretação: ambas as sessões leram vagas=1 (passos 3-4), o INSERT de B concluiu
   em ~1 ms sem esperar, e o estado final tem 4 matrículas (excedeu = True).

   VARIANTE 5b — MESMO aluno nas duas sessões (papel do UNIQUE, NÃO removido):
   Se A e B tentarem matricular 'conc_a' na mesma turma, o INSERT de B ESPERA a
   transação de A (lock em transactionid, para saber se a chave será confirmada) e,
   após o COMMIT de A, falha com SQLSTATE 23505. O UNIQUE protege contra DUPLICIDADE,
   não contra EXCESSO DE CAPACIDADE.
-- RESULTADO OBSERVADO (execução real; saída resumida do driver, PostgreSQL 16.15):
--   t= 0.020s  === EXP 1b: MESMO ALUNO nas duas sessões (papel do UNIQUE) ===
--   t= 0.024s  Sessão A (pid 1731)  BEGIN  =>  OK
--   t= 0.024s  Sessão B (pid 1732)  BEGIN  =>  OK
--   t= 0.025s  Sessão A (pid 1731)  INSERT matricula [aluno a, CONC-ANOM]  =>  OK
--   t= 0.078s  Observadora: Sessão B -> wait_event_type=Lock, wait_event=transactionid
--   t= 0.079s  Sessão A (pid 1731)  COMMIT  =>  OK
--   t= 0.079s  Sessão B (pid 1732)  INSERT matricula [aluno a, CONC-ANOM]  =>  ERRO SQLSTATE 23505: duplicate key value violates unique constraint "uq_matricula_aluno_turma"
--   t= 0.079s  Sessão B (pid 1732)  ROLLBACK  =>  OK
--   t= 0.079s  Sessão OBS(pid 1727)  SELECT estado -> (codigo, capacidade, matriculados, excedeu)  =>  [('CONC-ANOM', 3, 3, False)]

   Complemento — 8 sessões simultâneas disputando 1 vaga, sem controle (driver, 10 rodadas,
   largada sincronizada por barreira):
--   anom  sobrelotadas=10/10  contagem_final=[10]  matriculados=80  turma_cheia=0  desistencias=0  erros_40001=0  erros_40P01=0  tentativas_totais=80
   (Quantidade exata varia entre execuções, pois depende do escalonamento: em outra
   execução do mesmo teste, uma sessão chegou depois e viu 'turma cheia'. Em todas as
   rodadas de todas as execuções a turma ficou acima de 3.)
   ============================================================================= */


/* =============================================================================
   6. INSTRUÇÕES PARA EXECUÇÃO CONCORRENTE EM DUAS SESSÕES
   =============================================================================
   * Terminal 1 = Sessão A; Terminal 2 = Sessão B:  psql -X -d <seu_banco>
   * Opcional, Terminal 3 = Sessão C (observadora), para ver bloqueios:
       SELECT pid, application_name, wait_event_type, wait_event, state, pg_blocking_pids(pid) AS bloqueada_por
         FROM pg_stat_activity WHERE datname = current_database() AND pid <> pg_backend_pid();
   * Cada experimento usa uma turma própria (CONC-ANOM / CONC-LOCK / CONC-SER): NÃO
     misture os passos de experimentos diferentes na mesma transação/sessão aberta.
   * "esperado" = comportamento previsto pela documentação do PostgreSQL;
     "OBSERVADO" = efetivamente medido em execução real (blocos marcados assim).
   * Execute cada passo numerado SOMENTE depois de o anterior retornar, exceto os
     marcados "(BLOQUEIA)": este comando fica sem retorno até que a outra sessão
     confirme; execute o passo seguinte na OUTRA janela.
   * Antes de repetir um experimento, execute o seu passo [0] (reset) e dê COMMIT/ROLLBACK
     em sessões ainda abertas.
   ============================================================================= */


/* =============================================================================
   7. CORREÇÃO 1 — BLOQUEIO EXPLÍCITO (SELECT ... FOR UPDATE)
   =============================================================================
   Turma CONC-LOCK (capacidade 3, matriculados 2).

   REGISTRO BLOQUEADO: a linha de turma_capacidade da turma disputada
   (FOR UPDATE OF c). É o recurso cuja decisão é compartilhada: toda matrícula na
   turma precisa antes obter este lock; matrículas em OUTRAS turmas não são afetadas.
   Por que não bloquear a linha de turma? (a) o INSERT em matricula adquire
   FOR KEY SHARE na linha de turma (checagem da FK) — um FOR UPDATE em turma entraria
   em conflito com matrículas legítimas e com outros usos de turma; (b) usaríamos a
   linha errada para "capacidade". Alternativa válida: FOR NO KEY UPDATE em turma
   (não conflita com KEY SHARE), mas serializaria também outras alterações de turma.
   Também NÃO se bloqueiam as linhas de matricula (não resolveria: o problema é a
   linha que AINDA NÃO EXISTE — FOR UPDATE não bloqueia "fantasmas").

   QUANDO O LOCK É ADQUIRIDO: ao retornar o SELECT ... FOR UPDATE (passo 2).
   QUANDO É LIBERADO: no COMMIT ou ROLLBACK da transação (passo 6/7); locks de linha
   não são liberados antes do fim da transação.
   SEGUNDA TRANSAÇÃO: o FOR UPDATE de B fica em espera (wait_event_type=Lock) até A
   terminar. Em READ COMMITTED, ao ser liberada, B relê a linha bloqueada e, como a
   contagem (comando SEGUINTE, snapshot novo) já enxerga a matrícula confirmada de A,
   B vê vagas = 0 e desiste. A leitura de disponibilidade DEVE ser feita DEPOIS do lock.
   POR QUE IMPEDE O EXCESSO: o par "ler vagas + inserir" passa a ser uma seção crítica
   por turma: nunca há duas transações entre o lock e o COMMIT.
   LIMITAÇÕES: (1) só protege quem seguir o protocolo (toda inserção em matricula para a
   turma deve passar pelo lock; uma aplicação que insira direto não é impedida — a
   garantia estrutural exigiria um TRIGGER em matricula, que alteraria o modelo e não foi
   criado sem autorização); (2) cria fila: o tempo de espera de B ≈ tempo que A segura
   o lock; (3) locks em ordem inconsistente entre duas turmas causam deadlock (seção 12).

--   [0] reset:
--     DELETE FROM matricula WHERE id_turma = (SELECT id_turma FROM turma WHERE codigo = 'CONC-LOCK')
--        AND id_aluno NOT IN (SELECT id_aluno FROM aluno WHERE email LIKE 'conc\_f%@conc.invalid');
--   [1] Sessão A:
--     BEGIN;
--   [2] Sessão A:   adquire o lock; retorna 1 linha imediatamente
--     SELECT c.id_turma FROM turma_capacidade c JOIN turma t ON t.id_turma = c.id_turma
--      WHERE t.codigo = 'CONC-LOCK' FOR UPDATE OF c;
--   [3] Sessão A:   esperado: (3, 2, 1)
--     SELECT c.capacidade, count(m.id_matricula) AS matriculados,
--            c.capacidade - count(m.id_matricula) AS vagas
--       FROM turma_capacidade c JOIN turma t ON t.id_turma = c.id_turma
--       LEFT JOIN matricula m ON m.id_turma = c.id_turma
--      WHERE t.codigo = 'CONC-LOCK' GROUP BY c.capacidade;
--   [4] Sessão B:
--     BEGIN;
--   [5] Sessão B:   (BLOQUEIA) fica aguardando A  <-- PONTO DE SINCRONIZAÇÃO; veja a Sessão C
--     SELECT c.id_turma FROM turma_capacidade c JOIN turma t ON t.id_turma = c.id_turma
--      WHERE t.codigo = 'CONC-LOCK' FOR UPDATE OF c;
--   [6] Sessão A:   (na janela de A, enquanto B aguarda)
--     INSERT INTO matricula (id_aluno, id_turma, data_matricula, status)
--     SELECT a.id_aluno, t.id_turma, CURRENT_DATE, 'CONFIRMADA'
--       FROM aluno a, turma t WHERE a.email = 'conc_a@conc.invalid' AND t.codigo = 'CONC-LOCK';
--   [7] Sessão A:   libera o lock -> o passo 5 de B retorna
--     COMMIT;
--   [8] Sessão B:   comando NOVO, depois do lock; esperado: (3, 3, 0)
--     SELECT c.capacidade, count(m.id_matricula) AS matriculados,
--            c.capacidade - count(m.id_matricula) AS vagas
--       FROM turma_capacidade c JOIN turma t ON t.id_turma = c.id_turma
--       LEFT JOIN matricula m ON m.id_turma = c.id_turma
--      WHERE t.codigo = 'CONC-LOCK' GROUP BY c.capacidade;
--   [9] Sessão B: vagas = 0 -> a aplicação NÃO insere; encerra:
--     ROLLBACK;
--   [10] qualquer sessão:   esperado: matriculados = 3, excedeu = f
--     SELECT t.codigo, c.capacidade, count(m.id_matricula) AS matriculados,
--            count(m.id_matricula) > c.capacidade AS excedeu
--       FROM turma t JOIN turma_capacidade c ON c.id_turma = t.id_turma
--       LEFT JOIN matricula m ON m.id_turma = t.id_turma
--      WHERE t.codigo = 'CONC-LOCK' GROUP BY t.codigo, c.capacidade;

   RESULTADO ESPERADO: 3 matrículas; B desiste por "turma cheia" (resultado de negócio,
   não erro SQL). Nenhuma retentativa necessária — a concorrência foi resolvida por espera.
-- RESULTADO OBSERVADO (execução real; saída resumida do driver, PostgreSQL 16.15):
--   t= 0.084s  === EXP 2: BLOQUEIO EXPLICITO (SELECT ... FOR UPDATE OF turma_capacidade) ===
--   t= 0.085s  Sessão OBS(pid 1727)  SELECT estado -> (codigo, capacidade, matriculados, excedeu)  =>  [('CONC-LOCK', 3, 2, False)]
--   t= 0.089s  Sessão A (pid 1734)  BEGIN  =>  OK
--   t= 0.090s  Sessão A (pid 1734)  SELECT ... FOR UPDATE OF c  [CONC-LOCK]  =>  [(2,)]
--   t= 0.090s  Sessão A (pid 1734)  SELECT vagas  -> (capacidade, matriculados, vagas)  =>  [(3, 2, 1)]
--   t= 0.090s  Sessão B (pid 1735)  BEGIN  =>  OK
--   t= 0.092s  Observadora: Sessão B -> wait_event_type=Lock, wait_event=transactionid; bloqueada por pid [1734] (Sessão A pid 1734)
--   t= 0.092s  Sessão A: segura o lock por 1,5 s (simula processamento) antes de inserir e confirmar
--   t= 1.593s  Sessão A (pid 1734)  INSERT matricula [aluno a, CONC-LOCK]  =>  OK
--   t= 1.594s  Sessão A (pid 1734)  COMMIT  =>  OK
--   t= 1.594s  Sessão B (pid 1735)  SELECT ... FOR UPDATE OF c  [CONC-LOCK]  =>  [(2,)]
--   t= 1.594s  Sessão B ficou bloqueada ~1.50s no FOR UPDATE e só obteve o lock após o COMMIT de A
--   t= 1.595s  Sessão B (pid 1735)  SELECT vagas  -> (capacidade, matriculados, vagas)  =>  [(3, 3, 0)]
--   t= 1.595s  Sessão B (aplicação): vagas = 0 -> turma cheia; não insere
--   t= 1.595s  Sessão B (pid 1735)  ROLLBACK  =>  OK
--   t= 1.595s  Sessão OBS(pid 1727)  SELECT estado -> (codigo, capacidade, matriculados, excedeu)  =>  [('CONC-LOCK', 3, 3, False)]
   Interpretação: B ficou em espera por Lock (bloqueada pelo pid de A) por ~1,5 s, que é
   exatamente o tempo em que A segurou o lock; ao liberar, B viu vagas=0.
   Observação: wait_event=transactionid é o wait normal de quem espera uma linha
   bloqueada por outra transação.

   Complemento — 8 sessões simultâneas disputando 1 vaga com este protocolo:
--   lock  sobrelotadas=0/10  contagem_final=[3]  matriculados=10  turma_cheia=70  desistencias=0  erros_40001=0  erros_40P01=0  tentativas_totais=80
   ============================================================================= */


/* =============================================================================
   8. TESTE CONCORRENTE DA PRIMEIRA CORREÇÃO
   =============================================================================
   O teste concorrente da correção 1 é o roteiro numerado da seção 7 (Sessões A e B,
   resultado esperado e observado ali). Verificação final: seção 11.
   ============================================================================= */


/* =============================================================================
   9. CORREÇÃO 2 — ISOLAMENTO SERIALIZABLE (SSI)
   =============================================================================
   Turma CONC-SER (capacidade 3, matriculados 2). NÃO há FOR UPDATE nem lock explícito:
   a mesma lógica "ler vagas -> decidir -> inserir" roda em SERIALIZABLE.

   COMO O POSTGRESQL FAZ (Serializable Snapshot Isolation):
   * Cada transação trabalha com um snapshot (como REPEATABLE READ) e NÃO bloqueia
     leitores/escritores por causa de leituras.
   * Leituras registram "predicate locks" (SIREAD) — locks que não bloqueiam ninguém,
     apenas registram o que foi lido (aqui: a leitura de matricula da turma).
   * Quando uma transação escreve algo que outra já leu (ou lê algo que outra escreveu
     depois do seu snapshot), cria-se uma dependência rw-antidependência (rw-conflict).
   * Se o grafo de dependências forma uma "estrutura perigosa" (ciclo A->B e B->A:
     write skew, exatamente o caso das duas leituras de vaga=1), o PostgreSQL ABORTA uma
     das transações com SQLSTATE 40001 (serialization_failure) — no INSERT ou, como
     observado abaixo, no COMMIT. Não é espera por lock: é DETECÇÃO + ABORTO.
   * A transação sobrevivente confirma normalmente. A abortada deve ser REEXECUTADA
     INTEIRA (nova transação, relendo as vagas): ao reler, vê vagas = 0 e recusa.
   * SSI pode gerar FALSOS POSITIVOS (abortos desnecessários), p.ex. por granularidade
     de predicate lock (página/relação) em planos com varredura sequencial. Por isso a
     aplicação precisa estar preparada para 40001 mesmo quando a operação "poderia"
     ter funcionado. SERIALIZABLE NÃO garante sucesso de todas as transações.
   * Diferenciar: bloqueio explícito = espera; SSI = detecção de conflito; aborto =
     ROLLBACK forçado pelo servidor; retentativa = responsabilidade da aplicação.

   ORDEM DE EXECUÇÃO (duas janelas; SET TRANSACTION deve ser a PRIMEIRA instrução da
   transação — aqui usamos BEGIN ISOLATION LEVEL SERIALIZABLE, equivalente):

--   [0] reset:
--     DELETE FROM matricula WHERE id_turma = (SELECT id_turma FROM turma WHERE codigo = 'CONC-SER')
--        AND id_aluno NOT IN (SELECT id_aluno FROM aluno WHERE email LIKE 'conc\_f%@conc.invalid');
--   [1] Sessão A:
--     BEGIN ISOLATION LEVEL SERIALIZABLE;
--   [2] Sessão B:
--     BEGIN ISOLATION LEVEL SERIALIZABLE;
--   [3] Sessão A:   esperado: (3, 2, 1)
--     SELECT c.capacidade, count(m.id_matricula) AS matriculados,
--            c.capacidade - count(m.id_matricula) AS vagas
--       FROM turma_capacidade c JOIN turma t ON t.id_turma = c.id_turma
--       LEFT JOIN matricula m ON m.id_turma = c.id_turma
--      WHERE t.codigo = 'CONC-SER' GROUP BY c.capacidade;
--   [4] Sessão B:   esperado: (3, 2, 1)   <-- PONTO DE SINCRONIZAÇÃO
--     SELECT c.capacidade, count(m.id_matricula) AS matriculados,
--            c.capacidade - count(m.id_matricula) AS vagas
--       FROM turma_capacidade c JOIN turma t ON t.id_turma = c.id_turma
--       LEFT JOIN matricula m ON m.id_turma = c.id_turma
--      WHERE t.codigo = 'CONC-SER' GROUP BY c.capacidade;
--   [5] Sessão A:   esperado: INSERT 0 1
--     INSERT INTO matricula (id_aluno, id_turma, data_matricula, status)
--     SELECT a.id_aluno, t.id_turma, CURRENT_DATE, 'CONFIRMADA'
--       FROM aluno a, turma t WHERE a.email = 'conc_a@conc.invalid' AND t.codigo = 'CONC-SER';
--   [6] Sessão B:   esperado: INSERT 0 1 (sem espera) — OU já 40001 aqui
--     INSERT INTO matricula (id_aluno, id_turma, data_matricula, status)
--     SELECT a.id_aluno, t.id_turma, CURRENT_DATE, 'CONFIRMADA'
--       FROM aluno a, turma t WHERE a.email = 'conc_b@conc.invalid' AND t.codigo = 'CONC-SER';
--   [7] Sessão A:   esperado: COMMIT (o primeiro a confirmar costuma vencer)
--     COMMIT;
--   [8] Sessão B:   esperado: ERROR 40001 (ou o erro já ocorreu no passo 6)
--     COMMIT;
--   [9] Se B recebeu 40001: a transação está abortada. Encerrar e RETENTAR TUDO:
--     ROLLBACK;
--   [10] Sessão B:   NOVA transação (retentativa)
--     BEGIN ISOLATION LEVEL SERIALIZABLE;
--   [11] Sessão B:   releitura; esperado: (3, 3, 0)
--     SELECT c.capacidade, count(m.id_matricula) AS matriculados,
--            c.capacidade - count(m.id_matricula) AS vagas
--       FROM turma_capacidade c JOIN turma t ON t.id_turma = c.id_turma
--       LEFT JOIN matricula m ON m.id_turma = c.id_turma
--      WHERE t.codigo = 'CONC-SER' GROUP BY c.capacidade;
--   [12] Sessão B: vagas = 0 -> a aplicação NÃO insere:
--     ROLLBACK;
--   [13] qualquer sessão:   esperado: matriculados = 3, excedeu = f
--     SELECT t.codigo, c.capacidade, count(m.id_matricula) AS matriculados,
--            count(m.id_matricula) > c.capacidade AS excedeu
--       FROM turma t JOIN turma_capacidade c ON c.id_turma = t.id_turma
--       LEFT JOIN matricula m ON m.id_turma = t.id_turma
--      WHERE t.codigo = 'CONC-SER' GROUP BY t.codigo, c.capacidade;

   RESULTADO ESPERADO: 3 matrículas; uma transação abortada por 40001; após retentativa,
   "turma cheia". (Qual transação perde e em qual comando falha pode variar; o
   invariante — no máximo 3 matrículas — não varia.)
-- RESULTADO OBSERVADO (execução real; saída resumida do driver, PostgreSQL 16.15):
--   t= 1.599s  === EXP 3: SERIALIZABLE ===
--   t= 1.600s  Sessão OBS(pid 1727)  SELECT estado -> (codigo, capacidade, matriculados, excedeu)  =>  [('CONC-SER', 3, 2, False)]
--   t= 1.604s  Sessão A (pid 1737)  BEGIN ISOLATION LEVEL SERIALIZABLE  =>  OK
--   t= 1.604s  Sessão B (pid 1738)  BEGIN ISOLATION LEVEL SERIALIZABLE  =>  OK
--   t= 1.605s  Sessão A (pid 1737)  SELECT vagas  -> (capacidade, matriculados, vagas)  =>  [(3, 2, 1)]
--   t= 1.607s  Sessão B (pid 1738)  SELECT vagas  -> (capacidade, matriculados, vagas)  =>  [(3, 2, 1)]
--   t= 1.607s  Sessão A (pid 1737)  INSERT matricula [aluno a, CONC-SER]  =>  OK
--   t= 1.608s  Sessão B (pid 1738)  INSERT matricula [aluno b, CONC-SER]  =>  OK
--   t= 1.608s  Sessão A (pid 1737)  COMMIT  =>  OK
--   t= 1.608s  Sessão B (pid 1738)  COMMIT  =>  ERRO SQLSTATE 40001: could not serialize access due to read/write dependencies among transactions
--   t= 1.609s  Sessão OBS(pid 1727)  SELECT estado -> (codigo, capacidade, matriculados, excedeu)  =>  [('CONC-SER', 3, 3, False)]
--   t= 1.609s  Perdedora (40001): B
--   t= 1.609s  --- RETENTATIVA da Sessão B: NOVA transação, repetindo leitura + decisão ---
--   t= 1.609s  Sessão B (pid 1738)  BEGIN ISOLATION LEVEL SERIALIZABLE  =>  OK
--   t= 1.609s  Sessão B (pid 1738)  SELECT vagas  -> (capacidade, matriculados, vagas)  =>  [(3, 3, 0)]
--   t= 1.609s  Sessão B (aplicação): vagas = 0 -> turma cheia; não insere
--   t= 1.609s  Sessão B (pid 1738)  ROLLBACK  =>  OK
--   t= 1.610s  Sessão OBS(pid 1727)  SELECT estado -> (codigo, capacidade, matriculados, excedeu)  =>  [('CONC-SER', 3, 3, False)]
   Interpretação: o INSERT de B não esperou e retornou OK; o COMMIT de A teve sucesso e
   o COMMIT de B foi abortado com 40001 (read/write dependencies). Na retentativa B leu
   vagas=0 e recusou. Em 3 execuções adicionais a perdedora foi sempre B (no COMMIT).

   Complemento — 8 sessões simultâneas disputando 1 vaga, com retentativa (máx. 6
   tentativas, backoff exponencial 50 ms * 2^n com jitter; ver seção 12):
--   ser   sobrelotadas=0/10  contagem_final=[3]  matriculados=10  turma_cheia=70  desistencias=0  erros_40001=70  erros_40P01=0  tentativas_totais=150
   Leitura: 7 das 8 sessões receberam 40001 na 1ª tentativa em cada rodada, retentaram,
   viram 'turma cheia'; ninguém desistiu por limite de tentativas. A contagem final foi
   sempre 3. Isso é um comportamento observado neste ambiente (1 vCPU, 8 sessões, tabela
   minúscula), NÃO uma garantia: com outro plano/volume/granularidade o número de
   abortos muda.
   ============================================================================= */


/* =============================================================================
   10. TESTE CONCORRENTE DA SEGUNDA CORREÇÃO
   =============================================================================
   O teste concorrente da correção 2 é o roteiro numerado da seção 9 (Sessões A e B,
   resultado esperado e observado ali). Verificação final: seção 11.
   ============================================================================= */


/* =============================================================================
   11. CONSULTAS DE VERIFICAÇÃO DA INTEGRIDADE   (executáveis a qualquer momento)
   ============================================================================= */
-- 11.1 Matrículas por turma x capacidade (todas as turmas com capacidade cadastrada)
SELECT t.codigo, c.capacidade, count(m.id_matricula) AS matriculados,
       c.capacidade - count(m.id_matricula) AS vagas,
       count(m.id_matricula) > c.capacidade AS excedeu
  FROM turma t JOIN turma_capacidade c ON c.id_turma = t.id_turma
  LEFT JOIN matricula m ON m.id_turma = t.id_turma
 GROUP BY t.codigo, c.capacidade ORDER BY t.codigo;

-- 11.2 Turmas com matrículas excedentes (esperado após as correções: nenhuma linha;
--      após o experimento 5 SEM controle: CONC-ANOM aparece)
SELECT t.codigo, c.capacidade, count(*) AS matriculados
  FROM turma t JOIN turma_capacidade c ON c.id_turma = t.id_turma
  JOIN matricula m ON m.id_turma = t.id_turma
 GROUP BY t.codigo, c.capacidade HAVING count(*) > c.capacidade;

-- 11.3 Duplicidade de matrícula (esperado: nenhuma; garantida pelo UNIQUE do marco01)
SELECT id_aluno, id_turma, count(*) FROM matricula GROUP BY 1, 2 HAVING count(*) > 1;

-- 11.4 Matrículas órfãs (esperado: nenhuma; garantidas pelas FKs do marco01)
SELECT m.id_matricula FROM matricula m
  LEFT JOIN aluno a ON a.id_aluno = m.id_aluno LEFT JOIN turma t ON t.id_turma = m.id_turma
 WHERE a.id_aluno IS NULL OR t.id_turma IS NULL;

-- 11.5 Transações abertas/esquecidas (esperado: nenhuma além desta sessão)
SELECT pid, state, xact_start, left(query, 60) AS ultima_query
  FROM pg_stat_activity
 WHERE datname = current_database() AND pid <> pg_backend_pid() AND state LIKE 'idle in transaction%';

-- RESULTADO OBSERVADO (11.1 a 11.5 executadas ao final da execução real, após o último reset do driver):
--   CONC-ANOM 3|2|1|f ; CONC-DL1 3|0|3|f ; CONC-DL2 3|0|3|f ; CONC-LOCK 3|2|1|f ; CONC-SER 3|2|1|f
--   11.2, 11.3, 11.4 e 11.5: nenhuma linha.
--   Estado imediatamente APÓS cada experimento (seções 5, 7 e 9): ANOM = 4 (excedeu = True);
--   LOCK = 3 (excedeu = False); SER = 3 (excedeu = False).


/* =============================================================================
   12. TRATAMENTO DE ERROS E RETENTATIVAS
   =============================================================================
   SQLSTATEs relevantes:
   * 40001 serialization_failure  -> ROLLBACK + reexecutar a OPERAÇÃO COMPLETA.
   * 40P01 deadlock_detected      -> ROLLBACK + reexecutar a OPERAÇÃO COMPLETA.
   * 23505 unique_violation       -> erro de NEGÓCIO (aluno já matriculado): NÃO retentar.
   Regras:
   * Retentativa = NOVA transação repetindo TODAS as leituras e decisões; repetir só o
     comando que falhou é incorreto (a decisão "vagas > 0" estava baseada em dado velho).
   * A transação abortada fica inutilizável até o ROLLBACK ("current transaction is aborted").
   * Limite de tentativas + backoff exponencial com jitter; nunca laço infinito.
   * Retentativa não pode ser feita DENTRO de uma função PL/pgSQL com bloco EXCEPTION:
     o subtransação reutiliza o mesmo snapshot SERIALIZABLE; a retentativa deve ser no
     cliente (ou procedure com COMMIT próprio), reiniciando a transação.
   * Com bloqueio explícito a concorrência normalmente se resolve por ESPERA (sem 40001),
     mas 40P01 ainda é possível (ver abaixo), além de lock_timeout/statement_timeout se
     configurados e de falhas de conexão. Recomenda-se SET LOCAL lock_timeout para não
     esperar indefinidamente.
   * SERIALIZABLE exige tratamento de 40001 SEMPRE: não elimina erros, apenas troca
     "resultado errado silencioso" por "erro explícito".

   PSEUDOCÓDIGO (cliente):
       MAX = 5; base = 50 ms
       for tentativa in 1..MAX:
           try:
               BEGIN [ISOLATION LEVEL SERIALIZABLE]        -- ou BEGIN + FOR UPDATE (correção 1)
               [SELECT ... FOR UPDATE OF c]                -- só na correção 1
               vagas = SELECT capacidade - count(*) ...    -- SEMPRE depois do lock
               if vagas <= 0: ROLLBACK; return TURMA_CHEIA
               INSERT matricula ...
               COMMIT; return MATRICULADO
           except SQLSTATE in ('40001','40P01'):
               ROLLBACK
               dormir( base * 2^(tentativa-1) * (0.5 + aleatorio()) )   -- backoff + jitter
           except outro erro: ROLLBACK; propagar
       return FALHOU_APOS_MAX_TENTATIVAS      -- a aplicação decide (informar usuário/fila)

   Implementação real executada (driver Python/psycopg2, função worker): mesma lógica,
   MAX=6, backoff min(0,05*2^(n-1), 0,8) s * (0,5 + aleatório). Resultados nas seções 5, 7 e 9.

   --- DEMONSTRAÇÃO DE DEADLOCK (40P01) com a correção 1 ---
   Uma operação que matricule o mesmo contexto em DUAS turmas trava duas linhas de
   turma_capacidade. Se duas transações travarem em ordem inversa: deadlock. O PostgreSQL
   detecta após deadlock_timeout (padrão 1 s) e aborta UMA delas com 40P01.

--   [1] Sessão A: BEGIN
--   [2] Sessão B: BEGIN
--   [3] Sessão A:
--     SELECT c.id_turma FROM turma_capacidade c JOIN turma t ON t.id_turma = c.id_turma
--      WHERE t.codigo = 'CONC-DL1' FOR UPDATE OF c;
--   [4] Sessão B:
--     SELECT c.id_turma FROM turma_capacidade c JOIN turma t ON t.id_turma = c.id_turma
--      WHERE t.codigo = 'CONC-DL2' FOR UPDATE OF c;
--   [5] Sessão A:   (BLOQUEIA) espera B
--     SELECT c.id_turma FROM turma_capacidade c JOIN turma t ON t.id_turma = c.id_turma
--      WHERE t.codigo = 'CONC-DL2' FOR UPDATE OF c;
--   [6] Sessão B:   (BLOQUEIA) espera A -> ciclo; após ~1 s uma recebe 40P01
--     SELECT c.id_turma FROM turma_capacidade c JOIN turma t ON t.id_turma = c.id_turma
--      WHERE t.codigo = 'CONC-DL1' FOR UPDATE OF c;
--   [7] a vítima executa ROLLBACK e RETENTA a operação inteira; a outra segue.
-- RESULTADO OBSERVADO (execução real; saída resumida do driver, PostgreSQL 16.15):
--   t= 1.610s  === EXP 4: DEADLOCK (40P01) com FOR UPDATE em ordem inconsistente ===
--   t= 1.616s  Sessão A (pid 1739)  BEGIN  =>  OK
--   t= 1.616s  Sessão B (pid 1740)  BEGIN  =>  OK
--   t= 1.617s  Sessão A (pid 1739)  SELECT ... FOR UPDATE OF c  [CONC-DL1]  =>  [(1,)]
--   t= 1.618s  Sessão B (pid 1740)  SELECT ... FOR UPDATE OF c  [CONC-DL2]  =>  [(4,)]
--   t= 2.618s  Sessão A (pid 1739)  SELECT ... FOR UPDATE OF c  [CONC-DL2]  =>  ERRO SQLSTATE 40P01: deadlock detected
--   t= 2.619s  Sessão B (pid 1740)  SELECT ... FOR UPDATE OF c  [CONC-DL1]  =>  [(1,)]
--   t= 2.619s  Resultados: A=erro ('40P01', 'deadlock detected'); B=ok None
--   t= 2.619s  Sessão A (pid 1739)  ROLLBACK  =>  OK
--   t= 2.620s  Sessão B (pid 1740)  COMMIT  =>  OK
--   t= 2.620s  --- MITIGAÇÃO: ordem canônica (menor codigo/id primeiro) em ambas ---
--   t= 2.627s  Sessão A (pid 1743)  BEGIN  =>  OK
--   t= 2.627s  Sessão B (pid 1744)  BEGIN  =>  OK
--   t= 2.629s  Sessão A (pid 1743)  SELECT ... FOR UPDATE OF c  [CONC-DL1]  =>  [(1,)]
--   t= 2.682s  Observadora: Sessão B -> wait_event_type=Lock
--   t= 2.682s  Sessão A (pid 1743)  SELECT ... FOR UPDATE OF c  [CONC-DL2]  =>  [(4,)]
--   t= 2.683s  Sessão B (pid 1744)  SELECT ... FOR UPDATE OF c  [CONC-DL1]  =>  [(1,)]
--   t= 2.683s  Sessão A (pid 1743)  COMMIT  =>  OK
--   t= 2.683s  Sessão B (pid 1744)  SELECT ... FOR UPDATE OF c  [CONC-DL2]  =>  [(4,)]
--   t= 2.683s  Sessão B (pid 1744)  COMMIT  =>  OK
   MITIGAÇÃO: adquirir os locks SEMPRE em ordem canônica (ex.: menor id_turma primeiro).
   Observado: com ordem igual nas duas sessões, B apenas espera por A e não há deadlock
   (linhas "MITIGAÇÃO" acima).
   ============================================================================= */


/* =============================================================================
   13. COMPARAÇÃO TÉCNICA DAS ABORDAGENS
   =============================================================================
   Legenda: [T] = característica teórica/documentada do mecanismo;
            [O] = observado nos experimentos deste arquivo (ambiente descrito no cabeçalho);
            [A] = depende de ambiente/carga (não medido aqui).

   | Critério                  | Bloqueio explícito (FOR UPDATE)                          | SERIALIZABLE (SSI)                                              |
   |---------------------------|----------------------------------------------------------|-----------------------------------------------------------------|
   | Mecanismo de proteção     | [T] Lock de linha em turma_capacidade cria seção crítica | [T] Snapshot + predicate locks (SIREAD) + detecção de ciclos rw |
   | Garantia de integridade   | [T] Só vale para quem segue o protocolo de lock          | [T] Vale para toda transação SERIALIZABLE, sem escolher o recurso|
   | Comportamento concorrente | [O] B esperou ~1,5 s e depois viu vagas=0                | [O] A e B executaram em paralelo; B abortada com 40001 no COMMIT|
   | Contenção                 | [T] Fila por turma; só a turma disputada é serializada   | [T] Sem filas por leitura; contenção vira abortos/retrabalho    |
   | Espera por bloqueios      | [O] Sim: wait_event_type=Lock até o COMMIT de A          | [O] Não houve espera por lock neste cenário                     |
   | Possibilidade de aborto   | [T] Baixa; 40P01 se ordem de locks inconsistente [O]     | [T] Inerente: 40001 pode ocorrer, inclusive falso positivo [T]  |
   | Necessidade de retentativa| [T] Só para 40P01/timeouts; normalmente nenhuma [O]      | [T] Obrigatória para 40001 [O] 70 retentativas em 80 operações* |
   | Custo operacional         | [T] Lock de linha (barato) + espera; risco de segurar   | [T] Memória/CPU para predicate locks e grafo de conflitos;      |
   |                           |     lock durante processamento longo [A]                 |     retrabalho das transações abortadas [A]                     |
   | Escalabilidade            | [T] Boa se o lock for por turma e curto; ruim em "hot   | [T] Boa com pouco conflito; piora com muitos conflitos          |
   |                           |     row" (todos na mesma turma) [A]                      |     (abortos em cascata) e com limites de predicate locks [A]   |
   | Complexidade              | [T] Média: exige lock antes de ler, ordem canônica,      | [T] Baixa na SQL, mas exige laço de retentativa em TODA         |
   |                           |     lock_timeout                                          |     operação e idempotência da lógica de negócio                |
   | Cenários mais adequados   | Recurso disputado bem identificável (aqui: a turma);     | Invariantes que envolvem várias linhas/predicados difíceis de   |
   |                           | operações curtas; desejo de evitar abortos               | travar; baixa/média contenção; equipe que aceita retentativas   |

   * [O] Nas 8 sessões x 10 rodadas: 80 operações, 70 receberam 40001 e foram retentadas
     (todas terminaram em 'turma cheia'); com FOR UPDATE: 0 erros, 0 retentativas, 70
     sessões viram 'turma cheia' (a espera individual não foi medida). Isso NÃO é medição de throughput/latência.

   NÃO há vencedor universal: FOR UPDATE troca ABORTOS por ESPERA e exige conhecer o
   recurso certo; SERIALIZABLE troca ESPERA por ABORTOS e exige retentativa, mas protege
   sem que o programador identifique o recurso. Em ambos: transações curtas e bem
   delimitadas, e tratamento de falhas (40001, 40P01, timeouts, desconexão).

   O que NÃO foi medido e depende do ambiente: throughput, latência, uso de memória do
   SSI, comportamento com milhares de sessões, efeito de índices/plano (varredura
   sequencial x índice altera a granularidade dos predicate locks e a taxa de falsos
   positivos), efeito de max_pred_locks_per_transaction, e fila sob lock prolongado.
   ============================================================================= */


/* =============================================================================
   14. LIMPEZA OPCIONAL DOS DADOS DE TESTE   (executável; só remove marcadores 'CONC')
   =============================================================================
   Não toca em nenhuma linha preexistente. Antes: feche as sessões A/B (COMMIT/ROLLBACK).
   Os valores já consumidos das sequências IDENTITY não são devolvidos (comportamento
   normal do PostgreSQL).
   ============================================================================= */
BEGIN;
DELETE FROM matricula
 WHERE id_turma IN (SELECT id_turma FROM turma WHERE codigo LIKE 'CONC-%');
DELETE FROM turma_capacidade
 WHERE id_turma IN (SELECT id_turma FROM turma WHERE codigo LIKE 'CONC-%');
DELETE FROM turma     WHERE codigo LIKE 'CONC-%';
DELETE FROM aluno     WHERE email LIKE 'conc\_%@conc.invalid';
DELETE FROM professor WHERE matricula = 'CONC-PROF';
DELETE FROM disciplina WHERE codigo = 'CONC-DISC';
DELETE FROM periodo_letivo WHERE ano = 9999 AND semestre = 1;
COMMIT;

-- Remoção da tabela auxiliar (estrutura criada por este arquivo; só a execute se
-- não pretende repetir o experimento). Mantida COMENTADA por segurança:
-- DROP TABLE turma_capacidade;

-- Verificação (esperado: 0 em todas)
SELECT (SELECT count(*) FROM turma WHERE codigo LIKE 'CONC-%')                        AS turmas_teste,
       (SELECT count(*) FROM aluno WHERE email LIKE 'conc\_%@conc.invalid')           AS alunos_teste,
       (SELECT count(*) FROM turma_capacidade)                                        AS capacidades;
