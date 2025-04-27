# Ausschnitt für Installation von Node.js, Pandoc und docling
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    gnupg \
    pandoc \ 
  && mkdir -p /etc/apt/keyrings \
  && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
  && NODE_MAJOR=20 \ # Oder eine andere LTS Version
  && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
  && apt-get update && apt-get install nodejs -y \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Docling global via npm installieren
RUN npm install -g docling-js 

# ... (Rest: WORKDIR, USER, COPY requirements, pip install, COPY app.py, EXPOSE, CMD) ...
