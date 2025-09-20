# Configuração do Token Supabase

Para usar o Supabase CLI dentro do workspace, você precisa configurar o token de acesso:

## Passo 1: Obter o token

Execute este comando no terminal **fora** do sandbox:
```bash
supabase auth token
```

## Passo 2: Criar o arquivo de token

Copie o token retornado e cole no arquivo:
```bash
echo "SEU_TOKEN_AQUI" > supabase/.access-token
```

**Exemplo:**
```bash
echo "sbp_abc123def456..." > supabase/.access-token
```

## Passo 3: Verificar se funcionou

Após criar o arquivo, teste:
```bash
SUPABASE_ACCESS_TOKEN="$(cat supabase/.access-token)" supabase projects list
```

## Segurança

✅ O arquivo `supabase/.access-token` já está no `.gitignore`  
✅ Não será versionado no Git  
✅ Token fica local apenas no seu workspace  

## Comandos CLI Disponíveis

Após configurar, você pode usar:

```bash
# Listar projetos
SUPABASE_ACCESS_TOKEN="$(cat supabase/.access-token)" supabase projects list

# Listar edge functions
SUPABASE_ACCESS_TOKEN="$(cat supabase/.access-token)" supabase functions list

# Agendar cron jobs
SUPABASE_ACCESS_TOKEN="$(cat supabase/.access-token)" supabase functions schedule create

# Deploy de funções
SUPABASE_ACCESS_TOKEN="$(cat supabase/.access-token)" supabase functions deploy
```

---
**Avise quando o arquivo `supabase/.access-token` estiver criado para continuarmos!**
