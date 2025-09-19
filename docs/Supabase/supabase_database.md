# Database - Supabase

## Visão Geral

Cada projeto Supabase vem com um banco de dados Postgres completo, considerado um dos bancos de dados mais estáveis e avançados do mundo. O Supabase torna o Postgres tão fácil de usar quanto uma planilha através de sua interface visual.

## Características Principais

### Postgres Completo
- Cada projeto é um banco de dados Postgres completo
- Acesso de nível `postgres`
- Funcionalidade Realtime através do Realtime Server
- Gerenciamento automático de backups

### Interface Visual
- **Table View**: Interface semelhante a planilha para gerenciar dados
- **Relationships**: Visualização de relacionamentos entre dados
- **Clone Tables**: Duplicação de tabelas como em planilhas
- **SQL Editor**: Editor SQL integrado com capacidade de salvar queries favoritas

### Funcionalidades Avançadas
- Importação direta de dados via CSV ou Excel
- Extensões Postgres habilitadas com um clique
- Backups automáticos (não incluem objetos do Storage API)
- Suporte completo a todas as funcionalidades nativas do PostgreSQL

## Extensões

O Supabase permite expandir a funcionalidade do banco Postgres através de extensões que podem ser habilitadas facilmente pelo dashboard. Isso inclui extensões para:
- Funcionalidades geoespaciais
- Criptografia
- Busca full-text
- E muitas outras

## Terminologia

### Postgres vs PostgreSQL
- **PostgreSQL**: Nome oficial do banco de dados
- **Postgres**: Nome simplificado usado pelo Supabase
- Ambos se referem ao mesmo sistema de banco de dados

## Configurações Importantes

### Senha do Banco
- Possibilidade de resetar a senha do banco de dados
- Configuração de timezone do servidor
- Controle de acesso e permissões

## Integração com Ecossistema Supabase

O banco de dados Postgres do Supabase se integra nativamente com:
- **Auth**: Sistema de autenticação
- **Storage**: Armazenamento de arquivos
- **Realtime**: Funcionalidades em tempo real
- **Edge Functions**: Funções serverless
- **APIs**: REST e GraphQL auto-geradas

## Melhores Práticas

### Backup e Recuperação
- Backups diários automáticos
- Opção de upgrade para Point in Time Recovery
- Importante: Backups não incluem objetos do Storage API

### Segurança
- Row Level Security (RLS) para controle de acesso
- Integração com sistema de autenticação
- Políticas de segurança granulares

### Performance
- Índices otimizados
- Connection pooling
- Monitoramento de performance integrado
