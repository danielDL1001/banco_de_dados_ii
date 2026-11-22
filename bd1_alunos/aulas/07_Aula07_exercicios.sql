/*-------------------------------------------------------------------------------------------------------------------------
Disciplina: Banco de Dados I
Autor....: Prof. Rodrigo Gonçalves Pinto
Objetivo..: Exercícios da Aula 07 - ALTER, funções agregadas, GROUP BY, HAVING e JOINs
Objeto....: Aula07_exercicios.sql

Banco de dados: db_biblioteca (exceto onde estiver escrito outro)
--------------------------------------------------------------------------------------------------------------------------
COMO FAZER:
 1) rode o script Aula07_consultas.sql inteiro antes de começar.
 2) escreva a sua resposta LOGO ABAIXO de cada enunciado.
 3) rode a sua resposta e confira o resultado.
 4) não apague o enunciado.

LEMBRE) neste banco: obra = livro do acervo, area = área do conhecimento, autor = quem escreveu,
        leitor = quem pega emprestado, emprestimo = o empréstimo em si, com valor e data.

TRAVOU? Todo exercício tem um exemplo parecido no 06_Aula07_consultas.sql.
Procure pelo título da seção indicado na DICA.
--------------------------------------------------------------------------------------------------------------------------
*/

-- >>> TROQUE PARA O BANCO db_biblioteca no seletor do topo da janela <<<
-- a linha abaixo só funciona no psql. No DBeaver e no pgAdmin, deixe comentada.
-- \c db_biblioteca

SELECT current_database();
-- tem que responder: db_biblioteca. Se não respondeu, PARE e troque de banco.


/*------------------------------------------------------
BLOCO 1 - ALTER TABLE
--------------------------------------------------------*/

-- DICA PARA O BLOCO: PARTE 1 do script da aula, seção "COMANDO ALTER".
--                    Lá os exemplos são na tb_alunos; aqui é na tabela obra.

-- [1.1] Adicione à tabela obra uma coluna chamada isbn, texto de 20 caracteres.
-- RESPOSTA:



-- [1.2] Renomeie a coluna dias_emprestimo da tabela obra para prazo_dias.
--       Lembre que no PostgreSQL você NÃO repete o tipo de dados nessa operação.
-- RESPOSTA:



-- [1.3] Faça a coluna titulo da tabela obra não aceitar nulo.
-- RESPOSTA:



-- [1.4] Desfaça os três itens acima: apague a coluna isbn, devolva o nome prazo_dias para
--       dias_emprestimo e permita nulo de novo em titulo.
-- RESPOSTA:




/*------------------------------------------------------
BLOCO 2 - FUNÇÕES AGREGADAS
--------------------------------------------------------*/

-- [2.1] Quantas obras existem no acervo? Dê à coluna o nome total_obras.
-- RESPOSTA:



-- [2.2] Qual o valor total emprestado (soma da coluna valor da tabela emprestimo)?
--       Formate o resultado no padrão brasileiro, com ponto de milhar e vírgula decimal.
-- DICA: seção "Funções Agregadas --> SUM()", os dois passos com to_char e translate.
-- RESPOSTA:



-- [2.3] Qual a duração média, em minutos, das obras do acervo? E a maior? E a menor?
--       Traga as três respostas em UMA única consulta, com três colunas.
-- RESPOSTA:



-- [2.4] Calcule o desvio padrão POPULACIONAL e o desvio padrão AMOSTRAL do custo_reposicao
--       das obras. Em um comentário, escreva qual dos dois deu o número maior e por quê.
-- RESPOSTA:
-- O MAIOR FOI: ____________ PORQUE:



-- [2.5] PEGADINHA. Compare COUNT(*) com COUNT(ano_edicao_detalhes) na tabela detalhes_obra.
--       Os números batem? Explique em um comentário.
--       ATENÇÃO: a tabela detalhes_obra é criada no FIM do script da aula (seção COALESCE).
-- RESPOSTA:




/*------------------------------------------------------
BLOCO 3 - GROUP BY e HAVING
--------------------------------------------------------*/

-- DICA PARA O BLOCO: seções "Cláusula GROUP BY" e "Cláusula HAVING".
--   lembre da regra: coluna fora de função no SELECT tem que estar no GROUP BY.

-- [3.1] Quantas obras existem por classificação indicativa? Ordene da maior quantidade para a menor.
-- RESPOSTA:



-- [3.2] Qual a duração média das obras por idioma? Traga o NOME do idioma, não o id.
-- DICA: o nome do idioma está na tabela idioma. Você vai precisar de um JOIN:
--       obra.id_idioma = idioma.id_idioma
-- RESPOSTA:



-- [3.3] Liste apenas as ÁREAS cujo custo médio de reposição seja MAIOR que 20 reais,
--       da mais cara para a mais barata.
-- RESPOSTA:



-- [3.4] Liste os leitores (id_leitor) que fizeram mais de 26 empréstimos, mostrando também
--       a quantidade e o valor total movimentado. Traga só os 10 primeiros por valor total.
-- RESPOSTA:



-- [3.5] CONCEITO. Escreva a consulta do item 3.4 trocando o HAVING por WHERE.
--       Ela vai dar erro. Copie a mensagem e explique em uma linha por que WHERE não serve aqui.
-- RESPOSTA:
-- MENSAGEM DE ERRO:
-- POR QUE:




/*------------------------------------------------------
BLOCO 4 - JOINs
--------------------------------------------------------*/

-- DICA PARA O BLOCO: seção "JOINS possíveis no PostgreSQL".
--   o caminho entre as tabelas, para consultar:
--      obra   --(id_obra)-->   obra_area   --(id_area)-->   area
--      obra   --(id_obra)-->   obra_autor  --(id_autor)-->  autor
--      obra   --(id_idioma)--> idioma
--      leitor --(id_cidade)--> cidade      --(id_pais)-->   pais
--      emprestimo --(id_leitor)--> leitor

-- [4.1] Liste título da obra e nome da área, para as 10 primeiras obras por id_obra.
-- RESPOSTA:



-- [4.2] Liste os primeiros nomes e sobrenomes dos autores da obra de id_obra = 7.
-- RESPOSTA:



-- [4.3] Quantas obras existem por área? Traga o nome da área e a quantidade,
--       ordenando da área com mais obras para a com menos.
-- RESPOSTA:



-- [4.4] Existe alguma obra SEM área cadastrada? Encontre-a usando LEFT JOIN.
-- DICA: lembre do truque LEFT JOIN + WHERE ... IS NULL.
-- RESPOSTA:



-- [4.5] Existe alguma área SEM nenhuma obra? Encontre-a.
-- RESPOSTA:



-- [4.6] Responda os itens 4.4 e 4.5 de uma vez só, em UMA consulta, usando FULL JOIN.
-- RESPOSTA:



-- [4.7] Liste os 10 leitores que mais gastaram em empréstimos, mostrando
--       primeiro nome, sobrenome, a cidade e o valor total. Envolve três tabelas: emprestimo, leitor e cidade.
-- DICA: comece pelo JOIN entre emprestimo e leitor e rode. Funcionou? Acrescente a cidade.
--       Monte a consulta aos poucos, testando a cada JOIN novo.
-- RESPOSTA:




/*------------------------------------------------------
BLOCO 5 - TEXTO, NULOS E COALESCE
--------------------------------------------------------*/

-- [5.1] Monte uma coluna única no formato:  "TITULO DA OBRA (ano)" para as 10 primeiras obras.
--       Faça de duas formas: uma com CONCAT e outra com o operador ||.
-- RESPOSTA:



-- [5.2] Na tabela detalhes_obra, troque todo nulo da coluna editora_detalhes pelo texto
--       'Editora desconhecida' e todo nulo de paginas_detalhes por zero.
-- RESPOSTA:



-- [5.3] Ordene as obras pelo tamanho do título, do mais curto para o mais longo,
--       mostrando o título e a quantidade de caracteres. Traga só as 10 primeiras.
-- RESPOSTA:



-- [5.4] DESAFIO. Descubra quantos autores têm o mesmo primeiro nome de algum outro autor.
--       Dica: você vai precisar de GROUP BY, HAVING e uma contagem em cima do resultado.
--       Dica 2: faça primeiro a consulta que lista os primeiros nomes repetidos. Depois coloque
--               essa consulta entre parênteses, dentro de um  SELECT COUNT(*) FROM ( ... ) AS x
-- RESPOSTA:


/*
FIM DOS EXERCÍCIOS DA AULA 7
*/
