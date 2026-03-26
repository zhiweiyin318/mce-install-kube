#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# Check required environment variables
if [[ -z "${MCE_VERSION:-}" ]]; then
  echo "Error: MCE_VERSION environment variable must be set."
  exit 1
fi

# Validate MCE_VERSION format (must be a.b.c, where a, b, c are numbers(e.g., 2.14.3).)
if ! [[ "$MCE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: MCE_VERSION must be in the format a.b.c (e.g., 2.14.3)."
  exit 1
fi

echo "# The MCE version is $MCE_VERSION."

branch=$(echo "$MCE_VERSION" | awk -F. '{print $1"."$2}')

rm -rf backplane-operator

git clone --depth 1 --branch "backplane-$branch" https://github.com/stolostron/backplane-operator.git

cp ./backplane-operator/config/crd/bases/multicluster.openshift.io_multiclusterengines.yaml ./hack/mce-chart/crds/
cp ./backplane-operator/config/rbac/role.yaml ./hack/mce-chart/templates/clusterrole.yaml

rm -rf backplane-operator

echo "!!! Update completely !!!"
