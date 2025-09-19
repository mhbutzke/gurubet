# Períodos da API Sportmonks

## Visão Geral

O include `periods` permite recuperar informações sobre diferentes períodos dentro de uma partida de futebol, como tempo regular, prorrogação e pênaltis. Incluir `periods` em suas requisições da API permite recuperar informações detalhadas sobre o minuto e segundo atual da partida e o tempo que já decorreu.

## Como usar o include

```
https://api.sportmonks.com/v3/football/fixtures/{fixture_ID}?api_token=YOUR_TOKEN&include=periods
```

## Campos dos Períodos

| Campo | Descrição |
|-------|-----------|
| `id` | Identificador único para cada período |
| `fixture_id` | ID da partida associada |
| `type_id` | Tipo do período |
| `started` | Timestamp UNIX do início do período |
| `ended` | Timestamp UNIX do fim do período |
| `counts_from` | Minuto a partir do qual o período começa a contar |
| `ticking` | Boolean indicando se o período está sendo jogado atualmente |
| `sort_order` | Ordem do período |
| `description` | Descrição textual do período |
| `time_added` | Tempo adicionado ao período |
| `period_length` | Duração programada do período |
| `minutes` | Minuto atual do período |
| `seconds` | Segundo atual do período |
| `has_timer` | Boolean indicando se informações detalhadas de timer estão disponíveis |

## Como funciona?

Quando você usa `periods` em uma partida regular, obterá dois IDs de período diferentes. Se a partida for para prorrogação ou pênaltis, um novo ID de período único será criado e mostrado na resposta.

### Exemplo: Final da Copa do Mundo 2022 (Argentina vs França)

```json
"periods": [
    {
        "id": 4539357,
        "fixture_id": 18452325,
        "type_id": 1,
        "started": 1671378775,
        "ended": 1671382962,
        "counts_from": 30,
        "ticking": false,
        "sort_order": 1,
        "description": "1st-half",
        "time_added": 7,
        "period_length": 45,
        "minutes": null,
        "seconds": null,
        "has_timer": false
    },
    {
        "id": 4539396,
        "fixture_id": 18452325,
        "type_id": 2,
        "started": 1671379669,
        "ended": 1671382908,
        "counts_from": 45,
        "ticking": false,
        "sort_order": 2,
        "description": "2nd-half",
        "time_added": 3,
        "period_length": 45,
        "minutes": null,
        "seconds": null,
        "has_timer": false
    },
    {
        "id": 4539412,
        "fixture_id": 18452325,
        "type_id": 3,
        "started": 1671385452,
        "ended": 1671385485,
        "counts_from": 105,
        "ticking": false,
        "sort_order": 3,
        "description": "extra-time",
        "time_added": null,
        "period_length": 30,
        "minutes": null,
        "seconds": null,
        "has_timer": false
    },
    {
        "id": 4539415,
        "fixture_id": 18452325,
        "type_id": 5,
        "started": null,
        "ended": null,
        "counts_from": 120,
        "ticking": false,
        "sort_order": 4,
        "description": "penalties",
        "time_added": null,
        "period_length": null,
        "minutes": 120,
        "seconds": null,
        "has_timer": false
    }
]
```

## Outras opções de include

### `currentPeriod`
Permite recuperar o período em andamento de forma mais conveniente comparado ao uso do include `periods`. 

**Nota**: Este include pode retornar `NULL` quando:
- A partida ainda não começou
- Está no intervalo
- Terminou

### Includes adicionais para períodos

- **`periods.statistics`**: Fornece estatísticas para cada período
- **`periods.events`**: Mostra eventos específicos em cada período
- **`periods.timeline`**: Exibe a linha do tempo para um período
- **`periods.type`**: Ajuda a obter o tipo de um período específico

## Tipos de Períodos

| Type ID | Descrição |
|---------|-----------|
| 1 | Primeiro tempo |
| 2 | Segundo tempo |
| 3 | Prorrogação |
| 5 | Pênaltis |

## Casos de Uso Práticos

### Monitoramento de Tempo Real
```
&include=currentPeriod
```

### Análise Completa de Períodos
```
&include=periods.statistics;periods.events
```

### Timeline Detalhada
```
&include=periods.timeline;periods.type
```
