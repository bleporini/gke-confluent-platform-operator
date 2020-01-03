# GKE Confluent Operator provisioner

These scripts allows to spin up from scratch Confluent Platform managed by [Confluent Operator](https://docs.confluent.io/current/installation/operator/index.html) in [Google Kubernetes Engine](https://cloud.google.com/kubernetes-engine/):
- Creates a Kubernetes cluster in GKE with default parameters: it spawns 9 `n1-standard-1` nodes, 3 in each zones of the selected region.
- Rolls out all steps as defined in [Deploying Confluent Operator and Confluent Platform](https://docs.confluent.io/current/installation/operator/co-deployment.html), each step automatically verified by the script.

The maturity level is far from being a production provisioning tool, it intends to be a helper for quicky spin up a fully operational environment for POCs.

## Prerequisites 

- [gcloud CLI](https://cloud.google.com/sdk/gcloud)
- [kubectl CLI](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [helm](https://helm.sh/)
- Download the latest version of the Confluent Operator Helm charts defined in [https://docs.confluent.io/current/installation/operator/co-deployment.html](https://docs.confluent.io/current/installation/operator/co-deployment.html) / Step 1 
- bash 😎

## Spawning from scratch your cluster

1. Define the following Bash variables in a file:
    - `GCP_PROJECT`: GCP Project where the resources will be provisioned
    - `GCP_REGION`: Region where the resources will be located
    - `CLUSTER_NAME`: Name of the k8s cluster to create
    - `OPERATOR_DIR`: Path of the Confluent Operator directory
1. Edit the `$OPERATOR_DIR/helm/providers/gcp.yaml` and define the zone(s) where your Kubernetes cluster is deployed (`global/provider/kubernetes/deployment/zones` YAML node). You can optionally override any other value in this file to fit with your requirements.
1. Run the `setup.sh` script with the variable file as first argument
1. Wait... 😜

Optionaly you can deploy the [Kuberneted Dashboard UI](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/) by running the `deploy_k8s_dashboard.sh` script.

## Deleting the whole cluster

Run the `teardown.sh` shell script with your variable file as first argument.
