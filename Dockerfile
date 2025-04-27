# === Base Image ===
# Verwende ein schlankes Python-Basisimage
FROM python:3.11-slim-bullseye

# === System Dependencies (Node.js, Pandoc) ===
# Setze Umgebungsvariable für non-interactive Installation
ENV DEBIAN_FRONTEND=noninteractive

# Installiere notwendige Tools: curl (für NodeSource), Zertifikate, gnupg (für GPG Key), Pandoc
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    gnupg \
    pandoc \
    # Füge hier weitere System-Abhängigkeiten hinzu, falls docling sie benötigt
# Installiere Node.js (z.B. die LTS Version 20) über das NodeSource Repository
# Schritt 1: GPG Key hinzufügen
&& mkdir -p /etc/apt/keyrings \
&& curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
# Schritt 2: NodeSource Repository hinzufügen
&& NODE_MAJOR=20 \
&& echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
# Schritt 3: Node.js installieren
&& apt-get update && apt-get install nodejs -y \
# Schritt 4: apt-Cache aufräumen
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/*

# === Install docling-js globally ===
# Muss als root ausgeführt werden, bevor zum User gewechselt wird
# Prüfe ggf. die genaue Version oder Kompatibilität von docling-js
RUN npm install -g docling-js

# === Setup Application Directory and User ===
# Definiere das Arbeitsverzeichnis
WORKDIR /app

# Erstelle einen dedizierten User ohne Root-Rechte, um die Anwendung auszuführen
# --shell /bin/bash gibt dem User eine Shell, falls man sich mal einloggen muss
RUN useradd --create-home --shell /bin/bash appuser

# === Install Python Dependencies ===
# Kopiere zuerst nur die requirements.txt, um Docker's Layer Caching zu nutzen
# Stelle sicher, dass der appuser der Besitzer der Datei ist
COPY --chown=appuser:appuser requirements.txt .

# Wechsle zum non-root user, BEVOR Python-Pakete installiert werden
USER appuser

# Installiere Python-Pakete in das Home-Verzeichnis des Users (--user)
# Das vermeidet Rechteprobleme und ist eine gute Praxis
RUN pip install --no-cache-dir --user -r requirements.txt

# Füge das lokale bin-Verzeichnis des Users zum PATH hinzu
# Notwendig, damit der `gunicorn`-Befehl gefunden wird
ENV PATH="/home/appuser/.local/bin:${PATH}"

# === Copy Application Code ===
# Kopiere den Rest des Anwendungscodes (app.py)
# Stelle sicher, dass der appuser der Besitzer ist
COPY --chown=appuser:appuser app.py .

# === Expose Port and Define Start Command ===
# Informiere Docker, dass der Container auf Port 5000 lauscht (intern)
EXPOSE 5000

# Definiere den Befehl zum Starten der Anwendung mit Gunicorn
# Hört auf allen Interfaces (0.0.0.0) auf Port 5000
# 'app:app' bedeutet: In der Datei app.py wird die Flask-Instanz 'app' gesucht
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
