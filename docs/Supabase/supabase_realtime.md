# Realtime - Supabase

## Visão Geral

O Supabase Realtime é um serviço distribuído globalmente que permite enviar e receber mensagens entre clientes conectados. Oferece funcionalidades essenciais para aplicações em tempo real modernas.

## Funcionalidades Principais

### Broadcast
O Broadcast permite enviar mensagens de baixa latência entre clientes conectados. É perfeito para implementar mensagens em tempo real, notificações de mudanças no banco de dados, rastreamento de cursor, eventos de jogos e notificações customizadas.

### Presence
O Presence rastreia e sincroniza o estado do usuário entre clientes. É ideal para mostrar quem está online, participantes ativos em uma sessão, indicadores de digitação e status de atividade em tempo real.

### Postgres Changes
Esta funcionalidade permite escutar mudanças no banco de dados em tempo real através de WebSockets. Qualquer inserção, atualização ou exclusão no banco pode ser capturada instantaneamente pelos clientes conectados.

## Casos de Uso Práticos

### Aplicações de Chat
Implementação de mensagens em tempo real com indicadores de digitação e presença online. O sistema permite criar experiências de comunicação fluidas e responsivas.

### Ferramentas Colaborativas
Desenvolvimento de editores de documentos colaborativos, whiteboards compartilhados e espaços de trabalho onde múltiplos usuários podem interagir simultaneamente.

### Dashboards ao Vivo
Criação de visualizações de dados em tempo real e sistemas de monitoramento que atualizam automaticamente conforme os dados mudam.

### Jogos Multiplayer
Sincronização de estado de jogo e interações entre jogadores, permitindo experiências de jogo em tempo real responsivas e sincronizadas.

### Recursos Sociais
Implementação de notificações ao vivo, reações em tempo real e feeds de atividade de usuário que mantêm os usuários engajados.

## Arquitetura e Tecnologia

### Distribuição Global
O serviço Realtime é distribuído globalmente, garantindo baixa latência independentemente da localização dos usuários. Isso é crucial para aplicações que precisam de responsividade em tempo real.

### WebSockets
Toda a comunicação em tempo real acontece através de WebSockets, proporcionando conexões bidirecionais eficientes e de baixa latência entre cliente e servidor.

### Integração com Database
O Realtime se integra nativamente com o banco de dados Postgres do Supabase, permitindo que mudanças no banco sejam automaticamente propagadas para os clientes conectados.

## Recursos de Segurança

### Authorization
O sistema inclui recursos de autorização para Broadcast e Presence, permitindo controlar quem pode enviar mensagens e participar de canais específicos.

### Broadcast from Database
É possível fazer broadcast diretamente do banco de dados, permitindo que triggers e funções do Postgres enviem mensagens em tempo real.

### Políticas de Acesso
Integração com o sistema de autenticação do Supabase permite implementar políticas granulares de acesso aos recursos Realtime.

## Configuração e Gerenciamento

### Settings
O Realtime oferece configurações flexíveis para ajustar o comportamento do serviço conforme as necessidades específicas da aplicação.

### Quotas e Limites
O serviço inclui sistema de quotas para gerenciar o uso e garantir performance consistente.

### Monitoramento
Ferramentas integradas para monitorar conexões, mensagens e performance do sistema Realtime.

## Guias e Exemplos

### Getting Started
Guia completo para começar a usar o Realtime em projetos novos ou existentes.

### Framework-Specific Guides
- **Next.js**: Integração específica com Next.js
- **Flutter**: Uso do Realtime em aplicações Flutter
- **Postgres Changes**: Guias específicos para escutar mudanças no banco

### Exemplos Práticos
- **Multiplayer.dev**: Aplicação showcase mostrando cursores em tempo real
- **Chat**: Componente de chat usando Broadcast para mensagens instantâneas
