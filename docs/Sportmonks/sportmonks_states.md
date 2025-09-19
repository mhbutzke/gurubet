# Estados da API Sportmonks

## Usando o Include

O include `state` permite recuperar informações adicionais sobre o estado atual de uma partida. Incluir o `state` em sua requisição da API garante que a resposta inclua detalhes sobre o estado atual da partida, como se a partida está em andamento, terminou, foi adiada ou está em qualquer outro estado específico.

### Sintaxe
```
https://api.sportmonks.com/v3/football/fixtures?api_token=YOUR_TOKEN&include=state
```

## Filtragem por Estados

Se você quiser filtrar partidas com base em estados específicos, pode usar o parâmetro `&filters=` em sua requisição da API:

```
&filters=fixtureStates:StateIDs
```

### Exemplo: Filtrar partidas atrasadas ou interrompidas
```
https://api.sportmonks.com/v3/football/fixtures?api_token=YOUR_TOKEN&include=state&filters=fixtureStates:16;18
```

## Interações de Estados

Entender como os diferentes estados de partida interagem e fazem transição entre si é crucial para gerenciar efetivamente os dados de futebol.

### Fluxo Principal de Estados

| Estado Atual | Transição Para | Motivo |
|--------------|----------------|--------|
| `NS` (Not Started) | `INPLAY_1ST_HALF` | O jogo começa |
| `INPLAY_1ST_HALF` | `HT` | Quando o jogo chega ao intervalo |
| `HT` | `INPLAY_2ND_HALF` | Quando o intervalo termina |
| `INPLAY_2ND_HALF` | `FT` | Quando o segundo tempo termina |

### Estados de Tempo Extra

| Estado Atual | Transição Para | Motivo |
|--------------|----------------|--------|
| `FT` | `BREAK` | Quando nenhum vencedor foi decidido (geralmente em jogos eliminatórios) |
| `BREAK` | `INPLAY_ET` | Quando a prorrogação começa |
| `INPLAY_ET` | `ETB` | Quando o primeiro tempo da prorrogação termina |
| `ETB` | `INPLAY_ET` | Quando o intervalo curto entre a prorrogação termina |
| `INPLAY_ET` | `AET` | Quando a prorrogação termina |

### Estados de Pênaltis

| Estado Atual | Transição Para | Motivo |
|--------------|----------------|--------|
| `AET` | `PEN_BREAK` | Quando nenhum vencedor foi decidido e a partida vai para os pênaltis |
| `PENB` | `INPLAY_PENALTIES` | Quando a disputa de pênaltis começa |
| `INPLAY_PENALTIES` | `FT_PEN` | Quando a disputa de pênaltis termina |

### Estados de Interrupção/Cancelamento

| Estado Atual | Transição Para | Motivo |
|--------------|----------------|--------|
| `NS` | `SUSPENDED` | Jogo foi suspenso e continuará em outro momento ou dia |
| `NS` | `CANCELLED` | Jogo foi cancelado |
| `NS` | `WALKOVER` | Vitória foi concedida a um participante porque não há outros competidores |
| `NS` | `ABANDONED` | Jogo foi abandonado e continuará em outro momento ou dia |
| `NS` | `DELAYED` | Jogo está atrasado, então começará mais tarde |
| `NS` | `AWARDED` | O vencedor está sendo decidido externamente |
| `NS` | `POSTPONED` | O jogo foi adiado |

## Outros Estados

### Estados Especiais

- **Awarded (`AWAR`)**: Vencedor está sendo decidido externamente
  - Sem transições adicionais. O jogo permanece no estado `Awarded`

- **Interrupted (`INT`)**: O jogo foi interrompido, possivelmente devido ao mau tempo
  - Transições para vários estados baseados no motivo da interrupção

- **Awaiting Updates (`AU`)**: Pode ocorrer quando há problema de conectividade
  - Sem transição imediata. O jogo permanece no estado `Awaiting Updates` até atualizações adicionais

- **Deleted (`DEL`)**: Jogo não está mais disponível via chamadas normais da API porque foi substituído
  - Pode ser recuperado adicionando `&filters=deleted` a uma requisição para o endpoint Fixtures

- **Pending (`PEN`)**: A partida está aguardando uma atualização
  - Sem transição imediata. O jogo permanece no estado `Pending` até atualizações adicionais

## Casos de Uso Práticos

### Monitoramento de Partidas ao Vivo
```
&filters=fixtureStates:1;2;3  // NS, INPLAY_1ST_HALF, HT
```

### Partidas Finalizadas
```
&filters=fixtureStates:5  // FT
```

### Partidas com Problemas
```
&filters=fixtureStates:16;18;19  // DELAYED, INTERRUPTED, SUSPENDED
```
