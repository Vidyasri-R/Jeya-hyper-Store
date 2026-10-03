#!/bin/bash
# Creates the Play Store upload key for the customer app — run once, in your own terminal:
#   app/tool/create_upload_key.sh
# You type the password (hidden); it is written only to android/key.properties (git-ignored).
# The key file goes to ~/JeyaKeys/. Back up BOTH the .jks file and the password somewhere safe
# (password manager + a pen drive): every future app update must be signed with this key.
set -euo pipefail
cd "$(dirname "$0")/.."
KEYTOOL="${KEYTOOL:-/opt/homebrew/opt/openjdk@17/bin/keytool}"
DIR="$HOME/JeyaKeys"
JKS="$DIR/jeya-hyperstore-upload.jks"
PROPS="android/key.properties"
if [ -e "$JKS" ] || [ -e "$PROPS" ]; then
  echo "An upload key is already set up ($JKS / $PROPS) — not touching it." >&2
  exit 1
fi
read -r -s -p "Choose a password for the upload key (at least 12 characters): " UPLOAD_KEY_PW; echo
read -r -s -p "Type it again: " again; echo
if [ "$UPLOAD_KEY_PW" != "$again" ]; then echo "The passwords don't match — nothing created." >&2; exit 1; fi
if [ ${#UPLOAD_KEY_PW} -lt 12 ]; then echo "Please use at least 12 characters — nothing created." >&2; exit 1; fi
mkdir -p "$DIR"; chmod 700 "$DIR"
export UPLOAD_KEY_PW
"$KEYTOOL" -genkeypair -keystore "$JKS" -storetype PKCS12 -alias upload -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass:env UPLOAD_KEY_PW -keypass:env UPLOAD_KEY_PW \
  -dname "CN=Jeya Hyper Store, O=Jeya Hyper Store, L=Tiruchirappalli, ST=Tamil Nadu, C=IN" >/dev/null
chmod 600 "$JKS"
umask 077
printf 'storeFile=%s\nstorePassword=%s\nkeyAlias=upload\nkeyPassword=%s\n' "$JKS" "$UPLOAD_KEY_PW" "$UPLOAD_KEY_PW" > "$PROPS"
unset UPLOAD_KEY_PW again
echo "Upload key created: $JKS"
echo "Release builds are now signed with it. Back up the .jks file and the password today."
