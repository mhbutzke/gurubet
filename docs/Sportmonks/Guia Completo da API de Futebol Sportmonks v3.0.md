# Guia Completo da API de Futebol Sportmonks v3.0

**Autor:** Manus AI  
**Data:** 19 de setembro de 2025

## Introdução

Este documento serve como um guia definitivo para a utilização da API de Futebol v3.0 da Sportmonks. Ele foi projetado para levar desenvolvedores do básico ao avançado, cobrindo os conceitos mais importantes, funcionalidades poderosas e melhores práticas para uma integração eficiente e robusta. A API Sportmonks é uma fonte de dados esportivos de classe mundial, e dominar suas funcionalidades é a chave para construir aplicações ricas e dinâmicas.

## 1. Rate Limits: Gerenciando o Acesso

O sistema de rate limits da API Sportmonks é projetado para garantir um uso justo e estável dos recursos. Compreendê-lo é o primeiro passo para uma aplicação resiliente [1].

O modelo de limitação é baseado em **entidades**, com um plano padrão oferecendo **3.000 requisições por entidade por hora**. Isso significa que todas as chamadas para endpoints que compartilham a mesma entidade (por exemplo, `teams` e `teams/search/{name}`) contam para o mesmo limite. O contador de uma hora começa a partir da primeira requisição para aquela entidade. É crucial notar que atingir o limite para uma entidade, como `teams`, não afeta a capacidade de fazer chamadas para outras, como `fixtures`.

Para auxiliar no controle, cada resposta da API inclui o objeto `rate_limit`, que informa o número de requisições restantes (`remaining`) e o tempo em segundos para o reset do limite (`resets_in_seconds`). Quando o limite é excedido, a API retorna um erro **429 (Too Many Requests)**, sinalizando a necessidade de aguardar o reset.

| Propriedade | Descrição | Exemplo |
|---|---|---|
| `resets_in_seconds` | Segundos restantes para o reset do limite. | 2400 |
| `remaining` | Requisições restantes no ciclo atual. | 2850 |
| `requested_entity` | A entidade à qual o limite se aplica. | "teams" |

## 2. Sintaxe da API: A Linguagem da Requisição

A API Sportmonks utiliza uma sintaxe de query string consistente e poderosa que permite a construção de requisições complexas de forma intuitiva [2].

Os três pilares da sintaxe são os parâmetros `select`, `include`, e `filters`, que são combinados com os separadores `;` (para múltiplas relações), `:` (para especificar campos em uma relação) e `,` (para múltiplos valores).

- **`&select=`**: Usado para especificar quais campos da entidade principal devem ser retornados. `&select=name,founded`
- **`&include=`**: Usado para carregar entidades relacionadas. `&include=lineups;events`
- **`&filters=`**: Usado para aplicar filtros dinâmicos à consulta. `&filters=eventTypes:15`

## 3. Includes: O Coração da API

Os `includes` são a funcionalidade mais poderosa da API Sportmonks, permitindo que os desenvolvedores enriqueçam as respostas básicas com uma vasta gama de dados relacionados, evitando a necessidade de múltiplas chamadas de API [3].

### 3.1. Tipos de Includes Essenciais

#### **Events (Eventos)**
Os eventos são os momentos que definem uma partida. O include `events` permite rastrear gols, cartões, substituições e decisões do VAR [6]. Cada evento possui um `type_id` e um `sort_order` para garantir a sequência cronológica correta.

- **Uso**: `&include=events`
- **Nested Includes Comuns**: `events.player`, `events.relatedPlayer` (para assistências ou substituições), `events.subType` (para detalhes como gols de pé direito).

#### **States (Estados)**
O estado de uma partida (`state`) é fundamental para entender seu status atual, seja ela não iniciada (`NS`), em andamento (`INPLAY_1ST_HALF`), no intervalo (`HT`) ou finalizada (`FT`) [7]. A API define um fluxo claro de transições entre os estados, incluindo cenários como prorrogação, pênaltis e interrupções.

- **Uso**: `&include=state`
- **Filtragem**: `&filters=fixtureStates:1,2,3` (para partidas em andamento).

#### **Periods (Períodos)**
O include `periods` fornece informações detalhadas sobre cada segmento de uma partida, como primeiro tempo, segundo tempo, prorrogação e disputa de pênaltis [8]. Ele contém timestamps de início e fim, duração e o tempo de acréscimo.

- **Uso**: `&include=periods`
- **Alternativa**: `&include=currentPeriod` para obter apenas o período que está em andamento.

#### **Scores (Placares)**
Para obter a evolução do placar, o include `scores` é essencial. Ele detalha o placar para cada período do jogo, como `1ST_HALF`, `2ND_HALF`, `ET` (prorrogação) e o placar `CURRENT` [9].

- **Uso**: `&include=scores`
- **Nested Includes**: `scores.type` e `scores.participant` para mais detalhes.

#### **Participants (Participantes)**
O include `participants` carrega informações detalhadas sobre as equipes envolvidas na partida, incluindo nome, logo e metadados cruciais como a localização (`home`/`away`), se foi o vencedor (`winner`) e a posição na tabela (`position`) [10].

- **Uso**: `&include=participants`
- **Nested Includes Comuns**: `participants.coaches`, `participants.sidelined` (lesionados/suspensos), `participants.latest` (últimos jogos).

### 3.2. Nested Includes (Aninhados)

Os nested includes elevam o poder dos includes, permitindo carregar relações de relações usando a notação de ponto (`.`). Isso é vital para consultas complexas, como obter o histórico de transferências de todos os jogadores de um time (`players.player.transfers`) em uma única chamada [4].

## 4. Filtros e Seleção de Campos

Para otimizar a performance, a API oferece ferramentas para refinar as respostas. A **seleção de campos** (`&select=`) pode reduzir o tempo de resposta em até 70%, permitindo que você peça apenas os dados que precisa. Os **filtros** (`&filters=`), por sua vez, permitem restringir os resultados com base em critérios específicos, como filtrar apenas eventos de gol (`&filters=eventTypes:15`) [5].

## 5. Dicas e Truques Avançados

A documentação oficial revela várias técnicas para maximizar o uso da API [11]:

- **Enriqueça Eventos**: Use `events.subType` para descobrir detalhes como a parte do corpo com que um gol foi marcado.
- **Detalhes do Jogador**: O include `metadata` em um jogador pode revelar seu pé preferido.
- **Artilheiros com Transferências**: Para rastrear os gols de um jogador que trocou de time na mesma temporada, use `topscorers.topscorer`.
- **Evite o `.type`**: Em vez de usar o include `.type` repetidamente, é mais eficiente buscar todos os tipos no endpoint `/types` uma vez e armazená-los localmente.

## 6. Melhores Práticas e Conclusão

Para uma integração bem-sucedida, siga estas diretrizes:

- **Monitore o Rate Limit**: Sempre verifique o cabeçalho `rate_limit` e implemente uma lógica de recuo (backoff) para o erro 429.
- **Otimize as Requisições**: Combine `select`, `include` e `filters` para criar consultas precisas e eficientes.
- **Armazene Dados Estáticos**: Faça cache de informações que mudam raramente, como a lista de `types` e `leagues`.
- **Leia a Documentação**: A API é rica e complexa. A documentação oficial é o recurso mais importante para descobrir todo o seu potencial.

Este guia oferece uma base sólida para explorar a API Sportmonks. Ao combinar as técnicas aqui apresentadas, os desenvolvedores podem construir aplicações de futebol ricas em dados, performáticas e robustas.

---

## Referências

[1] [Rate limit - API Sportmonks](https://docs.sportmonks.com/football/api/rate-limit)
[2] [Syntax - API Sportmonks](https://docs.sportmonks.com/football/api/syntax)
[3] [Includes - API Sportmonks](https://docs.sportmonks.com/football/tutorials-and-guides/tutorials/includes)
[4] [Nested includes - API Sportmonks](https://docs.sportmonks.com/football/tutorials-and-guides/tutorials/enrich-your-response/nested-includes)
[5] [Filter and select fields - API Sportmonks](https://docs.sportmonks.com/football/tutorials-and-guides/tutorials/filter-and-select-fields)
[6] [Events - API Sportmonks](https://docs.sportmonks.com/football/tutorials-and-guides/tutorials/includes/events)
[7] [States - API Sportmonks](https://docs.sportmonks.com/football/tutorials-and-guides/tutorials/includes/states)
[8] [Periods - API Sportmonks](https://docs.sportmonks.com/football/tutorials-and-guides/tutorials/includes/periods)
[9] [Scores - API Sportmonks](https://docs.sportmonks.com/football/tutorials-and-guides/tutorials/includes/scores)
[10] [Participants - API Sportmonks](https://docs.sportmonks.com/football/tutorials-and-guides/tutorials/includes/participants)
[11] [Tips and tricks - API Sportmonks](https://docs.sportmonks.com/football/tutorials-and-guides/tutorials/includes/tips-and-tricks)

