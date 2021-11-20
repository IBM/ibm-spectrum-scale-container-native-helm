# Helm Chart Deployment of IBM Spectrum Scale CNSA/CSI

## Table of Contents

- [Abstract](#abstract)
- [Architecture](#architecture)
- [Requirements](#requirements)
- [Repository structure](#repository-structure)
- [Preinstallation tasks](#preinstallation-tasks)
  - [Add IBM Cloud Container Registry entitlement to OpenShift global cluster pull secret](#add-ibm-cloud-container-registry-entitlement-to-openshift-global-cluster-pull-secret)
  - [Prepare OpenShift worker nodes to run IBM Spectrum Scale](#prepare-openshift-worker-nodes-to-run-ibm-spectrum-scale)
  - [Prepare remote IBM Spectrum Scale storage cluster](#prepare-remote-ibm-spectrum-scale-storage-cluster)
    - [Apply required storage cluster configuration settings](#apply-required-storage-cluster-configuration-settings)
    - [Create required CNSA and CSI GUI users](#create-required-cnsa-and-csi-gui-users)
- [Deployment steps](#deployment-steps)
  - [(1) Edit the *config.yaml* file to reflect your local environment](#step1)
    - [Minimum required configuration](#minimum-required-configuration)
    - [Optional configuration options](#optional-configuration-options)
      - [Manual creation of CNSA and CSI secrets (optional)](#manual-creation-of-cnsa-and-csi-secrets-(optional))
      - [Defining host aliases (optional)](#defining-host-aliases-(optional))
      - [Enabling call home (optional)](#enabling-call-home-(optional))
      - [Enabling encryption (optional)](#enabling-encryption-(optional))
      - [Modifying container image names (optional)](#modifying-container-image-names-(optional))
  - [(2) Deploy the IBM Spectrum Scale CNSA Helm chart](#step2)
- [Verify your deployment](#verify-your-deployment)
- [CNSA Helm chart hooks](#cnsa-helm-chart-hooks)
- [Remove IBM Spectrum Scale CNSA and CSI deployment](#remove-ibm-spectrum-scale-cnsa-and-csi-deployment)
- [Deploy IBM Spectrum Scale CNSA and CSI driver using Helm chart templating](#deploy-ibm-spectrum-scale-cnsa-and-csi-driver-using-helm-chart-templating)
- [Example of using storage provisioning with IBM Spectrum Scale](#example-of-using-storage-provisioning-with-ibm-spectrum-scale)

## Abstract

This document provides details on how to use of this Helm chart to deploy
[*IBM Spectrum Scale Container Native Storage Access* (CNSA) v5.1.1.4](https://www.ibm.com/docs/en/scalecontainernative?topic=spectrum-scale-container-native-storage-access-5114) with 
[*IBM Spectrum Scale CSI driver* v2.3.1](https://www.ibm.com/docs/en/spectrum-scale-csi?topic=spectrum-scale-container-storage-interface-driver-231).

*Helm charts* allow to separate the *configurable parameters* from the *YAML manifests* of the individual components
and help to simplify and automate the deployment of containerized applications. 
An administrator only has to edit *one* central configuration file, here [*config.yaml*](config.yaml),
to configure and customize the whole deployment without touching any of the YAML manifests of the application.

The Helm chart comes with its own [README.md](helm/ibm-spectrum-scale/README.md) as a *quick start guide* on how to install it. 

If you have already prepared all pre-installation tasks from the official IBM Documentation and meet all 
the requirements listed in [Requirements](#requirements) then you can directly 
continue with the installation steps in [Deployment steps](#deployment-steps).

## Architecture

*IBM Spectrum Scale® Containers Native Storage Access* (CNSA) allows the deployment of an 
IBM Spectrum Scale cluster file system in a Red Hat® OpenShift® cluster. 
It provides a persistent storage for containerized applications in OpenShift 
through *persistent volumes* (PVs) and the IBM Spectrum Scale Container Storage Interface (CSI) driver.
IBM Spectrum Scale® CNSA makes use of a *remote mount* of an IBM Spectrum Scale file system 
on a remote IBM Spectrum Scale storage cluster.

IBM Spectrum Scale CNSA will be running on the OpenShift cluster and be referred to as 
*local* IBM Spectrum Scale *compute* cluster.
The physical storage is provided by the *remote* IBM Spectrum Scale *storage* cluster 
(e.g. an [IBM Elastic Storage System](https://www.ibm.com/products/elastic-storage-system))
using a remote mount of an IBM Spectrum Scale file system.

![plot](./pics/ibm-spectrum-scale-cnsa.png)

## Requirements

The deployment of *IBM Spectrum Scale Container Native* requires certain mandatory planning and preparation steps
as described in the official IBM documentation:
- [IBM Spectrum Scale Container Native - Planning](https://www.ibm.com/docs/en/scalecontainernative?topic=5114-planning),
- [IBM Spectrum Scale Container Native - Installation prerequisites](https://www.ibm.com/docs/en/scalecontainernative?topic=5114-installation-prerequisites) and
- [Installing the IBM Spectrum Scale container native operator and cluster](https://www.ibm.com/docs/en/scalecontainernative?topic=5114-installing-spectrum-scale-container-native-operator-cluster).

The major steps will also be outlined in detail this document. 

The following list provides a selective overview of the requirements that need to be met
to install IBM Spectrum Scale CNSA with this Helm chart on Red Hat OpenShift 4.x:

* General [Prerequisites](https://www.ibm.com/docs/en/scalecontainernative?topic=planning-prerequisites).
* [Hardware requirements](https://www.ibm.com/docs/en/scalecontainernative?topic=planning-hardware-requirements).
* [Software requirements](https://www.ibm.com/docs/en/scalecontainernative?topic=planning-software-requirements).
* A Red Hat OpenShift Container Platform cluster, version 4.7/4.8 with a minimum configuration 
  of *three* master nodes and *three* worker nodes (and a supported maximum of 128 worker nodes).
  A compact 3-node cluster running CNSA on master nodes in resource constrained environments, e.g. for Edge deployments, 
  is also supported, see [Compact Clusters Support](https://www.ibm.com/docs/en/scalecontainernative?topic=configuration-compact-cluster-support).
* An IBM Spectrum Scale *storage* cluster running IBM Spectrum Scale version 5.1.1.4 or higher (ideally a minimum of 3 nodes) 
  with IBM Spectrum Scale GUI to provide a REST API for IBM Spectrum Scale CNSA and CSI driver.
  The *storage* cluster provides an IBM Spectrum Scale file system that backs the persistent storage in OpenShift. This file system 
  is mounted through a *remote mount* (also referred to as *cross-cluster mount*) on the local IBM Spectrum Scale CNSA 
  *compute* cluster and the OpenShift worker nodes as a clustered parallel file system.
  Note that all nodes of the local *compute* and remote *storage* cluster need to be able to communicate over the 
  IBM Spectrum Scale *daemon* network with each other (this is a prerequisite for the *remote mount*).
* IBM Spectrum Scale CNSA v5.1.1.4 supports IBM Spectrum Scale file system versions V25 (5.1.1) or earlier for the remote mount 
  (`mmlsfs <fs name> -V`). Should you upgrade the remote storage cluster beyond 5.1.1.4 at some point, make sure to stay at 
  a supported version of the file system for the remote mount by making use of `mmchfs <fs name> -V compat` 
  to retain accessibility from the IBM Spectrum Scale CNSA compute cluster.
* Access to the *IBM Cloud Container Registry (ICR)* is required, 
  see [IBM Cloud Container Registry (ICR) entitlement](https://www.ibm.com/docs/en/scalecontainernative?topic=registry-cloud-container-icr-entitlement),
  with an *entitlement key* for either *IBM Spectrum Scale Data Access Edition* or *IBM Spectrum Scale Data Management Edition*
  so that the *IBM Spectrum Scale Container Native Storage Access* operator can automatically pull the required images 
  from the IBM Cloud Container Registry (icr.io).
* Modify the OpenShift *global cluster pull secret* to contain the credentials 
  (entitled registry user: "**cp**" & your **entitlement key**) for accessing the IBM Cloud Container Registry.
  See [Adding IBM Cloud Container Registry credentials](https://www.ibm.com/docs/en/scalecontainernative?topic=registry-adding-cloud-container-credentials)
  for instructions. Note that the updated config will be rolled out to all nodes in the OpenShift cluster one at a time and on OpenShift 4.6
  nodes will not be schedulable before rebooting. On OpenShift 4.7 and above the nodes do not need to reboot. Also see 
  [Updating the global cluster pull secret](https://docs.openshift.com/container-platform/4.7/openshift_images/managing_images/using-image-pull-secrets.html#images-update-global-pull-secret_using-image-pull-secrets). 
* Transport Layer Security (TLS) verification is used to guarantee secure HTTPS communication with the storage cluster GUI 
  by verifying the server's certificate chain and host name. Prepare for one of the *three* options described in
  [Configure Certificate Authority (CA) certificates for storage cluster](https://www.ibm.com/docs/en/scalecontainernative?topic=cluster-configuring-certificate-authority-ca-certificates).
  Note that the storage cluster verification can be skipped (e.g. for PoCs, demos) by setting *insecureSkipVerify* option to *true*, see 
  [Edit the *config.yaml* file to reflect your local environment](#step1). This is set as default in the Helm chart aimed at PoCs. Recommended setting is *false*. 
* Clone [this](https://github.com/IBM/ibm-spectrum-scale-container-native-helm/tree/v5.1.1.4-v2.3.1) Github repository to your local installation node. 
* The **helm** (v3) command binary (or higher) needs to be installed on the local installation node, see [Installing Helm](https://helm.sh/docs/intro/install/) to apply the Helm charts.
* A cluster-wide admin user (*cluster-admin* role) on OpenShift is required for the deployment. 
  The predefined `kube:admin` or `system:admin` accounts do suffice.
  See the [OPTIONAL NOTE](#clusteradmin) below for more information on how to create a *regular* OpenShift cluster-admin user.
* Internet access is required for the deployment so all required images for IBM Spectrum Scale CNSA and CSI driver can be accessed 
  on the worker nodes from their respective external image registries, e.g. icr.io, quay.io, us.gcr.io, docker.io, registry.access.redhat.com, etc.
  For a list of required container images and registries see 
  [Container image list for IBM Spectrum® Scale Container Native Storage Access](https://www.ibm.com/docs/en/scalecontainernative?topic=planning-container-image-list-spectrum-scale-container-native).
  and [Deployment considerations](https://www.ibm.com/docs/en/spectrum-scale-csi?topic=planning-deployment-considerations).
  See [Air gap setup for network restricted Red Hat OpenShift Container Platform clusters (optional)](https://www.ibm.com/docs/en/scalecontainernative?topic=odifccr-air-gap-setup-network-restricted-red-hat-openshift-container-platform-clusters)
  in case your OpenShift cluster does not allow access to external image registries. The Red Hat® OpenShift® internal image registry is no longer supported at this time. 
* Ensure that ports 1191, 443, and the ephemeral port ranges are open so IBM Spectrum Scale CNSA can remotely mount the file system from the storage cluster.
  See [Securing the IBM Spectrum Scale system using firewall](https://www.ibm.com/docs/en/spectrum-scale/5.1.1?topic=topics-securing-spectrum-scale-system-using-firewall) 
  for more information.

<a name="clusteradmin"></a>
*OPTIONAL NOTE* (**not required** for the deployment of IBM Spectrum Scale CNSA/CSI): 
A production-ready Red Hat OpenShift cluster typically would have a properly configured *identity provider* and a regular *cluster-admin* user 
other than the default admin users like `kube:admin` or `system:admin` which are meant primarily as temporary accounts for the initial deployment
and which, for example, do not provide a token (`oc whoami -t`) to access or push images to the internal OpenShift image registry.
The steps to create such a regular OpenShift *cluster-admin* user include 
1. Adding an *identity provider* like *HTPasswd* to the OpenShift cluster 
(see [Configuring an HTPasswd identity provider](https://docs.openshift.com/container-platform/4.5/authentication/identity_providers/configuring-htpasswd-identity-provider.html))
and
2. Creating a regular admin user account with a *cluster-admin* role with 
(see [Creating a cluster admin](https://docs.openshift.com/container-platform/4.5/authentication/using-rbac.html#creating-cluster-admin_using-rbac))
```
# oc adm policy add-cluster-role-to-user cluster-admin <user-name>
```

## Repository structure

When cloning this repository you will find the following files in your local directory:
```
README.md
config.yaml           << one central configuration file with minimum required variables for the customer
helm/
 \-ibm-spectrum-scale
   |-Chart.yaml       << defines Helm chart version and provides additional info
   |-LICENSE
   |-README.md
   |-values.yaml      << holds all configurable variables of the Helm chart / offers extended options
   |-crds/            << holds the custom resource definitions (CRD) and namespaces for the IBM Spectrum Scale CNSA/CSI deployment
   |-templates/       << holds the templates of the YAML manifests for the IBM Spectrum Scale CNSA/CSI deployment
scripts/
 |- upload_images.sh  << script to upload local IBM Spectrum Scale CNSA v5.1.0.x images (from tar archive) to the OpenShift internal image registry
 |- yaml-split.awk    << awk helper script to split the original CNSA YAMLs into individual YAMLs
 |- yaml-rename.sh    << helper script to rename the individual files created by yaml-split.awk based on "kind:" and "name:"
examples/
 |- ibm-spectrum-scale-sc.yaml         << storage class (SC) example, fileset based, used by ibm-spectrum-scale-pvc.yaml
 |- ibm-spectrum-scale-light-sc.yaml   << storage class (SC) example, lightweight / directory based (provided as additional example)
 |- ibm-spectrum-scale-pvc.yaml        << persistent volume claim (PVC), depends on storage class created by ibm-spectrum-scale-sc.yaml
 |- ibm-spectrum-scale-test-pod.yaml   << test pod example, mounts PVC created by ibm-spectrum-scale-pvc.yaml
```
The **config.yaml** file is a copy of the *values.yaml* and holds the customizable parameters for the 
IBM Spectrum Scale CNSA deployment. It needs to be edited accordingly to reflect the local environment. 

The Helm chart for the IBM Spectrum Scale CNSA and CSI driver deployment is located in the **helm/** directory 
as **ibm-spectrum-scale**. The Helm charts consists of a default **values.yaml** file 
that defines the available *parameters* and their *default values* which are used in the YAML templates. 

The **crds/** directory stores the unchanged official *custom resource definitions* (CRDs) 
and *namespace* manifests for IBM Spectrum Scale CNSA/CSI which will not be templated by Helm. 

The **Chart.yaml** file describes the general properties of the Helm chart such as the Helm chart name, the Helm chart *version* 
and the *appVersion*. The *appVersion* is *v5.1.1.4* reflecting the IBM Spectrum Scale CNSA version v5.1.1.4.

The Helm chart is based on the original YAML manifests from the public IBM Github repository:
- [IBM Spectrum Scale container native](https://github.com/IBM/ibm-spectrum-scale-container-native)

## Preinstallation tasks

Be sure to perform all pre-installation tasks for the IBM Spectrum Scale CNSA and CSI driver deployment
as outlined in
* [IBM Cloud Container Registry (ICR) entitlement](https://www.ibm.com/docs/en/scalecontainernative?topic=registry-cloud-container-icr-entitlement),
  to obtain your *entitlement key*,
* [Adding IBM Cloud Container Registry credentials](https://www.ibm.com/docs/en/scalecontainernative?topic=registry-adding-cloud-container-credentials)
  to add your *entitlement key* to the *global cluster pull secret* of your OpenShift cluster,
* [Red Hat OpenShift Container Platform configuration](https://www.ibm.com/docs/en/scalecontainernative?topic=prerequisites-red-hat-openshift-container-platform-configuration)
  to increase the **PIDS_LIMIT**, add the **kernel-devel** extensions and 
  increase **vmalloc kernel parameter** (the latter is only required for *Linux on System Z*) and
* [IBM Spectrum Scale storage cluster configuration](https://www.ibm.com/docs/en/scalecontainernative?topic=cluster-spectrum-scale-storage-configuration),
  to configure the remote storage cluster, e.g., creating the CNSA/CSI user credentials and setting the following options accordingly:
  ``` 
  -Q/quota, --perfileset-quota, --filesetdf, enforceFilesetQuotaOnRoot, controlSetxattrImmutableSELinux
  ```
The most common steps are described in the next section below.

### Add IBM Cloud Container Registry entitlement to OpenShift global cluster pull secret

You need to obtain an *entitlement key* from 
[IBM Container software library](https://myibm.ibm.com/products-services/containerlibrary) 
using your IBM id and password that is associated with the entitled software. 
This *entitlement key* must be added to the *global cluster pull secret* of your OpenShift cluster 
otherwise the IBM Spectrum Scale pods (except the operator) will fail to start due to image pull failures:
```
Failed to pull image "cp.icr.io/cp/spectrum/scale/ibm-spectrum-scale-core-init@sha256:a346f70d89755fe94143686d058e2e09698e4d6bb663df172befd91d54c7ffd6": 
rpc error: code = Unknown desc = Requesting bear token: invalid status code from registry 400 (Bad Request)
```
Create a local file *authority.json* with the entitled *user* **cp** and your **entitlement key** as *password*:
```
# cat authority.json 
{
  "auth": "< ENTER BASE64 ENCODED OUTPUT STRING OF (echo -n "cp:<YOUR ENTITLEMENT KEY>" | base64 -w0) HERE >",
  "username":"cp",
  "password":"< ENTER YOUR ORIGINAL ENTITLEMENT KEY HERE >"
}
```
An example *authority.json* file may look similar to
```
{
  "auth": "Y3A6ZXl...T3ZIckk=",
  "username":"cp",
  "password":"eyJhbGc...KUnqLOvHrI"
}
```
with
```
# echo -n "cp:eyJhbGc...KUnqLOvHrI" | base64 -w0
Y3A6ZXl...T3ZIckk=
```
For the next step you need the `jq` command locally installed (`yum install jq`) 
and access to the OpenShift cluster as cluster-admin with `oc` to read and modify the *global cluster pull secret*:
```
# oc get secret/pull-secret -n openshift-config -ojson | \
jq -r '.data[".dockerconfigjson"]' | \
base64 -d - | \
jq '.[]."cp.icr.io" += input' - authority.json > temp_config.json
```
This first step will take the previously created *authority.json* file and include it 
as a new authority in your *.dockerconfigjson* which will be stored in a local *temp_config.json* file.

In a second step we update the *global cluster pull secret* of the OpenShift cluster with the contents of the *temp_config.json* file:
```
# oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=temp_config.json
```
Note that the update will be rolled out to all nodes in the OpenShift cluster one at a time. On OpenShift 4.6
nodes will become *not schedulable* (*NotReady,SchedulingDisabled*) in the process and reboot. 
On OpenShift 4.7 and above the cluster nodes do not need to reboot to apply the update of the *global cluster pull secret*. 

Your new pull-secret has been updated with your new authority. You can issue the following command to confirm your authority is present:
```
# oc get secret/pull-secret -n openshift-config -ojson | jq -r '.data[".dockerconfigjson"]' | base64 -d -
{
  "auths": {
    [...]
    "cp.icr.io": {
      "auth": "Y3A6ZXl...T3ZIckk=",
      "username": "cp",
      "password": "eyJhbGc...KUnqLOvHrI"
    [...]
}
```
Be sure to delete both temporary files (*authority.json*, *temp_config.json*) from the local server 
as they contain your *entitlement key*.

### Prepare OpenShift worker nodes to run IBM Spectrum Scale

By applying the appropriate *Machine Config Operator* (MCO) settings we
- increase the CRIO containerRuntimeConfig **pids_limit** to a minimum of `pidsLimit: 4096`
- add the **kernel-devel** extensions
- increase **vmalloc** kernel parameter for IBM Spectrum Scale CNSA running on Linux on System Z.

Note: Applying *Machine Configurations* with the *Machine Config Operator* as instructed in the next steps to update the Red Hat OpenShift Container Platform cluster
will *reboot* the worker nodes one by one. The update could take a while to finish depending on the size of the worker node pool.

Note: If you have already applied these *Machine Configurations* once then you do not need to apply them again.

Apply the following *Machine Configuration* (use "x86" for x86_64, "ppc64le" for ppc64le or "s390x" for s390x platforms):
```
ARCH="x86_64" (or "ppc64le" or "s390x")
OCP="4.7" (or "4.8")
# oc apply -f https://raw.githubusercontent.com/IBM/ibm-spectrum-scale-container-native/v5.1.1.4/generated/mco/ocp${OCP}/mco_${ARCH}.yaml
```
You can check the progress of the update with
```
# oc get MachineConfigPool
NAME     CONFIG                                             UPDATED   UPDATING   DEGRADED   MACHINECOUNT   READYMACHINECOUNT   UPDATEDMACHINECOUNT   DEGRADEDMACHINECOUNT   AGE
master   rendered-master-4edc40e45e3072f17116573b6a984a1c   True      False      False      3              3                   3                     0                      5d6h
worker   rendered-worker-3f929c38f3da19ee9f717ad774a6c6a6   False     True       False      4              1                   1                     0                      5d6h

[root@fscc-sr650-54 CNSA]# oc get nodes
NAME                          STATUS                     ROLES    AGE    VERSION
master01.ocp2.scale.ibm.com   Ready                      master   5d6h   v1.20.0+df9c838
master02.ocp2.scale.ibm.com   Ready                      master   5d6h   v1.20.0+df9c838
master03.ocp2.scale.ibm.com   Ready                      master   5d6h   v1.20.0+df9c838
worker01.ocp2.scale.ibm.com   Ready                      worker   5d3h   v1.20.0+df9c838
worker02.ocp2.scale.ibm.com   Ready                      worker   5d3h   v1.20.0+df9c838
worker03.ocp2.scale.ibm.com   Ready,SchedulingDisabled   worker   5d3h   v1.20.0+df9c838
worker04.ocp2.scale.ibm.com   Ready                      worker   5d3h   v1.20.0+df9c838
```
Wait until the update has finished successfully.

After the successful update all nodes will be in status *Ready* and the *MachineConfigPool* will show:  
```
# oc get MachineConfigPool
NAME     CONFIG                                             UPDATED   UPDATING   DEGRADED   MACHINECOUNT   READYMACHINECOUNT   UPDATEDMACHINECOUNT   DEGRADEDMACHINECOUNT   AGE
master   rendered-master-4edc40e45e3072f17116573b6a984a1c   True      False      False      3              3                   3                     0                      5d16h
worker   rendered-worker-be5e4051f4372f039554255a172eb20e   True      False      False      4              4                   4                     0                      5d16h
```

You can validate that the *pids_limit* has been applied by running
```
# oc get nodes -l node-role.kubernetes.io/worker --no-headers | while read a b; do echo "## Node: $a - $(oc debug node/$a -- chroot /host crio-status config 2>/dev/null | grep pids_limit)" ; done 
## Node: worker01.ocp2.scale.ibm.com -     pids_limit = 4096
## Node: worker02.ocp2.scale.ibm.com -     pids_limit = 4096
## Node: worker03.ocp2.scale.ibm.com -     pids_limit = 4096
## Node: worker04.ocp2.scale.ibm.com -     pids_limit = 4096
```
Note: This command will run through all the worker nodes. Use with discretion if you have a large system.

You can validate that the *kernel-devel* package is successfully applied by running
```
# oc get nodes -l node-role.kubernetes.io/worker --no-headers | while read a b; do echo "## Node: $a - $(oc debug node/$a -- chroot /host sh -c "rpm -q kernel-devel" 2>/dev/null)" ; done
## Node: worker01.ocp2.scale.ibm.com - kernel-devel-4.18.0-240.22.1.el8_3.x86_64
## Node: worker02.ocp2.scale.ibm.com - kernel-devel-4.18.0-240.22.1.el8_3.x86_64
## Node: worker03.ocp2.scale.ibm.com - kernel-devel-4.18.0-240.22.1.el8_3.x86_64
## Node: worker04.ocp2.scale.ibm.com - kernel-devel-4.18.0-240.22.1.el8_3.x86_64
```
Note: This command will run through all the worker nodes. Use with discretion if you have a large system.

On Linux on System Z validate that the machine config has the vmalloc kernel parameter set by running
```
# oc describe machineconfig | grep vmalloc
```
and that the vmalloc kernel parameter is applied on the worker nodes by using the following command:
```
# oc get nodes -l node-role.kubernetes.io/worker --no-headers | while read a b; do echo "## Node: $a - $(oc debug node/$a -- chroot /host cat /proc/cmdline 2>/dev/null)" ; done
```
You will see *vmalloc=4096G* in the output.

### Prepare remote IBM Spectrum Scale storage cluster

#### Apply required storage cluster configuration settings

In order to prepare the remote IBM Spectrum Scale storage cluster for the IBM Spectrum Scale CSI driver we need
to apply the following quota and configuration settings.

(1) Ensure that per `--fileset-quota` is set to "no" on the file systems to be used by IBM Spectrum Scale CNSA and CSI driver. 

Here we are going to use *essfs1* as the *remote* file system for IBM Spectrum Scale CNSA and CSI.
```
# mmlsfs essfs1 --perfileset-quota
flag                value                    description
------------------- ------------------------ -----------------------------------
 --perfileset-quota no                       Per-fileset quota enforcement
```
If it is set to "yes" you can set it to "no" with
```
# mmchfs essfs1 --noperfileset-quota
```

(2) Enable *quota* for all the file systems being used for fileset-based dynamic provisioning with IBM Spectrum Scale CSI driver:
```
# mmchfs essfs1 -Q yes
```
Verify that quota (flag -Q) is enabled for the file system, here *essfs1*:
```
# mmlsfs essfs1 -Q 

flag                value                    description
------------------- ------------------------ -----------------------------------
 -Q                 user;group;fileset       Quotas accounting enabled
                    user;group;fileset       Quotas enforced
                    none                     Default quotas enabled
```

(3) Enable *quota* for the root user by issuing the following command:
```
# mmchconfig enforceFilesetQuotaOnRoot=yes -i
```

(4) For Red Hat OpenShift, ensure that the `controlSetxattrImmutableSELinux` parameter is set to "yes" by issuing the following command:
```
# mmchconfig controlSetxattrImmutableSELinux=yes -i
```

(5) To display the correct volume size in a container, enable `filesetdf` on the file system by using the following command:
```
# mmchfs essfs1 --filesetdf
```
Verify that `filesetdf` is enabled for the file system, here *essfs1*:
```
# mmlsfs essfs1 --filesetdf
flag                value                    description
------------------- ------------------------ -----------------------------------
 --filesetdf        yes                      Fileset df enabled?
```

#### Create required CNSA and CSI GUI users

(1) Create GUI user for IBM Spectrum Scale CNSA

On the remote IBM Spectrum Scale storage cluster check if the GUI user group *ContainerOperator* exists by issuing the following command:
```
# /usr/lpp/mmfs/gui/cli/lsusergrp ContainerOperator
```
If the GUI user group *ContainerOperator* does not exist, create it using the following command:
```
# /usr/lpp/mmfs/gui/cli/mkusergrp ContainerOperator --role containeroperator
```
If no user for IBM Spectrum Scale CNSA exists in the *ContainerOperator*  group
```
# /usr/lpp/mmfs/gui/cli/lsuser | grep ContainerOperator
# 
```
then create one as follows:
```
# /usr/lpp/mmfs/gui/cli/mkuser cnsa_admin -p cnsa_PASSWORD -g ContainerOperator -e 1
```
The user credentials will later be provided to *IBM Spectrum Scale CNSA* through the `cnsa-remote-gui-secret` secret
in the `ibm-spectrum-scale` namespace.

Note: By default user passwords expire after 90 days in the IBM Spectrum Scale GUI. 
Here we use the `-e 1` option in order to create a user with a never-expiring password.

(2) Create GUI user for IBM Spectrum Scale CSI driver

On the remote IBM Spectrum Scale storage cluster check if the GUI user group *CsiAdmin* exists by issuing the following command:
```
# /usr/lpp/mmfs/gui/cli/lsusergrp CsiAdmin
```
If the GUI user group *CsiAdmin* should not exist, create it using the following command:
```
# /usr/lpp/mmfs/gui/cli/mkusergrp CsiAdmin --role csiadmin
```
If no user for the CSI driver exists in the *CsiAdmin*  group
```
# /usr/lpp/mmfs/gui/cli/lsuser | grep CsiAdmin
# 
```
create one as follows:
```
# /usr/lpp/mmfs/gui/cli/mkuser csi_admin -p csi_PASSWORD -g CsiAdmin -e 1
```
The user credentials will later be provided to *IBM Spectrum Scale CSI driver* through the `csi-remote-gui-secret` secret 
in the `ibm-spectrum-scale-csi` namespace.

Note: By default user passwords expire after 90 days in the IBM Spectrum Scale GUI. 
Here we use the `-e 1` option in order to create a user with a never-expiring password.

## Deployment Steps

The deployment of the Helm chart for IBM Spectrum Scale CNSA with IBM Spectrum Scale CSI driver requires two steps:

1. Edit the [*config.yaml*](config.yaml) file to reflect your local environment
2. Install the IBM Spectrum Scale CNSA Helm chart: [helm/ibm-spectrum-scale](helm/ibm-spectrum-scale)

The [*config.yaml*](config.yaml) file contains the configurable parameters that describe the local environment 
for the deployment of IBM Spectrum Scale CNSA and the CSI driver. 
These configuration parameters will automatically be applied to the YAML manifests and custom resources (CRs). 

The Helm chart also creates the Kubernetes *secrets* for the CNSA and CSI user credentials automatically 
and uses *hooks* to test proper access to the GUI of the remote storage cluster 
with the provided credentials prior to starting the actual deployment.
See [CNSA Helm Chart Hooks](#cnsa-helm-chart-hooks) for more details.

Make sure that the Red Hat OpenShift Container Platform *global cluster pull secret* for IBM Spectrum Scale CNSA has been 
configured with the credentials for the entitled registry user and an entitlement key otherwise the 
required container images cannot be pulled from the IBM Cloud Container Registry (icr.io) and 
your deployment will encounter image pull failures.

<a name="step1"></a>
## (1) Edit the *config.yaml* file to reflect your local environment

The [*config.yaml*](config.yaml) file is a simple copy of the [*values.yaml*](helm/ibm-spectrum-scale/values.yaml) file 
which contains the default values for the Helm chart.

Edit the [*config.yaml*](config.yaml) to reflect the configuration of your local environment for the
*IBM Spectrum Scale CNSA* and the *IBM Spectrum Scale CSI driver* deployment.

Please handle the file with care as it holds sensitive information once configured with your CNSA/CSI GUI user credentials!

### Minimum required configuration

At *minimum* you need to specify the following parameters to successfully deploy IBM Spectrum Scale CNSA/CSI: 

(1) Accept the IBM Spectrum Scale license and select the proper IBM Spectrum Scale license (*data-access* or *data-management*):
``` 
license:
    accept: true
    license: data-access
```
(2) Specify the *credentials* for the created CNSA and CSI user accounts on the remote storage cluster GUI:
```
cnsaGuiUser:
  username: "cnsa_admin"
  password: "cnsa_PASSWORD"

csiGuiUser:
  username: "csi_admin"
  password: "csi_PASSWORD"
```
(3) Specify the *name* of the *local* and *remote* IBM Spectrum Scale file system:
```
primaryFilesystem:
  localFs:          "fs1"      <-- local CNSA file system name (can be chosen freely), will be mounted at /mnt/<localFs>
  remoteFs:         "essfs1"   <-- remote file system name on storage cluster (must exist)
```
(4) Specify the *GUI node* for accessing the remote storage cluster:
```
remoteCluster:
  gui:
    host:               "remote-scale-gui.mydomain.com"
```
Note: 
- The *localFs* name must comply with Kubernetes DNS label rules and, for example, cannot contain a "_", see 
  [DNS Label Names](https://www.ibm.com/links?url=https%3A%2F%2Fkubernetes.io%2Fdocs%2Fconcepts%2Foverview%2Fworking-with-objects%2Fnames%2F%23dns-label-names)).
- The *remoteFs* name is the IBM Spectrum Scale file system on the remote IBM Spectrum Scale storage cluster
  that will used for the remote mount. This file system *must* exist prior to the deployment.
  A list of available file systems on the storage cluster can be obtained from `mmlsconfig` or by running 
  ```
  # curl -k -u 'cnsa_admin:cnsa_PASSWORD' https://<remote storage cluster GUI host>:443/scalemgmt/v2/filesystems
  ```

This minimum configuration will automatically create the *secrets* for the CNSA/CSI GUI users 
(`cnsa-remote-gui-secret`, `csi-remote-gui-secret`) 
in their respective namespaces (CNSA: `ibm-spectrum-scale`, CSI: `ibm-spectrum-scale-csi`), 
create a *RemoteCluster CR* with name `primary-storage-cluster` and deploy IBM Spectrum Scale CNSA with the CSI driver on 
all OpenShift worker nodes with the default CNSA *nodeSelector* `node-role.kubernetes.io/worker: ""`. 

Further settings can be configured as needed to customize the deployment. These settings are listed and
and described in the [config.yaml](config.yaml) or [values.yaml](helm/ibm-spectrum-scale/values.yaml) file
with references to the official documentation. 

If these settings meet your needs you can directly move on to 
[(STEP 2) Deploy the IBM Spectrum Scale CNSA Helm chart](#step2) section.

### Optional configuration options

Only selected options are described below. Please refer directly to the [config.yaml](config.yaml) 
or [values.yaml](helm/ibm-spectrum-scale/values.yaml) file for all implemented parameters in the Helm chart.

#### Manual creation of CNSA and CSI secrets (optional)

By setting the following option in the [config.yaml](config.yaml) file
```
createSecrets:false
```
you can decide *not* to have the Kubernetes *secrets* for the CNSA/CSI user credentials created for you by the Helm chart 
but instead create them manually.

In this case you need to start by creating the CNSA and CSI *namespaces* first and then create the *secrets* as follows:
```
# oc apply -f helm/ibm-spectrum-scale/crds/Namespace-ibm-spectrum-scale.yaml
# oc apply -f helm/ibm-spectrum-scale/crds/Namespace-ibm-spectrum-scale-csi.yaml

# oc create secret generic cnsa-remote-gui-secret  --from-literal=username='cnsa_admin' --from-literal=password='cnsa_PASSWORD' -n ibm-spectrum-scale

# oc create secret generic csi-remote-gui-secret --from-literal=username='csi_admin' --from-literal=password='csi_PASSWORD' -n ibm-spectrum-scale-csi
# oc label secret csi-remote-gui-secret product=ibm-spectrum-scale-csi -n ibm-spectrum-scale-csi
```
Note that the CNSA user secret needs to be created in the CNSA namespace (*ibm-spectrum-scale*) and 
the CSI user secret needs to be created in the CSI namespace (*ibm-spectrum-scale-csi*). 

The Helm chart will use *hooks* to test proper access to the GUI of the remote storage cluster 
with the manually created secrets and credentials prior to starting the actual deployment.
See [CNSA Helm Chart Hooks](#cnsa-helm-chart-hooks) for more details.

#### Defining host aliases (optional)

The hostnames of the remote IBM Spectrum Scale storage cluster contact nodes must be resolvable (including a *reverse* lookup) 
via DNS by the OpenShift nodes. If the IP addresses of these nodes cannot be resolved via DNS then the hostnames 
and their IP addresses need to be specified in the `hostAliases` section of the [*config.yaml*](config.yaml) file by uncommenting
the two lines and adding as many additional list items as needed: 
```
  hostAliases:
    #- hostname: "my-hostname1.mydomain.com"
    #  ip: "10.11.12.101"
```

#### Enabling call home (optional)

You can enable and configure *call home* for IBM Spectrum Scale CNSA by setting `accept: true` and configuring 
the following section of the [*config.yaml*](config.yaml) file accordingly:
```
callHome:
  license:
    accept: false
  companyName: "myCompany"
  customerID: "123456-gs"
  companyEmail: "smith@email.mydomain.org"
  countryCode: "DE"
  type: production
  proxy:
    host: ""
    port: 443
    #secretName: ""
```

#### Enabling encryption (optional)

The Helm chart also allows to configure *encryption* in order to access encrypted data from a remote mounted file system
by defining a *name* for the encryption CR (must comply with DNS label name rules as outlined above) and
configuring the following section of the [*config.yaml*](config.yaml):
```
encryptionConfig:
  name: ""
  server: keyserver.example.com
  tenant: sampleTenant
  secret: keyserver-credentials
  client: sampleClient
  remoteRKM: sampleRKM
  #port: 9443
  #cacert: sample-ca-cert
  filesystems:
  #- name: vdisknsd-sample
  #  algorithm: DEFAULTNISTSP800131A
```

#### Modifying container image names (optional)

The Helm chart also allows to easily modify the container image names for the deployment in case you need to redirect them
to another image registry or need to work with different image versions. All container images are listed and defined in the
last section of the [*config.yaml*](config.yaml) file.
```
# The following container images are used by IBM Spectrum Scale CNSA:
cnsaVersion:      v5.1.1.4
cnsaImages:
  operator:       icr.io/cpopen/ibm-spectrum-scale-operator@sha256:[...]
  coreECE:        cp.icr.io/cp/spectrum/scale/erasure-code/ibm-spectrum-scale-daemon@sha256:[...]
  coreDME:        cp.icr.io/cp/spectrum/scale/data-management/ibm-spectrum-scale-daemon@sha256:[...]
  coreDAE:        cp.icr.io/cp/spectrum/scale/data-access/ibm-spectrum-scale-daemon@sha256:[...]
  coreInit:       cp.icr.io/cp/spectrum/scale/ibm-spectrum-scale-core-init@sha256:[...]
  gui:            cp.icr.io/cp/spectrum/scale/ibm-spectrum-scale-gui@sha256:[...]
  postgres:       cp.icr.io/cp/spectrum/scale/postgres@sha256:[...]
  logs:           cp.icr.io/cp/spectrum/scale/ubi-minimal@sha256:[...]
  pmcollector:    cp.icr.io/cp/spectrum/scale/ibm-spectrum-scale-pmcollector@sha256:[...]
  sysmon:         cp.icr.io/cp/spectrum/scale/ibm-spectrum-scale-monitor@sha256:[...]
  grafanaBridge:  cp.icr.io/cp/spectrum/scale/ibm-spectrum-scale-grafana-bridge@sha256:[...]

# The following container images are used by IBM Spectrum Scale CSI Driver v2.3.1:
csiVersion:       v2.3.1
csiImages:
  operator:       icr.io/cpopen/ibm-spectrum-scale-csi-operator@sha256:[...]
  driver:         cp.icr.io/cp/spectrum/scale/csi/ibm-spectrum-scale-csi-driver@sha256:[...]
  snapshotter:    cp.icr.io/cp/spectrum/scale/csi/csi-snapshotter@sha256:[...]
  attacher:       cp.icr.io/cp/spectrum/scale/csi/csi-attacher@sha256:[...]
  provisioner:    cp.icr.io/cp/spectrum/scale/csi/csi-provisioner@sha256:[...]
  livenessprobe:  cp.icr.io/cp/spectrum/scale/csi/livenessprobe@sha256:[...]
  nodeRegistrar:  cp.icr.io/cp/spectrum/scale/csi/csi-node-driver-registrar@sha256:[...]
```
Note: The container image names are typically **NOT** supposed to be changed for a regular deployment!

<a name="step2"></a>
## (2) Deploy the IBM Spectrum Scale CNSA Helm chart

Log in to the OpenShift cluster as admin user with a *cluster-admin* role.

(a) Create the IBM Spectrum Scale CNSA namespace (here: `ibm-spectrum-scale`):
```
# oc apply -f helm/ibm-spectrum-scale/crds/Namespace-ibm-spectrum-scale.yaml
``` 
This namespace will be used for the IBM Spectrum Scale CNSA pods as well as 
*release namespace* for the Helm chart (i.e. where the Helm chart *lives* and can be listed with `helm list`).

Note, the Helm chart is self-contained and will create all IBM Spectrum Scale CNSA/CSI components 
and namespaces properly even without this step.

(b) Install the *ibm-spectrum-scale* Helm chart with
```
# helm install ibm-spectrum-scale helm/ibm-spectrum-scale -f config.yaml -n ibm-spectrum-scale
```
with
  - ibm-spectrum-scale :         *Release name* of the deployed Helm chart; can be chosen freely
  - helm/ibm-spectrum-scale :    Helm chart for IBM Spectrum Scale CNSA
  - -f config.yaml :             The customized configuration file as input for the Helm chart deployment
  - -n ibm-spectrum-scale :      The *release namespace* to use for the Helm chart (here we select the CNSA namespace)

The deployment will create and use the following *namespaces* as listed below:
- ibm-spectrum-scale (CNSA namespace)
- ibm-spectrum-scale-operator (CNSA operator namespace)
- ibm-spectrum-scale-csi (CSI namespace)

These namespaces are not configurable in the Helm chart because additional objects are created and managed 
by the operators which have dependencies on these namespaces and are beyond the control of this Helm chart.

The namespaces will not be removed by Helm with `helm uninstall`. 
The namespace manifests are located in the [crds/](helm/ibm-spectrum-scale/crds) directory of the Helm chart
to ensure that they are applied automatically prior to the deployment of the manifests 
in the [templates/](helm/ibm-spectrum-scale/templates) directory.

You can check the Helm chart deployment with
```
# helm list -A
NAME               NAMESPACE          REVISION UPDATED                                 STATUS   CHART                    APP VERSION
ibm-spectrum-scale ibm-spectrum-scale 1        2021-11-12 05:59:28.290601766 -0500 EST deployed ibm-spectrum-scale-1.1.4 v5.1.1.4
```
The status should be *deployed*. If the status is *failed* then most likely one of the *pre-installation hooks* failed when
verifying access to the remote storage cluster GUI with the provided CNSA/CSI user credentials (or manually created secrets).
See [CNSA Helm chart hooks](#cnsa-helm-chart-hooks) for more details.

Wait for all IBM Spectrum Scale CNSA and CSI pods to come up:
```
# oc get pods -n ibm-spectrum-scale-operator
NAME                                                     READY   STATUS    RESTARTS   AGE
ibm-spectrum-scale-controller-manager-75f9c9f6fd-wxk52   1/1     Running   0          10m

# oc get pods -n ibm-spectrum-scale 
NAME                               READY   STATUS    RESTARTS   AGE
ibm-spectrum-scale-gui-0           4/4     Running   0          9m21s
ibm-spectrum-scale-gui-1           4/4     Running   0          6m42s
ibm-spectrum-scale-pmcollector-0   2/2     Running   0          8m51s
ibm-spectrum-scale-pmcollector-1   2/2     Running   0          6m56s
worker01                           2/2     Running   0          9m21s
worker02                           2/2     Running   0          9m21s
worker03                           2/2     Running   0          9m21s
worker04                           2/2     Running   0          9m21s

# oc get pods -n ibm-spectrum-scale-csi 
NAME                                              READY   STATUS    RESTARTS   AGE
ibm-spectrum-scale-csi-4ls7t                      3/3     Running   0          4m39s
ibm-spectrum-scale-csi-96dwz                      3/3     Running   0          4m39s
ibm-spectrum-scale-csi-attacher-0                 1/1     Running   0          4m50s
ibm-spectrum-scale-csi-hclv8                      3/3     Running   0          4m40s
ibm-spectrum-scale-csi-operator-8f7f6fb47-gvnmt   1/1     Running   0          9m37s
ibm-spectrum-scale-csi-provisioner-0              1/1     Running   0          4m47s
ibm-spectrum-scale-csi-snapshotter-0              1/1     Running   0          4m43s
ibm-spectrum-scale-csi-xh7hw                      3/3     Running   0          4m39s
```

*!!! CONGRATULATIONS - DEPLOYMENT IS COMPLETED !!!*

The deployment is now completed and IBM Spectrum Scale CNSA and IBM Spectrum Scale CSI driver 
should be running on your OpenShift cluster.

Now you can start creating Kubernetes *storage classes* (SCs) and *persistent volume claims* (PVCs) 
to provide persistent storage to your containerized applications as described in 
[Example of using storage provisioning with IBM Spectrum Scale](#example-of-using-storage-provisioning-with-ibm-spectrum-scale).

See [Using IBM Spectrum Scale Container Storage Interface driver](https://www.ibm.com/docs/en/spectrum-scale-csi?topic=231-using-spectrum-scale-container-storage-interface-driver)
for more details.

## Verify your deployment

Select an IBM Spectrum Scale CNSA *core* pod, here named *worker01* to *worker04*,
```
# oc get pods -n ibm-spectrum-scale 
NAME                               READY   STATUS    RESTARTS   AGE
ibm-spectrum-scale-gui-0           4/4     Running   0          9m21s
ibm-spectrum-scale-gui-1           4/4     Running   0          6m42s
ibm-spectrum-scale-pmcollector-0   2/2     Running   0          8m51s
ibm-spectrum-scale-pmcollector-1   2/2     Running   0          6m56s
worker01                           2/2     Running   0          9m21s
worker02                           2/2     Running   0          9m21s
worker03                           2/2     Running   0          9m21s
worker04                           2/2     Running   0          9m21s
```
and execute the following commands to verify that the local IBM Spectrum Scale CNSA cluster 
has been created successfully and that the remote file system is properly mounted:
```
COREPOD="worker01"
# oc exec $COREPOD -n ibm-spectrum-scale -- mmlscluster
# oc exec $COREPOD -n ibm-spectrum-scale -- mmgetstate -a
# oc exec $COREPOD -n ibm-spectrum-scale -- mmremotecluster show all
# oc exec $COREPOD -n ibm-spectrum-scale -- mmremotefs show all
# oc exec $COREPOD -n ibm-spectrum-scale -- mmlsmount all -L
```
All IBM Spectrum Scale CNSA client nodes should be active (`mmgetstate`), 
the remote IBM Spectrum Scale storage cluster and file system should be configured `(mmremotecluster`/`mmremotefs`),
and the remote file system should be mounted on all eligible nodes (`mmlsmount`).   

An example output of a successful deployment would look similar to
```
# oc rsh $COREPOD -n ibm-spectrum-scale
sh-4.4# mmlscluster

GPFS cluster information
========================
  GPFS cluster name:         ibm-spectrum-scale.ocp2.scale.ibm.com
  GPFS cluster id:           17732446135908190530
  GPFS UID domain:           ibm-spectrum-scale.ocp2.scale.ibm.com
  Remote shell command:      /usr/bin/ssh
  Remote file copy command:  /usr/bin/scp
  Repository type:           CCR

 Node  Daemon node name  IP address  Admin node name  Designation
------------------------------------------------------------------
   1   worker02          10.0.10.22  worker02         quorum-manager-perfmon
   2   worker03          10.0.10.23  worker03         quorum-manager-perfmon
   3   worker04          10.0.10.24  worker04         quorum-manager-perfmon
   4   worker01          10.0.10.21  worker01         perfmon

sh-4.4# mmgetstate -a

 Node number  Node name        GPFS state  
-------------------------------------------
       1      worker02         active
       2      worker03         active
       3      worker04         active
       4      worker01         active

sh-4.4# mmremotefs show all
Local Name  Remote Name  Cluster name            Mount Point        Mount Options    Automount  Drive  Priority
fs1         essfs1       ess3k-2a1.scale.ibm.com /mnt/essfs1        rw               yes          -        0

sh-4.4# mmremotecluster show all
Cluster name:    ess3k-2a1.scale.ibm.com
Contact nodes:   ess3k-2a1.scale.ibm.com,ess3k-gui.scale.ibm.com,ess3k-2b1.scale.ibm.com
SHA digest:      5d26357a46d0526b2ba985bd18f910c9111f3219d241c27141cca050c854ddc8
File systems:    fs1 (essfs1)  

sh-4.4# mlsmount all -L
                                                                      
File system fs1 (ess3k-2a1.scale.ibm.com:essfs1) is mounted on 7 nodes:
  10.0.10.102     ess3k-2b1.scale.ibm.com   ess3k-2a1.scale.ibm.com   
  10.0.10.100     ess3k-2a1.scale.ibm.com   ess3k-2a1.scale.ibm.com   
  10.0.10.110     ess3k-gui.scale.ibm.com   ess3k-2a1.scale.ibm.com   
  10.0.10.22      worker02                  ibm-spectrum-scale.ocp2.scale.ibm.com 
  10.0.10.23      worker03                  ibm-spectrum-scale.ocp2.scale.ibm.com 
  10.0.10.24      worker04                  ibm-spectrum-scale.ocp2.scale.ibm.com 
  10.0.10.21      worker01                  ibm-spectrum-scale.ocp2.scale.ibm.com 
```
You can also check the status of the cluster through the IBM Spectrum Scale CNSA custom resources (CRs).

Check the *Status* and *Events* of the *Cluster* CR to verify that the local CNSA cluster was properly created
(use `oc get clusters -n ibm-spectrum-scale` to obtain the name of the local cluster, the default is *ibm-spectrum-scale*):
```
#  oc describe cluster ibm-spectrum-scale -n ibm-spectrum-scale
Name:         ibm-spectrum-scale
API Version:  scale.spectrum.ibm.com/v1beta1
Kind:         Cluster
[...]
Status:
  Conditions:
    Last Transition Time:  2021-11-12T10:59:49Z
    Message:               The cluster has been configured successfully. Creation of pods and IBM Spectrum Scale cluster is ongoing or completed.
    Reason:                Configured
    Status:                True
    Type:                  Success
Events:                    <none>
```
Check the *Status* and *Events* of the *RemoteCluster* CR to ensure that the status is *True* which indicates that
storage cluster authentication was created successfully. The default name for the *RemoteCluster* CR created 
by the Helm chart is *primary-storage-cluster* 
(use `oc get remoteclusters -n ibm-spectrum-scale` to obtain a list of configured remote clusters):
```
# oc describe remoteclusters primary-storage-cluster -n ibm-spectrum-scale
Name:         primary-storage-cluster
Namespace:    ibm-spectrum-scale
Kind:         RemoteCluster
[...]
Status:
  Conditions:
    Last Transition Time:  2021-11-12T11:03:55Z
    Message:               The remote cluster has been configured successfully.
    Reason:                AuthCreated
    Status:                True
    Type:                  Ready
Events:
  Type     Reason       Age                From           Message
  ----     ------       ----               ----           -------
  Warning  GUINotReady  44m (x4 over 47m)  RemoteCluster  GUI pods are not available yet, waiting and will retry.
  Normal   Created      42m                RemoteCluster  The remote cluster has been configured successfully.
```
Check the *Status* and *Events* of the *Filesystems* CR to verify that the file system was properly created 
(use `oc get filesystems -n ibm-spectrum-scale` to obtain a list of configured file systems, here *fs1*):
```
# oc describe filesystems fs1 -n ibm-spectrum-scale
Name:         fs1
Namespace:    ibm-spectrum-scale
Kind:         Filesystem
[...]
Status:
  Conditions:
    Last Transition Time:  2021-11-12T11:05:00Z
    Message:               The remote filesystem has been created and mounted.
    Reason:                FilesystemEstablished
    Status:                True
    Type:                  Success
Events:
  Type    Reason   Age   From        Message
  ----    ------   ----  ----        -------
  Normal  Created  43m   Filesystem  Attempting to mount filesystem on: [worker01 worker04]
  Normal  Created  42m   Filesystem  The filesystem has been created and mounted.
```

The custom resource (CR) objects contain helpful information which can be retrieved by entering the `oc describe` command.
Depending on your configuration you can view the *Status* and *Events* of the custom resources (CRs), 
such as `cluster`, `daemon`, `filesystem`, `remotecluster`, `callhome` and others.

In case you run into trouble you can also examine the IBM Spectrum Scale CNSA operator log:
```
# oc get pods -n ibm-spectrum-scale-operator
NAME                                                     READY   STATUS    RESTARTS   AGE
ibm-spectrum-scale-controller-manager-75f9c9f6fd-wxk52   1/1     Running   0          3d2h

# oc logs ibm-spectrum-scale-controller-manager-75f9c9f6fd-wxk52 -n ibm-spectrum-scale-operator
[...]
```

## CNSA Helm chart hooks

The Helm chart makes use of *hooks* (Kubernetes *Jobs*) to test that the provided user credentials for CNSA and CSI on the 
storage cluster GUI are properly configured before deploying the application. 
The *hooks* run with the credentials being provided in the *config.yaml* file (`createSecrets: true`) 
or with the manually created *secrets* (`createSecrets: false`).

If you wish to deploy the Helm chart *without* hooks just add the `--no-hooks` option:
```
# helm install ibm-spectrum-scale helm/ibm-spectrum-scale -f config.yaml --no-hooks -n ibm-spectrum-scale
```
If the hooks indicate a failure the deployment of the Helm chart will fail before
any further templates are deployed. Only the *CRDs* and *namespaces* as located 
in [crds/](helm/ibm-spectrum-scale/crds) will have been applied. 
The Helm chart deployment will be listed as *failed*:
```
# helm list -A
NAME                NAMESPACE           REVISION  UPDATED                                 STATUS  CHART                     APP VERSION
ibm-spectrum-scale  ibm-spectrum-scale  1         2021-11-12 04:43:42.797431382 -0500 EST failed  ibm-spectrum-scale-1.1.4  v5.1.1.4  
```
If you encounter an error like
```
# helm install ibm-spectrum-scale helm/ibm-spectrum-scale -f config.yaml -n ibm-spectrum-scale
Error: failed pre-install: job failed: BackoffLimitExceeded
```
then check the logs of the related Kubernetes Jobs for the *hooks* to identify *why* 
the CNSA / CSI user access to the storage GUI failed:
```
# oc logs job/ibm-spectrum-scale-cnsa-gui-access-test -n ibm-spectrum-scale
# oc logs job/ibm-spectrum-scale-csi-gui-access-test -n ibm-spectrum-scale-csi
```
A `401 Unauthorized Error` indicates that the provided credentials are not correct or that
the user has not properly been created on the storage cluster GUI.

If the Helm chart deployment should fail (typically after 5 minutes) with
```
# helm install ibm-spectrum-scale helm/ibm-spectrum-scale -f config.yaml -n ibm-spectrum-scale
Error: failed pre-install: job failed: DeadlineExceeded
```
then this may indicate that the Kubernetes Jobs failed because the manually created Kubernetes *secrets* 
(`createSecrets: false`) were not found in their respective namespaces:
- `cnsa-remote-gui-secret` (default name) in the CNSA namespace `ibm-spectrum-scale`
- `csi-remote-gui-secret` (default name) in the CSI namespace `ibm-spectrum-scale-csi`. 

In this case you will see events like
```
# oc get events -n ibm-spectrum-scale | grep Error
13m  Warning   Failed   pod/ibm-spectrum-scale-cnsa-gui-access-test-452sc   Error: secret "cnsa-remote-gui-secret" not found

# oc get events -n ibm-spectrum-scale-csi | grep Error
24m  Warning   Failed   pod/ibm-spectrum-scale-csi-gui-access-test-8p8k2   Error: secret "csi-remote-gui-secret" not found
```
You would have to fix the issue (validate that the secrets are created in the right namespaces, 
that network connectivity to the GUI server exists, that the GUI users are created properly
and that the credentials are correct) and uninstall the failed Helm chart before redeploying it:
```
# helm uninstall ibm-spectrum-scale -n ibm-spectrum-scale
release "ibm-spectrum-scale" uninstalled
```
You can verify proper access to the GUI of the remote IBM Spectrum Scale storage cluster by running, for example, 
```
# curl -k -u 'csi_admin:csi_PASSWORD' https://<remote storage cluster GUI host>:443/scalemgmt/v2/cluster
```
with the IBM Spectrum Scale *CSI user* as well as the *CNSA user* credentials 
(from an admin node on the OpenShift cluster network).

This ensures that the user credentials are correct and that the nodes on the OpenShift network will have access 
to the remote IBM Spectrum Scale storage cluster.

## Remove IBM Spectrum Scale CNSA and CSI deployment

IMPORTANT: Don't simply run `helm uninstall` as some resources which were created by the operators
require a proper clean-up first!

To remove *IBM Spectrum Scale Container Native Storage Access* with *IBM Spectrum Scale CSI driver* please refer to the
official IBM documentation at 
[Cleaning up the container native cluster](https://www.ibm.com/docs/en/scalecontainernative?topic=5114-cleaning-up-container-native-cluster)

When completely uninstalling the IBM Spectrum Scale CNSA and CSI driver deployment make sure that all applications 
using persistent storage provided by IBM Spectrum Scale are stopped and verify that all related SC, PVC and PV objects are removed.

The complete removal of the IBM Spectrum Scale CNSA and CSI involves these steps: 

(1) Delete the *ibm-spectrum-scale-controller-manager* deployment:
```
# oc delete deployment ibm-spectrum-scale-controller-manager -n ibm-spectrum-scale-operator
```

(2) Delete the *csiscaleoperators* CR to remove IBM Spectrum Scale CSI driver:
```
# oc delete  csiscaleoperators ibm-spectrum-scale-csi -n ibm-spectrum-scale-csi
```
Wait until all resources from the previous steps were successfully deleted.

(3) Uninstall the Helm chart to remove IBM Spectrum Scale CNSA:
```
# helm uninstall ibm-spectrum-scale -n ibm-spectrum-scale
```

(4) Delete the applied IBM Spectrum Scale CRDs and namespaces:
```
# oc delete -f helm/ibm-spectrum-scale/crds
```

(5) Clean up remaining IBM Spectrum Scale CNSA PVs and Storage Classes:
```
# oc delete pv -lapp.kubernetes.io/instance=ibm-spectrum-scale,app.kubernetes.io/name=pmcollector
# oc delete sc -lapp.kubernetes.io/instance=ibm-spectrum-scale,app.kubernetes.io/name=pmcollector
```

(6) Clean up local IBM Spectrum Scale directories on the OpenShift worker nodes:
```
# oc get nodes -l node-role.kubernetes.io/worker --no-headers | while read a b; do echo "## $a ##"; oc debug node/$a -- chroot /host sh -c "rm -rf /var/mmfs; rm -rf /var/adm/ras"; sleep 5; done
# oc get nodes -l node-role.kubernetes.io/worker --no-headers | while read a b; do echo "## $a ##"; oc debug node/$a -- chroot /host sh -c "ls /var/mmfs; ls /var/adm/ras"; sleep 5; done
```
Make sure that all these directories have been removed successfully.

(7) Remove all IBM Spectrum Scale CNSA node labels:
```
# oc label node --all scale.spectrum.ibm.com/role- scale.spectrum.ibm.com/designation- scale-
```

(8) Clean up remote storage cluster: 

(a) Remove the authorization for the remote mount for IBM Spectrum Scale CNSA:
```
# mmauth show all
Cluster name:        ibm-spectrum-scale.ocp2.scale.ibm.com
Cipher list:         AUTHONLY
SHA digest:          120181a28e571aebef129fc3d6f0ab4808f7805b1bb1c702ad0900fd9dfcba05
File system access:  essfs1   (rw, root allowed)

Cluster name:        ess3k-2a1.scale.ibm.com (this cluster)
Cipher list:         AUTHONLY
SHA digest:          5d26357a46d0526b2ba985bd18f910c9111f3219d241c27141cca050c854ddc8
File system access:  (all rw)

# mmauth delete ibm-spectrum-scale.ocp2.scale.ibm.com
mmauth: Propagating the cluster configuration data to all affected nodes.
mmauth: Command successfully completed
```
The CNSA cluster will show up as `ibm-spectrum-scale.[your-OpenShift-domain]`.

(b) Remove the primary fileset created by IBM Spectrum Scale CSI:
```
# mmlsfileset essfs1 -L
Filesets in file system 'essfs1':
Name                                    Id  RootInode  ParentId Created                      InodeSpace      MaxInodes    AllocInodes Comment
root                                     0          3        -- Thu Jul  1 10:15:19 2021        0             24830976         500736 root fileset
primary-fileset-fs1-17732446135908190530 1     524291         0 Fri Nov 12 12:04:41 2021        1              1048576          52224 Fileset created by IBM Container Storage Interface driver

# mmunlinkfileset essfs1 primary-fileset-fs1-17732446135908190530
Fileset primary-fileset-fs1-17732446135908190530 unlinked.

# mmdelfileset essfs1 primary-fileset-fs1-17732446135908190530 -f
Checking fileset ...
Checking fileset complete.
Deleting user files ...
 100.00 % complete on Mon Nov 15 16:46:54 2021  (     52224 inodes with total        204 MB data processed)
Deleting fileset ...
Fileset primary-fileset-fs1-17732446135908190530 deleted.
```
The name of the primary fileset name of the IBM Spectrum Scale CSI driver is built as follows: 
`primary-fileset-[your-CNSA-file-system-name]-[your-CNSA-cluster-ID]`.

## Deploy IBM Spectrum Scale CNSA and CSI driver using Helm chart templating

By deploying IBM Spectrum Scale CNSA with IBM Spectrum Scale CSI driver as a Helm chart
with `helm install` the deployed application has ties to Helm as a deployed Helm chart *release*
which offers additional (but, here, also *unsupported*) features after the initial deployment 
like *uninstall*, *upgrade* and *rollback* of releases.

However, the Helm chart is meant to assist with an initial installation but is not a formally supported offering by IBM. 
The Helm chart is not supported by the IBM Spectrum Scale container native nor CSI offerings 
and is outside the scope of the IBM PMR process. 

In order to take Helm out of the picture for the deployment there is a way of using the Helm chart
without actually using Helm for *deploying* and *managing* the application as an *active* Helm chart release.

While still enjoying the convenience of a Helm chart deployment with a central [*config.yaml*](config.yaml) file
as described above we can also deploy IBM Spectrum Scale CNSA with IBM Spectrum Scale CSI driver 
based on the very same Helm chart but without any further dependencies on Helm for the deployed application.

By using `helm template` Helm allows to generate a deployable YAML manifest from a given Helm chart with all 
parameters from the [*config.yaml*](config.yaml) applied. Instead of
```
# helm install ibm-spectrum-scale helm/ibm-spectrum-scale -f config.yaml -n ibm-spectrum-scale
```
you can simply use
```
# oc apply -f helm/ibm-spectrum-scale/crds 
# helm template ibm-spectrum-scale helm/ibm-spectrum-scale -f config.yaml --no-hooks -n ibm-spectrum-scale | oc apply -f -
```
which generates a complete YAML manifest from the Helm charts and applies it to the OpenShift cluster 
like a regular deployment of YAML manifests without any ties to Helm. As the *custom resource definitions* (CRDs) and 
*namespaces* in the [crds/](helm/ibm-spectrum-scale/crds) folder are not templated
by Helm they need to be applied separately when using this approach.

In this case Helm is only used as *generator* to build the final YAML manifests from the parameters in the 
[*config.yaml*](config.yaml) file and manifest templates in the Helm chart. 
Helm itself is not used for the deployment nor for the management of the deployed release of the application. 

This would allow to deploy IBM Spectrum Scale CNSA and CSI driver with the *ease of use* and *convenience* of a Helm chart 
but leaving no ties nor dependencies on Helm. 
The result is similar to a manual deployment of the officially released and manually edited YAML manifests.

Note, the templated manifests above would still add one additional *label* to all deployed resources 
but this additional label should not cause any issues:
```
helm.sh/chart: {{ include "ibm-spectrum-scale.chart" . }}
```
To remove this label and leave absolutely no traces of the Helm chart you can run:
```
# oc apply -f ./helm/ibm-spectrum-scale/crds 
# helm template ibm-spectrum-scale helm/ibm-spectrum-scale -f config.yaml --no-hooks -n ibm-spectrum-scale | grep -v 'helm.sh/chart' | oc apply -f -
```

## Example of using storage provisioning with IBM Spectrum Scale

This Github repository also provides a set of YAML manifests in the [*examples/*](examples/) directory 
to quickly get started with *dynamic provisioning* of persistent volumes (PVs) with IBM Spectrum Scale CNSA.

These sample manifests allow to create a *storage class* (SC) and run a quick *sanity check* with 
a full cycle of dynamic storage provisioning using a *persistent volume claim* (PVC) and a *test pod*
after the successful deployment of IBM Spectrum Scale CNSA and the IBM Spectrum Scale CSI driver.

The examples manifests in the [*examples/*](examples/) directory comprise:
- [*ibm-spectrum-scale-sc.yaml*](examples/ibm-spectrum-scale-sc.yaml) (storage class, fileset based, used for the PVC and test-pod)
- [*ibm-spectrum-scale-light-sc.yaml*](examples/ibm-spectrum-scale-light-sc.yaml) (storage class, lightweight / directory based)
- [*ibm-spectrum-scale-pvc.yaml*](examples/ibm-spectrum-scale-pvc.yaml) (persistent volume claim / PVC) 
- [*ibm-spectrum-scale-test-pod.yaml*](examples/ibm-spectrum-scale-test-pod.yaml) (test pod using a Red Hat *ubi8/ubi-minimal* image)

For a full *dynamic provisioning* test cycle we will
1. Create a *storage class* (SC) named *ibm-spectrum-scale-sc*
   from [*ibm-spectrum-scale-sc.yaml*](examples/ibm-spectrum-scale-sc.yaml)
   to allow dynamic provisioning of *persistent volumes* (PVs).
2. Issue a *persistent volume claim* (PVC) by applying [*ibm-spectrum-scale-pvc.yaml*](examples/ibm-spectrum-scale-pvc.yaml)
   in order to request a *persistent volume* (PV) from the above *storage class*. The PV will then be bound to the PVC.
3. Run a test pod created from [*ibm-spectrum-scale-test-pod.yaml*](examples/ibm-spectrum-scale-test-pod.yaml)
   that will mount the above PVC as a volume and write timestamps in 5-second intervals 
   into the directory on IBM Spectrum Scale that is backing the PV.

The *storage class* (SC) for *dynamic provisioning* needs to be created by an OpenShift *cluster-admin* user.

The *persistent volume claim* (PVC) can be issued by a regular OpenShift user to request and consume persistent storage 
in the user's namespace.

In this example we use a storage class from [*ibm-spectrum-scale-sc.yaml*](examples/ibm-spectrum-scale-sc.yaml)
that provides *dynamic provisioning* of persistent volumes backed by *independent filesets* in IBM Spectrum Scale.

The IBM Spectrum Scale CSI driver allows to use three different kinds of *storage classes* for *dynamic provisioning*:
* *lightweight* volumes using simple directories in IBM Spectrum Scale
* file-set based volumes using *independent filesets* in IBM Spectrum Scale
* file-set based volumes using *dependent filesets* in IBM Spectrum Scale

See [*IBM Spectrum Scale CSI Driver: Storage Class*](https://www.ibm.com/docs/en/spectrum-scale-csi?topic=configurations-storage-class)
for more details and options.

Edit the provided *storage class* manifest [ibm-spectrum-scale-sc.yaml](examples/ibm-spectrum-scale-sc.yaml)
and set the values of **volBackendFs** and **clusterId** accordingly to match your environment:
```
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ibm-spectrum-scale-sc
provisioner: spectrumscale.csi.ibm.com
parameters:
  volBackendFs: "<file system name on the local CNSA cluster, here: fs1>"
  clusterId: "<cluster ID of the remote storage cluster, here: 215057217487177715>"
  [...]
reclaimPolicy: Delete
```
You can ignore all other parameters in the storage class for now. Please refer to 
[*Storage Class*](https://www.ibm.com/docs/en/spectrum-scale-csi?topic=configurations-storage-class) to learn more about them.

Apply the *storage class* (SC) in OpenShift as a user with a *cluster-admin* role: 
```
# oc apply -f examples/ibm-spectrum-scale-sc.yaml 
storageclass.storage.k8s.io/ibm-spectrum-scale-sc created

# oc get sc
NAME                          PROVISIONER                    RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
ibm-spectrum-scale-sc         spectrumscale.csi.ibm.com      Delete          Immediate              false                  2s
```
Now you can switch to a regular user profile in OpenShift, create a new namespace (optional)
```
# oc new-project test-namespace
Now using project "test-namespace" on server "https://api.2.scale.ibm.com:6443".
```
and issue a request for a *persistent volume claim* (PVC) by applying the 
[*ibm-spectrum-scale-pvc.yaml*](examples/ibm-spectrum-scale-pvc.yaml) manifest:
```
# oc apply -f examples/ibm-spectrum-scale-pvc.yaml
persistentvolumeclaim/ibm-spectrum-scale-pvc created

# oc get pvc
NAME                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS            AGE
ibm-spectrum-scale-pvc   Bound    pvc-87f18620-9fac-44ce-ad19-0def5f4304a1   1Gi        RWX            ibm-spectrum-scale-sc   75s
```
In this example we request a PV with only 1 GiB of storage capacity from the *ibm-spectrum-scale-sc* storage class:
```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ibm-spectrum-scale-pvc
spec:
  storageClassName: ibm-spectrum-scale-sc
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
```
You can increase the requested capacity in [*ibm-spectrum-scale-pvc.yaml*](examples/ibm-spectrum-scale-pvc.yaml) 
by setting `storage: 1Gi` to the capacity wanted, e.g. 100Gi. 

Wait until the PVC is bound to a PV. A PVC (like a pod) is bound to a *namespace* in OpenShift 
(unlike a PV which is not a *namespaced* object).

Once the PVC is bound to a PV we can run the *test pod* by applying the
[*ibm-spectrum-scale-test-pod.yaml*](examples/ibm-spectrum-scale-test-pod.yaml) manifest: 
```
# oc apply -f examples/ibm-spectrum-scale-test-pod.yaml 
pod/ibm-spectrum-scale-test-pod created
```
The *test pod* will mount the PV under the local mount point */data* in the container of the created pod.
Once the pod is running you can see that a time stamp is written in 5-second intervals 
to a log file *stream1.out* in the local */data* directory:
```
# oc get pods
NAME                          READY   STATUS    RESTARTS   AGE
ibm-spectrum-scale-test-pod   1/1     Running   0          23s

# oc rsh ibm-spectrum-scale-test-pod
/ # cat /data/stream1.out 
ibm-spectrum-scale-test-pod 20210215-12:00:54
ibm-spectrum-scale-test-pod 20210215-12:00:59
ibm-spectrum-scale-test-pod 20210215-12:01:04
ibm-spectrum-scale-test-pod 20210215-12:01:09
ibm-spectrum-scale-test-pod 20210215-12:01:14
```
The */data* directory in the pod's container is backed by the 
*pvc-87f18620-9fac-44ce-ad19-0def5f4304a1/pvc-87f18620-9fac-44ce-ad19-0def5f4304a1-data/* directory
in the IBM Spectrum Scale file system on the remote IBM Spectrum Scale storage cluster:
```
# cat /<mount point of filesystem on remote storage cluster>/pvc-87f18620-9fac-44ce-ad19-0def5f4304a1/pvc-87f18620-9fac-44ce-ad19-0def5f4304a1-data/stream1.out 
ibm-spectrum-scale-test-pod 20210215-12:00:54
ibm-spectrum-scale-test-pod 20210215-12:00:59
ibm-spectrum-scale-test-pod 20210215-12:01:04
ibm-spectrum-scale-test-pod 20210215-12:01:09
ibm-spectrum-scale-test-pod 20210215-12:01:14
```
In this example *pvc-87f18620-9fac-44ce-ad19-0def5f4304a1* is created as an 
*independent fileset* on the file system *essfs1* on the remote storage cluster:
```
# mmlsfileset essfs1 -L
Filesets in file system 'essfs1':
Name                                    Id      RootInode  ParentId Created                      InodeSpace      MaxInodes    AllocInodes Comment
root                                     0              3        -- Mon May 11 20:19:22 2020        0             15490304         500736 root fileset
pvc-87f18620-9fac-44ce-ad19-0def5f4304a1 1         524291         0 Mon Feb 15 12:56:11 2021        1                 1024           1024 Fileset created by IBM Container Storage Interface driver
```
Be sure to *clean up* after this test and delete the *test pod*, *persistent volume claim* and *storage class*:
```
# oc delete -f examples/ibm-spectrum-scale-test-pod.yaml 
pod "ibm-spectrum-scale-test-pod" deleted

# oc delete -f examples/ibm-spectrum-scale-pvc.yaml
persistentvolumeclaim "ibm-spectrum-scale-pvc" deleted

# oc delete -f examples/ibm-spectrum-scale-sc.yaml 
storageclass.storage.k8s.io "ibm-spectrum-scale-sc" deleted
```
You may keep the *storage class* (SC) as an intial storage class to start with.
