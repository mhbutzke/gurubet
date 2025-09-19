# Eventos da API Sportmonks

## Visão Geral

Os eventos em uma partida de futebol são momentos cruciais que definem o curso e o resultado da partida. Cada tipo de evento é representado por um código único, permitindo rastrear e analisar vários eventos durante uma partida.

## Como usar o include

Para incluir eventos em suas requisições da API, adicione o parâmetro `&include=events`:

```
https://api.sportmonks.com/v3/football/fixtures/{fixture_ID}?api_token=YOUR_TOKEN&include=events
```

## Campos dos Eventos

| Campo | Descrição |
|-------|-----------|
| `id` | Identificador único para cada evento |
| `fixture_id` | ID da partida associada |
| `team_id` | ID da equipe relacionada ao evento |
| `player_id` | ID do jogador associado ao evento |
| `related_player_id` | Liga eventos relacionados (ex: gol e assistência) |
| `minute` | Minuto em que o evento ocorreu |
| `sort_order` | Ordem cronológica dos eventos |

## Tipos de Eventos

### Eventos de Gol

- **GOAL**: Quando um gol é marcado
- **OWN GOAL**: Quando um gol contra é marcado

**Nota**: O `related_player_id` será o jogador que deu a assistência para o gol (pode estar em branco se não houve assistência).

### Eventos de Cartão

- **YELLOWCARD**: Quando um jogador recebe cartão amarelo
- **REDCARD**: Quando um jogador recebe cartão vermelho direto
- **YELLOWREDCARD**: Quando um jogador recebe o segundo cartão amarelo resultando em vermelho

### Eventos de Pênalti

**Durante o jogo:**
- **PENALTY**: Quando o pênalti é convertido
- **MISSED_PENALTY**: Quando o pênalti é perdido

**Durante disputa de pênaltis:**
- **PENALTY_SHOOTOUT_GOAL**: Pênalti convertido na disputa
- **PENALTY_SHOOTOUT_MISS**: Pênalti perdido na disputa

### Substituições

- **SUBSTITUTION**: Única substituição disponível
  - `player_id`: Jogador que entra em campo
  - `related_player_id`: Jogador que sai de campo

### Eventos VAR

- **VAR_CARD**: Verificação VAR para possível cartão
- **Goal Disallowed**: Gol inicialmente concedido mas anulado após revisão VAR
- **Penalty Disallowed**: Pênalti inicialmente concedido mas anulado após revisão VAR
- **Penalty confirmed**: Pênalti confirmado após revisão VAR
- **Goal cancelled**: Gol cancelado após revisão VAR
- **Goal confirmed**: Gol confirmado após revisão VAR
- **Goal under review**: Gol sob revisão VAR

## Includes Extras

### `events.type`
Permite acessar mais dados sobre o tipo específico de evento que ocorreu.

### `events.subType`
Permite acessar dados mais detalhados relacionados a um evento, como gols, que se enquadram em um determinado tipo.

### `events.player`
Fornece informações detalhadas sobre os jogadores relacionados ao evento da partida.

### `events.relatedPlayer`
Fornece informações sobre o jogador relacionado a este evento.

## Sort Order para Eventos

Cada evento agora recebe um valor numérico no campo `sort_order` baseado em sua ocorrência. Este recurso é especialmente útil para garantir que eventos como substituições, gols e decisões VAR sejam exibidos na sequência cronológica correta.

**Benefícios:**
- Exibição correta de múltiplos eventos do mesmo tipo
- Representação mais clara e intuitiva dos eventos da partida
- Análise precisa de momentos complexos como múltiplas substituições ou verificações VAR
