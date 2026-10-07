#!/bin/bash
# Creates the signing key for the Jeya Staff Android app — run once, in your own terminal:
#   staff_app/tool/create_release_key.sh
# You type the password (hidden); it is written only to android/key.properties (git-ignored).
# The key file goes to ~/JeyaKeys/. Back up BOTH the .jks file and the password (password manager +
# pen drive): every future APK must be signed with this key, or phones refuse the update.
set -euo pipefail
cd "$(dirname "$0")/.."
KEYTOOL="${KEYTOOL:-/opt/homebrew/opt/openjdk@17/bin/keytool}"
DIR="$HOME/JeyaKeys"
JKS="$DIR/jeya-staff-release.jks"
PROPS="android/key.properties"
if [ -e "$JKS" ] || [ -e "$PROPS" ]; then
  echo "A signing key is already set up ($JKS / $PROPS) — not touching it." >&2
  exit 1
fi
read -r -s -p "Choose a password for the Jeya Staff signing key (at least 12 characters): " KEY_PW; echo
read -r -s -p "Type it again: " again; echo
if [ "$KEY_PW" != "$again" ]; then echo "The passwords don't match — nothing created." >&2; exit 1; fi
if [ ${#KEY_PW} -lt 12 ]; then echo "Please use at least 12 characters — nothing created." >&2; exit 1; fi
mkdir -p "$DIR"; chmod 700 "$DIR"
export KEY_PW
"$KEYTOOL" -genkeypair -keystore "$JKS" -storetype PKCS12 -alias release -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass:env KEY_PW -keypass:env KEY_PW \
  -dname "CN=Jeya Staff, O=Jeya Hyper Store, L=Tiruchirappalli, ST=Tamil Nadu, C=IN" >/dev/null
chmod 600 "$JKS"
umask 077
printf 'storeFile=%s\nstorePassword=%s\nkeyAlias=release\nkeyPassword=%s\n' "$JKS" "$KEY_PW" "$KEY_PW" > "$PROPS"
unset KEY_PW again
echo "Signing key created: $JKS"
echo "Back up the .jks file and the password today."
