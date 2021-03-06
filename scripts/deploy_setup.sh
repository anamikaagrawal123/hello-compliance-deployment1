#!/usr/bin/bash

export IBMCLOUD_API_KEY
export IBMCLOUD_TOOLCHAIN_ID
export IBMCLOUD_IKS_REGION
export IBMCLOUD_IKS_CLUSTER_NAME
export IBMCLOUD_IKS_CLUSTER_NAMESPACE
export IMAGE_PULL_SECRET_NAME
export TARGET_ENVIRONMENT
export HOME
export BREAK_GLASS
export DEPLOYMENT_DELTA

if [ -f /config/api-key ]; then
  IBMCLOUD_API_KEY="$(cat /config/api-key)" # pragma: allowlist secret
else
  IBMCLOUD_API_KEY="$(cat /config/ibmcloud-api-key)" # pragma: allowlist secret
fi

HOME=/root

TARGET_ENVIRONMENT="$(cat /config/environment)"
INVENTORY_PATH="$(cat /config/inventory-path)"
DEPLOYMENT_DELTA_PATH="$(cat /config/deployment-delta-path)"
DEPLOYMENT_DELTA=$(cat "${DEPLOYMENT_DELTA_PATH}")

echo "Target environment: ${TARGET_ENVIRONMENT}"
echo "Deployment Delta (inventory entries with updated artifacts)"
echo ""

echo "$DEPLOYMENT_DELTA" | jq '.'

echo ""
echo "Inventory content"
echo ""

ls -la ${INVENTORY_PATH}

BREAK_GLASS=$(cat /config/break_glass || echo "")
IBMCLOUD_TOOLCHAIN_ID="$(jq -r .toolchain_guid /toolchain/toolchain.json)"
IBMCLOUD_IKS_REGION="$(cat /config/dev-region | awk -F ":" '{print $NF}')"
IBMCLOUD_IKS_CLUSTER_NAMESPACE="$(cat /config/dev-cluster-namespace)"
IBMCLOUD_IKS_CLUSTER_NAME="$(cat /config/cluster-name)"

if [[ -n "$BREAK_GLASS" ]]; then
  export KUBECONFIG
  KUBECONFIG=/config/cluster-cert
else
  IBMCLOUD_IKS_REGION=$(echo "${IBMCLOUD_IKS_REGION}" | awk -F ":" '{print $NF}')
  ibmcloud login -r "$IBMCLOUD_IKS_REGION"
  ibmcloud ks cluster config --cluster "$IBMCLOUD_IKS_CLUSTER_NAME"

  ibmcloud ks cluster get --cluster "${IBMCLOUD_IKS_CLUSTER_NAME}" --json > "${IBMCLOUD_IKS_CLUSTER_NAME}.json"
  # If the target cluster is openshift then make the appropriate additional login with oc tool
  if which oc > /dev/null && jq -e '.type=="openshift"' "${IBMCLOUD_IKS_CLUSTER_NAME}.json" > /dev/null; then
    echo "${IBMCLOUD_IKS_CLUSTER_NAME} is an openshift cluster. Doing the appropriate oc login to target it"
    oc login -u apikey -p "${IBMCLOUD_API_KEY}"
  fi
  #
  # check pull traffic & storage quota in container registry
  #
  if ibmcloud cr quota | grep 'Your account has exceeded its pull traffic quota'; then
    echo "Your account has exceeded its pull traffic quota for the current month. Review your pull traffic quota in the preceding table."
    exit 1
  fi

  if ibmcloud cr quota | grep 'Your account has exceeded its storage quota'; then
    echo "Your account has exceeded its storage quota. You can check your images at https://cloud.ibm.com/kubernetes/registry/main/images"
    exit 1
  fi
fi
