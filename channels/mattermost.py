import os, threading, json, time
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

def _set_last(msg, post_id=""):
    """Store latest user message.

    NOTE: loop.metta detects new messages via string-equality against the
    previous poll. If a user sends the same text twice in a row, the bare
    text would compare equal and Claire would never wake up for the second
    send. We tag every stored message with the Mattermost post ID so that
    even byte-identical text from two different posts produces two different
    strings. Claire treats the [#xxxx] tag as an opaque identifier.
    """
    global _last_message
    with _msg_lock:
        if post_id:
            _last_message = f"[#{post_id[:8]}] {msg}"
        else:
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
    """Connect (and reconnect) to Mattermost websocket with exponential backoff.

    Outer loop: keep trying to (re)establish a connection while _running.
    Inner loop: read events until the connection drops.
    Backoff doubles after each failed attempt, capped at 60s.
    """
    global _ws, _connected, BOT_USER_ID

    ws_url = MM_URL.replace("https", "wss").replace("http", "ws") + "/api/v4/websocket"
    backoff = 2

    while _running:
        ws = None
        try:
            print(f"[Mattermost] Connecting to {ws_url}...")
            ws = websocket.WebSocket()
            ws.connect(ws_url, header=[f"Authorization: Bearer {BOT_TOKEN}"])
            BOT_USER_ID = _get_bot_user_id()
            _ws = ws
            _connected = True
            print(f"[Mattermost] Connected as bot user {BOT_USER_ID[:8]}...")
            backoff = 2  # reset backoff after a successful connection

            # Inner loop: receive events until something breaks
            while _running:
                event = json.loads(ws.recv())
                if event.get("event") == "posted":
                    post = json.loads(event["data"]["post"])
                    if post["channel_id"] == CHANNEL_ID and post["user_id"] != BOT_USER_ID:
                        name = _get_display_name(post["user_id"])
                        _set_last(f"{name}: {post['message']}", post.get("id", ""))
                        print(f"[Mattermost] received post #{post.get('id','')[:8]} from {name} ({len(post['message'])} chars)")

        except Exception as e:
            _connected = False
            print(f"[Mattermost] Connection lost: {type(e).__name__}: {e} -- "
                  f"reconnecting in {backoff}s")
            try:
                if ws is not None:
                    ws.close()
            except Exception:
                pass
            if not _running:
                break
            time.sleep(backoff)
            backoff = min(backoff * 2, 60)  # exponential, capped at 60s

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
    """Post a message to the configured Mattermost channel.
    The websocket and the REST API are independent -- we send via HTTP POST
    regardless of websocket state, so a mid-reconnect blip doesn't drop replies.
    All failures are logged loudly so they never get swallowed into PeTTa as a
    generic skill failure.
    """
    text = text.replace("\\n", "\n")
    if not MM_URL or not CHANNEL_ID or not BOT_TOKEN:
        print("[Mattermost] send_message: NOT CONFIGURED -- dropping message")
        return
    try:
        r = requests.post(
            f"{MM_URL}/api/v4/posts",
            headers=_headers,
            json={"channel_id": CHANNEL_ID, "message": text},
            timeout=10,
        )
        if r.status_code >= 300:
            print(f"[Mattermost] send_message FAILED: HTTP {r.status_code} -- {r.text[:300]}")
        else:
            print(f"[Mattermost] sent ({len(text)} chars)")
    except Exception as e:
        print(f"[Mattermost] send_message EXCEPTION: {type(e).__name__}: {e}")
