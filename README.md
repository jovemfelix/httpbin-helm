# Setup
> variables
```shell
NS=httpbin-v1
CTRL_PLANE_NS=istio-system
SECRET=httpbin-v2
export INGRESS_PORT=80
export SECURE_INGRESS_PORT=443
export MY_HOST_INTERNAL=intranet.example.com
export MY_HOST_EXTERNAL=dmz.example.com
export INGRESS_HOST=$(oc get pod -l app=vsphere-infra-vrrp -o yaml -n openshift-vsphere-infra | grep -i '\-\-ingress-vip' -A1 | grep -v '\-\-ingress-vip\|--' | uniq | awk '{print $2}')
export INGRESS_HOST_DMZ=10.36.5.100
export ROUTE_INTRA=route-intra-tls
export ROUTE_DMZ=route-dmz-tls
```

> create namespace
```shell
$ oc new-project $NS
```


# TLS

```shell
DOMAIN=example.com
APP=v1-httpbin

$ mkdir -p keys && cd $_

$ sh ../generate-keys.sh ${DOMAIN} ${MY_HOST_INTERNAL} ${APP}
$ sh ../generate-keys.sh ${DOMAIN} ${MY_HOST_EXTERNAL} ${APP}
cd ..
```shell

# Secret
```shell
$ oc create secret tls ${ROUTE_INTRA} --key=keys/${MY_HOST_INTERNAL}.key --cert=keys/${MY_HOST_INTERNAL}.crt
$ oc create secret tls ${ROUTE_DMZ} --key=keys/${MY_HOST_EXTERNAL}.key --cert=keys/${MY_HOST_EXTERNAL}.crt
```


# Manual Execution
> policy
```shell
$ oc adm policy add-scc-to-user anyuid -z v1-httpbin
```
## With Internal Route
```shell
$ helm template . --set gateway.hosts=${MY_HOST_INTERNAL} --set route.name=intranet  --set route.certsFromSecret=${ROUTE_INTRA} --name-template v1 | oc apply -f -
# helm template . --set gateway.hosts=${MY_HOST_INTERNAL} --set route.name=intranet  --set route.certsFromSecret=${ROUTE_INTRA} --name-template v1 --output-dir target
```

## With External Route
```shell
$ helm template . --set gateway.hosts=${MY_HOST_EXTERNAL} --set route.name=dmz  --set route.certsFromSecret=${ROUTE_DMZ} --set route.shard=infra-shard --name-template v1 --output-dir target
$ oc apply -f target\httpbin\templates\route.yml
```


# Helpers
```shell
oc get route -n ${CTRL_PLANE_NS}
# teste http
curl -H "Host: $MY_HOST" --resolve "$MY_HOST:$INGRESS_PORT:$INGRESS_HOST" "http://$MY_HOST:$INGRESS_PORT/status/418"
curl -H "Host: $MY_HOST" --resolve "$MY_HOST:$INGRESS_PORT:$INGRESS_HOST" "http://$MY_HOST:$INGRESS_PORT/status/200"
curl -H "Host: $MY_HOST" --resolve "$MY_HOST:$INGRESS_PORT:$INGRESS_HOST" "http://$MY_HOST:$INGRESS_PORT/delay/2"

curl -s -I -HHost:$MY_HOST "http://$INGRESS_HOST:$INGRESS_PORT/status/200"

curl -H "Host: $MY_HOST" --resolve "$MY_HOST:443:$INGRESS_HOST" "https://$MY_HOST:$SECURE_INGRESS_PORT/status/418"
  
```
# Testing with Route

```shell
# remove gw and vs and restart de Pods
oc delete gw,vw,pod --all -n $NS
# 
curl -sH "Host: $MY_HOST" --resolve "$MY_HOST:$SECURE_INGRESS_PORT:$INGRESS_HOST" "https://$MY_HOST:$SECURE_INGRESS_PORT/status/418" -k
```


# INTERNO
```shell
$ curl -sH "Host: ${MY_HOST_INTERNAL}" --resolve "${MY_HOST_INTERNAL}:$SECURE_INGRESS_PORT:$INGRESS_HOST" "https://${MY_HOST_INTERNAL}:$SECURE_INGRESS_PORT/status/418" -k

$ curl -sH "Host: ${MY_HOST_INTERNAL}" --cacert keys/${MY_HOST_INTERNAL}.crt --resolve "${MY_HOST_INTERNAL}:$SECURE_INGRESS_PORT:$INGRESS_HOST" "https://${MY_HOST_INTERNAL}:$SECURE_INGRESS_PORT/status/418"
```

# EXTERNO
```shell
$ curl -sH "Host: ${MY_HOST_EXTERNAL}" --resolve "${MY_HOST_EXTERNAL}:$SECURE_INGRESS_PORT:${INGRESS_HOST_DMZ}" "https://${MY_HOST_EXTERNAL}:$SECURE_INGRESS_PORT/status/418" -k

$ curl -sH "Host: ${MY_HOST_EXTERNAL}" --cacert keys/${MY_HOST_EXTERNAL}.crt --resolve "${MY_HOST_EXTERNAL}:$SECURE_INGRESS_PORT:${INGRESS_HOST_DMZ}" "https://${MY_HOST_EXTERNAL}:$SECURE_INGRESS_PORT/status/418"
```

while sleep 2; do curl -sH "Host: ${MY_HOST_EXTERNAL}" --cacert keys/${MY_HOST_EXTERNAL}.crt --resolve "${MY_HOST_EXTERNAL}:$SECURE_INGRESS_PORT:${INGRESS_HOST_DMZ}" "https://${MY_HOST_EXTERNAL}:$SECURE_INGRESS_PORT/status/418"; done
