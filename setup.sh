#!/usr/bin/env bash
set -e

usage(){
    echo "./setup.sh <configuration file>"
    echo Expected variables are :
    echo GCP_PROJECT: GCP Project where the resources will be provisioned
    echo GCP_REGION: Region where the resources will be located
    echo CLUSTER_NAME: Name of the k8s cluster to create
    echo OPERATOR_DIR: Path of the Confluent Operator directory
}

if [ -z "$1" ] && [ ! -e "$1" ] || [ ! -r "$1" ]
then
    >&2 echo Please provide a configuration file
    usage
    exit -1
fi

. $1

if [ -z "$GCP_PROJECT" ] || [ -z "$GCP_REGION" ] || [ -z "$CLUSTER_NAME" ] || [ -z "$OPERATOR_DIR" ]
then
    >&2 echo Please check configuration variables
    usage
fi

echo Variables:
echo CLUSTER_NAME= $CLUSTER_NAME
echo OPERATOR_DIR= $OPERATOR_DIR
echo GCP_PROJECT= $GCP_PROJECT
echo GCP_REGION= $GCP_REGION


gcloud config set project $GCP_PROJECT
gcloud config set compute/zone $GCP_REGION

gcloud container clusters create $CLUSTER_NAME

gcloud container clusters get-credentials $CLUSTER_NAME

kubectl create serviceaccount tiller -n kube-system

kubectl create clusterrolebinding tiller \
--clusterrole=cluster-admin \
--serviceaccount kube-system:tiller

echo Deploying Helm

helm init --service-account tiller

wait_for_status(){
    local status=$1
    local query=$2
    local nbTries=$3
    local maxTries=$((120))
    local sleepTime=$((2))

    if [ -z "$nbTries" ]; then nbTries=0 ; fi

    if [ $nbTries -gt $maxTries ]
    then
        echo Tried $maxTries to get see if the status is $status, exiting...
        exit -1
    fi

    pod_status=$($query)
    echo Status is $pod_status, expecting $status ...

    if [ "$pod_status" = "$status" ]
    then
        echo "OK"
    else
        nbTries=$(($nbTries + 1))
        sleep $sleepTime
        wait_for_status "$status" $query $nbTries
    fi
}


tiller_query_running(){
    kubectl get pods  -n kube-system -l name=tiller \
        -o jsonpath="{.items[*].status.phase}"
}

wait_for_status "Running" tiller_query_running


metrics_query(){
    kubectl get --raw "/apis/metrics.k8s.io/v1beta1/" > /dev/null 2>&1 && echo OK || echo NOK
}
wait_for_status "OK" metrics_query


cd $OPERATOR_DIR/helm

echo Deploying Confluent Operator 

helm install \
-f ./providers/gcp.yaml \
--name operator \
--namespace operator \
--set operator.enabled=true \
./confluent-operator

kubectl -n operator patch serviceaccount default -p '{"imagePullSecrets": [{"name": "confluent-docker-registry" }]}'

operator_query(){
    kubectl get pods  -n operator  -l app=cc-operator \
        -o jsonpath="{.items[*].status.phase}"
 }
manager_query(){
    kubectl get pods  -n operator  -l app=cc-manager \
        -o jsonpath="{.items[*].status.phase}"
}

wait_for_status "Running" operator_query
wait_for_status "Running" manager_query

crd_kafka_query(){
    set +e #may fail
    kubectl get crd  -n operator \
        --field-selector="metadata.name=kafkaclusters.cluster.confluent.com" \
        -o jsonpath="{.items[*].metadata.name}"
    set -e
}
crd_zk_query(){
    set +e #may fail
    kubectl get crd  -n operator \
        --field-selector="metadata.name=zookeeperclusters.cluster.confluent.com" \
        -o jsonpath="{.items[*].metadata.name}"
    set -e
}

wait_for_status "kafkaclusters.cluster.confluent.com" crd_kafka_query
wait_for_status "zookeeperclusters.cluster.confluent.com" crd_zk_query

command_broker_query(){
    kubectl get broker -n operator > /dev/null 2>&1 && \
        echo Broker command OK|| echo Broker command NOK
}
command_zk_query(){
    kubectl get zookeeper -n operator > /dev/null 2>&1 && \
        echo ZK command OK||  command NOK
}

wait_for_status "Broker command OK" command_broker_query
wait_for_status "ZK command OK" command_zk_query

echo Deploying Zookeeper

helm install \
-f ./providers/gcp.yaml \
--name zookeeper \
--namespace operator \
--set zookeeper.enabled=true \
./confluent-operator

zk_query(){
    kubectl get pods  -n operator  -l type=zookeeper \
        -o jsonpath="{.items[*].status.phase}"
}
wait_for_status "Running Running Running" zk_query

echo Deploying Kafka brokers

helm install \
-f ./providers/gcp.yaml \
--name kafka \
--namespace operator \
--set kafka.enabled=true \
./confluent-operator

kafka_query(){
    kubectl get pods  -n operator  -l type=kafka \
        -o jsonpath="{.items[*].status.phase}"
 }
wait_for_status "Running Running Running" kafka_query




