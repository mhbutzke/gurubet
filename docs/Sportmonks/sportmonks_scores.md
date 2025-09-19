# Scores da API Sportmonks

## Visão Geral

O include `scores` permite recuperar informações sobre os placares dentro de uma partida de futebol de ambos os participantes, as equipes da casa e visitante. Incluir `scores` em suas requisições da API permite recuperar informações detalhadas sobre os placares do 1º tempo, 2º tempo, Prorrogação, Pênaltis e **placar atual**.

## Como usar o include

```
https://api.sportmonks.com/v3/football/fixtures/{fixture_ID}?api_token=YOUR_TOKEN&include=scores
```

## Como funciona?

Quando você usa `scores` para uma partida regular que terminou, obterá apenas quatro tipos diferentes de placares:
- 1º tempo
- 2º tempo
- Apenas 2º tempo
- Atual

Se a partida for para Prorrogação ou Pênaltis, dois novos placares serão mostrados na resposta:
- Prorrogação
- Pênaltis

### Exemplo: Quartas de final da Euro 2024 (Espanha vs Alemanha)

```json
"scores": [
  {
    "id": 14588866,
    "fixture_id": 19032601,
    "type_id": 1,
    "participant_id": 18660,
    "score": {
      "goals": 0,
      "participant": "away"
    },
    "description": "1ST_HALF"
  },
  {
    "id": 14588867,
    "fixture_id": 19032601,
    "type_id": 1,
    "participant_id": 18710,
    "score": {
      "goals": 0,
      "participant": "home"
    },
    "description": "1ST_HALF"
  },
  {
    "id": 14588874,
    "fixture_id": 19032601,
    "type_id": 1525,
    "participant_id": 18710,
    "score": {
      "goals": 2,
      "participant": "home"
    },
    "description": "CURRENT"
  }
]
```

## Campos dos Scores

| Campo | Descrição |
|-------|-----------|
| `id` | Identificador único para cada placar |
| `fixture_id` | ID da partida associada |
| `type_id` | Tipo do placar |
| `participant_id` | ID da equipe (casa ou visitante) |
| `score` | Objeto contendo gols e participante |
| `description` | Descrição textual do período relacionado ao placar |

## Tipos de Placares

### Placares Básicos

| Tipo | Descrição |
|------|-----------|
| **1st half** | Placar de ambas as equipes apenas no 1º tempo |
| **2nd half only** | Placar de ambas as equipes apenas no 2º tempo |
| **2nd half** | Placar de ambas as equipes no final do 2º tempo |
| **Current** | Placar atual se a partida está em andamento ou placar final após FT ou ET quando a partida termina |

### Placares Especiais

| Tipo | Descrição |
|------|-----------|
| **Extra Time** | Placar de ambas as equipes na Prorrogação |
| **Penalties** | Placares de pênaltis de ambas as equipes |

## Estrutura do Objeto Score

```json
{
  "score": {
    "goals": 2,
    "participant": "home"
  }
}
```

### Campos do Score
- **`goals`**: Número de gols marcados
- **`participant`**: Indica se é equipe da casa ("home") ou visitante ("away")

## Includes Extras

### `scores.type`
Permite acessar mais dados sobre o tipo específico de placar.

### `scores.participant`
Permite acessar mais informações sobre a equipe participante.

## Casos de Uso Práticos

### Placar ao Vivo
```
&include=scores&filters=fixtureStates:1,2,3  // Partidas em andamento
```

### Análise de Placares por Período
```
&include=scores.type&select=name,starting_at
```

### Informações Completas de Placar
```
&include=scores.participant:name,image_path
```

## Interpretação dos Dados

### Partida Regular (90 minutos)
- Você receberá placares para: 1ST_HALF, 2ND_HALF, 2ND_HALF_ONLY, CURRENT

### Partida com Prorrogação
- Adiciona: ET (Extra Time)

### Partida com Pênaltis
- Adiciona: PENALTIES

### Exemplo de Interpretação
```json
// Placar final: Casa 2 x 1 Visitante (após prorrogação)
// 1º tempo: 0 x 0
// 2º tempo: 1 x 1 (acumulado)
// Prorrogação: 1 x 0 (apenas na prorrogação)
// Final: 2 x 1
```
