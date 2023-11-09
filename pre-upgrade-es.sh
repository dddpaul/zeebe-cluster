#!/bin/bash
for i in {0..2}; do
    ES_PV_NAME="$(kubectl get pvc elasticsearch-master-elasticsearch-master-$i -o jsonpath='{.spec.volumeName}')"
    kubectl patch pv "${ES_PV_NAME}" -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
    kubectl get pv "${ES_PV_NAME}" | grep Retain || echo '[ERROR] Reclaim Policy is not Retain!'
done
