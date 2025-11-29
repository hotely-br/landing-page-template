# --------------------------------------------------------------------------------------
# STAGE 1: Dependency Installation (Instalação de Dependências)
# Instala o pnpm e TODAS as dependências (incluindo devDependencies) necessárias para o build.
# --------------------------------------------------------------------------------------
FROM node:20-alpine AS deps

# Instalar pnpm (crucial para o seu projeto)
RUN npm install -g pnpm

# Definir o diretório de trabalho
WORKDIR /app

# Copiar os arquivos de manifesto. Usamos o pnpm-lock.yaml.
COPY package.json pnpm-lock.yaml ./

# Instalar TODAS as dependências (sem --prod). Isso corrige o MODULE_NOT_FOUND.
RUN pnpm install --frozen-lockfile

# --------------------------------------------------------------------------------------
# STAGE 2: Builder (Construção da Aplicação)
# Copia o código fonte e executa o comando de build do Next.js.
# --------------------------------------------------------------------------------------
FROM node:20-alpine AS builder

# Instalar pnpm (se não estiver disponível, embora não seja estritamente necessário se a instalação for global)
RUN npm install -g pnpm

# Definir o diretório de trabalho
WORKDIR /app

# Copiar arquivos de manifesto e node_modules COMPLETOS (do Stage 1)
COPY package.json pnpm-lock.yaml ./
COPY --from=deps /app/node_modules ./node_modules

# Copiar todo o código fonte
COPY . .

# Comando de Build: Gera o output 'standalone' (essencial para o Docker).
RUN pnpm run build

# --------------------------------------------------------------------------------------
# STAGE 3: Runner (Imagem Final de Produção - Mínima e Segura)
# Esta é a imagem final, minimalista, que será usada em produção.
# --------------------------------------------------------------------------------------
FROM node:20-alpine AS runner

# Definir o diretório de trabalho
WORKDIR /app

# Variáveis de Ambiente
# NODE_ENV precisa ser 'production' para otimizar o Next.js.
ENV NODE_ENV production
# HOST e PORT para que o servidor escute corretamente no ambiente Docker.
ENV HOST 0.0.0.0
ENV PORT 3000

# Criar um grupo e usuário não-root para segurança (boas práticas)
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001

# Copiar a pasta 'standalone' (que inclui os módulos necessários), 'public' e 'static' do Stage Builder
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Definir o usuário que irá executar a aplicação
USER nextjs

# Expor a porta que o app Next.js escutará
EXPOSE 3000

# Comando de Início (Executa o Next.js Standalone Server)
CMD ["node", "server.js"]
