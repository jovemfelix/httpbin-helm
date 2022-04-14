# Setup
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