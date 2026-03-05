from flask import Flask, Response, request, send_from_directory
import subprocess
import os

app = Flask(__name__)

def text(message, status=200):
    return Response(message, mimetype="text/plain", status=status)

@app.route("/")
def index():
    return send_from_directory(".", "index.html")

@app.route("/webhook/<token>", methods=["POST"])
def webhook(token):
    if token != os.getenv("TOKEN"):
        return text("Forbidden.", 403)

    data = request.json

    content = data.get("content")
    if not content:
        return text("Bad request.", 400)

    file = content.get("slug")
    if not file:
        return text("Bad request.", 400)

    return handle_track(file, data)

@app.route("/track/<file>", methods=["POST"])
def track(file):
    data = request.json
    token = data.get("token")

    if token != os.getenv("TOKEN"):
        return text("Forbidden.", 403)

    return handle_track(file, data)

def handle_track(file, data):
    content = data.get("content")
    if not content:
        return text("Bad request.", 400)

    source = content.get("source_code")
    if not file or not source:
        return text("Bad request.", 400)

    if ".." in file or "'" in file:
        return text("Bad request.", 400)

    repo = os.getenv("ROOT")
    path = os.path.join(repo, file)

    try:
        with open(path, "r") as ref:
            old_source = ref.read()
    except FileNotFoundError:
        old_source = None

    with open(path, "w") as ref:
        ref.write(source)

    if old_source and old_source.strip() == source.strip():
        return text("Not changed.", 200)

    subprocess.check_output(
        f"git add . && git commit -m 'Edited {file}'",
        cwd=repo,
        shell=True
    )
    return text("Committed.", 200)

@app.route("/squash/<file>", methods=["POST"])
def squash(file):
    data = request.json
    token = data.get("token")

    if token != os.getenv("TOKEN"):
        return text("Forbidden.", 403)

    message = data.get("message")
    if not message or not file or ".." in file or "'" in file:
        return text("Bad request.", 400)

    repo = os.getenv("ROOT")

    last_squash_commit = subprocess.check_output(
        ["git", "log", "--grep=squash", "--format=%H", "-n1", "--", file],
        cwd=repo
    ).decode().strip()

    if last_squash_commit:
        target = subprocess.check_output(
            ["git", "rev-parse", f"{last_squash_commit}^"],
            cwd=repo
        ).decode().strip()
    else:
        initial_commit = subprocess.check_output(
            ["git", "rev-list", "--max-parents=0", "HEAD"],
            cwd=repo
        ).decode().strip()
        target = f"{initial_commit}^"

    subprocess.run(
        ["git", "reset", "--soft", target, "--", file],
        cwd=repo,
        check=True
    )
    subprocess.run(
        ["git", "commit", "-m", f"(squash) {message}", "--", file],
        cwd=repo,
        check=True
    )

    return text(f"Squashed.", 200)

if __name__ == "__main__":
    app.run(debug=True, port=4000)
