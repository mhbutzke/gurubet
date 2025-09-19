# Includes da API Sportmonks

## O que são Includes?

Os includes são a **pedra angular** da API Sportmonks e permitem enriquecer e personalizar suas requisições. Esta flexibilidade é o que distingue a Sportmonks de todos os concorrentes. Cada endpoint vem com uma lista de includes disponíveis.

## Como Funcionam os Includes

### Resposta Básica (sem includes)
Por padrão, todos os endpoints fornecem uma resposta 'básica' contendo principalmente IDs únicos:

```json
{
  "data": [
    {
      "id": 18537988,
      "sport_id": 1,
      "league_id": 501,
      "season_id": 19735,
      "venue_id": 336296,
      "name": "Hearts vs St. Johnstone",
      "starting_at": "2023-03-04 15:00:00"
    }
  ]
}
```

### Resposta Enriquecida (com includes)
Ao adicionar `&include=participants` à requisição, você obtém informações detalhadas:

```
https://api.sportmonks.com/v3/football/fixtures/date/2022-09-03?api_token=YOUR_TOKEN&include=participants
```

**Resultado:**
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

## Combinando Múltiplos Includes

Você pode combinar vários includes usando ponto e vírgula (`;`):

```
https://api.sportmonks.com/v3/football/fixtures/date/2022-09-03?api_token=YOUR_TOKEN&include=participants;events
```

Isso retornará:
- **Participants**: Informações detalhadas das equipes
- **Events**: Todos os eventos da partida (gols, cartões, substituições)

## Conceitos Importantes

### Query Complexity
A API usa um mecanismo de complexidade de consulta para determinar o número de includes que você pode usar. Nem todos os includes funcionam com todos os endpoints.

### Flexibilidade
- Os includes são basicamente complementos que você pode usar com sua requisição para informações adicionais
- O endpoint fornece dados básicos, enquanto o include fornece informações extras
- Você deve verificar quais includes estão disponíveis por endpoint no guia de referência da API

## Tipos de Includes Disponíveis

### Includes Básicos
- `participants` - Informações das equipes participantes
- `events` - Eventos da partida (gols, cartões, substituições)
- `lineups` - Escalações das equipes
- `scores` - Placar detalhado
- `states` - Estado da partida
- `periods` - Períodos da partida

### Includes Avançados
- `ballCoordinates` - Coordenadas da bola
- `pressureIndex` - Índice de pressão
- E muitos outros específicos por endpoint

## Exemplo Prático Completo

**Objetivo**: Analisar uma partida de 3 de setembro de 2022, conhecer as equipes e eventos.

**Passo 1 - Requisição básica:**
```
https://api.sportmonks.com/v3/football/fixtures/date/2022-09-03?api_token=YOUR_TOKEN
```

**Passo 2 - Adicionar informações das equipes:**
```
https://api.sportmonks.com/v3/football/fixtures/date/2022-09-03?api_token=YOUR_TOKEN&include=participants
```

**Passo 3 - Adicionar eventos da partida:**
```
https://api.sportmonks.com/v3/football/fixtures/date/2022-09-03?api_token=YOUR_TOKEN&include=participants;events
```

## Conclusão

A API é muito flexível. Você descobrirá mais sobre a flexibilidade e opções de requisição conforme explora. Nem todos os includes funcionam com todos os endpoints, então certifique-se de verificar quais includes estão disponíveis por endpoint no guia de referência da API.

### Próximos Passos
- Explore **nested includes** para relacionamentos de relacionamentos
- Aprenda sobre **paginação** se não estiver vendo todos os dados esperados
- Consulte tutoriais específicos para cada tipo de include
