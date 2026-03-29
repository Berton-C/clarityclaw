import socket, threading, random, time

_running = False
_sock = None
_sock_lock = threading.Lock()
_last_message = None
_msg_lock = threading.Lock()
_channel = None
_connected = False
_server = None
_port = None
_nick = None

# Flood protection: Libera.Chat allows ~5 messages per 10 seconds.
# We use a token-bucket rate limiter to stay well under that.
_MSG_INTERVAL = 2.0   # minimum seconds between PRIVMSG sends
_last_send_time = 0.0
_send_rate_lock = threading.Lock()

def _send(cmd):
    with _sock_lock:
        if _sock:
            try:
                _sock.sendall((cmd + "\r\n").encode())
            except OSError:
                pass  # connection lost, will be detected by recv loop

def _send_privmsg(channel, text):
    """Send a single PRIVMSG with rate limiting to avoid flood kicks."""
    global _last_send_time
    with _send_rate_lock:
        now = time.time()
        wait = _MSG_INTERVAL - (now - _last_send_time)
        if wait > 0:
            time.sleep(wait)
        _send(f"PRIVMSG {channel} :{text}")
        _last_send_time = time.time()

def _set_last(msg):
    global _last_message
    with _msg_lock:
        _last_message = msg

def getLastMessage():
    with _msg_lock:
        return _last_message

def _irc_connect(channel, server, port, nick):
    """Single connection attempt. Returns socket on success, None on failure."""
    try:
        sock = socket.socket()
        sock.settimeout(300)  # 5-min timeout — detect dead connections
        sock.connect((server, int(port)))
        sock.sendall((f"NICK {nick}\r\n").encode())
        sock.sendall((f"USER {nick} 0 * :{nick}\r\n").encode())
        return sock
    except Exception as e:
        print(f"[IRC] Connection failed: {e}", flush=True)
        return None

def _irc_loop(channel, server, port, nick):
    global _running, _sock, _connected
    backoff = 1

    while _running:
        print(f"[IRC] Connecting to {server}:{port} as {nick}...", flush=True)
        sock = _irc_connect(channel, server, port, nick)
        if not sock:
            print(f"[IRC] Retrying in {backoff}s...", flush=True)
            time.sleep(backoff)
            backoff = min(backoff * 2, 120)
            continue

        with _sock_lock:
            _sock = sock

        connected_at = time.time()
        _buf = ""
        try:
            while _running:
                try:
                    data = sock.recv(4096)
                except socket.timeout:
                    # No data for 5 minutes — server likely gone, reconnect
                    print("[IRC] Socket timeout, reconnecting...", flush=True)
                    break
                except OSError:
                    print("[IRC] Socket error, reconnecting...", flush=True)
                    break

                if not data:
                    # Server closed connection (recv returned empty bytes)
                    print("[IRC] Connection closed by server, reconnecting...", flush=True)
                    break

                _buf += data.decode(errors="ignore")
                while "\r\n" in _buf:
                    line, _buf = _buf.split("\r\n", 1)
                    if not line:
                        continue

                    if line.startswith("PING"):
                        _send(f"PONG {line.split()[1]}")

                    parts = line.split()
                    if len(parts) > 1 and parts[1] == "001":
                        _connected = True
                        _send(f"JOIN {channel}")
                        print(f"[IRC] Registered and joined {channel}", flush=True)

                    # Detect server-side kill/error messages
                    elif len(parts) > 1 and parts[1] == "ERROR":
                        reason = line.split(":", 2)[-1] if ":" in line else "unknown"
                        print(f"[IRC] Server ERROR: {reason}", flush=True)

                    elif line.startswith(":") and " PRIVMSG " in line:
                        try:
                            prefix, trailing = line[1:].split(" PRIVMSG ", 1)
                            sender = prefix.split("!", 1)[0]

                            if " :" not in trailing:
                                continue  # malformed, skip

                            msg = trailing.split(" :", 1)[1]
                            _set_last(f"{sender}: {msg}")
                        except Exception:
                            pass  # never let IRC parsing kill the thread

        finally:
            _connected = False
            with _sock_lock:
                _sock = None
            try:
                sock.close()
            except Exception:
                pass

        # Smart backoff: if the connection was short-lived (< 60s),
        # the server is probably rejecting us — apply exponential backoff.
        # If it lasted a long time, reset backoff (was a normal disconnect).
        uptime = time.time() - connected_at
        if uptime < 60:
            backoff = min(backoff * 2, 120)
            print(f"[IRC] Connection lasted only {uptime:.0f}s — backing off {backoff}s", flush=True)
        else:
            backoff = 1
            print(f"[IRC] Connection lasted {uptime:.0f}s — reconnecting immediately", flush=True)

        time.sleep(backoff)

    print("[IRC] Loop stopped.", flush=True)

def start_irc(channel, server="irc.libera.chat", port=6667, nick="mettaclaw"):
    global _running, _channel, _server, _port, _nick
    nick = f"{nick}{random.randint(1000, 9999)}"
    _running = True
    _channel = channel
    _server = server
    _port = port
    _nick = nick
    t = threading.Thread(target=_irc_loop, args=(channel, server, port, nick), daemon=True)
    t.start()
    return t

def stop_irc():
    global _running
    _running = False

def send_message(text):
    """Send a message to the IRC channel, splitting long text across multiple lines.

    IRC has a hard 512-byte limit per raw message (RFC 2812). After accounting
    for 'PRIVMSG #channel :' prefix, sender mask, and CRLF, usable payload is
    roughly 400 chars. We split on newlines first, then chunk any line that
    exceeds the limit. Rate-limited to avoid Libera.Chat flood kicks.

    Long responses are capped at 10 chunks (~4000 chars) to avoid flooding
    the channel. If the response is longer, a truncation notice is appended.
    """
    if not _connected:
        return
    max_len = 400   # conservative — leaves room for protocol overhead
    max_chunks = 10  # cap to avoid flood kicks on very long responses

    # Split on literal \n sequences (MeTTa sends \\n as newline marker)
    parts = text.replace("\\n", "\n").split("\n")
    chunks = []
    for part in parts:
        part = part.strip()
        if not part:
            continue
        # Chunk long lines
        while len(part) > max_len:
            split_at = part.rfind(" ", 0, max_len)
            if split_at == -1:
                split_at = max_len  # no space found, hard break
            chunks.append(part[:split_at])
            part = part[split_at:].lstrip()
        if part:
            chunks.append(part)

    # Enforce chunk cap
    if len(chunks) > max_chunks:
        chunks = chunks[:max_chunks]
        chunks.append("[Response truncated — too long for IRC. Ask me to continue.]")

    for chunk in chunks:
        _send_privmsg(_channel, chunk)
