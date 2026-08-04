$ErrorActionPreference = "Stop"

$argsList = @("run")

# Les variables restent utilisables pour remplacer ponctuellement la
# configuration embarquée, mais elles ne sont plus obligatoires.
if ($env:AUTOCLAIR_SUPABASE_URL) {
    $argsList += (
        "--dart-define=SUPABASE_URL=" +
        $env:AUTOCLAIR_SUPABASE_URL
    )
}

if ($env:AUTOCLAIR_SUPABASE_PUBLISHABLE_KEY) {
    $argsList += (
        "--dart-define=SUPABASE_PUBLISHABLE_KEY=" +
        $env:AUTOCLAIR_SUPABASE_PUBLISHABLE_KEY
    )
}

if ($env:AUTOCLAIR_PASSWORD_RESET_REDIRECT) {
    $argsList += (
        "--dart-define=PASSWORD_RESET_REDIRECT=" +
        $env:AUTOCLAIR_PASSWORD_RESET_REDIRECT
    )
}

& flutter @argsList
