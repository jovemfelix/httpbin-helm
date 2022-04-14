# Setup
> variables
```shell
NS=httpbin-v2
CTRL_PLANE_NS=istio-system
SECRET=httpbin-v2
SECURE_INGRESS_PORT=443
INGRESS_HOST=$(oc get pod -l app=vsphere-infra-vrrp -o yaml -n openshift-vsphere-infra | grep -i '\-\-ingress-vip' -A1 | grep -v '\-\-ingress-vip\|--' | uniq | awk '{print $2}')
```

> create namespace
```shell
$ oc new-project redhat-httbin-v1
```

# Manual Execution
> Example using template and openshift apply
```shell
$ helm template . --name-template v1 --output-dir target
$ oc apply -f target\httpbin\templates
```