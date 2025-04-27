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

# === Setup Application Directory ===
WORKDIR /app

# === Install Node.js Dependencies (LOKAL, als root) ===
# Kopiere package.json zuerst
COPY package*.json ./ 
# Installiere Node.js Pakete lokal im WORKDIR (/app)
RUN npm install --omit=dev 

# === Setup User ===
# Erstelle User erst NACH npm install
RUN useradd --create-home --shell /bin/bash appuser
# Korrigiere ggf. Besitzer von node_modules (optional, oft nicht nötig)
# RUN chown -R appuser:appuser /app/node_modules

# === Install Python Dependencies ===
# Kopiere requirements.txt jetzt erst (gehört dann root, macht aber nichts)
COPY requirements.txt .
# Wechsle zum non-root user
USER appuser 
# Installiere Pakete als appuser ins Home-Verzeichnis
RUN pip install --no-cache-dir --user -r requirements.txt

# === Update PATH (als appuser) ===
# Füge Python User bin UND lokales node_modules/.bin zum PATH hinzu
ENV PATH="/app/node_modules/.bin:/home/appuser/.local/bin:${PATH}"

# === Copy Application Code ===
# Kopiere app.py (gehört dann root, wird aber nur gelesen)
# Um es appuser zu geben: COPY --chown=appuser:appuser app.py .
COPY app.py . 

# === Expose Port and Define Start Command ===
EXPOSE 5000
# CMD läuft als appuser
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
