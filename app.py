import os
import subprocess
import tempfile
import logging
from flask import Flask, request, jsonify

# --- Konfiguration ---
# Einfaches Logging konfigurieren
logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s:%(name)s:%(message)s')

app = Flask(__name__)
app.logger.setLevel(logging.INFO) # Flask Logger verwenden

PANDOC_CMD = "pandoc" # Pandoc sollte im PATH sein nach apt-get install
FLASK_PORT = int(os.environ.get("PORT", 5000))

# --- API Endpunkt ---
@app.route('/convert', methods=['POST'])
def convert_document():
    """
    Nimmt eine Datei (DOCX, ODT etc.) per Form-Data ('file') entgegen
    und gibt Markdown im JSON-Body zurück ({ "markdown": "..." }).
    """
    app.logger.info("Received request for /convert")

    # Prüfen, ob der 'file'-Teil in der Anfrage vorhanden ist
    if 'file' not in request.files:
        app.logger.warning("No file part in the request")
        return jsonify({"error": "No file part in the request"}), 400
    
    file = request.files['file']

    # Prüfen, ob ein Dateiname ausgewählt wurde
    if file.filename == '':
        app.logger.warning("No selected file")
        return jsonify({"error": "No selected file"}), 400

    # Suffix für temporäre Datei ermitteln (Pandoc erkennt oft daran das Format)
    file_suffix = os.path.splitext(file.filename)[1]
    # Standard-Suffix hinzufügen, falls keiner vorhanden ist (verhindert Fehler bei NamedTemporaryFile)
    if not file_suffix:
        file_suffix = ".tmp" 

    tmp_file_path = None # Außerhalb definieren für finally-Block
    markdown_output = None
    error_output = None

    try:
        # Temporäre Datei sicher erstellen und Pfad merken
        # delete=False, damit wir den Pfad an subprocess übergeben können
        # und die Datei im finally-Block selbst löschen
        with tempfile.NamedTemporaryFile(delete=False, suffix=file_suffix) as tmp_file:
            file.save(tmp_file.name)
            tmp_file_path = tmp_file.name 
            app.logger.info(f"Saved uploaded file temporarily to {tmp_file_path}")

        # --- Subprocess Aufruf ---
        try:
            # Pandoc aufrufen: Input-Format (-f) wird meist automatisch erkannt
            # Output-Format (-t) ist markdown_strict (oder 'gfm', 'commonmark' etc.)
            # Lese von tmp_file_path (Input), schreibe nach stdout (-o - ist default)
            # Optional: Input-Format explizit angeben, falls Pandoc es nicht errät
            input_format = None 
            if file_suffix.lower() == ".docx":
                input_format = "docx"
            elif file_suffix.lower() == ".odt":
                input_format = "odt"
            # Füge ggf. weitere Formate hinzu

            cmd_list = [PANDOC_CMD]
            if input_format:
                 cmd_list.extend(["-f", input_format])
            # Wähle das gewünschte Markdown-Format
            # markdown_strict, commonmark, gfm (GitHub Flavored Markdown), etc.
            cmd_list.extend(["-t", "markdown_strict", tmp_file_path]) 
            
            app.logger.info(f"Executing command: {' '.join(cmd_list)}")

            process = subprocess.run(
                cmd_list,
                capture_output=True, # stdout und stderr auffangen
                text=True,           # Ein- und Ausgabe als Text behandeln
                encoding='utf-8',    # Kodierung sicherstellen
                check=True           # Löst CalledProcessError aus, wenn pandoc fehlschlägt
            )
            markdown_output = process.stdout
            app.logger.info(f"Pandoc execution successful. Output length: {len(markdown_output)}")

        except subprocess.CalledProcessError as e:
            # Fehler, wenn pandoc einen Fehlercode != 0 zurückgibt
            app.logger.error(f"Pandoc execution failed with code {e.returncode}")
            app.logger.error(f"Pandoc stderr: {e.stderr.strip()}")
            error_output = e.stderr.strip()
        except FileNotFoundError:
             # Fehler, wenn der pandoc-Befehl selbst nicht gefunden wird
             app.logger.error(f"Error: The command '{PANDOC_CMD}' was not found.")
             error_output = f"Command not found: {PANDOC_CMD}"
        except Exception as e:
            # Andere, unerwartete Fehler abfangen
            app.logger.exception("An unexpected error occurred during pandoc conversion.")
            error_output = "Internal server error"

    finally:
        # --- Temporäre Datei sicher löschen ---
        if tmp_file_path and os.path.exists(tmp_file_path):
            try:
                os.remove(tmp_file_path)
                app.logger.info(f"Removed temporary file {tmp_file_path}")
            except OSError as e:
                # Fehler beim Löschen loggen, aber weitermachen
                app.logger.error(f"Error removing temporary file {tmp_file_path}: {e}")

    # --- Antwort senden ---
    if error_output:
         # Fehlername im JSON anpassen
         return jsonify({"error": "Pandoc conversion failed", "details": error_output}), 500
    else:
        # Erfolgreich
        return jsonify({"markdown": markdown_output})

# --- Startpunkt für den Server (nur für lokale Tests relevant, Gunicorn übernimmt im Container) ---
if __name__ == '__main__':
    # Host 0.0.0.0 macht den Server von außerhalb des Containers erreichbar
    # debug=False ist wichtig für Produktion (Gunicorn ignoriert dies aber ohnehin)
    app.run(host='0.0.0.0', port=FLASK_PORT, debug=False)
