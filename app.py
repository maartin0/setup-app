#!/usr/bin/env python3
from flask import Flask, request, redirect, Response, render_template, make_response
from string import ascii_letters, digits
from dotenv import load_dotenv
import subprocess, os, json, base64, sys, urllib.parse

# Create flask app
app = Flask(__name__)

# Some util methods

"""Executes the provided shell command as root (assuming this script is running as root) otherwise as the provided username"""
def execute_shell(command, username=None):
    if username:
        return subprocess.run(["sudo", "-u", username, *command], capture_output=True)
    return subprocess.run(command, capture_output=True)

"""Checks if the provided value is None or an empty string (similar to the javascript equivalent of a nullish value)"""
def is_blank(value):
    return value is None or value == ""

# Load data from .env

environment_defaults = {
    "PASSWORD_MIN_LENGTH": 5,
    "BIND_PORT": 8999,
    "START_PORT": 9000,
    "HOSTNAME": "127.0.0.1"
}

load_dotenv()
for var in environment_defaults.keys():
    value = os.environ.get(var)
    if not is_blank(value):
        environment_defaults[var] = value

MISSING_AUTH_RESPONSE = Response("Invalid auth-key provided", 403)
VALID_USERNAME_CHARS = ascii_letters + digits
AUTH_KEY_POST_NAME = "auth_key"
SESSION_COOKIE_NAME = "code-server-session"
AUTH_GET_KEY_NAME = "key"
TOKEN_STORE_LOCATION = "./tokens.json"
PORT_COUNTER_LOCATION = "./lastport.txt"
PASSWORD_MIN_LENGTH = environment_defaults["PASSWORD_MIN_LENGTH"]
BIND_PORT = int(environment_defaults["BIND_PORT"])
START_PORT = int(environment_defaults["START_PORT"])
HOSTNAME = environment_defaults["HOSTNAME"]
URL_BASE = f"http://{HOSTNAME}"

setup = "setup" in sys.argv

# More util methods, some of which link to scripts in scripts/

"""Generates an SSH public key after adding the private key to the provided users ~/.ssh/authorized_keys file"""
def gen_ssh_key(username):
    return execute_shell(["./scripts/asuser/gen-ssh-key.sh"], username).stdout.decode().strip()

"""Initialises user"""
def init_user(username):
    execute_shell(["./scripts/asroot/initialise-user.sh", username])

"""Changes the provided users password"""
def update_password(username, password):
    execute_shell(["./scripts/asroot/update-password.sh", username, password])

"""Hashes the provided key into a sha256 token"""
def hash_key(key):
    return execute_shell(["./scripts/util/hash-login-key.sh", key]).stdout.decode().strip().split(" ")[0]

"""Generates a 64-character long random base64 string for use as a login token"""
def gen_key():
    return execute_shell(["./scripts/util/gen-login-key.sh"]).stdout.decode().strip()

"""Stores the provided token in TOKEN_STORE_LOCATION"""
def store_token(username, token):
    with open(TOKEN_STORE_LOCATION, "rt+") as token_store_wrt:
        contents = token_store_wrt.read()
        if is_blank(contents):
            contents = "{}"
        parsed = json.loads(contents)
        parsed[token] = username
        token_store_wrt.seek(0)
        token_store_wrt.write(json.dumps(parsed))
        token_store_wrt.truncate()

"""Checks if the provided username is made up of just letters and numbers (i.e safe to use for a linux user)"""
def valid_username(username):
    return not is_blank(username) and len(username) > 0 and all([letter in VALID_USERNAME_CHARS for letter in username])

"""Checks if the provided user is a valid user"""
def is_user(username):
    return valid_username(username) and execute_shell(["id", username]).returncode == 0

"""Checks if the provided user is in the sudoers group"""
def is_admin(username):
    return valid_username(username) and execute_shell(["./scripts/util/has-sudo.sh", username]).returncode == 0

"""Parses the auth key from the URL search params given by AUTH_GET_KEY_NAME"""
def parse_auth_key():
    return request.args.get(AUTH_GET_KEY_NAME, type=str)

"""Gets the user stored in the token store (if any) and returns it's username, otherwise None"""
def get_user(token):
    with open(TOKEN_STORE_LOCATION, "rt") as token_store_rt:
        contents = token_store_rt.read()
        parsed = json.loads(contents)
        return parsed[token] if token in parsed else None

"""Checks if the provided value is valid base64"""
def is_base64(value):
    try:
        return base64.b64encode(base64.b64decode(value)) == value
    except Exception:
        return False

"""Returns None on error and a username on success"""
def parse_auth(auth_key, admin_required=False):
    if is_blank(auth_key) or " " in auth_key:
        return None
    token = hash_key(auth_key)
    username = get_user(token)
    if is_blank(username):
        return None
    if admin_required and not is_admin(username):
        return None
    return username

# Flask routes

@app.route("/")
def index():
    return "Flask server"

@app.route("/bulk")
def bulk():
    auth_key = parse_auth_key()
    username = parse_auth(auth_key, True)
    if is_blank(username):
        return MISSING_AUTH_RESPONSE
    return render_template('bulk.html', auth_key_raw=auth_key, auth_key=urllib.parse.quote(auth_key))

@app.route("/bulk", methods=["POST"])
def bulk_run():
    auth_key = request.form.get(AUTH_KEY_POST_NAME)
    username = parse_auth(auth_key, True)
    if is_blank(username):
        return MISSING_AUTH_RESPONSE
    usernames = request.form.get("usernames")
    generate_url = request.form.get("generate_url") is not None
    purge_existing = request.form.get("purge_existing_urls") is not None
    if is_blank(usernames):
        return Response("Invalid request", 400)
    new_usernames = [username.strip() for username in usernames.split("\n")]
    total = len(new_usernames)
    new_usernames = list(filter(valid_username, new_usernames))
    
    if purge_existing:
        with open(TOKEN_STORE_LOCATION, "rt+") as token_store_wrt:
            contents = token_store_wrt.read()
            parsed = json.loads(contents)
            for token, user in list(parsed.items()):
                if user in new_usernames:
                    del parsed[token]
            token_store_wrt.seek(0)
            token_store_wrt.write(json.dumps(parsed))
            token_store_wrt.truncate()

    successes = len(new_usernames)
    keys = {}
    for new_username in new_usernames:
        init_user(new_username)
        if generate_url:
            key = gen_key()
            token = hash_key(key)
            store_token(new_username, token)
            keys[new_username] = key
    output = "\n".join([f"{user},{URL_BASE}/user?key={urllib.parse.quote(key)}" for user, key in keys.items()])
    result = f"username,url\n{output}"
    return render_template('result.html', auth_key=urllib.parse.quote(auth_key), log_output=f"Created {successes}/{total} users", filename="logins.csv", data=result)

@app.route("/user")
def user():
    auth_key = parse_auth_key()
    username = parse_auth(auth_key)
    if is_blank(username):
        return MISSING_AUTH_RESPONSE
    action = request.args.get("action", type=str)
    response = None
    if action == "launch":
        # Initialise VS code
        if execute_shell(["./scripts/asroot/init-vscode.sh", username]).returncode != 0:
            return Response("Non-zero exit code when initialising vscode", 500)
        # Parse session cookie
        hash_value = execute_shell(["./scripts/asuser/parse-vscode-hash.sh"], username).stdout.decode().strip()
        if is_blank(hash_value):
            return Response("Couldn't find stored hash, try relaunching the session?", 500)
        # Parse service port
        port = execute_shell(["./scripts/asuser/get-port.sh"], username).stdout.decode().strip()
        if is_blank(port):
            return Response("Couldn't find cached port", 500)
        try:
            port = int(port)
        except ValueError:
            return Response("Couldn't parse stored port from cache file", 500)
        if port < START_PORT or port >= 65535:
            return Response("Found an invalid port... aborting", 500)
        # Redirect to VS code proxy
        response = make_response(redirect(f"/code/{username}/"))
        response.set_cookie(SESSION_COOKIE_NAME, urllib.parse.quote(hash_value))
        return response
    elif action == "generate":
        # Generate SSH key
        return render_template('result.html', auth_key=urllib.parse.quote(auth_key), log_output=gen_ssh_key(username))
    # Return user control panel
    return render_template('user.html', auth_key=urllib.parse.quote(auth_key), auth_key_raw=auth_key, username=username, hostname=HOSTNAME, admin=("yes" if is_admin(username) else ""))

@app.route("/user", methods=["POST"])
def change_password():
    auth_key = request.form.get(AUTH_KEY_POST_NAME)
    username = parse_auth(auth_key, True)
    if is_blank(username):
        return MISSING_AUTH_RESPONSE
    password = request.form.get("new_password")
    if len(password) < PASSWORD_MIN_LENGTH:
        return render_template('result.html', auth_key=urllib.parse.quote(auth_key), log_output=f"Password is shorter than minimum length ({PASSWORD_MIN_LENGTH})" )
    return render_template('result.html', auth_key=urllib.parse.quote(auth_key), log_output="Done")

# Initial setup/checks

if not os.path.exists(PORT_COUNTER_LOCATION):
    with open(PORT_COUNTER_LOCATION, "wt+") as file: # wt+ overwrites the file contents
        file.write(str(START_PORT))

if setup:
    print("Running setup...")
    if not os.path.exists(TOKEN_STORE_LOCATION):
        print("Initialising new token store...")
        with open(TOKEN_STORE_LOCATION, "wt+") as token_store_wt:
            token_store_wt.write("{}")
    username = ""
    while is_blank(username) \
        or not is_user(username) \
            or not is_admin(username):
        username = input("Enter user to generate key for (must be a valid user in the 'sudo' group)\n: ")
    key = gen_key()
    token = hash_key(key)
    store_token(username, token)
    print("Generated the following key. Keep it safe!:")
    print(key)
    print("Alternatively, save this URL:")
    print(f"{URL_BASE}/user?key={urllib.parse.quote(key)}")
    exit(0)

if not os.path.exists(TOKEN_STORE_LOCATION):
    print("Couldn't find token store. Try running this script in setup mode: python3 app.py setup")
    exit(3)

with open(TOKEN_STORE_LOCATION, "rt") as token_store_rt:
    if is_blank(token_store_rt.read()):
        print("Detected broken (blank) token store. Try deleting it and running setup again: python3 app.py setup")
        exit(3)

# Run server in development

if __name__ == "__main__" and not setup:
    app.run(debug=False, port=BIND_PORT)