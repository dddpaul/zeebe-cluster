#!/bin/bash
# Combined tips from:
# - https://docs.camunda.io/docs/self-managed/platform-deployment/helm-kubernetes/upgrade/#v830-minor
# - https://medium.com/building-the-open-data-stack/reclaiming-persistent-volumes-in-kubernetes-5e035ba8c770
for i in {0..2}; do
    # Set PersistantVolume as Retain
    ES_PV_NAME="$(kubectl get pvc elasticsearch-master-elasticsearch-master-$i -o jsonpath='{.spec.volumeName}')"
    kubectl patch pv "${ES_PV_NAME}" -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
    kubectl get pv "${ES_PV_NAME}" | grep Retain || echo '[ERROR] Reclaim Policy is not Retain!'

    # Export current PVC (with PV bind) to file
    kubectl get pvc elasticsearch-master-elasticsearch-master-$i -o json | jq "
    .metadata.name = \"data-camunda-elasticsearch-master-$i\"
    | with_entries(
        select([.key] |
            inside([\"metadata\", \"spec\", \"apiVersion\", \"kind\"]))
        )
    | del(
        .metadata.creationTimestamp, .metadata.resourceVersion, .metadata.selfLink, .metadata.uid
        )
    " > /tmp/pvc-data-camunda-elasticsearch-master-$i.json

    # Remove PVC (PV becomes Released)
    kubectl delete pvc elasticsearch-master-elasticsearch-master-$i

    # Unbind PV from PVC (PV becomes Available)
    kubectl patch pv "${ES_PV_NAME}" -p '{"spec":{"claimRef": null}}'
done

# Pre-create new PVC with binds to old PVs
for i in {0..2}; do
    kubectl apply -f /tmp/pvc-data-camunda-elasticsearch-master-$i.json
done
