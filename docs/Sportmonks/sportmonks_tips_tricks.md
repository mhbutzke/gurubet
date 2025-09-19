# Dicas e Truques da API Sportmonks

## Placar da Partida

### Obtendo Placares
Você pode recuperar os placares de uma partida usando o parâmetro `&include=scores`:

```
https://api.sportmonks.com/v3/football/fixtures/18804545?api_token=YOUR_TOKEN&include=scores
```

### Interpretando Placares
- Os placares são retornados com descrição e tipo
- Exemplos: `1ST_HALF`, `2ND_HALF`
- Use o indicador `CURRENT` para exibir os placares mais recentes, incluindo prorrogação

## Eventos da Partida

### Adicionando Informações do Jogador
Para obter informações detalhadas sobre jogadores relacionados aos eventos:

```
https://api.sportmonks.com/v3/football/fixtures/18804545?api_token=YOUR_TOKEN&include=events.player
```

### Selecionando Campos Específicos
Para recuperar apenas informações específicas do jogador:

```
https://api.sportmonks.com/v3/football/fixtures/{fixture_id}?api_token=YOUR_TOKEN&include=events.player:image_path
```

### Informações Extras de Eventos com SubType

O include `events.subType` fornece informações adicionais sobre eventos específicos:

```
https://api.sportmonks.com/v3/football/fixtures/18804545?api_token=YOUR_TOKEN&include=events.subType
```

**Exemplo de uso:**
- Para gols (`type_id: 14`), o `subType` pode indicar:
  - Se foi marcado com o pé direito
  - Se foi marcado com o pé esquerdo
  - Se foi marcado de cabeça

## Informações Extras da Partida

### Metadata da Partida
Use o include `metadata` para obter informações sobre:
- Condições do campo
- Cores das equipes
- Formações
- Se a escalação está confirmada
- Hashtag da partida (quando disponível)

```
https://api.sportmonks.com/v3/football/fixtures/18535517?api_token=YOUR_TOKEN&include=metadata.type
```

### Formações (Recomendado)
Para obter formações, use o include específico:

```
https://api.sportmonks.com/v3/football/fixtures/18535517?api_token=YOUR_TOKEN&include=formations
```

## Informações Extras do Jogador

### Perfil Completo do Jogador
Para construir um perfil completo, incluindo pé preferido:

```
https://api.sportmonks.com/v3/football/players/580?api_token=YOUR_TOKEN&include=metadata.type
```

### Informações de Metadata do Jogador
- Pé preferido
- Características específicas
- Dados técnicos adicionais

## Detalhes Extras de Artilheiros

### Artilheiros com Transferências
Para jogadores que se transferiram durante a temporada, use:

```
https://api.sportmonks.com/v3/football/seasons/19734?api_token=YOUR_TOKEN&filters=seasonTopscorerTypes:208&include=topscorers.topscorer
```

**Benefícios:**
- Mostra para quais equipes individuais o jogador marcou gols
- Contabiliza transferências durante a temporada
- Fornece histórico detalhado de gols por equipe

## Melhores Práticas

### Sobre Includes de Tipo (.type)
**⚠️ Não recomendado:** Incluir `.type` em endpoints regulares

**✅ Recomendado:** 
- Recuperar todos os tipos do endpoint `/types`
- Armazenar em banco de dados ou estrutura de dados
- Usar apenas quando necessário para testes

### Otimização de Requisições

#### Combine Múltiplos Includes
```
&include=events.player:display_name,image_path;scores;participants:name
```

#### Use Seleção de Campos
```
&include=events.player:display_name&select=name,starting_at
```

#### Filtre Dados Desnecessários
```
&filters=eventTypes:15,17,18&include=events.subType
```

## Casos de Uso Avançados

### Dashboard Completo de Partida
```
https://api.sportmonks.com/v3/football/fixtures/{id}?api_token=YOUR_TOKEN&include=participants:name,image_path;scores;events.player:display_name;events.subType&select=name,starting_at,result_info
```

### Análise Detalhada de Eventos
```
https://api.sportmonks.com/v3/football/fixtures/{id}?api_token=YOUR_TOKEN&include=events.player:display_name,position;events.subType&filters=eventTypes:15
```

### Perfil de Jogador com Estatísticas
```
https://api.sportmonks.com/v3/football/players/{id}?api_token=YOUR_TOKEN&include=metadata.type;statistics;transfers&select=display_name,position,age
```

## Dicas de Performance

1. **Cache de Tipos**: Armazene tipos localmente para evitar includes desnecessários
2. **Seleção Inteligente**: Use `select` para reduzir payload
3. **Filtros Específicos**: Aplique filtros para reduzir dados irrelevantes
4. **Combines Eficientes**: Agrupe includes relacionados em uma única requisição

## Troubleshooting Comum

### Problema: Muitos dados desnecessários
**Solução:** Use seleção de campos específicos

### Problema: Informações de tipo ausentes
**Solução:** Cache tipos separadamente ou use `.type` apenas quando necessário

### Problema: Performance lenta
**Solução:** Reduza includes, use filtros e implemente cache local
