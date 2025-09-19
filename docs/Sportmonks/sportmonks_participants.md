# Participantes da API Sportmonks

## Visão Geral

O include `participants` fornece informações adicionais sobre os participantes envolvidos em uma partida específica. Incluir `participants` em sua requisição permite recuperar informações detalhadas sobre cada equipe, como nome, imagem e qual equipe venceu uma partida.

## Como usar o include

```
https://api.sportmonks.com/v3/football/fixtures/{fixture_ID}?api_token=YOUR_TOKEN&include=participants
```

## Entendendo a Resposta

Cada equipe é representada como um objeto com os seguintes atributos:

### Campos Principais

| Campo | Descrição |
|-------|-----------|
| `id` | Identificador único para a equipe |
| `sport_id` | Identificador para o esporte |
| `country_id` | Identificador para o país ao qual a equipe pertence |
| `venue_id` | Identificador para o estádio onde a equipe joga seus jogos em casa |
| `gender` | Categoria de gênero |
| `name` | Nome da equipe |
| `short_code` | Código curto ou abreviação para o nome da equipe |
| `image_path` | URL para o logo ou imagem da equipe |
| `founded` | Ano em que a equipe foi fundada |
| `type` | Tipo de equipe |
| `placeholder` | Indica se a equipe é um placeholder ou não |
| `last_played_at` | Data e hora da última partida da equipe |

### Seção Meta

Na seção "meta" você pode encontrar dados adicionais sobre aquela equipe relacionados à partida:

| Campo Meta | Descrição |
|------------|-----------|
| `location` | Indica se a equipe é mandante ("home") ou visitante ("away") |
| `winner` | Indica se a equipe venceu a partida ou não. Se a partida ainda não terminou, será definido como null |
| `position` | Indica a posição na classificação para aquela equipe |

### Exemplo de Resposta

```json
{
  "participants": [
    {
      "id": 53,
      "sport_id": 1,
      "country_id": 1161,
      "venue_id": 336296,
      "gender": "male",
      "name": "Celtic",
      "short_code": "CEL",
      "image_path": "https://cdn.sportmonks.com/images/soccer/teams/21/53.png",
      "founded": 1888,
      "type": "domestic",
      "placeholder": false,
      "last_played_at": "2023-03-04 15:00:00",
      "meta": {
        "location": "home",
        "winner": true,
        "position": 1
      }
    }
  ]
}
```

## Outras Opções de Include

Além do include `participants`, você pode usar nested includes para recuperar dados ainda mais detalhados:

### Includes Mais Utilizados

| Include | Descrição |
|---------|-----------|
| `participants.upcoming` | Fornece as próximas partidas para cada equipe |
| `participants.latest` | Fornece as partidas passadas para cada equipe |
| `participants.sidelined` | Fornece todos os jogadores lesionados e suspensos para cada equipe |
| `participants.coaches` | Fornece os técnicos para cada equipe |

### Exemplos de Uso

#### Informações Básicas dos Participantes
```
&include=participants&select=name,starting_at
```

#### Participantes com Próximas Partidas
```
&include=participants.upcoming:name,starting_at
```

#### Participantes com Jogadores Lesionados
```
&include=participants.sidelined.player:display_name,position
```

#### Participantes com Técnicos
```
&include=participants.coaches:display_name,nationality
```

## Casos de Uso Práticos

### Dashboard de Partida
```
&include=participants:name,image_path,founded&select=name,starting_at,result_info
```

### Análise de Forma das Equipes
```
&include=participants.latest:name,starting_at,result_info&filters=fixtureStates:5
```

### Informações Completas para Preview
```
&include=participants.upcoming;participants.sidelined.player:display_name;participants.coaches:display_name
```

## Interpretação dos Dados Meta

### Location
- **"home"**: Equipe mandante (joga em casa)
- **"away"**: Equipe visitante

### Winner
- **true**: Equipe venceu a partida
- **false**: Equipe perdeu a partida
- **null**: Partida ainda não terminou ou empatou

### Position
- Número inteiro indicando a posição atual da equipe na classificação do campeonato

## Benefícios do Include Participants

1. **Informações Completas**: Obtém dados detalhados das equipes em uma única requisição
2. **Contexto da Partida**: Fornece informações específicas sobre o papel de cada equipe na partida
3. **Flexibilidade**: Permite combinar com outros includes para análises mais profundas
4. **Eficiência**: Reduz o número de chamadas necessárias para obter informações das equipes
