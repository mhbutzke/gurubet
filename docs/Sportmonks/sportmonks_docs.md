# Documentação Completa da API Sportmonks

Este documento fornece um guia completo sobre como usar a API Sportmonks, abrangendo desde os limites de taxa até a sintaxe avançada de consulta.



## Rate Limits da API Sportmonks

### Como funciona o rate limit?

- **Limite padrão**: 3000 chamadas de API por entidade por hora
- **Contagem por entidade**: Todas as requisições para endpoints da mesma entidade contam para o mesmo limite
- **Reset**: O limite é resetado após 1 hora da primeira requisição
- **Exemplo**: Se a primeira requisição for feita às 18:18 UTC, o reset será às 19:18 UTC

### O que acontece quando atinjo o rate limit?

- **Código de resposta**: 429 (Too Many Requests)
- **Comportamento**: Não é possível fazer mais requisições para a entidade que atingiu o limite
- **Outras entidades**: Ainda é possível fazer requisições para outras entidades que não atingiram o limite

### Como verificar quantas requisições restam?

A resposta da API inclui um objeto `rate_limit` com 3 propriedades:

| Propriedade | Significado |
|---|---|
| `resets_in_seconds` | Segundos restantes antes do reset do rate limit |
| `remaining` | Número de requisições restantes no período atual |
| `requested_entity` | Entidade à qual o rate limit se aplica |

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



## Sintaxe da API Sportmonks

Esta sintaxe pode ser usada em todos os endpoints. A documentação de cada endpoint descreve as exceções relacionadas à exclusão de alguns campos/relações.

### Parâmetros de Sintaxe

| Sintaxe | Uso | Exemplo |
|---|---|---|
| `&select=` | Selecionar campos específicos na entidade base | `&select=name` |
| `&include=` | Incluir relações | `&include=lineups` |
| `&filters=` | Filtrar sua requisição | `&filters=eventTypes:15` |
| `;` | Marcar fim de relação (aninhada). Você pode começar incluindo outras relações a partir daqui | `&include=lineups;events;participants` |
| `:` | Marcar seleção de campo | `&include=lineups:player_name;events:player_name,related_player_name,minute` |
| `,` | Usado como separação para selecionar ou filtrar em mais IDs | `&include=events:player_name,related_player_name,minute&filters=eventTypes:15` |

### Exemplos Práticos

#### Seleção de Campos
```
&select=name
```

#### Inclusão de Relações
```
&include=lineups
```

#### Filtros
```
&filters=eventTypes:15
```

#### Relações Aninhadas com Seleção de Campos
```
&include=lineups:player_name;events:player_name,related_player_name,minute
```

#### Filtros Combinados
```
&include=events:player_name,related_player_name,minute&filters=eventTypes:15
```



## Includes da API Sportmonks

### O que são Includes?

Os includes são a **pedra angular** da API Sportmonks e permitem enriquecer e personalizar suas requisições. Esta flexibilidade é o que distingue a Sportmonks de todos os concorrentes. Cada endpoint vem com uma lista de includes disponíveis.

### Como Funcionam os Includes

#### Resposta Básica (sem includes)
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

#### Resposta Enriquecida (com includes)
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

### Combinando Múltiplos Includes

Você pode combinar vários includes usando ponto e vírgula (`;`):

```
https://api.sportmonks.com/v3/football/fixtures/date/2022-09-03?api_token=YOUR_TOKEN&include=participants;events
```

Isso retornará:
- **Participants**: Informações detalhadas das equipes
- **Events**: Todos os eventos da partida (gols, cartões, substituições)

### Conceitos Importantes

#### Query Complexity
A API usa um mecanismo de complexidade de consulta para determinar o número de includes que você pode usar. Nem todos os includes funcionam com todos os endpoints.

#### Flexibilidade
- Os includes são basicamente complementos que você pode usar com sua requisição para informações adicionais
- O endpoint fornece dados básicos, enquanto o include fornece informações extras
- Você deve verificar quais includes estão disponíveis por endpoint no guia de referência da API

### Tipos de Includes Disponíveis

#### Includes Básicos
- `participants` - Informações das equipes participantes
- `events` - Eventos da partida (gols, cartões, substituições)
- `lineups` - Escalações das equipes
- `scores` - Placar detalhado
- `states` - Estado da partida
- `periods` - Períodos da partida

#### Includes Avançados
- `ballCoordinates` - Coordenadas da bola
- `pressureIndex` - Índice de pressão
- E muitos outros específicos por endpoint

### Exemplo Prático Completo

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

### Conclusão

A API é muito flexível. Você descobrirá mais sobre a flexibilidade e opções de requisição conforme explora. Nem todos os includes funcionam com todos os endpoints, então certifique-se de verificar quais includes estão disponíveis por endpoint no guia de referência da API.

### Próximos Passos
- Explore **nested includes** para relacionamentos de relacionamentos
- Aprenda sobre **paginação** se não estiver vendo todos os dados esperados
- Consulte tutoriais específicos para cada tipo de include



## Nested Includes da API Sportmonks

### O que são Nested Includes?

Os nested includes permitem enriquecer ainda mais seus dados solicitando informações adicionais de um include padrão. Eles são representados na forma de pontos (.), que são então vinculados a um include padrão, mostrando sua relação.

### Como usar Nested Includes

#### Sintaxe
- Use pontos (.) para conectar includes aninhados
- Exemplo: `events.player` - obtém dados do evento e do jogador relacionado

#### Exemplo Prático

**Requisição básica com includes:**
```
https://api.sportmonks.com/v3/football/fixtures/date/2022-09-03?api_token=YOUR_TOKEN&include=participants;events
```

**Requisição com nested includes:**
```
https://api.sportmonks.com/v3/football/fixtures/date/2022-09-03?api_token=YOUR_TOKEN&include=participants;events.player
```

### Benefícios dos Nested Includes

1. **Enriquecimento de dados**: Permite obter informações relacionadas em uma única requisição
2. **Eficiência**: Reduz o número de chamadas à API necessárias
3. **Flexibilidade**: Permite customizar exatamente quais dados relacionados você precisa

### Exemplo de Uso

Se você quiser saber mais sobre os jogadores que marcaram gols, como país de origem, altura, peso, idade, imagem, etc., é onde o nested include entra em ação!

**Antes (sem nested include):**
- Você recebe apenas dados básicos do evento
- Precisa fazer requisições adicionais para obter dados do jogador

**Depois (com nested include):**
- Você recebe dados do evento E dados completos do jogador em uma única requisição
- Exemplo: `events.player` retorna informações detalhadas do jogador relacionado ao evento

### Estrutura da Resposta

Com nested includes, você recebe uma estrutura hierárquica onde os dados relacionados são aninhados dentro do objeto principal:

```json
{
  "events": {
    "id": 123,
    "type": "goal",
    "player": {
      "id": 456,
      "name": "Nome do Jogador",
      "country": "Brasil",
      "height": 180,
      "weight": 75
    }
  }
}
```

### Sintaxe e Relações

#### Como saber qual sintaxe usar?

É essencial verificar a resposta da API para ver qual modelo é retornado. Você precisa verificar a relação exata das entidades solicitadas para determinar a sintaxe.

#### Nested Includes Mais Importantes

Dois dos nested includes mais negligenciados são:

1. **`players.player`** → Pode ser usado para incluir detalhes do jogador em vários endpoints
   ```
   https://api.sportmonks.com/v3/football/teams/{ID}?api_token=YOUR_TOKEN&include=players.player
   ```

2. **`teams.team`** → Pode ser usado para incluir detalhes da equipe em vários endpoints
   ```
   https://api.sportmonks.com/v3/football/players/{ID}?api_token=YOUR_TOKEN&include=teams.team
   ```

#### Exemplo Prático: Transferências de Jogadores

**Cenário**: Você está interessado nos jogadores de uma equipe específica com todas as transferências históricas do jogador.

**Passo 1 - Requisição básica:**
```
https://api.sportmonks.com/v3/football/teams/{ID}?api_token=YOUR_TOKEN&include=players
```
*Retorna apenas IDs dos jogadores com datas de início e fim, mas não o registro do jogador.*

**Passo 2 - Incluir modelo do jogador:**
```
https://api.sportmonks.com/v3/football/teams/{ID}?api_token=YOUR_TOKEN&include=players.player
```
*Agora você tem acesso aos dados completos do jogador.*

**Passo 3 - Incluir transferências históricas:**
```
https://api.sportmonks.com/v3/football/teams/{ID}?api_token=YOUR_TOKEN&include=players.player.transfers
```
*Agora você pode adicionar o include de transferências para todas as transferências históricas do jogador.*

#### Importante

- Se você usar apenas `players.transfer`, receberá apenas a transferência que levou o jogador à equipe solicitada
- Para obter todas as transferências, você deve incluir primeiro o modelo do jogador usando `.player`
- Sempre verifique a relação exata das entidades solicitadas para determinar a sintaxe correta



## Filtros e Seleção de Campos

Este capítulo ensina como selecionar e filtrar dados da nossa API, o que é útil quando você deseja solicitar dados específicos e pode omitir o resto para um tempo de resposta mais rápido. Você pode filtrar dados para vários parâmetros por endpoint.

### Selecionando Campos

A API 3.0 introduz a possibilidade de solicitar campos específicos em entidades. A vantagem de selecionar campos específicos é que isso reduz a velocidade e o tamanho da resposta.

#### Selecionar um campo específico

Adicione `&select={campos}` para selecionar campos específicos na entidade base.

**Exemplo:**
```
https://api.sportmonks.com/v3/football/fixtures/18535517?api_token=YOUR_TOKEN&select=name
```

#### Selecionar um campo específico em um include

Você também pode usar a seleção de campos com base em includes.

**Exemplo:**
```
https://api.sportmonks.com/v3/football/fixtures/18535517?api_token=YOUR_TOKEN&include=lineups.player:display_name,image_path;lineups.player.country:name,image_path
```

### Filtrando

A filtragem permite que você personalize suas chamadas de API para seus requisitos específicos, tornando a recuperação de dados mais eficiente e direcionada.

#### Tipos de Filtros

1.  **Filtros estáticos:** operam de maneira predefinida.
2.  **Filtros dinâmicos:** baseados em entidades e includes, oferecendo mais flexibilidade.

#### Como usar filtros dinâmicos

Para filtrar sua solicitação, você precisa:

1.  Adicionar o parâmetro `&filters=`
2.  Selecionar a entidade que deseja filtrar
3.  Selecionar o campo que deseja filtrar
4.  Preencher os IDs nos quais você está interessado.

**Exemplo:**
```
https://api.sportmonks.com/v3/football/fixtures/18535517?api_token=YOUR_TOKEN&include=events&filters=eventTypes:18
```


