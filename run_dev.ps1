$ErrorActionPreference = "Stop"

if (-not $env:AUTOCLAIR_SUPABASE_URL) {
    throw "Variable AUTOCLAIR_SUPABASE_URL absente."
}

if (-not $env:AUTOCLAIR_SUPABASE_PUBLISHABLE_KEY) {
    throw "Variable AUTOCLAIR_SUPABASE_PUBLISHABLE_KEY absente."
}

$argsList = @(
    "run",
    "--dart-define=SUPABASE_URL=$($env:AUTOCLAIR_SUPABASE_URL)",
    "--dart-define=SUPABASE_PUBLISHABLE_KEY=$($env:AUTOCLAIR_SUPABASE_PUBLISHABLE_KEY)"
)

if ($env:AUTOCLAIR_PASSWORD_RESET_REDIRECT) {
    $argsList += "--dart-define=PASSWORD_RESET_REDIRECT=$($env:AUTOCLAIR_PASSWORD_RESET_REDIRECT)"
}

& flutter @argsList
