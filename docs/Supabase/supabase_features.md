# Funcionalidades do Supabase

## Database

### Postgres Database
Cada projeto é um banco de dados Postgres completo com todas as funcionalidades nativas do PostgreSQL.

### Vector Database
Armazenamento de embeddings vetoriais diretamente junto com o resto dos dados, permitindo aplicações de IA e busca semântica.

### Auto-generated REST API via PostgREST
APIs RESTful são geradas automaticamente a partir do banco de dados, sem necessidade de escrever código.

### Auto-generated GraphQL API via pg_graphql
APIs GraphQL rápidas usando extensão customizada do Postgres.

### Database Webhooks
Envio de mudanças do banco de dados para qualquer serviço externo usando Webhooks.

### Secrets and Encryption
Criptografia de dados sensíveis e armazenamento de segredos usando a extensão Supabase Vault.

## Platform

### Database Backups
Projetos têm backup diário com opção de upgrade para Point in Time Recovery.

### Custom Domains
White-label das APIs do Supabase para criar experiência com marca própria.

### Network Restrictions
Restrição de faixas de IP que podem conectar ao banco de dados.

### SSL Enforcement
Forçar clientes Postgres a conectar via SSL.

### Branching
Uso do Supabase Branches para testar e visualizar mudanças.

### Terraform Provider
Gerenciamento da infraestrutura Supabase via Terraform.

### Read Replicas
Deploy de bancos de dados read-only em múltiplas regiões para menor latência.

### Log Drains
Exportação de logs do Supabase para provedores terceiros e ferramentas externas.

## Studio

### Studio Single Sign-On
Login no dashboard do Supabase via SSO.

### Column Privileges
Controle granular de privilégios de colunas.

## Realtime

### Postgres Changes
Recebimento de mudanças do banco de dados através de WebSockets.

### Broadcast
Envio de mensagens entre usuários conectados através de WebSockets.

### Presence
Sincronização de estado compartilhado entre usuários, incluindo status online e indicadores de digitação.

### Authorization
Autorização para Broadcast e Presence.

### Broadcast from Database
Capacidade de fazer broadcast diretamente do banco de dados.

## Auth

### Email Login
Construção de logins por email para aplicação ou website.

### Social Login
Logins sociais - Apple, GitHub, Slack, entre outros.

### Phone Login
Logins por telefone usando provedor SMS terceiro.

### Passwordless Login
Logins sem senha via magic links.

### SSO with SAML
Single Sign-On com SAML.

### Authorization via RLS
Controle de dados que cada usuário pode acessar com Postgres Policies.

### CAPTCHA Protection
Adição de CAPTCHA aos formulários de sign-in, sign-up e reset de senha.

### Server-side Auth
Helpers para implementar autenticação de usuário em linguagens e frameworks server-side populares.

### Third-Party Auth
Integração com provedores de autenticação terceiros.

### Hooks
Hooks de autenticação para lógica customizada.

## Storage

### File Storage
Armazenamento e servir arquivos de forma simples.

### Content Delivery Network (CDN)
Cache de arquivos grandes usando CDN do Supabase.

### Smart CDN
Revalidação automática de assets no edge via Smart CDN.

### Image Transformations
Transformação de imagens em tempo real.

### Resumable Uploads
Upload de arquivos grandes usando uploads resumíveis.

### S3 Compatibility
Interação com Storage através de ferramentas que suportam protocolo S3.

## Edge Functions

### Global Distribution
Funções TypeScript distribuídas globalmente para executar lógica de negócio customizada.

### Regional Invocations
Execução de Edge Function em região próxima ao banco de dados.

### NPM Compatibility
Suporte nativo a módulos NPM e APIs built-in do Node.

## CLI e Management

### CLI
Uso da CLI para desenvolver projeto localmente e fazer deploy na Plataforma Supabase.

### Management API
Gerenciamento de projetos programaticamente.

## Client Libraries

### Oficiais
- JavaScript
- Flutter
- Swift
- Python (Beta)

### Não-oficiais
Bibliotecas suportadas pela comunidade para outras linguagens.

## Estágios de Desenvolvimento

### Private Alpha
Funcionalidades lançadas inicialmente como alpha privado para coletar feedback da comunidade.

### Public Alpha
API pode mudar no futuro, mas serviço é estável. Não coberto pelo SLA de uptime.

### Beta
Testado por testador de penetração externo para questões de segurança. API garantidamente estável.

### Generally Available (GA)
Além dos requisitos Beta, funcionalidades em GA são cobertas pelo SLA de uptime.

## Tabela de Status das Funcionalidades

| Produto | Funcionalidade | Estágio | Disponível Self-hosted |
|---------|----------------|---------|------------------------|
| Database | Postgres | GA | ✅ |
| Database | Vector Database | GA | ✅ |
| Database | Auto-generated REST API | GA | ✅ |
| Database | Auto-generated GraphQL API | GA | ✅ |
| Database | Webhooks | Beta | ✅ |
| Database | Vault | Public Alpha | ✅ |
| Platform | Database Backups | GA | ✅ |
| Platform | Point-in-Time Recovery | GA | 🚧 |
| Platform | Custom Domains | GA | N/A |
| Platform | Network Restrictions | GA | N/A |
| Platform | SSL Enforcement | GA | N/A |
| Platform | Branching | Beta | N/A |
| Platform | Terraform Provider | Public Alpha | N/A |
| Platform | Read Replicas | GA | N/A |
| Platform | Log Drains | Public Alpha | ✅ |
| Studio | Studio | GA | ✅ |
| Studio | SSO | GA | ✅ |
| Studio | Column Privileges | Public Alpha | ✅ |
| Realtime | Postgres Changes | GA | ✅ |
| Realtime | Broadcast | GA | ✅ |
| Realtime | Presence | GA | ✅ |
| Realtime | Broadcast Authorization | Public Beta | ✅ |
| Realtime | Presence Authorization | Public Beta | ✅ |
| Realtime | Broadcast from Database | Public Beta | ✅ |
| Storage | Storage | GA | ✅ |
| Storage | CDN | GA | 🚧 |
| Storage | Smart CDN | GA | 🚧 |
| Storage | Image Transformations | GA | ✅ |
| Storage | Resumable Uploads | GA | ✅ |
| Storage | S3 Compatibility | GA | ✅ |
| Edge Functions | Edge Functions | GA | ✅ |
| Edge Functions | Regional Invocations | GA | ✅ |
| Edge Functions | NPM Compatibility | GA | ✅ |
| Auth | Auth | GA | ✅ |
| Auth | Email Login | GA | ✅ |
| Auth | Social Login | GA | ✅ |
| Auth | Phone Login | GA | ✅ |
| Auth | Passwordless Login | GA | ✅ |
| Auth | SSO with SAML | GA | ✅ |
| Auth | Authorization via RLS | GA | ✅ |
| Auth | CAPTCHA Protection | GA | ✅ |
| Auth | Server-side Auth | Beta | ✅ |
| Auth | Third-Party Auth | GA | ✅ |
| Auth | Hooks | Beta | ✅ |
| CLI | CLI | GA | ✅ |
| Management API | Management API | GA | N/A |
| Client Library | JavaScript | GA | N/A |
| Client Library | Flutter | GA | N/A |
| Client Library | Swift | GA | N/A |
| Client Library | Python | Beta | N/A |

**Legenda:**
- ✅ = Totalmente Disponível
- 🚧 = Disponível, mas requer ferramentas ou configuração externa
- N/A = Não Aplicável
