# Immagine n8n estesa con i moduli necessari ai Code Node:
# - sharp           -> composizione tipografica sull'immagine generata
# - better-sqlite3  -> accesso al DB locale delle citazioni
#
# Estendiamo l'immagine ufficiale n8n (Alpine) e installiamo i moduli
# nel node_modules globale di n8n cosi' siano risolvibili dai Function/Code
# Node tramite NODE_FUNCTION_ALLOW_EXTERNAL.
FROM n8nio/n8n:latest

USER root

# Toolchain di build (rimossa a fine installazione) + libreria runtime per sharp (vips).
RUN apk add --no-cache --virtual .build-deps python3 make g++ vips-dev \
    && apk add --no-cache vips \
    && cd /usr/local/lib/node_modules/n8n \
    && npm install --omit=dev sharp better-sqlite3 \
    && apk del .build-deps \
    && rm -rf /root/.npm /tmp/*

# Cartella DB persistita via volume (vedi docker-compose.yml).
RUN mkdir -p /data/database && chown -R node:node /data

USER node
