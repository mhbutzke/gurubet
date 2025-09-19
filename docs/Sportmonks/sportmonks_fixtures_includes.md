# Sportmonks API - Fixtures Includes

## Include Options Disponíveis

Com base na documentação oficial, os includes disponíveis para fixtures são:

### Básicos
- sport
- round
- stage
- group
- aggregate
- league
- season
- state
- venue
- participants
- scores

### Detalhes da Partida
- events
- timeline
- periods
- lineups
- formations
- statistics
- trends
- comments
- weatherReport

### Pessoas Envolvidas
- coaches
- referees
- sidelined

### Mídia e Transmissão
- tvStations
- prematchNews
- postmatchNews

### Dados Avançados
- odds
- premiumOdds
- inplayOdds
- predictions
- ballCoordinates
- xGFixture
- pressure
- metadata

### Outros
- expectedLineups

## Endpoints Disponíveis

1. GET All Fixtures - retorna todas as fixtures acessíveis na sua assinatura
2. GET Fixture by ID - retorna uma fixture específica por ID
3. GET Fixtures by Multiple IDs - retorna múltiplas fixtures por IDs
4. GET Fixture by Date Range - retorna fixtures por intervalo de datas
5. GET Fixture by Date - retorna fixtures de uma data específica
6. GET Fixture by Date Range for Team - retorna fixtures por intervalo de datas para um time específico
7. GET Fixture by Head To Head - retorna fixtures head-to-head de dois times
8. GET Fixture by Search by Name - retorna fixtures que correspondem à busca
9. GET Upcoming Fixtures by Market ID - retorna fixtures futuras por Market ID
10. GET Fixture by Last Updated Fixtures - retorna jogos que receberam atualizações nos últimos 10 segundos

## Nota Importante
Para fixtures em tempo real (in-play), é necessário usar os endpoints de livescores.


## Filtros Estáticos (Static Filters)

Os filtros estáticos são sempre os mesmos e filtram de uma forma específica sem opções customizadas:

| Filtro | Entidade | Descrição | Exemplo |
|--------|----------|-----------|---------|
| **participantSearch** | Fixture | Filtrar partidas de participantes específicos | `&include=participants&filters=participantSearch:celtic` |
| **todayDate** | Fixture | Filtrar apenas as fixtures de hoje | `&filters=todayDate` |
| **venues** | Fixture | Encontrar todas as fixtures jogadas em um local específico | `&include=venue&filters=venues:venueIDs` ou `&include=venue&filters=venues:10,12` |
| **Deleted** | Fixture | Filtrar apenas fixtures deletadas. Ajuda a manter o banco de dados sincronizado | `&filters=Deleted` |
| **IdAfter** | All | Filtrar todas as fixtures a partir de um ID específico. Útil quando interessado apenas nas fixtures mais recentes | `&filters=IdAfter:fixtureID` ou `&filters=IdAfter:16535487` |
| **markets** | Odds | Filtrar as odds em uma seleção de mercados separados por vírgula | `&include=odds&filters=markets:marketIDs` ou `&include=odds&filters=markets:12,14` |
| **bookmakers** | Odds | Filtrar as odds em uma seleção de bookmakers separados por vírgula (ex: 2,14) | `&include=odds&filters=bookmakers:bookmakerIDs` ou `&include=odds&filters=bookmakers:2,14` |
| **WinningOdds** | Odds | Filtrar todas as winning odds | `&include=odds&filters=WinningOdds` |

## Filtros Dinâmicos (Dynamic Filters)

Os filtros dinâmicos são baseados em entidades e includes. Cada filtro dinâmico usa uma entidade para filtrar e uma entidade para aplicar o filtro:

| Filtro | Entidade Disponível | Descrição | Exemplos |
|--------|-------------------|-----------|----------|
| **types** | Statistics, Events, Lineup, e mais | Filtrar estatísticas, eventos e mais em uma seleção de IDs de tipo separados por vírgula | `&include=statistics.type&filters=fixtureStatisticTypes:TypeIDs` <br> `&include=statistics.type&filters=fixtureStatisticTypes:42,49` <br> `&include=events&filters=eventTypes:14` <br> `&include=lineups.details.type&filters=lineupDetailTypes:118` |
| **states** | Fixtures | Filtrar os estados das fixtures separados por vírgula | `&include=state&filters=fixtureStates:StateIDs` <br> `&include=state&filters=fixtureStates:1` |
| **leagues** | Fixtures, Seasons, Standings, e mais | Filtrar as fixtures baseado em ligas e suas rodadas | `&filters=fixtureLeagues:leagueIDs` <br> `&filters=fixtureLeagues:501,271` |
| **groups** | Fixtures, Standing, e mais | Filtrar as fixtures baseado em grupos. Obter suas fixtures e standings | `&include=groups&filters=fixtureGroups:groupIDs` <br> `&include=groups&filters=fixtureGroups:246091` |
| **countries** | Coaches, Leagues, Players, Teams, e mais | Filtrar os coaches, ligas, jogadores e mais baseado em países | `&include=coaches&filters=coachCountries:CountryIDs` <br> `&include=coaches&filters=coachCountries:1161` |
| **seasons** | Statistics (players, team, coaches, referees), Standings, e mais | Filtrar estatísticas, standings e topscorers baseado em temporadas | `&include=season.statistics&filters=seasonStatisticTypes:TypeIDs` <br> `&include=season.statistics&filters=seasonStatisticTypes:52` |

## Dica Importante sobre Includes

Ao usar um include, você pode aplicar filtros relacionados a equipes em sua respectiva página de entidade. Por exemplo, se você usar `&include=participants`, pode aplicar filtros relacionados a equipes.

## Endpoint para Descobrir Filtros

Para mais informações sobre quais filtros usar, você pode verificar o seguinte endpoint:
```
https://api.sportmonks.com/v3/my/filters/entity?api_token=YOUR_TOKEN
```
