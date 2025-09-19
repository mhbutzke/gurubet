# Storage - Supabase

## Visão Geral

O Supabase Storage simplifica o upload e servir arquivos de qualquer tamanho, fornecendo um framework robusto para controles de acesso a arquivos. Suporta imagens, vídeos, documentos e qualquer tipo de arquivo.

## Funcionalidades Principais

### Armazenamento Universal
O Storage do Supabase permite armazenar qualquer tipo de arquivo, desde imagens pequenas até vídeos grandes e documentos complexos. O sistema é projetado para escalar automaticamente conforme as necessidades da aplicação.

### CDN Global
Os assets são servidos através de uma CDN global que reduz a latência em mais de 285 cidades ao redor do mundo. Isso garante que os usuários tenham acesso rápido aos arquivos independentemente de sua localização geográfica.

### Otimização de Imagens
O Storage inclui um otimizador de imagens integrado que permite redimensionar e comprimir arquivos de mídia em tempo real. Isso elimina a necessidade de pré-processar imagens em diferentes tamanhos.

## Categorias de Funcionalidades

### Buckets (Baldes)
- **Fundamentals**: Conceitos básicos de organização
- **Creating Buckets**: Criação e configuração de containers

### Segurança
- **Ownership**: Controle de propriedade de arquivos
- **Access Control**: Políticas granulares de acesso

### Uploads
- **Standard Uploads**: Upload tradicional de arquivos
- **Resumable Uploads**: Upload de arquivos grandes com capacidade de retomada
- **S3 Uploads**: Compatibilidade com protocolo S3

### Serving (Servir Arquivos)
- **Serving Assets**: Distribuição eficiente de arquivos
- **Image Transformations**: Transformação de imagens em tempo real
- **Bandwidth & Storage Egress**: Gerenciamento de tráfego

### Gerenciamento
- **Copy / Move Objects**: Operações de arquivo
- **Delete Objects**: Remoção segura de arquivos
- **Limits**: Limitações e quotas

## Recursos Técnicos

### Compatibilidade S3
O Storage oferece compatibilidade com o protocolo S3, permitindo que ferramentas existentes que suportam Amazon S3 funcionem diretamente com o Supabase Storage.

### Uploads Resumíveis
Para arquivos grandes, o sistema suporta uploads resumíveis usando o protocolo TUS (Tus Resumable Upload Standard), garantindo que uploads interrompidos possam ser retomados do ponto onde pararam.

### Transformações de Imagem
As transformações de imagem acontecem on-the-fly, permitindo:
- Redimensionamento dinâmico
- Compressão otimizada
- Conversão de formatos
- Aplicação de filtros

## Integração e Segurança

### Row Level Security
O Storage se integra com o sistema de autenticação do Supabase, permitindo políticas de acesso baseadas em Row Level Security (RLS) que controlam quem pode acessar quais arquivos.

### Controle de Acesso Granular
É possível definir políticas específicas para:
- Upload de arquivos
- Download de arquivos
- Modificação de metadados
- Exclusão de arquivos

## Exemplos e Templates

### Resumable Uploads com Uppy
O Supabase fornece exemplos de integração com a biblioteca Uppy para implementar uploads resumíveis de forma simples e eficiente.

### API e Documentação
- **Supabase Storage API**: Código fonte disponível
- **OpenAPI Spec**: Documentação Swagger completa
- **Templates**: Exemplos práticos no repositório GitHub

## Casos de Uso Comuns

### Aplicações de Mídia
Ideal para aplicações que precisam gerenciar grandes volumes de imagens, vídeos ou documentos com acesso rápido e transformações dinâmicas.

### Sistemas de Backup
Pode ser usado como sistema de backup confiável com versionamento e controle de acesso granular.

### Distribuição de Conteúdo
Perfeito para distribuir conteúdo estático com baixa latência através da CDN global integrada.
