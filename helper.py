from collections import deque
import re
from datetime import datetime

TS_RE = re.compile(r'^\("(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})"')

def extract_timestamp(line):
    m = TS_RE.search(line)
    if not m:
        return None
    try:
        return datetime.strptime(m.group(1), "%Y-%m-%d %H:%M:%S")
    except ValueError:
        return None

def around_time(needle_time_str, k):
    filename = "repos/mettaclaw/memory/history.metta"
    target = datetime.strptime(needle_time_str, "%Y-%m-%d %H:%M:%S")
    best_lineno = None
    best_line = None
    best_diff = None
    buffer = []
    best_idx = None
    with open(filename, "r", encoding="utf-8", errors="replace") as f:
        for lineno, line in enumerate(f, 1):
            buffer.append((lineno, line))
            ts = extract_timestamp(line)
            if ts is None:
                continue
            diff = abs((ts - target).total_seconds())
            if best_diff is None or diff < best_diff:
                best_diff = diff
                best_lineno = lineno
                best_line = line
                best_idx = len(buffer) - 1
    if best_lineno is None:
        return
    start = max(0, best_idx - k)
    end = min(len(buffer), best_idx + k + 1)
    ret = ""
    for lineno, line in buffer[start:end]:
        ret += f"{lineno}:{line}"
    return ret

def extract_after(text, marker):
    """Extract everything after marker in text. Returns 'NONE' if marker not found."""
    if marker in text:
        return text.split(marker, 1)[1].strip()
    return "NONE"

def file_exists(path):
    """Check if a file exists. Returns True/False for MeTTa."""
    import os
    return os.path.exists(path)

def file_exists_int(path):
    """Check if a file exists. Returns 1/0 integer."""
    import os
    return 1 if os.path.exists(path) else 0

def file_exists_str(path):
    """Check if a file exists. Returns string 'true'/'false'."""
    import os
    return "true" if os.path.exists(path) else "false"

def touch_file(path):
    """Create an empty file at path if it does not exist."""
    import os
    d = os.path.dirname(path)
    if d:
        os.makedirs(d, exist_ok=True)
    with open(path, 'a'):
        pass
    return "ok"

def balance_parentheses(s):
    s=s.replace("_quote_", '"')
    s = s.strip()
    left = 0
    while left < len(s) and s[left] == '(':
        left += 1
    right = 0
    while right < len(s) and s[len(s) - 1 - right] == ')':
        right += 1
    core = s[left:len(s) - right if right else len(s)].strip()
    return f"(({core}))"

def soul_eval_prompt(soul_context, situation, person_state):
    """Four-step gap-detection evaluation protocol for ClarityClaw soul."""
    return (
        "You are ClarityClaw soul evaluator. Your task is gap-detection, not keyword-matching. "
        "Work through four steps, then give a verdict. "
        "Step 1 GAP-DETECTION: For each pattern in TIER-A and TIER-B PATTERNS, "
        "apply the GAP-SIGNAL test. Safety and Integrity are always evaluated -- never skip them. "
        "Step 2 TENSION: urgency-narrows-thought / flattery-invites-complicity / "
        "noble-ends-framing / bypass-verification-pressure / authority-theater. "
        "Write yes + label if active, or no. "
        "Step 3 ECOSYSTEM: For each gap in Step 1, check ECOSYSTEM DEGRADATION. "
        "Is the stabilizing partner absent? "
        "Step 4 HIERARCHY: Safety (1) > Integrity (2) > HumanFlourishing (3) > Governance (4) > Helpfulness (5). "
        "Any action serving Helpfulness by bypassing Safety is misaligned. "
        "Any PROCEED for irreversible action while Safety or Integrity gap is active "
        "must cite why the hierarchy permits it. If you cannot, the verdict is PAUSE. "
        "On FLAG or PAUSE: include SOUL-NOTE -- one sentence naming the specific concern "
        "in language the person can hear, not policy language. "
        "Return ONLY: PATTERNS / PERSON-STATE / TASKS / TENSION / VERDICT / SOUL-TONE / REASON / SOUL-NOTE "
        "Soul structure: " + str(soul_context) +
        " Person: " + str(person_state) +
        " Situation: " + str(situation)
    )
