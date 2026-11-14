/*-------------------------------------------------------------------------------------------------------------------------
Disciplina: Banco de Dados I
Autor....: Prof. Rodrigo Gonçalves Pinto
Objetivo..: Stored Procedures, Views e Triggers
Bimestre.: 2 Bimestre
Objeto....: Aula08_views_triggers_procedures.sql

Data Criação...................: 15/05/2023
Data Alteração................. : versão PostgreSQL 16
Alteração Feita: conversão do script de MySQL para PostgreSQL 16, mantendo a mesma sequência de aula.
                 O banco sakila foi substituído pelo banco db_biblioteca.
--------------------------------------------------------------------------------------------------------------------------
Banco de dados: db_biblioteca
Versão 1.0

COMO RODAR ESTA AULA: um bloco de cada vez, selecionando o trecho e executando.
Cada CREATE de function ou procedure vai do CREATE até o $$; final. Selecione TUDO isso junto.
Se selecionar só um pedaço, o PostgreSQL acusa erro de sintaxe.
*/

-- >>> TROQUE PARA O BANCO db_biblioteca no seletor do topo da janela <<<
-- a linha abaixo só funciona no psql. No DBeaver e no pgAdmin, deixe comentada.
-- \c db_biblioteca

SELECT current_database();
-- tem que responder: db_biblioteca. Se não respondeu, PARE e troque de banco.

-- PREPARAÇÃO) limpa o que ficou de uma execução anterior desta mesma aula.
-- Sem isto, cada vez que a aula roda, os idiomas de exemplo são cadastrados de novo e se acumulam.
DELETE FROM idioma WHERE nome IN ('Esperanto', 'Latim', 'Grego', 'Mandarim');
-- na primeira vez o banco responde DELETE 0: não havia nada para apagar. Está certo.


/*------------------------------------------------------
VIEWS - VISUALIZAÇÕES
CRIAÇÃO
--------------------------------------------------------*/
/*
 Views são tabelas virtuais baseadas no resultado de uma consulta SQL.
 Elas não armazenam dados fisicamente,
 mas sim uma definição de consulta que pode ser usada como se fosse uma tabela.
*/

-- Criando uma View.
CREATE OR REPLACE VIEW vw_idiomas
AS
   SELECT id_idioma, nome
    FROM idioma;

-- consultando uma view;
SELECT * FROM vw_idiomas;
-- resultado esperado: os 6 idiomas (Português, Inglês, Espanhol, Francês, Alemão e Italiano).
-- repare: a view é consultada EXATAMENTE como uma tabela. Quem consulta nem sabe que é uma view.

-- OBS) o CREATE OR REPLACE VIEW substitui a view se ela já existir. No MySQL era a mesma ideia.
-- A regra do PostgreSQL é mais rígida: o REPLACE só aceita se as colunas antigas continuarem
-- existindo, com os mesmos nomes e tipos. Você pode ACRESCENTAR coluna no fim, mas não pode
-- remover nem renomear. Para mudar isso, DROP VIEW e cria de novo.

-- uma view que vale a pena: junta obra, área e idioma, e esconde os JOINs de quem for consultar.
CREATE OR REPLACE VIEW vw_acervo
AS
SELECT O.id_obra,
       O.titulo,
       A.nome AS area_do_conhecimento,
       I.nome AS idioma,
       O.custo_reposicao,
       O.classificacao
  FROM obra O
  LEFT JOIN obra_area OA ON OA.id_obra  = O.id_obra
  LEFT JOIN area A       ON A.id_area   = OA.id_area
  LEFT JOIN idioma I     ON I.id_idioma = O.id_idioma;

-- agora a consulta do dia a dia fica assim, sem nenhum JOIN à vista:
SELECT * FROM vw_acervo WHERE area_do_conhecimento = 'Medicina' LIMIT 10;

-- dá até para agrupar em cima da view, como numa tabela comum:
SELECT area_do_conhecimento, COUNT(*) AS quantidade
  FROM vw_acervo
 GROUP BY area_do_conhecimento
 ORDER BY quantidade DESC;
-- resultado esperado: as 16 áreas com 62 ou 63 obras cada, e uma linha com a área VAZIA (NULL)
-- para o MANUSCRITO SOLITARIO, que criamos sem área na Aula 07. É o LEFT JOIN da view trabalhando.

-- POR QUE USAR VIEW: quem consulta não precisa saber onde estão as tabelas nem como elas se ligam.
-- E o dia em que você mudar o desenho das tabelas, muda a view e ninguém mais precisa mudar nada.

-- OBS) o PostgreSQL tem também a MATERIALIZED VIEW, que NÃO existe no MySQL.
-- A view normal roda a consulta toda vez que alguém a chama. A materializada GRAVA o resultado
-- em disco e só atualiza quando você mandar. Serve para consulta pesada que muda pouco.
DROP MATERIALIZED VIEW IF EXISTS mvw_custo_por_area;

CREATE MATERIALIZED VIEW mvw_custo_por_area AS
SELECT A.nome                           AS area_do_conhecimento,
       COUNT(*)                         AS quantidade_obras,
       ROUND(AVG(O.custo_reposicao), 2) AS custo_medio
  FROM obra O
  JOIN obra_area OA ON OA.id_obra = O.id_obra
  JOIN area A       ON A.id_area  = OA.id_area
 GROUP BY A.nome;

SELECT * FROM mvw_custo_por_area ORDER BY custo_medio DESC;

-- para atualizar o conteúdo gravado:
REFRESH MATERIALIZED VIEW mvw_custo_por_area;


/*------------------------------------------------------
O DELIMITADOR: O QUE MUDA DO MYSQL PARA O POSTGRESQL
--------------------------------------------------------*/
-- No MySQL, para criar trigger, procedure ou function, a gente precisava trocar o delimitador:
--      DELIMITER //
--      CREATE PROCEDURE ... BEGIN ... END //
--      DELIMITER ;
-- O motivo era que o MySQL interpretava o ponto e vírgula de DENTRO do bloco como fim do comando,
-- e isso gerava o famoso ERRO 1064.

-- No PostgreSQL o problema é o mesmo, mas a solução é outra e é mais simples:
-- o corpo da rotina vai entre CIFRÃO CIFRÃO, assim:  $$ ... $$
-- Tudo que estiver entre os dois $$ é tratado como um texto único, e os pontos e vírgulas
-- de dentro não atrapalham ninguém. Isso se chama DOLLAR QUOTING.

-- Você também pode dar um nome ao delimitador, para casos em que o próprio corpo tenha $$:
--      $corpo$ ... $corpo$
-- É o mesmo papel do // do MySQL, só que sem precisar avisar o cliente antes e nem desfazer depois.


/*------------------------------------------------------
TRIGGERS - GATILHOS
CRIAÇÃO
--------------------------------------------------------*/
/*
Triggers são blocos de código que são automaticamente executados em resposta
a determinados eventos em uma tabela,
como inserções,
atualizações ou deleções.
Eles são úteis para manter a integridade dos dados e
implementar regras de negócios.
*/

-- DIFERENÇA IMPORTANTE: no MySQL a trigger era UM objeto só, com o código dentro dela.
-- No PostgreSQL são DOIS objetos:
--   1) uma FUNÇÃO que retorna o tipo especial "trigger", onde mora o código;
--   2) a TRIGGER propriamente dita, que diz QUANDO chamar aquela função.
-- Parece burocracia, e tem uma vantagem: a mesma função serve para várias tabelas.

-- MODELO PARA DECORAR. Toda função de trigger tem este esqueleto, só muda o miolo:
--
--      CREATE OR REPLACE FUNCTION nome_da_funcao()
--      RETURNS TRIGGER
--      LANGUAGE plpgsql
--      AS $$
--      BEGIN
--          ... o que fazer ...
--          RETURN NEW;
--      END;
--      $$;

-- [OBJETO 1] a função
CREATE OR REPLACE FUNCTION fn_valida_idioma()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- NEW é a linha que está entrando. Existe também OLD, a linha como estava antes.
    IF NEW.nome = '' OR NEW.nome IS NULL THEN
        -- no MySQL era: SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '...'
        -- no PostgreSQL é RAISE EXCEPTION. Bem mais legível.
        RAISE EXCEPTION 'nome da língua não pode ser vazio';
    END IF;

    -- em trigger BEFORE, devolver NEW significa "pode gravar esta linha".
    -- devolver NULL significaria "cancele a gravação, sem erro".
    RETURN NEW;
END;
$$;

-- [OBJETO 2] a trigger
DROP TRIGGER IF EXISTS trg_before_idioma_insert ON idioma;

CREATE TRIGGER trg_before_idioma_insert
  BEFORE INSERT ON idioma
FOR EACH ROW
EXECUTE FUNCTION fn_valida_idioma();

-- Testando a trigger
-- Tentando inserir uma linha com o campo 'nome' vazio.
-- ESTA LINHA DÁ ERRO DE PROPÓSITO. Leia a mensagem: é a nossa, escrita lá dentro do RAISE.
INSERT INTO idioma (nome) VALUES ('');

-- agora com um valor válido: passa normalmente.
INSERT INTO idioma (nome) VALUES ('Esperanto');
SELECT * FROM idioma;
-- resultado esperado (na primeira vez que você roda a aula):
-- 7 idiomas, e o Esperanto entrou com id_idioma = 8, e NÃO 7. Por quê?
-- O INSERT do texto vazio pegou o número 7 da sequence ANTES de a trigger barrar a linha.
-- A linha foi cancelada, mas o número já tinha sido gasto. A sequence nunca volta atrás.
-- REGRA: buraco na numeração do id é NORMAL no PostgreSQL. O id serve para identificar, não para contar.

-- listando as triggers da tabela
SELECT trigger_name, event_manipulation AS evento, action_timing AS momento
  FROM information_schema.triggers
 WHERE event_object_table = 'idioma';


/*------------------------------------------------------
STORED PROCEDURES ou PROCEDIMENTOS ARMAZENADOS
CRIAÇÃO
--------------------------------------------------------*/
-- STORED PROCEDURES são conjuntos de comandos SQL que podem ser armazenados no
-- servidor de banco de dados e reutilizados. Esses procedimentos são úteis
-- para encapsular lógica complexa e melhorar a eficiência e manutenção do código.

-- ATENÇÃO À DIFERENÇA MAIS IMPORTANTE DESTA AULA:
--   PROCEDURE  --> NÃO devolve resultado. Executa com CALL. PODE controlar transação (COMMIT/ROLLBACK).
--   FUNCTION   --> DEVOLVE um valor. Executa dentro de um SELECT. NÃO controla transação.
-- No MySQL a separação também existia, mas era mais frouxa. Aqui a regra é dura: se você precisa
-- do resultado dentro de um SELECT, é FUNCTION. Se você precisa de COMMIT no meio, é PROCEDURE.

DROP PROCEDURE IF EXISTS stp_adiciona_novo_idioma(VARCHAR);

CREATE PROCEDURE stp_adiciona_novo_idioma(IN p_nome_do_idioma VARCHAR(50))
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO idioma (nome) VALUES (p_nome_do_idioma);
END;
$$;

-- OBS) repare no p_ na frente do nome do parâmetro. Não é frescura: se o parâmetro se chamasse
-- "nome", igual à coluna, o PostgreSQL não saberia a qual dos dois você está se referindo dentro
-- do INSERT. O prefixo p_ (de parâmetro) resolve isso e é convenção de mercado.


/*------------------------------------------------------
STORED PROCEDURES ou PROCEDIMENTOS ARMAZENADOS
chamando uma stored procedure que já foi criada
--------------------------------------------------------*/
-- Chamando a Stored Procedure passando argumento para o parâmetro p_nome_do_idioma
CALL stp_adiciona_novo_idioma('Latim');

SELECT * FROM idioma ORDER BY id_idioma;


/*------------------------------------------------------
STORED PROCEDURES ou PROCEDIMENTOS ARMAZENADOS
listando e visualizando parâmetros das STP
--------------------------------------------------------*/

-- no MySQL era SHOW PROCEDURE STATUS WHERE Db = 'sakila'.
-- no PostgreSQL consultamos o catálogo. Lista todas as rotinas criadas por nós:
SELECT routine_name AS nome_da_rotina,
       routine_type AS tipo
  FROM information_schema.routines
 WHERE routine_schema = 'public'
 ORDER BY routine_type, routine_name;

-- lista os parâmetros de uma rotina específica
SELECT r.routine_name          AS nome_da_procedure,
       p.parameter_name        AS parametros_da_procedure,
       p.data_type             AS tipo_de_dados,
       p.character_maximum_length AS tamanho_maximo,
       p.parameter_mode        AS modo_do_parametro
  FROM information_schema.routines r
  JOIN information_schema.parameters p
    ON p.specific_name = r.specific_name
 WHERE r.routine_name = 'stp_adiciona_novo_idioma'
 ORDER BY p.ordinal_position;

-- exibe a declaração de criação, ou seja, o código-fonte da rotina.
-- é o equivalente ao SHOW CREATE PROCEDURE do MySQL.
SELECT pg_get_functiondef(oid) AS codigo_fonte
  FROM pg_proc
 WHERE proname = 'stp_adiciona_novo_idioma';

-- no psql existe um atalho: \df lista as rotinas, \sf nome mostra o código.


/*------------------------------------------------------
STORED PROCEDURES ou PROCEDIMENTOS ARMAZENADOS
criando uma stored procedure caso ela não exista
--------------------------------------------------------*/
-- o PostgreSQL resolve isso em uma linha, com CREATE OR REPLACE.
-- No MySQL a gente precisava escrever aquele procedimento inteiro que consultava o
-- information_schema, montava o comando em texto e executava com PREPARE. Aqui não precisa.

CREATE OR REPLACE PROCEDURE stp_adiciona_novo_idioma(IN p_nome_do_idioma VARCHAR(50))
LANGUAGE plpgsql
AS $$
BEGIN
    -- versão melhorada: não deixa cadastrar idioma repetido.
    IF EXISTS (SELECT 1 FROM idioma WHERE UPPER(nome) = UPPER(p_nome_do_idioma)) THEN
        RAISE NOTICE 'idioma % já está cadastrado. Nada foi feito.', p_nome_do_idioma;
        RETURN;
    END IF;

    INSERT INTO idioma (nome) VALUES (p_nome_do_idioma);
    RAISE NOTICE 'idioma % cadastrado com sucesso.', p_nome_do_idioma;
END;
$$;

-- testando as duas situações
CALL stp_adiciona_novo_idioma('Latim');    -- já existe, avisa e não faz nada
CALL stp_adiciona_novo_idioma('Grego');    -- não existe, cadastra

SELECT * FROM idioma ORDER BY id_idioma;

-- OBS) RAISE NOTICE avisa sem interromper. RAISE EXCEPTION interrompe e desfaz.
-- A diferença entre os dois é a diferença entre "atenção" e "pare tudo".


/*------------------------------------------------------
ELEMENTOS DE PROGRAMAÇÃO

[1.VARIÁVEIS] --> LOCAIS
--------------------------------------------------------*/
-- variáveis locais só podem ser utilizadas dentro de functions, procedures ou blocos DO.
-- Elas são declaradas no DECLARE, antes do BEGIN.

-- Vamos criar uma function que retorna o total emprestado para um leitor específico.

-- exclui a função se já existe
DROP FUNCTION IF EXISTS fn_pega_total_emprestimos_por_leitor(INT);

CREATE FUNCTION fn_pega_total_emprestimos_por_leitor(p_id_leitor INT)
RETURNS NUMERIC(10,2)   -- retorna um valor numérico
LANGUAGE plpgsql
STABLE                  -- no MySQL escrevíamos DETERMINISTIC e READS SQL DATA.
                        -- no PostgreSQL a palavra é STABLE: mesma entrada, mesmo resultado dentro
                        -- da mesma consulta, e a função só LÊ, não escreve.
AS $$
-- declaração das variáveis locais
DECLARE
    v_total_emprestimos NUMERIC(10,2);
BEGIN
    -- Atribuindo um valor à variável v_total_emprestimos
    SELECT SUM(valor) INTO v_total_emprestimos
      FROM emprestimo
     WHERE id_leitor = p_id_leitor;

    -- Retornando o valor da variável
    RETURN v_total_emprestimos;
END;
$$;

-- chamando a função. Repare: FUNCTION se chama dentro de um SELECT.
SELECT fn_pega_total_emprestimos_por_leitor(2) AS total_emprestado;
-- resultado esperado: 171.73

-- usando somente o pedaço interno do código da função, sem a função.
SELECT SUM(valor) AS total_emprestado
    FROM emprestimo
  WHERE id_leitor = 2;
-- resultado esperado: 171.73, o mesmo número. A função é só esta consulta guardada com um nome.

-- e a grande vantagem da função: ela entra no meio de qualquer consulta, linha a linha.
SELECT id_leitor,
       primeiro_nome,
       fn_pega_total_emprestimos_por_leitor(id_leitor) AS total_emprestado
  FROM leitor
 ORDER BY id_leitor
 LIMIT 5;

-- OBS) e um bloco DO, para quando você quer programar uma vez só e não guardar nada.
-- É o rascunho do plpgsql: roda e some.
DO $$
DECLARE
    v_quantidade INT;
BEGIN
    SELECT COUNT(*) INTO v_quantidade FROM obra;
    RAISE NOTICE 'o acervo tem % obras', v_quantidade;
END;
$$;


/*------------------------------------------------------
ELEMENTOS DE PROGRAMAÇÃO

[Comandos de Fluxo de Dados] -->

IF, ELSIF, ELSE, CASE-WHEN, LOOP
--------------------------------------------------------*/

/*------------------------------------------------------
IF - ELSIF - ELSE
--------------------------------------------------------*/

-- Instruções IF, ELSIF e ELSE devem obrigatoriamente estar dentro de uma
-- procedure, function ou bloco DO. Não existe IF solto no SQL.
-- ATENÇÃO) no MySQL era ELSEIF, tudo junto. No PostgreSQL é ELSIF, sem o "e" do meio.
-- Esse é o erro de digitação que mais aparece na turma.

DROP PROCEDURE IF EXISTS stp_ver_tamanho_obra(INT, VARCHAR, NUMERIC);

-- cria a stored Procedure stp_ver_tamanho_obra
-- parâmetro de entrada = p_id_obra
-- parâmetros de saída  = mensagem e tamanho_obra
-- OBS) no PostgreSQL usamos INOUT com DEFAULT NULL para os parâmetros de saída.
-- Assim a procedure pode ser chamada passando só a entrada.
-- TRADUZINDO: IN = o que ENTRA na procedure.  INOUT = o que ela DEVOLVE para você.
-- O DEFAULT NULL quer dizer "não precisa passar nada aqui". Por isso o CALL lá embaixo tem só o id.
-- E o sinal  :=  é a ATRIBUIÇÃO dentro do plpgsql: "a variável recebe o valor".
CREATE PROCEDURE stp_ver_tamanho_obra(IN    p_id_obra     INT,
                                      INOUT mensagem      VARCHAR DEFAULT NULL,
                                      INOUT tamanho_obra  NUMERIC DEFAULT NULL)
LANGUAGE plpgsql
AS $$
-- declarando uma variável local
DECLARE
    v_duracao INT;
BEGIN
    -- guardando o retorno da consulta na tabela obra dentro da variável local.
    SELECT duracao_minutos INTO v_duracao
      FROM obra
     WHERE id_obra = p_id_obra
     LIMIT 1;

    -- guarda a duração da obra na variável de saída.
    tamanho_obra := v_duracao;

    -- testando a variável com IF
    -- condições múltiplas para determinar a mensagem
    IF v_duracao IS NULL THEN
        mensagem := 'obra não encontrada';

    ELSIF v_duracao > 120 THEN                    -- se a obra passa de 120 minutos de leitura
        mensagem := 'A obra tem duração longa';

    ELSIF v_duracao BETWEEN 81 AND 120 THEN       -- se está entre 81 e 120 minutos
        mensagem := 'A obra tem duração média';

    ELSIF v_duracao < 60 THEN                     -- se for menor que 60 minutos
        mensagem := 'A obra é muito curta';

    ELSE
        mensagem := 'A obra tem duração curta';   -- sobra a faixa de 60 a 80 minutos
    END IF;
END;
$$;

-- Chamando a procedure. Os parâmetros de saída voltam como se fossem uma linha de consulta.
-- escolhemos uma obra para cair em CADA caminho do IF:
CALL stp_ver_tamanho_obra(6);       -- 124 minutos --> A obra tem duração longa
CALL stp_ver_tamanho_obra(1);       --  86 minutos --> A obra tem duração média
CALL stp_ver_tamanho_obra(2);       --  72 minutos --> A obra tem duração curta  (este cai no ELSE)
CALL stp_ver_tamanho_obra(11);      --  49 minutos --> A obra é muito curta
CALL stp_ver_tamanho_obra(99999);   -- id que não existe --> obra não encontrada

-- OBS) a ordem dos ELSIF importa: o banco testa de cima para baixo e PARA no primeiro que for verdadeiro.
-- E o teste de IS NULL vem primeiro de propósito: com a duração nula, nenhuma conta funciona.

-- OBS) repare na faixa que o IF do MySQL deixava de fora: entre 60 e 80 minutos, nenhuma condição
-- pegava e a mensagem voltava vazia. Aqui fechamos o buraco com o ELSE.
-- REGRA: todo encadeamento de IF deve terminar com ELSE. O ELSE é onde mora o caso que você não previu.


/*------------------------------------------------------
CASE-WHEN
--------------------------------------------------------*/
-- Instruções CASE podem ser utilizadas dentro das consultas.
-- NÃO precisam estar dentro de uma stored procedure ou function.

-- traduzindo a classificação indicativa em texto, direto no SELECT
SELECT id_obra,
       titulo,
       classificacao,
    CASE
        WHEN classificacao = 'L'  THEN 'Classificação Livre'
        WHEN classificacao = '10' THEN 'Não recomendado para menores de 10 anos'
        WHEN classificacao = '12' THEN 'Não recomendado para menores de 12 anos'
        WHEN classificacao = '14' THEN 'Não recomendado para menores de 14 anos'
        WHEN classificacao = '16' THEN 'Não recomendado para menores de 16 anos'
        WHEN classificacao = '18' THEN 'Não recomendado para menores de 18 anos'
        ELSE 'Classificação Desconhecida'
    END AS classificacao_para_emprestar   -- necessário para usar como nome de coluna na saída.
  FROM obra
 ORDER BY id_obra
 LIMIT 10;

-- o CASE também funciona DENTRO de uma função agregada. Este é o uso mais poderoso dele:
-- contar coisas diferentes na mesma passada pela tabela.
SELECT COUNT(*) FILTER (WHERE classificacao = 'L')  AS livres,
       COUNT(*) FILTER (WHERE classificacao = '18') AS dezoito,
       SUM(CASE WHEN classificacao = 'L' THEN 1 ELSE 0 END) AS livres_com_case
  FROM obra;
-- resultado esperado: livres = 167 | dezoito = 167 | livres_com_case = 167
-- OBS) o FILTER é do PostgreSQL e não existe no MySQL. Faz o mesmo que o CASE dentro do SUM,
-- e se lê muito melhor. As duas colunas de "livres" dão o mesmo número.
-- COMO LER O SUM(CASE...): para cada obra, o CASE vale 1 se for 'L' e 0 se não for. O SUM soma os 1.
-- Somar uns e zeros é o mesmo que contar.


/*------------------------------------------------------
FUNCTION - Funções
--------------------------------------------------------*/
-- uma função que classifica a obra pelo custo de reposição.
DROP FUNCTION IF EXISTS fn_faixa_de_custo(NUMERIC);

CREATE FUNCTION fn_faixa_de_custo(p_custo NUMERIC)
RETURNS VARCHAR(20)   -- decide qual é o tipo de retorno
LANGUAGE plpgsql
IMMUTABLE             -- IMMUTABLE: para a mesma entrada, sempre a mesma saída, e não lê tabela nenhuma.
                      -- Use STABLE quando a função LÊ tabela. Use VOLATILE quando ela ESCREVE.
AS $$
BEGIN
    IF p_custo IS NULL THEN
        RETURN 'não informado';
    ELSIF p_custo < 15 THEN
        RETURN 'barata';
    ELSIF p_custo < 25 THEN
        RETURN 'média';
    ELSE
        RETURN 'cara';
    END IF;
END;
$$;

-- Usando a função dentro de um SELECT comum
SELECT titulo,
       custo_reposicao,
       fn_faixa_de_custo(custo_reposicao) AS faixa
  FROM obra
 ORDER BY id_obra
 LIMIT 10;

-- e usando a função para agrupar. Ela vira uma coluna como outra qualquer.
SELECT fn_faixa_de_custo(custo_reposicao) AS faixa,
       COUNT(*) AS quantidade
  FROM obra
 GROUP BY faixa
 ORDER BY quantidade DESC;
-- resultado esperado: média = 499 | barata = 313 | cara = 189


/*------------------------------------------------------
FOR

No MySQL NÃO existe estrutura FOR: a gente simulava com WHILE.
No PostgreSQL o FOR EXISTE, e ainda percorre o resultado de uma consulta linha a linha.
--------------------------------------------------------*/

-- FOR contando de 1 a 10
DO $$
DECLARE
    v_i INT;
BEGIN
    FOR v_i IN 1..10 LOOP
        RAISE NOTICE 'contador = %', v_i;
    END LOOP;
END;
$$;

-- FOR percorrendo o resultado de uma consulta. Aqui está a diferença real para o MySQL:
-- não precisa de cursor, não precisa de contador, não precisa saber quantas linhas vêm.
DO $$
DECLARE
    v_linha RECORD;   -- RECORD guarda uma linha inteira, com todas as colunas
BEGIN
    FOR v_linha IN SELECT id_obra, titulo FROM obra ORDER BY id_obra LIMIT 5
    LOOP
        RAISE NOTICE 'obra % : %', v_linha.id_obra, v_linha.titulo;
    END LOOP;
END;
$$;


/*------------------------------------------------------
WHILE
LOOPS: no MySQL só existia WHILE. Aqui temos WHILE, FOR e LOOP.
--------------------------------------------------------*/

DROP PROCEDURE IF EXISTS stp_exemplo_de_while();

CREATE PROCEDURE stp_exemplo_de_while()
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_inicial INT := 1;    -- Valor inicial
    v_id_final   INT := 10;   -- Valor final
    v_id_atual   INT;
    v_titulo     VARCHAR(120);
BEGIN
    v_id_atual := v_id_inicial;

    -- Loop WHILE
    WHILE v_id_atual <= v_id_final LOOP

        -- Seleciona o título da obra com o ID atual
        SELECT titulo INTO v_titulo FROM obra WHERE id_obra = v_id_atual;
        RAISE NOTICE 'obra % : %', v_id_atual, v_titulo;

        -- Incrementa o ID atual
        v_id_atual := v_id_atual + 1;
    END LOOP;
END;
$$;

CALL stp_exemplo_de_while();

-- OBS) por que a procedure usa RAISE NOTICE e não SELECT?
-- No MySQL, um SELECT solto dentro da procedure devolvia uma grade de resultado para a tela.
-- No PostgreSQL isso NÃO acontece: procedure não devolve grade. Se você precisa dos dados,
-- use uma FUNCTION com RETURNS TABLE. Para apenas acompanhar a execução, RAISE NOTICE.

-- a versão certa, quando o objetivo é devolver dados:
-- OBS) repare no O. na frente de O.id_obra e O.titulo, dentro da função. É OBRIGATÓRIO aqui.
-- A função devolve colunas chamadas id_obra e titulo, e a tabela também tem id_obra e titulo.
-- Sem o O. o PostgreSQL não sabe de qual dos dois você está falando e acusa "ambiguous".
DROP FUNCTION IF EXISTS fn_primeiras_obras(INT);

CREATE FUNCTION fn_primeiras_obras(p_quantidade INT)
RETURNS TABLE (id_obra INT, titulo VARCHAR(120))
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
        SELECT O.id_obra, O.titulo
          FROM obra O
         ORDER BY O.id_obra
         LIMIT p_quantidade;
END;
$$;

-- e agora sim, resultado em grade, como qualquer consulta:
SELECT * FROM fn_primeiras_obras(10);


/*------------------------------------------------------
LIMPEZA (opcional)
--------------------------------------------------------*/
-- se quiser deixar o banco como estava antes da aula, descomente as linhas abaixo.

-- DROP TRIGGER IF EXISTS trg_before_idioma_insert ON idioma;
-- DROP FUNCTION IF EXISTS fn_valida_idioma();
-- DROP FUNCTION IF EXISTS fn_pega_total_emprestimos_por_leitor(INT);
-- DROP FUNCTION IF EXISTS fn_faixa_de_custo(NUMERIC);
-- DROP FUNCTION IF EXISTS fn_primeiras_obras(INT);
-- DROP PROCEDURE IF EXISTS stp_adiciona_novo_idioma(VARCHAR);
-- DROP PROCEDURE IF EXISTS stp_ver_tamanho_obra(INT, VARCHAR, NUMERIC);
-- DROP PROCEDURE IF EXISTS stp_exemplo_de_while();
-- DROP MATERIALIZED VIEW IF EXISTS mvw_custo_por_area;
-- DROP VIEW IF EXISTS vw_acervo;
-- DROP VIEW IF EXISTS vw_idiomas;
-- DELETE FROM idioma WHERE nome IN ('Esperanto','Latim','Grego');


/*
FIM AULA 8
*/
