# Guia Completo da API Sportmonks

**Autor:** Manus AI  
**Data:** 19 de setembro de 2025

Este documento fornece um guia completo e abrangente sobre como usar a API Sportmonks, cobrindo desde conceitos básicos até técnicas avançadas de consulta. A API Sportmonks é uma das principais fontes de dados esportivos do mundo, oferecendo informações detalhadas sobre futebol e outros esportes.

## Índice

1. [Rate Limits](#rate-limits)
2. [Sintaxe da API](#sintaxe-da-api)
3. [Includes](#includes)
4. [Nested Includes](#nested-includes)
5. [Filtros e Seleção de Campos](#filtros-e-seleção-de-campos)
6. [Códigos de Resposta](#códigos-de-resposta)
7. [Melhores Práticas](#melhores-práticas)
8. [Exemplos Práticos](#exemplos-práticos)

---

## Rate Limits

O sistema de rate limits da API Sportmonks é fundamental para garantir o uso eficiente e justo dos recursos da API [1].

### Como funciona o rate limit?

A API Sportmonks implementa um sistema de rate limiting baseado em entidades, onde cada plano padrão oferece **3000 chamadas de API por entidade por hora**. Este sistema apresenta características específicas que diferem de outras APIs:

- **Contagem por entidade**: Todas as requisições para endpoints da mesma entidade contam para o mesmo limite. Por exemplo, a entidade "teams" é usada em múltiplos endpoints relacionados a equipes, e todas essas requisições compartilham o mesmo limite de 3000 por hora.
- **Reset temporal**: O limite é resetado após exatamente 1 hora da primeira requisição. Se a primeira requisição for feita às 18:18 UTC, o reset ocorrerá às 19:18 UTC.
- **Isolamento entre entidades**: Quando uma entidade atinge o limite, outras entidades permanecem disponíveis para uso.

### Monitoramento do Rate Limit

A resposta da API inclui automaticamente um objeto `rate_limit` que fornece informações essenciais para monitoramento:

| Propriedade | Descrição | Exemplo |
|-------------|-----------|---------|
| `resets_in_seconds` | Segundos restantes antes do reset do rate limit | 2400 |
| `remaining` | Número de requisições restantes no período atual | 2850 |
| `requested_entity` | Entidade à qual o rate limit se aplica | "teams" |

### Exemplo de resposta rate_limit:
```json
{
  "rate_limit": {
    "resets_in_seconds": 2400,
    "remaining": 2850,
    "requested_entity": "teams"
  }
}
```

### Tratamento de Limite Excedido

Quando o rate limit é atingido, a API retorna o código de resposta **429 (Too Many Requests)**. Neste cenário:

- Não é possível fazer mais requisições para a entidade que atingiu o limite
- Outras entidades que não atingiram o limite permanecem disponíveis
- É recomendado implementar retry logic com backoff exponencial

---

## Sintaxe da API

A sintaxe da API Sportmonks é consistente e pode ser aplicada em todos os endpoints, com algumas exceções específicas documentadas para cada endpoint [2].

### Parâmetros Fundamentais

A API utiliza uma sintaxe baseada em parâmetros de query string que permite grande flexibilidade na construção de requisições:

| Sintaxe | Função | Exemplo de Uso |
|---------|--------|----------------|
| `&select=` | Selecionar campos específicos na entidade base | `&select=name,founded` |
| `&include=` | Incluir relações/entidades relacionadas | `&include=lineups,events` |
| `&filters=` | Aplicar filtros à requisição | `&filters=eventTypes:15` |
| `;` | Separador de relações aninhadas | `&include=lineups;events;participants` |
| `:` | Especificador de seleção de campo | `&include=lineups:player_name` |
| `,` | Separador para múltiplos valores | `&include=events:player_name,minute` |

### Exemplos Práticos de Sintaxe

#### Seleção Básica de Campos
```
https://api.sportmonks.com/v3/football/teams/53?api_token=YOUR_TOKEN&select=name,founded,image_path
```

#### Inclusão de Relações Múltiplas
```
https://api.sportmonks.com/v3/football/fixtures/18535517?api_token=YOUR_TOKEN&include=participants;events;lineups
```

#### Combinação Avançada
```
https://api.sportmonks.com/v3/football/fixtures/18535517?api_token=YOUR_TOKEN&include=events:player_name,minute&filters=eventTypes:15&select=name,starting_at
```

---

## Includes

Os includes representam a **pedra angular** da API Sportmonks, oferecendo flexibilidade incomparável na personalização de requisições [3]. Esta funcionalidade distingue a Sportmonks de seus concorrentes ao permitir que desenvolvedores obtenham exatamente os dados necessários em uma única requisição.

### Conceito Fundamental

Por padrão, todos os endpoints retornam uma resposta "básica" contendo principalmente identificadores únicos e campos essenciais. Os includes permitem enriquecer essa resposta com dados relacionados, transformando uma requisição simples em uma fonte rica de informações.

#### Resposta Básica (sem includes)
```json
{
  "data": {
    "id": 18537988,
    "sport_id": 1,
    "league_id": 501,
    "season_id": 19735,
    "venue_id": 336296,
    "name": "Hearts vs St. Johnstone",
    "starting_at": "2023-03-04 15:00:00"
  }
}
```

#### Resposta Enriquecida (com includes)
```json
{
  "data": {
    "id": 18535605,
    "name": "Rangers vs Celtic",
    "participants": [
      {
        "id": 53,
        "name": "Celtic",
        "short_code": "CEL",
        "image_path": "https://cdn.sportmonks.com/images/soccer/teams/21/53.png",
        "founded": 1888,
        "meta": {
          "location": "away",
          "winner": false,
          "position": 1
        }
      }
    ]
  }
}
```

### Categorias de Includes

#### Includes Básicos
- `participants` - Informações detalhadas das equipes participantes
- `events` - Eventos da partida (gols, cartões, substituições)
- `lineups` - Escalações completas das equipes
- `scores` - Placar detalhado e progressão
- `states` - Estado atual da partida
- `periods` - Informações sobre períodos da partida

#### Includes Avançados
- `ballCoordinates` - Coordenadas da bola durante a partida
- `pressureIndex` - Índice de pressão das equipes
- `statistics` - Estatísticas detalhadas da partida
- `commentary` - Comentários em tempo real

### Query Complexity

A API implementa um sistema de **Query Complexity** que determina quantos includes podem ser utilizados simultaneamente. Este mecanismo:

- Previne sobrecarga do sistema
- Varia conforme o plano de assinatura
- É específico para cada endpoint
- Deve ser consultado na documentação de cada endpoint

### Exemplo Prático Completo

Considere o cenário de análise de uma partida específica:

**Objetivo**: Analisar a partida Celtic vs Rangers de 3 de setembro de 2022.

**Evolução da requisição:**

1. **Requisição básica:**
```
https://api.sportmonks.com/v3/football/fixtures/date/2022-09-03?api_token=YOUR_TOKEN
```

2. **Adicionando informações das equipes:**
```
https://api.sportmonks.com/v3/football/fixtures/date/2022-09-03?api_token=YOUR_TOKEN&include=participants
```

3. **Incluindo eventos da partida:**
```
https://api.sportmonks.com/v3/football/fixtures/date/2022-09-03?api_token=YOUR_TOKEN&include=participants;events
```

4. **Versão completa com múltiplos includes:**
```
https://api.sportmonks.com/v3/football/fixtures/date/2022-09-03?api_token=YOUR_TOKEN&include=participants;events;lineups;scores;statistics
```

---

## Nested Includes

Os nested includes representam uma evolução natural dos includes básicos, permitindo acesso a relacionamentos de relacionamentos em uma única requisição [4]. Esta funcionalidade é essencial para obter dados profundamente relacionados sem múltiplas chamadas à API.

### Conceito e Sintaxe

Os nested includes utilizam a notação de ponto (`.`) para conectar relacionamentos em cadeia:

```
entidade_principal.entidade_relacionada.entidade_sub_relacionada
```

### Benefícios dos Nested Includes

1. **Eficiência de Rede**: Reduz drasticamente o número de requisições necessárias
2. **Consistência de Dados**: Garante que todos os dados relacionados sejam do mesmo momento
3. **Simplicidade de Código**: Elimina a necessidade de lógica complexa de agregação de dados
4. **Performance**: Otimiza o tempo total de resposta

### Nested Includes Essenciais

#### `players.player`
Usado para incluir detalhes completos do jogador em vários endpoints:
```
https://api.sportmonks.com/v3/football/teams/53?api_token=YOUR_TOKEN&include=players.player
```

#### `teams.team`
Inclui detalhes completos da equipe em endpoints relacionados:
```
https://api.sportmonks.com/v3/football/players/275?api_token=YOUR_TOKEN&include=teams.team
```

### Exemplo Avançado: Transferências de Jogadores

Este exemplo demonstra a progressão lógica no uso de nested includes:

**Cenário**: Obter jogadores de uma equipe com histórico completo de transferências.

**Progressão:**

1. **Requisição básica** (apenas IDs):
```
https://api.sportmonks.com/v3/football/teams/53?api_token=YOUR_TOKEN&include=players
```
*Resultado: Lista de IDs de jogadores com datas, mas sem dados do jogador.*

2. **Incluindo dados do jogador**:
```
https://api.sportmonks.com/v3/football/teams/53?api_token=YOUR_TOKEN&include=players.player
```
*Resultado: Dados completos dos jogadores atuais.*

3. **Incluindo histórico de transferências**:
```
https://api.sportmonks.com/v3/football/teams/53?api_token=YOUR_TOKEN&include=players.player.transfers
```
*Resultado: Dados completos dos jogadores + histórico completo de transferências.*

### Estrutura de Resposta Hierárquica

Com nested includes, a resposta mantém uma estrutura hierárquica clara:

```json
{
  "data": {
    "id": 53,
    "name": "Celtic",
    "players": [
      {
        "id": 12345,
        "player": {
          "id": 275,
          "name": "Joe Hart",
          "country": "England",
          "transfers": [
            {
              "id": 98765,
              "from_team": "Manchester City",
              "to_team": "Celtic",
              "date": "2021-08-01"
            }
          ]
        }
      }
    ]
  }
}
```

### Determinando a Sintaxe Correta

Para determinar a sintaxe correta de nested includes:

1. **Examine a resposta da API** para identificar os modelos retornados
2. **Consulte a documentação** do endpoint específico
3. **Verifique as relações** entre entidades na seção de entidades
4. **Teste incrementalmente** adicionando um nível por vez

---

## Filtros e Seleção de Campos

O sistema de filtros e seleção de campos da API Sportmonks permite otimização granular de requisições, reduzindo tanto o tempo de resposta quanto o volume de dados transferidos [5].

### Seleção de Campos

A seleção de campos permite especificar exatamente quais campos devem ser retornados, resultando em:

- **Redução do tempo de resposta** em até 70% para requisições grandes
- **Diminuição do uso de banda** significativa
- **Simplificação do processamento** no lado cliente

#### Sintaxe Básica
```
&select=campo1,campo2,campo3
```

#### Exemplos Práticos

**Seleção simples:**
```
https://api.sportmonks.com/v3/football/fixtures/18535517?api_token=YOUR_TOKEN&select=name,starting_at,result_info
```

**Seleção em includes:**
```
https://api.sportmonks.com/v3/football/fixtures/18535517?api_token=YOUR_TOKEN&include=lineups.player:display_name,image_path;lineups.player.country:name,image_path
```

### Sistema de Filtros

O sistema de filtros da API oferece duas categorias principais:

#### Filtros Estáticos
- Operam de maneira predefinida
- Não requerem configuração adicional
- Disponíveis na aba "Static Filters" de cada endpoint

#### Filtros Dinâmicos
- Baseados em entidades e relacionamentos
- Oferecem máxima flexibilidade
- Podem ser combinados com includes

### Construção de Filtros Dinâmicos

Para criar um filtro dinâmico, siga esta estrutura:

1. **Defina a entidade base** (sempre singular, minúscula)
2. **Especifique a entidade de resultado** (sempre plural, primeira letra maiúscula)
3. **Forneça os IDs de filtro** (separados por vírgula para múltiplos valores)

#### Sintaxe
```
&filters=entidadeResultado:id1,id2,id3
```

#### Exemplo: Filtrar Eventos por Tipo
```
https://api.sportmonks.com/v3/football/fixtures/18535517?api_token=YOUR_TOKEN&include=events&filters=eventTypes:18
```

Este exemplo filtra apenas eventos de substituição (tipo 18).

### Combinação Avançada

É possível combinar seleção de campos, includes e filtros em uma única requisição:

```
https://api.sportmonks.com/v3/football/fixtures/18535517?api_token=YOUR_TOKEN&select=name,starting_at&include=events:player_name,minute&filters=eventTypes:15,18&include=participants:name,image_path
```

Esta requisição:
- Seleciona apenas nome e horário da partida
- Inclui eventos (apenas nome do jogador e minuto)
- Filtra apenas gols (15) e substituições (18)
- Inclui participantes (apenas nome e imagem)

---

## Códigos de Resposta

A API Sportmonks utiliza códigos de resposta HTTP padrão para comunicar o status das requisições:

| Código | Status | Descrição |
|--------|--------|-----------|
| 200 | OK | Requisição bem-sucedida |
| 400 | Bad Request | Requisição malformada ou parâmetros inválidos |
| 401 | Unauthorized | Token de API ausente ou inválido |
| 403 | Forbidden | Acesso negado ao recurso (limitação do plano) |
| 429 | Too Many Requests | Rate limit excedido |
| 500 | Internal Server Error | Erro interno do servidor |

---

## Melhores Práticas

### Otimização de Performance

1. **Use seleção de campos** sempre que possível para reduzir o payload
2. **Implemente cache local** para dados que não mudam frequentemente
3. **Monitore o rate limit** e implemente retry logic adequado
4. **Combine múltiplos includes** em uma única requisição quando apropriado

### Tratamento de Erros

```python
import requests
import time

def fazer_requisicao_com_retry(url, max_retries=3):
    for tentativa in range(max_retries):
        response = requests.get(url)
        
        if response.status_code == 200:
            return response.json()
        elif response.status_code == 429:
            # Rate limit excedido - aguardar antes de tentar novamente
            time.sleep(2 ** tentativa)  # Backoff exponencial
        elif response.status_code == 403:
            raise Exception("Acesso negado - verifique seu plano")
        else:
            raise Exception(f"Erro na requisição: {response.status_code}")
    
    raise Exception("Máximo de tentativas excedido")
```

### Estruturação de Código

```python
class SportmonksAPI:
    def __init__(self, api_token):
        self.api_token = api_token
        self.base_url = "https://api.sportmonks.com/v3/football"
    
    def construir_url(self, endpoint, includes=None, select=None, filters=None):
        url = f"{self.base_url}/{endpoint}?api_token={self.api_token}"
        
        if includes:
            url += f"&include={';'.join(includes)}"
        if select:
            url += f"&select={','.join(select)}"
        if filters:
            filter_str = '&'.join([f"{k}:{','.join(v)}" for k, v in filters.items()])
            url += f"&filters={filter_str}"
        
        return url
```

---

## Exemplos Práticos

### Exemplo 1: Análise Completa de Partida

```python
# Obter dados completos de uma partida específica
url = api.construir_url(
    endpoint="fixtures/18535517",
    includes=[
        "participants",
        "events.player",
        "lineups.player:display_name,position",
        "statistics",
        "scores"
    ],
    select=["name", "starting_at", "result_info"],
    filters={
        "eventTypes": ["15", "17", "18"]  # Gols, cartões, substituições
    }
)
```

### Exemplo 2: Monitoramento de Transferências

```python
# Obter histórico completo de transferências de uma equipe
url = api.construir_url(
    endpoint="teams/53",
    includes=[
        "players.player.transfers.teams",
        "players.player:display_name,age,position"
    ],
    select=["name", "founded"]
)
```

### Exemplo 3: Dashboard de Liga

```python
# Dados para dashboard de uma liga específica
url = api.construir_url(
    endpoint="seasons/19735/fixtures",
    includes=[
        "participants:name,image_path",
        "scores",
        "events:type,minute"
    ],
    select=["name", "starting_at", "state_id"],
    filters={
        "fixtureStates": ["1", "5"]  # Agendadas e finalizadas
    }
)
```

---

## Referências

[1] [Rate limit - API Sportmonks](https://docs.sportmonks.com/football/api/rate-limit)  
[2] [Syntax - API Sportmonks](https://docs.sportmonks.com/football/api/syntax)  
[3] [Includes - API Sportmonks](https://docs.sportmonks.com/football/tutorials-and-guides/tutorials/includes)  
[4] [Nested includes - API Sportmonks](https://docs.sportmonks.com/football/tutorials-and-guides/tutorials/enrich-your-response/nested-includes)  
[5] [Filter and select fields - API Sportmonks](https://docs.sportmonks.com/football/tutorials-and-guides/tutorials/filter-and-select-fields)

---

**Nota**: Este documento foi criado com base na documentação oficial da API Sportmonks versão 3.0. Para informações mais atualizadas, consulte sempre a documentação oficial em [docs.sportmonks.com](https://docs.sportmonks.com).



---

## Eventos

Os eventos são momentos cruciais que definem o curso de uma partida de futebol. A API Sportmonks oferece um sistema detalhado para rastrear e analisar esses eventos [6].

### Como usar o include `events`

Para incluir eventos em suas requisições, adicione o parâmetro `&include=events`:

```
https://api.sportmonks.com/v3/football/fixtures/{fixture_ID}?api_token=YOUR_TOKEN&include=events
```

### Campos Principais dos Eventos

| Campo | Descrição |
|---|---|
| `id` | Identificador único do evento |
| `fixture_id` | ID da partida associada |
| `team_id` | ID da equipe relacionada ao evento |
| `player_id` | ID do jogador principal do evento |
| `related_player_id` | ID do jogador secundário (ex: assistência) |
| `minute` | Minuto em que o evento ocorreu |
| `sort_order` | Ordem cronológica para desempate em eventos no mesmo minuto |

### Tipos de Eventos

#### Eventos de Gol
- **GOAL**: Gol marcado
- **OWN GOAL**: Gol contra

#### Eventos de Cartão
- **YELLOWCARD**: Cartão amarelo
- **REDCARD**: Cartão vermelho direto
- **YELLOWREDCARD**: Segundo cartão amarelo, resultando em vermelho

#### Eventos de Pênalti
- **PENALTY**: Pênalti convertido durante o jogo
- **MISSED_PENALTY**: Pênalti perdido durante o jogo
- **PENALTY_SHOOTOUT_GOAL**: Gol em disputa de pênaltis
- **PENALTY_SHOOTOUT_MISS**: Pênalti perdido em disputa de pênaltis

#### Substituições
- **SUBSTITUTION**: `player_id` é quem entra, `related_player_id` é quem sai.

#### Eventos de VAR
- **VAR_CARD**: Revisão de cartão
- **Goal Disallowed**: Gol anulado pelo VAR
- **Penalty Disallowed**: Pênalti anulado pelo VAR
- **Goal confirmed**: Gol confirmado pelo VAR

### Includes Extras para Eventos

- `events.type`: Detalhes sobre o tipo de evento.
- `events.subType`: Detalhes mais específicos (ex: parte do corpo no gol).
- `events.player`: Informações completas do jogador principal.
- `events.relatedPlayer`: Informações completas do jogador secundário.




---

## Estados

O estado de uma partida é crucial para entender seu andamento. A API Sportmonks fornece um sistema de estados detalhado para classificar cada partida [7].

### Como usar o include `state`

Para incluir o estado em suas requisições, use o parâmetro `&include=state`:

```
https://api.sportmonks.com/v3/football/fixtures?api_token=YOUR_TOKEN&include=state
```

### Filtragem por Estados

Filtre partidas por estados específicos usando o parâmetro `&filters=fixtureStates:StateIDs`:

```
https://api.sportmonks.com/v3/football/fixtures?api_token=YOUR_TOKEN&include=state&filters=fixtureStates:16,18
```

### Fluxo de Estados de uma Partida

| Estado Atual | Transição Para | Motivo |
|---|---|---|
| `NS` (Not Started) | `INPLAY_1ST_HALF` | Início da partida |
| `INPLAY_1ST_HALF` | `HT` (Half Time) | Intervalo |
| `HT` | `INPLAY_2ND_HALF` | Início do 2º tempo |
| `INPLAY_2ND_HALF` | `FT` (Full Time) | Fim do tempo regulamentar |
| `FT` | `BREAK` | Intervalo antes da prorrogação |
| `BREAK` | `INPLAY_ET` | Início da prorrogação |
| `INPLAY_ET` | `AET` (After Extra Time) | Fim da prorrogação |
| `AET` | `PEN_BREAK` | Intervalo antes dos pênaltis |
| `PEN_BREAK` | `INPLAY_PENALTIES` | Início da disputa de pênaltis |
| `INPLAY_PENALTIES` | `FT_PEN` | Fim da disputa de pênaltis |

### Outros Estados Importantes

- **`POSTPONED`**: Partida adiada.
- **`CANCELLED`**: Partida cancelada.
- **`SUSPENDED`**: Partida suspensa.
- **`ABANDONED`**: Partida abandonada.
- **`DELAYED`**: Partida atrasada.
- **`AWARDED`**: Resultado decidido externamente.
- **`DELETED`**: Partida removida (acessível com `&filters=deleted`).




---

## Períodos

O include `periods` permite recuperar informações sobre os diferentes períodos de uma partida, como tempo regular, prorrogação e pênaltis [8].

### Como usar o include `periods`

```
https://api.sportmonks.com/v3/football/fixtures/{fixture_ID}?api_token=YOUR_TOKEN&include=periods
```

### Campos Principais dos Períodos

| Campo | Descrição |
|---|---|
| `id` | ID único do período |
| `type_id` | Tipo do período (1 para 1º tempo, 2 para 2º tempo, etc.) |
| `started` | Timestamp UNIX do início do período |
| `ended` | Timestamp UNIX do fim do período |
| `ticking` | Booleano que indica se o período está em andamento |
| `minutes` | Minuto atual do período |

### `currentPeriod`

Para uma forma mais direta de obter o período atual, use o include `currentPeriod`. Ele pode retornar `NULL` se a partida não estiver em andamento.

### Includes Extras para Períodos

- `periods.statistics`: Estatísticas por período.
- `periods.events`: Eventos que ocorreram em cada período.
- `periods.timeline`: Linha do tempo de cada período.
- `periods.type`: Detalhes sobre o tipo de período.




---

## Scores

O include `scores` permite recuperar informações detalhadas sobre os placares de uma partida, incluindo placares de diferentes períodos do jogo [9].

### Como usar o include `scores`

```
https://api.sportmonks.com/v3/football/fixtures/{fixture_ID}?api_token=YOUR_TOKEN&include=scores
```

### Tipos de Placares

- **1st half**: Placar apenas do 1º tempo.
- **2nd half only**: Placar apenas do 2º tempo.
- **2nd half**: Placar acumulado ao final do 2º tempo.
- **Extra Time**: Placar da prorrogação.
- **Penalties**: Placar da disputa de pênaltis.
- **Current**: Placar atual (em andamento) ou final.

### Includes Extras para Scores

- `scores.type`: Detalhes sobre o tipo de placar.
- `scores.participant`: Informações sobre a equipe relacionada ao placar.




---

## Participantes

O include `participants` fornece informações detalhadas sobre as equipes envolvidas em uma partida [10].

### Como usar o include `participants`

```
https://api.sportmonks.com/v3/football/fixtures/{fixture_ID}?api_token=YOUR_TOKEN&include=participants
```

### Campos Principais dos Participantes

| Campo | Descrição |
|---|---|
| `id` | ID único da equipe |
| `name` | Nome da equipe |
| `image_path` | URL do logo da equipe |
| `meta.location` | Posição da equipe na partida (home/away) |
| `meta.winner` | Booleano que indica se a equipe venceu |
| `meta.position` | Posição da equipe na classificação |

### Includes Extras para Participantes

- `participants.upcoming`: Próximas partidas da equipe.
- `participants.latest`: Últimas partidas da equipe.
- `participants.sidelined`: Jogadores lesionados ou suspensos.
- `participants.coaches`: Técnicos da equipe.




---

## Dicas e Truques

A documentação da Sportmonks oferece várias dicas e truques para otimizar o uso da API e descobrir funcionalidades poderosas [11].

### Placar da Partida

- Use o include `scores` para obter os placares.
- Utilize o indicador `CURRENT` para o placar mais recente, incluindo prorrogação.

### Eventos da Partida

- Enriqueça os dados de eventos com `events.player` para informações detalhadas do jogador.
- Use `events.subType` para obter detalhes extras, como a parte do corpo com que um gol foi marcado.

### Informações Extras da Partida e do Jogador

- O include `metadata` em partidas pode fornecer informações sobre o campo, cores das equipes e formações.
- O include `metadata` em jogadores pode revelar o pé preferido e outras características.

### Detalhes de Artilheiros

- Para lidar com jogadores que mudam de time na mesma liga, use o nested include `topscorers.topscorer` para ver os gols marcados por cada equipe.

### Melhores Práticas

- **Evite o include `.type`**: É mais eficiente obter todos os tipos do endpoint `/types` e armazená-los localmente.
- **Otimize requisições**: Combine includes, use seleção de campos (`select`) e filtros para minimizar o tráfego de dados e melhorar a performance.

