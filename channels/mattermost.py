import os, threading, json
import requests, websocket

_running = False
_ws = None
_ws_lock = threading.Lock()
_last_message = None
_msg_lock = threading.Lock()
_connected = False

# ---- Mattermost config (dummy token ok) ----
MM_URL = "https://chat.singularitynet.io"
CHANNEL_ID = "8fjrmabjx7gupy7e5kjznpt5qh" #NOT AN ID JUST NAME: "mettaclaw"x
BOT_TOKEN = ""

def _get_bot_user_id():
    global _headers
    r = requests.get(
        f"{MM_URL}/api/v4/users/me",
        headers=_headers
    )
    return r.json()["id"]

def _set_last(msg):
    global _last_message
    with _msg_lock:
        _last_message = msg

def getLastMessage():
    with _msg_lock:
        return _last_message

def _get_display_name(user_id):
    r = requests.get(
        f"{MM_URL}/api/v4/users/{user_id}",
        headers=_headers
    )
    u = r.json()

    # Mimic common Mattermost display setting
    if u.get("first_name") or u.get("last_name"):
        return f"{u.get('first_name','')} {u.get('last_name','')}".strip()

    return u["username"]

def _ws_loop():
    global _ws, _connected, BOT_USER_ID

    ws_url = MM_URL.replace("https", "wss").replace("http", "ws") + "/api/v4/websocket"
    ws = websocket.WebSocket()
    ws.connect(ws_url, header=[f"Authorization: Bearer {BOT_TOKEN}"])
    BOT_USER_ID = _get_bot_user_id()
    _ws = ws
    _connected = True

    while _running:
        try:
            event = json.loads(ws.recv())
            if event.get("event") == "posted":
                post = json.loads(event["data"]["post"])
                if post["channel_id"] == CHANNEL_ID and post["user_id"] != BOT_USER_ID:
                    name = _get_display_name(post["user_id"])
                    _set_last(f"{name}: {post['message']}")
        except Exception:
            break

    ws.close()
    _connected = False

def start_mattermost(MM_URL_, CHANNEL_ID_, BOT_TOKEN_):
    """Start Mattermost websocket listener.

    Any empty argument falls back to the corresponding environment variable
    (MM_URL, MM_CHANNEL_ID, MM_BOT_TOKEN). This lets channels.metta keep the
    three values empty so secrets never have to be committed to the repo.
    """
    global _running, MM_URL, CHANNEL_ID, BOT_TOKEN, _headers
    MM_URL     = MM_URL_     or os.environ.get("MM_URL",        "")
    CHANNEL_ID = CHANNEL_ID_ or os.environ.get("MM_CHANNEL_ID", "")
    BOT_TOKEN  = BOT_TOKEN_  or os.environ.get("MM_BOT_TOKEN",  "")
    if not MM_URL or not CHANNEL_ID or not BOT_TOKEN:
        print("[Mattermost] FATAL: MM_URL, MM_CHANNEL_ID, and MM_BOT_TOKEN "
              "must be set (via channels.metta or environment variables).")
        return None
    print(f"[Mattermost] Connecting to {MM_URL} channel {CHANNEL_ID[:8]}...")
    _headers = {"Authorization": f"Bearer {BOT_TOKEN}"}
    _running = True
    t = threading.Thread(target=_ws_loop, daemon=True)
    t.start()
    return t

def stop_mattermost():
    global _running
    _running = False

def send_message(text):
    text = text.replace("\\n", "\n")
    if not _connected:
        return
    requests.post(
        f"{MM_URL}/api/v4/posts",
        headers=_headers,
        json={"channel_id": CHANNEL_ID, "message": text}
    )
