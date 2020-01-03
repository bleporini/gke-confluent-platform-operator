#!/usr/bin/env bash
set -e
. $1

gcloud config set project $GCP_PROJECT
gcloud config set compute/zone $GCP_REGION

gcloud container clusters delete $CLUSTER_NAME