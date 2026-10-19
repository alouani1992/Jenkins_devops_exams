#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:?Usage: deploy.sh namespace image-tag}"
IMAGE_TAG="${2:?Tag image manquant}"
export KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"

case "$NAMESPACE" in
  dev|qa|staging|prod) ;;
  *) echo "Environnement invalide"; exit 1 ;;
esac

export EXAM_NAMESPACE="$NAMESPACE"

python3 - <<'PY'
import json
import os
import secrets
import subprocess

namespace = os.environ["EXAM_NAMESPACE"]

for service in ("movie", "cast"):
    name = f"jenkins-exam-db-{service}"
    result = subprocess.run(
        ["kubectl", "-n", namespace, "get", "secret", name,
         "--ignore-not-found", "-o", "name"],
        check=True, capture_output=True, text=True
    )
    if result.stdout.strip():
        print(f"{name} : conservé")
        continue

    password = secrets.token_hex(24)
    user = f"{service}_user"
    database = f"{service}_db"

    secret = {
        "apiVersion": "v1",
        "kind": "Secret",
        "metadata": {"name": name, "namespace": namespace},
        "type": "Opaque",
        "stringData": {
            "POSTGRES_USER": user,
            "POSTGRES_PASSWORD": password,
            "POSTGRES_DB": database,
            "DATABASE_URI":
                f"postgresql://{user}:{password}@{name}:5432/{database}"
        }
    }
    subprocess.run(
        ["kubectl", "create", "-f", "-"],
        input=json.dumps(secret), text=True, check=True
    )
PY

helm upgrade --install jenkins-exam-db ./charts-databases \
  --namespace "$NAMESPACE" \
  --wait --timeout 5m

for SERVICE in cast movie; do
  helm upgrade --install "jenkins-exam-$SERVICE" ./charts \
    --namespace "$NAMESPACE" \
    -f charts/values-exam.yaml \
    -f "charts/values-$SERVICE.yaml" \
    --set-string image.tag="$IMAGE_TAG" \
    --wait --timeout 5m
done
