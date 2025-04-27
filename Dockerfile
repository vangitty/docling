# === Base Image ===
FROM python:3.11-slim-bullseye

# === System Dependencies (NUR Pandoc etc.) ===
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    pandoc \
    # Füge hier weitere System-Abhängigkeiten hinzu, falls benötigt (z.B. für Schriftarten)
# Cleanup
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/*

# === Setup Application Directory and User ===
WORKDIR /app
RUN useradd --create-home --shell /bin/bash appuser

# === Install Python Dependencies ===
COPY --chown=appuser:appuser requirements.txt .
USER appuser
RUN pip install --no-cache-dir --user -r requirements.txt

# === Update PATH (nur für Python User bin) ===
ENV PATH="/home/appuser/.local/bin:${PATH}"

# === Copy Application Code ===
COPY --chown=appuser:appuser app.py .

# === Expose Port and Define Start Command ===
EXPOSE 5000
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
