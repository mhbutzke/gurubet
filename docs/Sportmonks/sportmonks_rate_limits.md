# Rate Limits da API Sportmonks

## Como funciona o rate limit?

- **Limite padrão**: 3000 chamadas de API por entidade por hora
- **Contagem por entidade**: Todas as requisições para endpoints da mesma entidade contam para o mesmo limite
- **Reset**: O limite é resetado após 1 hora da primeira requisição
- **Exemplo**: Se a primeira requisição for feita às 18:18 UTC, o reset será às 19:18 UTC

## O que acontece quando atinjo o rate limit?

- **Código de resposta**: 429 (Too Many Requests)
- **Comportamento**: Não é possível fazer mais requisições para a entidade que atingiu o limite
- **Outras entidades**: Ainda é possível fazer requisições para outras entidades que não atingiram o limite

## Como verificar quantas requisições restam?

A resposta da API inclui um objeto `rate_limit` com 3 propriedades:

| Propriedade | Significado |
|-------------|-------------|
| `resets_in_seconds` | Segundos restantes antes do reset do rate limit |
| `remaining` | Número de requisições restantes no período atual |
| `requested_entity` | Entidade à qual o rate limit se aplica |

## Exemplo de resposta rate_limit:
```json
{
  "rate_limit": {
    "resets_in_seconds": 2400,
    "remaining": 2850,
    "requested_entity": "teams"
  }
}
```
