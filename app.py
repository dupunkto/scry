from flask import Flask, Response, request

import subprocess
import os

app = Flask(__name__)

@app.route("/")
def index():
    return text("words of prophets are\nwritten on the subway walls.")

@app.route("/track/<token>", methods=["POST"])
def track(token):
    if token != os.getenv("TOKEN"):
        return text("Forbidden.", 403)
    else:
        data = request.json
        change = data.get("change")

        if not change:
            return text("Bad request.", 400)
        else:
            slug = change.get("slug")
            source = change.get("source_code")
            
            if not slug or not source:
                return text("Bad request.", 400)
            else:
                if ".." in slug or "'" in slug:
                    return text("Bad request.", 400)
                else:
                    repo = os.getenv("ROOT")
                    path = os.path.join(repo, f"{slug}.ex")

                    try:
                        with open(path, "r") as ref:
                            old_source = ref.read()
                    except FileNotFoundError:
                        old_source = None

                    with open(path, "w") as ref:
                        ref.write(source)

                    if old_source.strip() == source.strip():
                        return text("Not changed.", 200)
                    else:
                        subprocess.check_output(f"git add . && git commit -m 'Edited {slug}'", cwd=repo, shell=True)
                        return text("Committed.", 200)
            
        

def text(message, status=200):
    return Response(message, mimetype="text/plain", status=status)

if __name__ == "__main__":
    app.run(debug=True, port=4000)
