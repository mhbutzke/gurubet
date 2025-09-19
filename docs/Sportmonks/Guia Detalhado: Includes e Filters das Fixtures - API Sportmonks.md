# Guia Detalhado: Includes e Filters das Fixtures - API Sportmonks

**Autor:** Manus AI  
**Data:** 19 de setembro de 2025

## Introdução

Este documento fornece uma explicação completa e detalhada de todos os includes e filters disponíveis para o endpoint de fixtures da API Sportmonks. As fixtures são o coração da API de futebol, representando as partidas, e entender como enriquecer essas informações é fundamental para criar aplicações robustas e informativas.

## 1. Includes Disponíveis

Os includes permitem enriquecer a resposta da API com dados relacionados. A API Sportmonks oferece uma vasta gama de includes para fixtures, organizados em diferentes categorias conforme sua funcionalidade.

### 1.1. Informações Básicas da Partida

Estes includes fornecem informações fundamentais sobre o contexto da partida:

- **sport**: Informações sobre o esporte (sempre futebol no contexto da API de futebol)
- **league**: Dados da liga onde a partida está sendo disputada
- **season**: Informações da temporada atual
- **round**: Dados da rodada específica
- **stage**: Informações do estágio da competição (fase de grupos, oitavas, etc.)
- **group**: Dados do grupo (relevante para competições com fase de grupos)
- **aggregate**: Informações de agregado para jogos de ida e volta

### 1.2. Local e Condições

Informações sobre onde e em que condições a partida será disputada:

- **venue**: Dados do estádio onde a partida será realizada
- **weatherReport**: Relatório meteorológico para a partida

### 1.3. Participantes e Equipes

Dados sobre as equipes e pessoas envolvidas na partida:

- **participants**: Informações das equipes participantes
- **coaches**: Dados dos técnicos das equipes
- **referees**: Informações sobre os árbitros da partida
- **sidelined**: Jogadores lesionados ou suspensos

### 1.4. Estado e Resultado da Partida

Informações sobre o status atual e resultados:

- **state**: Estado atual da partida (não iniciada, em andamento, finalizada, etc.)
- **scores**: Placares da partida por período
- **periods**: Informações detalhadas sobre os períodos de jogo

### 1.5. Eventos e Timeline

Dados sobre os acontecimentos durante a partida:

- **events**: Eventos da partida (gols, cartões, substituições, etc.)
- **timeline**: Linha do tempo detalhada dos eventos
- **comments**: Comentários sobre a partida

### 1.6. Dados Táticos e Técnicos

Informações avançadas sobre aspectos táticos:

- **lineups**: Escalações das equipes
- **formations**: Formações táticas utilizadas
- **statistics**: Estatísticas detalhadas da partida
- **trends**: Tendências e padrões identificados

### 1.7. Dados Avançados e Analytics

Informações especializadas para análise profunda:

- **ballCoordinates**: Coordenadas da bola durante a partida
- **xGFixture**: Dados de Expected Goals (xG) da partida
- **pressure**: Índice de pressão durante o jogo
- **expectedLineups**: Escalações esperadas antes da partida

### 1.8. Apostas e Mercado

Dados relacionados ao mercado de apostas:

- **odds**: Odds básicas da partida
- **premiumOdds**: Odds premium com mais mercados
- **inplayOdds**: Odds durante o jogo (ao vivo)
- **predictions**: Previsões para a partida

### 1.9. Mídia e Transmissão

Informações sobre cobertura midiática:

- **tvStations**: Emissoras que transmitirão a partida
- **prematchNews**: Notícias pré-jogo
- **postmatchNews**: Notícias pós-jogo

### 1.10. Metadados

Informações adicionais e metadados:

- **metadata**: Metadados diversos sobre a partida

## 2. Filtros Estáticos

Os filtros estáticos são predefinidos e funcionam de forma consistente, sem necessidade de parâmetros customizados. Eles são ideais para casos de uso comuns e oferecem uma forma simples de filtrar dados.

### 2.1. Filtros Baseados em Participantes

**participantSearch**: Este filtro permite buscar partidas de equipes específicas usando o nome da equipe. É especialmente útil quando você conhece o nome da equipe mas não seu ID.

> Exemplo: `&include=participants&filters=participantSearch:celtic` retorna todas as partidas do Celtic.

### 2.2. Filtros Temporais

**todayDate**: Filtra apenas as partidas que ocorrem no dia atual. Este filtro é extremamente útil para aplicações que mostram jogos do dia.

> Exemplo: `&filters=todayDate` retorna apenas as partidas de hoje.

### 2.3. Filtros de Local

**venues**: Permite filtrar partidas por estádio específico. Você pode usar um único ID de venue ou múltiplos IDs separados por vírgula.

> Exemplo: `&include=venue&filters=venues:10,12` retorna partidas nos estádios com IDs 10 e 12.

### 2.4. Filtros de Sincronização

**Deleted**: Este filtro é crucial para manter bancos de dados sincronizados, retornando apenas partidas que foram deletadas do sistema.

**IdAfter**: Permite buscar partidas com ID maior que um valor específico, útil para implementar sincronização incremental.

> Exemplo: `&filters=IdAfter:16535487` retorna partidas com ID superior a 16535487.

### 2.5. Filtros de Apostas

**markets**: Filtra odds por mercados específicos de apostas.
**bookmakers**: Filtra odds por casas de apostas específicas.
**WinningOdds**: Retorna apenas as odds vencedoras.

## 3. Filtros Dinâmicos

Os filtros dinâmicos são mais flexíveis e poderosos, baseados em entidades e includes. Eles permitem filtragem granular baseada em relacionamentos entre diferentes entidades.

### 3.1. Filtros de Tipo (types)

Este é um dos filtros mais versáteis, permitindo filtrar por tipos específicos em várias entidades:

**Estatísticas**: `&include=statistics.type&filters=fixtureStatisticTypes:42,49` filtra estatísticas por tipos específicos.

**Eventos**: `&include=events&filters=eventTypes:14` filtra eventos por tipo (gols, cartões, etc.).

**Detalhes de Escalação**: `&include=lineups.details.type&filters=lineupDetailTypes:118` filtra detalhes específicos das escalações.

### 3.2. Filtros de Estado (states)

Permite filtrar partidas por seu estado atual:

> `&include=state&filters=fixtureStates:1` retorna apenas partidas em um estado específico.

### 3.3. Filtros de Liga (leagues)

Filtra partidas baseado em ligas específicas:

> `&filters=fixtureLeagues:501,271` retorna partidas das ligas com IDs 501 e 271.

### 3.4. Filtros de Grupo (groups)

Útil para competições com fase de grupos:

> `&include=groups&filters=fixtureGroups:246091` retorna partidas de um grupo específico.

### 3.5. Filtros de País (countries)

Permite filtrar baseado em países de origem:

> `&include=coaches&filters=coachCountries:1161` filtra técnicos por país.

### 3.6. Filtros de Temporada (seasons)

Filtra dados baseado em temporadas específicas:

> `&include=season.statistics&filters=seasonStatisticTypes:52` filtra estatísticas por temporada.

## 4. Estratégias de Uso

### 4.1. Combinando Includes e Filters

A verdadeira potência da API Sportmonks vem da combinação inteligente de includes e filters. Por exemplo:

```
&include=participants,events,statistics.type
&filters=fixtureLeagues:501;eventTypes:14;fixtureStatisticTypes:42
```

Esta combinação retorna partidas de uma liga específica, incluindo participantes, apenas eventos de gol, e estatísticas específicas.

### 4.2. Otimização de Performance

Para otimizar performance e reduzir o uso de rate limits:

1. **Use filtros específicos** em vez de buscar todos os dados
2. **Combine múltiplos filtros** para reduzir o volume de dados
3. **Selecione apenas campos necessários** usando o parâmetro `select`

### 4.3. Casos de Uso Práticos

**Dashboard de Liga**: `&include=participants,scores,state&filters=fixtureLeagues:501`

**Análise de Eventos**: `&include=events.type,participants&filters=eventTypes:14,18`

**Monitoramento ao Vivo**: `&include=scores,events,state&filters=fixtureStates:2`

## 5. Descoberta de Filtros

Para descobrir todos os filtros disponíveis para uma entidade específica, use o endpoint:

```
https://api.sportmonks.com/v3/my/filters/entity?api_token=YOUR_TOKEN
```

Este endpoint retorna uma lista completa de todos os filtros disponíveis, seus tipos e como utilizá-los.

## Conclusão

O sistema de includes e filters da API Sportmonks é extremamente poderoso e flexível. Compreender como utilizá-los efetivamente permite criar aplicações que consomem exatamente os dados necessários, otimizando performance e fornecendo experiências ricas aos usuários. A chave está em combinar includes e filters de forma inteligente, sempre considerando as necessidades específicas da aplicação e os limites de rate limiting da API.

---

## Referências

[1] [Sportmonks - Fixtures Documentation](https://docs.sportmonks.com/football/endpoints-and-entities/endpoints/fixtures)  
[2] [Sportmonks - GET All Fixtures](https://docs.sportmonks.com/football/endpoints-and-entities/endpoints/fixtures/get-all-fixtures)  
[3] [Sportmonks - Filters Documentation](https://docs.sportmonks.com/football/tutorials-and-guides/tutorials/filter-and-select-fields)  
[4] [Sportmonks - Includes Tutorial](https://docs.sportmonks.com/football/tutorials-and-guides/tutorials/includes)
