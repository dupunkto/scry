from flask import Flask, Response, abort, request, jsonify

import subprocess
import os

app = Flask(__name__)

@app.route("/")
def index():
    return text("words of prophets are\nwritten on the subway walls.")

@app.route("/track/<token>", methods=["POST"])
def track(token):
    if token == os.getenv("TOKEN"):
        data = request.json
        change = data.get("change")

        if change:
            slug = change.get("slug")
            source = change.get("source_code")
            
            if slug and source:
                if ".." in slug or "'" in slug:
                    return text("Bad request.", 400)
                else:
                    repo = os.getenv("ROOT")
                    path = os.path.join(repo, f"{slug}.ex")

                    try:
                        with open(path, 'r') as ref:
                            old_source = ref.read()
                    except FileNotFoundError:
                        old_source = ""

                    with open(path, 'w+') as ref:
                        ref.write(source)

                    if old_source.strip() == source.strip():
                        return text("Not changed.", 200)
                    else:
                        subprocess.check_output(f"git add . && git commit -m 'Edit {slug}'", cwd=repo, shell=True)
                        return text("Committed.", 200)
            else:
                return text("Bad request.", 400)
        else:
            return text("Bad request.", 400)
    else:
        return text("Forbidden.", 403)

def text(message, status=200):
    return Response(message, mimetype="text/plain", status=status)

# Fucking Python. Doe ff normaal man.
if __name__ == "__main__":
    app.run(debug=True, port=4000)
