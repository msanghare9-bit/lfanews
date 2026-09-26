"""Envoie une notification pour chaque article publié pas encore annoncé."""
import json
import os
import sys

import requests
from google.auth.transport.requests import Request
from google.oauth2 import service_account

brut = os.environ.get("FIREBASE_SA", "").strip()
if not brut:
    print("Secret FIREBASE_SA absent : rien à faire.")
    sys.exit(0)

sa = json.loads(brut)
projet = sa["project_id"]
cred = service_account.Credentials.from_service_account_info(
    sa,
    scopes=[
        "https://www.googleapis.com/auth/datastore",
        "https://www.googleapis.com/auth/firebase.messaging",
    ],
)
cred.refresh(Request())
H = {"Authorization": "Bearer " + cred.token}
BASE = f"https://firestore.googleapis.com/v1/projects/{projet}/databases/(default)/documents"

requete = {
    "structuredQuery": {
        "from": [{"collectionId": "articles"}],
        "where": {
            "fieldFilter": {
                "field": {"fieldPath": "notifie"},
                "op": "EQUAL",
                "value": {"booleanValue": False},
            }
        },
        "limit": 20,
    }
}
r = requests.post(BASE + ":runQuery", headers=H, json=requete, timeout=30)
r.raise_for_status()

envoyes = 0
for ligne in r.json():
    doc = ligne.get("document")
    if not doc:
        continue
    f = doc.get("fields", {})
    ident = doc["name"].split("/")[-1]
    titre = f.get("titre", {}).get("stringValue", "Nouvel article")
    categorie = f.get("categorie", {}).get("stringValue", "")
    urgent = f.get("urgent", {}).get("booleanValue", False)
    entete = "URGENT" if urgent else (f"LFANEWS · {categorie}" if categorie else "LFANEWS")
    message = {
        "message": {
            "topic": "tous",
            "notification": {"title": entete, "body": titre},
            "data": {"articleId": ident},
            "android": {
                "priority": "HIGH",
                "notification": {"icon": "ic_notification", "color": "#0F6B3A"},
            },
        }
    }
    s = requests.post(
        f"https://fcm.googleapis.com/v1/projects/{projet}/messages:send",
        headers=H, json=message, timeout=30,
    )
    print(ident, s.status_code, s.text[:200])
    if s.ok:
        requests.patch(
            f"{BASE}/articles/{ident}?updateMask.fieldPaths=notifie",
            headers=H, json={"fields": {"notifie": {"booleanValue": True}}}, timeout=30,
        ).raise_for_status()
        envoyes += 1

print(f"{envoyes} notification(s) envoyée(s).")
