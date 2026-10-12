# Sourced by the Xcode "Run Script" build phase before Flutter compiles Dart.
# Adds VAPI_PUBLIC_KEY and API_BASE_URL from .env when the build didn't pass
# them, so launches from Xcode, an IDE Run button, or plain `flutter run` match
# tool/run.sh. Values passed with --dart-define win. Only these two keys are
# read so VAPI_PRIVATE_KEY and the Twilio credentials never reach the app.

_env_file="$SRCROOT/../.env"

_has_define() {
  _saved_ifs=$IFS
  IFS=,
  for _entry in $DART_DEFINES; do
    case "$(printf '%s' "$_entry" | base64 --decode 2>/dev/null)" in
      "$1="*) IFS=$_saved_ifs; return 0 ;;
    esac
  done
  IFS=$_saved_ifs
  return 1
}

if [ -f "$_env_file" ]; then
  for _name in VAPI_PUBLIC_KEY API_BASE_URL; do
    _has_define "$_name" && continue
    _value=$(sed -nE "s/^[[:space:]]*(export[[:space:]]+)?$_name=//p" "$_env_file" |
      tail -n 1 | sed -E "s/^[\"']//; s/[\"'][[:space:]]*$//; s/[[:space:]]*$//")
    [ -n "$_value" ] || continue
    _encoded=$(printf '%s=%s' "$_name" "$_value" | base64 | tr -d '\n')
    DART_DEFINES="${DART_DEFINES:+$DART_DEFINES,}$_encoded"
  done
  export DART_DEFINES
fi
