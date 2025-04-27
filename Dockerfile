# === Base Image ===
FROM python:3.11-slim-bullseye

# === System Dependencies (Node.js, Pandoc) ===
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    gnupg \
    pandoc \
# Install Node.js
&& mkdir -p /etc/apt/keyrings \
&& curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
&& NODE_MAJOR=20 \
&& echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
&& apt-get update && apt-get install nodejs -y \
# Cleanup
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/*

# === Setup Application Directory and User ===
WORKDIR /app
RUN useradd --create-home --shell /bin/bash appuser
# USER wird erst später gewechselt

# === Install Node.js Dependencies (LOKAL) ===
# Kopiere package.json und ggf. package-lock.json
COPY --chown=appuser:appuser package*.json ./ 
# Installiere Node.js Pakete lokal im WORKDIR (/app)
# --omit=dev überspringt devDependencies
RUN npm install --omit=dev 
# Setze Rechte für node_modules, falls nötig (oft nicht erforderlich)
# RUN chown -R appuser:appuser node_modules

# === Install Python Dependencies ===
COPY --chown=appuser:appuser requirements.txt .
USER appuser # JETZT zum User wechseln
RUN pip install --no-cache-dir --user -r requirements.txt

# === Update PATH ===
# Füge Python User bin UND lokales node_modules/.bin zum PATH hinzu
ENV PATH="/app/node_modules/.bin:/home/appuser/.local/bin:${PATH}"

# === Copy Application Code ===
COPY --chown=appuser:appuser app.py .

# === Expose Port and Define Start Command ===
EXPOSE 5000
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
