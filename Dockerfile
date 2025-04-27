# === Base Image ===
FROM python:3.11-slim-bullseye

# === System Dependencies (Pandoc) ===
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    pandoc \
    # Füge hier weitere System-Abhängigkeiten hinzu, falls pandoc sie für spezielle Formate braucht (z.B. Schriftarten)
# Cleanup
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/*

# === Setup Application Directory and User ===
WORKDIR /app
# Erstelle User vor dem Kopieren von Dateien, die ihm gehören sollen
RUN useradd --create-home --shell /bin/bash appuser

# === Install Python Dependencies ===
# Kopiere requirements.txt zuerst (Besitzer ist hier noch root, das ist ok)
COPY requirements.txt . 
# Wechsle zum non-root user (Dieser Befehl muss nach RUN useradd kommen)
USER appuser
# Installiere Pakete als appuser ins Home-Verzeichnis
RUN pip install --no-cache-dir --user -r requirements.txt

# === Update PATH (als appuser) ===
# Füge das lokale bin-Verzeichnis des Users zum PATH hinzu (für gunicorn etc.)
ENV PATH="/home/appuser/.local/bin:${PATH}"

# === Copy Application Code ===
# Kopiere app.py (Besitzer wird appuser sein, da USER vorher gesetzt wurde)
COPY app.py . 

# === Expose Port and Define Start Command ===
# Informiere Docker, dass der Container auf Port 5000 lauscht (intern)
EXPOSE 5000
# Definiere den Befehl zum Starten der Anwendung mit Gunicorn (läuft als appuser)
# 'app:app' bedeutet: In der Datei app.py wird die Flask-Instanz 'app' gesucht
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
