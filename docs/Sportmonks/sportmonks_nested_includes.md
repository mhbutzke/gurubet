# Nested Includes da API Sportmonks

## O que são Nested Includes?

Os nested includes permitem enriquecer ainda mais seus dados solicitando informações adicionais de um include padrão. Eles são representados na forma de pontos (.), que são então vinculados a um include padrão, mostrando sua relação.

## Como usar Nested Includes

### Sintaxe
- Use pontos (.) para conectar includes aninhados
- Exemplo: `events.player` - obtém dados do evento e do jogador relacionado

### Exemplo Prático

**Requisição básica com includes:**
```
https://api.sportmonks.com/v3/football/fixtures/date/2022-09-03?api_token=YOUR_TOKEN&include=participants;events
```

**Requisição com nested includes:**
```
https://api.sportmonks.com/v3/football/fixtures/date/2022-09-03?api_token=YOUR_TOKEN&include=participants;events.player
```

## Benefícios dos Nested Includes

1. **Enriquecimento de dados**: Permite obter informações relacionadas em uma única requisição
2. **Eficiência**: Reduz o número de chamadas à API necessárias
3. **Flexibilidade**: Permite customizar exatamente quais dados relacionados você precisa

## Exemplo de Uso

Se você quiser saber mais sobre os jogadores que marcaram gols, como país de origem, altura, peso, idade, imagem, etc., é onde o nested include entra em ação!

**Antes (sem nested include):**
- Você recebe apenas dados básicos do evento
- Precisa fazer requisições adicionais para obter dados do jogador

**Depois (com nested include):**
- Você recebe dados do evento E dados completos do jogador em uma única requisição
- Exemplo: `events.player` retorna informações detalhadas do jogador relacionado ao evento

## Estrutura da Resposta

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


## Sintaxe e Relações

### Como saber qual sintaxe usar?

É essencial verificar a resposta da API para ver qual modelo é retornado. Você precisa verificar a relação exata das entidades solicitadas para determinar a sintaxe.

### Nested Includes Mais Importantes

Dois dos nested includes mais negligenciados são:

1. **`players.player`** → Pode ser usado para incluir detalhes do jogador em vários endpoints
   ```
   https://api.sportmonks.com/v3/football/teams/{ID}?api_token=YOUR_TOKEN&include=players.player
   ```

2. **`teams.team`** → Pode ser usado para incluir detalhes da equipe em vários endpoints
   ```
   https://api.sportmonks.com/v3/football/players/{ID}?api_token=YOUR_TOKEN&include=teams.team
   ```

### Exemplo Prático: Transferências de Jogadores

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

### Importante

- Se você usar apenas `players.transfer`, receberá apenas a transferência que levou o jogador à equipe solicitada
- Para obter todas as transferências, você deve incluir primeiro o modelo do jogador usando `.player`
- Sempre verifique a relação exata das entidades solicitadas para determinar a sintaxe correta
