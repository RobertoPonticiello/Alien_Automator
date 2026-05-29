# Estende l'immagine ufficiale n8nio/n8n:latest aggiungendo solo i due moduli
# che servono ai Code Node:
#   - sharp           (composizione tipografica)
#   - better-sqlite3  (DB citazioni)
#
# Strategia: ci affidiamo ai PREBUILT BINARIES che entrambi i pacchetti pubblicano
# per Linux x64 (sharp porta libvips compilata staticamente, better-sqlite3 porta
# il proprio sqlite3). Niente toolchain/apt-get — bypassiamo il fatto che
# l'immagine ufficiale n8n e' su una distro hardenizzata senza package manager.
#
# Installiamo in /opt/n8n-extra-modules (NON nel global npm prefix dell'immagine,
# che varia tra versioni di n8n). NODE_PATH dice a node dove cercarli.
FROM n8nio/n8n:latest

USER root

ENV npm_config_fetch_retries=10 \
    npm_config_fetch_retry_mintimeout=20000 \
    npm_config_fetch_retry_maxtimeout=120000 \
    npm_config_fetch_timeout=600000

# IMPORTANTE: NIENTE --omit=optional. Sharp distribuisce i prebuilt come
# optionalDependencies; con --omit=optional npm li salta e prova a buildare
# da sorgente, fallendo (mancano gcc/python/libvips-dev).
RUN mkdir -p /opt/n8n-extra-modules \
    && cd /opt/n8n-extra-modules \
    && npm init -y >/dev/null \
    && npm install --no-fund --no-audit sharp better-sqlite3 \
    && (rm -rf /root/.npm /tmp/* /var/tmp/* 2>/dev/null || true)

# Path noto e deterministico per i Code/Function Node.
ENV NODE_PATH=/opt/n8n-extra-modules/node_modules
ENV NODE_FUNCTION_ALLOW_EXTERNAL=sharp,better-sqlite3
ENV NODE_FUNCTION_ALLOW_BUILTIN=fs,path,crypto,util,buffer,stream

# /data/database e' bind-mountato dal compose; n8n gira gia' come utente `node`.
USER node
