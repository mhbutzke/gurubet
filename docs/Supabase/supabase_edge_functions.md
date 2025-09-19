# Edge Functions - Supabase

## Visão Geral

As Edge Functions do Supabase são funções TypeScript server-side distribuídas globalmente no edge, próximas aos usuários. Podem ser usadas para escutar webhooks ou integrar projetos Supabase com terceiros como Stripe.

## Tecnologia Base

### Deno Runtime
As Edge Functions são desenvolvidas usando Deno, que oferece vários benefícios:
- **Open Source**: Tecnologia aberta e transparente
- **Portabilidade**: Funciona localmente e em qualquer plataforma compatível com Deno
- **TypeScript First**: Suporte nativo ao TypeScript
- **WASM Support**: Suporte a WebAssembly
- **Distribuição Global**: Baixa latência através de distribuição no edge

## Como Funciona

### Fluxo de Requisição
1. **Request enters edge gateway**: O gateway roteia tráfego, lida com headers de auth/validação JWT e aplica regras de roteamento
2. **Auth & policies applied**: Validação de JWTs do Supabase, aplicação de rate-limits e verificações de segurança centralizadas
3. **Edge runtime executes function**: A função roda em um nó Edge Runtime distribuído regionalmente mais próximo ao usuário
4. **Integrations & data access**: Funções comumente chamam APIs do Supabase ou APIs terceiras
5. **Response returns via gateway**: O gateway encaminha a resposta de volta ao cliente

### Características Técnicas
- **Runtime**: Supabase Edge Runtime (compatível com Deno, TypeScript first)
- **Local Development**: CLI do Supabase para runtime local similar à produção
- **Global Deployment**: Deploy via Dashboard, CLI ou MCP
- **Cold Starts**: Possíveis cold starts - projetar para operações curtas e idempotentes
- **Database Connections**: Tratar Postgres como serviço remoto com pool de conexões

## Quando Usar Edge Functions

### Casos de Uso Ideais
- **Endpoints HTTP autenticados ou públicos** que precisam de baixa latência
- **Webhook receivers** para Stripe, GitHub, etc.
- **Geração on-demand** de imagens ou Open Graph
- **Tarefas pequenas de IA** ou orquestração de chamadas para APIs LLM externas
- **Envio de emails transacionais**
- **Bots de mensagem** para Slack, Discord, etc.

### Limitações
- Não adequadas para jobs longos e pesados
- Workers em background devem ser movidos para outras soluções
- Conexões de banco devem usar estratégias serverless-friendly

## Configuração e Desenvolvimento

### Environment Variables
Armazenamento de credenciais em project secrets do Supabase, acessíveis via variáveis de ambiente.

### Managing Dependencies
Suporte nativo a módulos NPM e APIs built-in do Node, facilitando a reutilização de código existente.

### Function Configuration
Configuração flexível de funções através de arquivos de configuração e dashboard.

### Error Handling
Sistema robusto de tratamento de erros com logging integrado.

## Deployment e Produção

### Deploy to Production
Processo simplificado de deploy através de CLI ou dashboard, com versionamento automático.

### Regional Invocations
Capacidade de executar funções em regiões específicas próximas ao banco de dados para otimizar performance.

### Routing
Sistema de roteamento flexível para organizar múltiplas funções.

## Debugging e Monitoramento

### Local Debugging
Ferramentas integradas para debug local usando DevTools do navegador.

### Testing
Framework de testes para validar funções antes do deploy.

### Logging
Sistema de logs abrangente para monitorar execução e performance.

### Troubleshooting
Guias e ferramentas para identificar e resolver problemas comuns.

## Limitações e Preços

### Status Codes
Códigos de status específicos para diferentes cenários de execução.

### Limits
Limitações de tempo de execução, memória e tamanho de payload.

### Pricing
Modelo de preços baseado em invocações e tempo de execução.

## Exemplos e Templates

O Supabase mantém um repositório GitHub com exemplos de Edge Functions cobrindo diversos casos de uso, desde integrações simples até implementações complexas com IA e processamento de dados.
