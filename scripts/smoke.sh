#!/usr/bin/env bash
set -euo pipefail
export KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"
NAMESPACE="${1:?Namespace manquant}"

kubectl exec -i -n "$NAMESPACE" deployment/jenkins-exam-movie -- python - <<'PY'
import json
import urllib.request
from app.api.service import is_cast_present

client = urllib.request.build_opener(urllib.request.ProxyHandler({}))

with client.open("http://127.0.0.1:8000/api/v1/movies/", timeout=15) as response:
    assert response.status == 200
    assert isinstance(json.load(response), list)
print("Lecture films : OK", flush=True)

base = "http://jenkins-exam-cast:8000/api/v1/casts/"
request = urllib.request.Request(
    base,
    data=json.dumps({"name": "Test Jenkins", "nationality": "France"}).encode(),
    headers={"Content-Type": "application/json"},
    method="POST"
)
with client.open(request, timeout=15) as response:
    assert response.status == 201
    actor = json.load(response)

with client.open(base + str(actor["id"]) + "/", timeout=15) as response:
    assert response.status == 200
    assert json.load(response)["name"] == "Test Jenkins"
print("Création et lecture acteur : OK", flush=True)

assert is_cast_present(actor["id"])
print("Communication entre API : OK", flush=True)
PY
