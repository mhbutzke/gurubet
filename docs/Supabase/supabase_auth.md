# Auth - Supabase

## Visão Geral

O Supabase Auth facilita a implementação de autenticação e autorização em aplicações. Fornece SDKs cliente e endpoints de API para criar e gerenciar usuários, suportando múltiplos métodos de autenticação populares.

## Conceitos Fundamentais

### Autenticação vs Autorização
- **Autenticação**: Verificar se um usuário é quem diz ser
- **Autorização**: Verificar quais recursos um usuário tem permissão para acessar

### Tecnologia Base
- Utiliza JSON Web Tokens (JWTs) para autenticação
- Integração com funcionalidades de banco de dados do Supabase
- Row Level Security (RLS) para autorização granular

## Métodos de Autenticação Suportados

### Autenticação por Senha
- Login tradicional com email e senha
- Gerenciamento seguro de credenciais

### Magic Link e OTP
- Login sem senha via magic links
- One-Time Password (OTP) por email
- Experiência de usuário simplificada

### Autenticação Social (OAuth)
- Múltiplos provedores suportados
- Integração com plataformas populares
- Configuração simplificada

### Autenticação por Telefone
- Login via SMS
- Integração com provedores SMS terceiros
- Verificação por código

### Enterprise SSO
- Single Sign-On para empresas
- Suporte a SAML
- Integração com sistemas corporativos

### Autenticação Anônima
- Acesso temporário sem registro
- Conversão posterior para usuário registrado

### Web3
- Suporte a carteiras Ethereum e Solana
- Autenticação descentralizada

## Integração com Ecossistema Supabase

### Banco de Dados
- Armazenamento de dados de usuário em schema especial
- Conexão com tabelas próprias via triggers e foreign keys
- Políticas RLS automáticas

### API REST
- Controle de acesso automático à API gerada
- Tokens de autenticação incluídos automaticamente
- Escopo de acesso por linha quando usado com RLS

### Standalone vs Integrado
- Pode ser usado como produto independente
- Integração nativa com todo ecossistema Supabase
- Flexibilidade de implementação

## Recursos de Segurança

### Row Level Security (RLS)
- Controle granular de acesso a dados
- Políticas baseadas em usuário
- Integração automática com JWT

### Multi-Factor Authentication
- Camada adicional de segurança
- Suporte a múltiplos fatores
- Configuração flexível

### CAPTCHA Protection
- Proteção contra bots
- Integração em formulários de registro e login
- Prevenção de ataques automatizados

### Identity Linking
- Vinculação de múltiplas identidades
- Consolidação de contas de usuário
- Experiência unificada

## Funcionalidades Avançadas

### Server-Side Auth
- Helpers para frameworks server-side
- Suporte a Next.js, SvelteKit, Remix
- Renderização do lado servidor

### Hooks de Autenticação
- Lógica customizada em eventos de auth
- Integração com sistemas externos
- Automação de processos

### Mobile Deep Linking
- Redirecionamento para aplicações móveis
- Experiência nativa em dispositivos móveis
- Configuração de URL schemes

## Preços e Limitações

### Modelo de Cobrança
- Monthly Active Users (MAU)
- Monthly Active Third-Party Users
- Monthly Active SSO Users
- Add-ons para MFA avançado

### Considerações de Implementação
- Limites por plano de assinatura
- Escalabilidade automática
- Monitoramento de uso
