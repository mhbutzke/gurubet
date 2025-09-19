# Sintaxe da API Sportmonks

Esta sintaxe pode ser usada em todos os endpoints. A documentação de cada endpoint descreve as exceções relacionadas à exclusão de alguns campos/relações.

## Parâmetros de Sintaxe

| Sintaxe | Uso | Exemplo |
|---------|-----|---------|
| `&select=` | Selecionar campos específicos na entidade base | `&select=name` |
| `&include=` | Incluir relações | `&include=lineups` |
| `&filters=` | Filtrar sua requisição | `&filters=eventTypes:15` |
| `;` | Marcar fim de relação (aninhada). Você pode começar incluindo outras relações a partir daqui | `&include=lineups;events;participants` |
| `:` | Marcar seleção de campo | `&include=lineups:player_name;events:player_name,related_player_name,minute` |
| `,` | Usado como separação para selecionar ou filtrar em mais IDs | `&include=events:player_name,related_player_name,minute&filters=eventTypes:15` |

## Exemplos Práticos

### Seleção de Campos
```
&select=name
```

### Inclusão de Relações
```
&include=lineups
```

### Filtros
```
&filters=eventTypes:15
```

### Relações Aninhadas com Seleção de Campos
```
&include=lineups:player_name;events:player_name,related_player_name,minute
```

### Filtros Combinados
```
&include=events:player_name,related_player_name,minute&filters=eventTypes:15
```
