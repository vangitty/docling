# Beispielhafter Flask Code für File Upload und Subprocess (Ausschnitt)
import os
import subprocess
import tempfile
from flask import Flask, request, jsonify

app = Flask(__name__)

# ... (Logging etc. wie im markitdown Beispiel) ...

DOCLING_CMD = "docling" # Befehl nach globaler npm Installation

@app.route('/convert', methods=['POST'])
def convert_docling():
    if 'file' not in request.files:
        return jsonify({"error": "No file part in the request"}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({"error": "No selected file"}), 400

    # Temporäre Datei sicher erstellen
    with tempfile.NamedTemporaryFile(delete=False, suffix=os.path.splitext(file.filename)[1]) as tmp_file:
        file.save(tmp_file.name)
        tmp_file_path = tmp_file.name
        app.logger.info(f"Saved uploaded file temporarily to {tmp_file_path}")

    markdown_output = None
    error_output = None
# ... (innerhalb der try...except Logik)
 try:
     # Pandoc aufrufen: Von docx (-f docx) nach markdown_strict (-t markdown_strict)
     # Lese von tmp_file_path (Input), schreibe nach stdout (-o - wäre explizit, ist aber default)
     cmd = ["pandoc", "-f", "docx", "-t", "markdown_strict", tmp_file_path] 
     app.logger.info(f"Executing command: {' '.join(cmd)}")

     process = subprocess.run(
         cmd,
         capture_output=True, # stdout und stderr auffangen
         text=True,
         encoding='utf-8',
         check=True # Löst CalledProcessError bei Fehler aus
     )
     markdown_output = process.stdout
     app.logger.info(f"Pandoc execution successful. Output length: {len(markdown_output)}")

 except subprocess.CalledProcessError as e:
     app.logger.error(f"Pandoc execution failed with code {e.returncode}")
     app.logger.error(f"Pandoc stderr: {e.stderr.strip()}")
     error_output = e.stderr.strip()
 except FileNotFoundError:
      # Sollte jetzt nicht mehr passieren, da pandoc via apt installiert wird
      app.logger.error("Error: The command 'pandoc' was not found.")
      error_output = "Command not found: pandoc"
 except Exception as e:
     app.logger.exception("An unexpected error occurred during pandoc conversion.")
     error_output = "Internal server error"
 finally:
     # Temporäre Datei immer löschen
     # ... (Rest der finally-Klausel bleibt gleich) ...

 if error_output:
      # Fehlername im JSON anpassen
      return jsonify({"error": "Pandoc conversion failed", "details": error_output}), 500
 else:
     return jsonify({"markdown": markdown_output})
 # ...
