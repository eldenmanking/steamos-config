# Colored log helpers. error exits the script.
info()  { printf '\033[32m[info]\033[0m %s\n' "$*"; }
warn()  { printf '\033[33m[warn]\033[0m %s\n' "$*" >&2; }
error() { printf '\033[31m[error]\033[0m %s\n' "$*" >&2; exit 1; }
