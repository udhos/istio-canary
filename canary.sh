#!/bin/bash

api=v1beta1
#api=v1alpha3

usage() {
    cat <<EOF
usage:   $0 namespace service      port target_port label_v1     label_v2          weight_v1
example: $0 develop   pismo-egress 3000 3000        pismo-egress npc-regress-pismo 1
EOF
    exit 1
}

msg() {
    echo >&2 $0: $@
}

die() {
    msg $@
    exit 1
}

required=7
if [ $# -ne $required ]; then
    msg "required $required arguments, but got: $#"
    usage
fi

namespace="$1"
service="$2"
port="$3"
target_port="$4"
label_v1="$5"
label_v2="$6"
weight_v1="$7"

if ! echo $weight_v1 | grep -E '^[0-9]+$' >/dev/null; then
    die "weight_v1='$weight_v1' must be a number"
    usage
fi

weight_v2=$((100-$weight_v1))

cat <<EOF
namespace=$namespace
service=$service
port=$port
target_port=$target_port
label_v1=$label_v1
label_v2=$label_v2
weight_v1=$weight_v1
weight_v2=$weight_v2
EOF

[ "$weight_v1" -ge 0 ] || die "weight_v1=$weight_v1 cant be lower than 0"
[ "$weight_v1" -le 100 ] || die "weight_v1=$weight_v1 cant higher than 100"

svc_manifest() {
    local svc="$1"
    local lab="$2"

    cat <<EOF
apiVersion: v1
kind: Service
metadata:
  name: $svc
  namespace: $namespace
spec:
  ports:
  - port: $port
    targetPort: $target_port
    name: http
  selector:
    app: $lab
  type: ClusterIP
EOF
}

vs_manifests() {
    cat <<EOF
apiVersion: networking.istio.io/$api
kind: VirtualService
metadata:
  name: $service
  namespace: $namespace
spec:
  hosts:
    - $service
  http:
  - route:
    - destination:
        host: $label_v1
      weight: $weight_v1
    - destination:
        host: $label_v2
      weight: $weight_v2
EOF
}

# vs_manifests() {

#   local host=$service.$namespace.svc.cluster.local

#   cat <<EOF
# apiVersion: networking.istio.io/$api
# kind: VirtualService
# metadata:
#   name: $service
#   namespace: $namespace
# spec:
#   hosts:
#     - $host
#   http:
#   - route:
#     - destination:
#         host: $host
#         subset: v1
#       weight: $weight_v1
#     - destination:
#         host: $host
#         subset: v2
#       weight: $weight_v2
# ---
# apiVersion: networking.istio.io/$api
# kind: DestinationRule
# metadata:
#   name: $service
#   namespace: $namespace
# spec:
#   host: $host
#   subsets:
#   - name: v1
#     labels:
#       app: $label_v1
#   - name: v2
#     labels:
#       app: $label_v2
# EOF
# }

#
# mail
#

if [ $weight_v1 -eq 100 ]; then
    #
    # full v1
    #
    kubectl -n $namespace delete DestinationRule $service
    kubectl -n $namespace delete VirtualService $service

    kubectl -n $namespace delete svc $service

    #kubectl -n $namespace expose deploy $label_v1 --port=$port --target-port=$target_port --name=$service

    svc_manifest $service $label_v1 > apply-svc.yaml
    kubectl -n $namespace apply -f apply-svc.yaml

    exit
fi

if [ $weight_v1 -eq 0 ]; then
    #
    # full v2
    #
    kubectl -n $namespace delete DestinationRule $service
    kubectl -n $namespace delete VirtualService $service

    kubectl -n $namespace delete svc $service

    #kubectl -n $namespace expose deploy $label_v2 --port=$port --target-port=$target_port --name=$service

    svc_manifest $service $label_v2 > apply-svc.yaml
    kubectl -n $namespace apply -f apply-svc.yaml

    exit
fi

#
# partial
#

kubectl -n $namespace delete svc $label_v1
svc_manifest $label_v1 $label_v1 > apply-svc-$label_v1.yaml
kubectl -n $namespace apply -f apply-svc-$label_v1.yaml

kubectl -n $namespace delete svc $label_v2
svc_manifest $label_v2 $label_v2 > apply-svc-$label_v2.yaml
kubectl -n $namespace apply -f apply-svc-$label_v2.yaml

vs_manifests > apply-vs.yaml
kubectl -n $namespace apply -f apply-vs.yaml
