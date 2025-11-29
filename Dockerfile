# --------------------------------------------------------------------------------------
# STAGE 1: Dependency Installation (Instalação de Dependências)
# Esta etapa garante que as dependências sejam instaladas de forma eficiente e segura.
# --------------------------------------------------------------------------------------
FROM node:20-alpine AS deps

# Definir o diretório de trabalho
WORKDIR /app

# Copiar os arquivos de manifesto (package.json e yarn.lock ou package-lock.json)
COPY package.json yarn.lock* package-lock.json* ./

# Instalar as dependências de produção (necessárias em runtime)
RUN npm install --frozen-lockfile

# --------------------------------------------------------------------------------------
# STAGE 2: Builder (Construção da Aplicação)
# Esta etapa realiza a compilação do código Next.js para o ambiente de produção.
# --------------------------------------------------------------------------------------
FROM node:20-alpine AS builder

# Definir o diretório de trabalho
WORKDIR /app

# Copiar arquivos de manifesto e dependências (do Stage 1)
COPY package.json yarn.lock* package-lock.json* ./
COPY --from=deps /app/node_modules ./node_modules

# Copiar todo o código fonte
COPY . .

# Comando de Build
# O comando de build do Next.js compila o app e gera o output 'standalone'.
RUN npm run build

# --------------------------------------------------------------------------------------
# STAGE 3: Runner (Imagem Final de Produção)
# Esta é a imagem final, mínima e segura, que será usada em produção.
# Ela contém apenas o necessário para executar o output 'standalone'.
# --------------------------------------------------------------------------------------
FROM node:20-alpine AS runner

# Instalar 'dumb-init' para gerenciamento de processos (opcional, mas recomendado)
# RUN apk add --no-cache dumb-init

# Definir o diretório de trabalho
WORKDIR /app

# Variáveis de Ambiente
# NODE_ENV precisa ser 'production' para otimizar o Next.js
ENV NODE_ENV production
# HOST e PORT para que o servidor escute corretamente no ambiente Docker
ENV HOST 0.0.0.0
ENV PORT 3000

# Criar um grupo e usuário não-root para segurança (boas práticas)
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001

# Copiar a pasta 'standalone' e 'public' do Stage Builder
# O output standalone inclui todos os node_modules necessários para a execução
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
# REMOVIDO: A linha abaixo era redundante, pois o .next/standalone já inclui os módulos.
# COPY --from=builder --chown=nextjs:nodejs /app/node_modules ./node_modules 

# Definir o usuário que irá executar a aplicação
USER nextjs

# Expor a porta que o app Next.js escutará
EXPOSE 3000

# Comando de Início (Next.js Standalone Server)
# O Next.js usa o server.js gerado no standalone output
CMD ["node", "server.js"]

# Caso tenha usado 'dumb-init' (descomente a linha RUN e use este CMD alternativo)
# CMD ["dumb-init", "node", "server.js"]
