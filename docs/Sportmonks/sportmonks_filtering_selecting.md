

## Selecionando Campos

A API 3.0 introduz a possibilidade de solicitar campos específicos em entidades. Isso é útil quando você usa apenas campos específicos em uma resposta da API. A vantagem de selecionar campos específicos é que isso reduz a velocidade da resposta, principalmente em respostas grandes. Além de reduzir o tempo de resposta, o tamanho da resposta também pode ser drasticamente reduzido.

### Selecionar um campo específico

Usando o endpoint de fixtures, você pode selecionar campos específicos da entidade de fixtures. Você pode fazer isso adicionando `&select={campos específicos na entidade base}`.

**Exemplo:**
```
https://api.sportmonks.com/v3/football/fixtures/18535517?api_token=YOUR_TOKEN&select=name
```

### Selecionar um campo específico em um include

Você também pode usar a seleção de campos com base em includes. Como estamos usando o include `lineups.player`, a primeira entidade base é `players`. Podemos selecionar todos os campos dessa entidade. Em nosso exemplo, você precisa selecionar `display_name` e `image_path`.

A segunda entidade base é `countries`. Assim como na entidade do jogador, podemos selecionar todos os campos da entidade `countries`. Em nosso exemplo, você precisa selecionar `name` e `image_path`.

**Exemplo:**
```
https://api.sportmonks.com/v3/football/fixtures/18535517?api_token=YOUR_TOKEN&include=lineups.player:display_name,image_path;lineups.player.country:name,image_path
```



## Filtrando

Neste tutorial, exploraremos como você pode filtrar solicitações de dados para recuperar precisamente as informações de que precisa. A filtragem permite que você personalize suas chamadas de API para seus requisitos específicos, tornando a recuperação de dados mais eficiente e direcionada.

### Entendendo os conceitos básicos de filtragem

Existem dois tipos principais de filtros:

1.  **Filtros estáticos:** esses filtros sempre operam da mesma maneira predefinida, sem nenhuma opção personalizada.
2.  **Filtros dinâmicos:** esses filtros são baseados em entidades e includes, proporcionando mais flexibilidade nas opções de filtragem.

### Como usar filtros dinâmicos

Os filtros dinâmicos são baseados em entidades, permitindo que você especifique a entidade que deseja filtrar e aplique os critérios de acordo. Além disso, eles podem ser combinados com includes para refinar a recuperação de dados de entidades relacionadas, permitindo que você acesse dados detalhados e específicos de acordo com seus requisitos de filtragem.

Para filtrar sua solicitação, você precisa:

1.  Adicionar o parâmetro `&filters=`
2.  Selecionar a entidade que deseja filtrar
3.  Selecionar o campo que deseja filtrar
4.  Preencher os IDs nos quais você está interessado.

**Exemplo:**
```
https://api.sportmonks.com/v3/football/fixtures/18535517?api_token=YOUR_TOKEN&include=events&filters=eventTypes:18
```


