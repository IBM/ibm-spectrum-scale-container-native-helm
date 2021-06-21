# Helm Chart Deployment of IBM Spectrum Scale CNSA/CSI

## Table of Contents

- [Abstract](#abstract)
- [Architecture](#architecture)
- [Requirements](#requirements)
- [Repository structure](#repository-structure)
- [Preinstallation tasks](#preinstallation-tasks)
  - [Upload IBM Spectrum Scale CNSA images to local image registry](#upload-ibm-spectrum-scale-cnsa-images-to-local-image-registry)
  - [Prepare OpenShift cluster nodes to run IBM Spectrum Scale CNSA](#prepare-openshift-cluster-nodes-to-run-ibm-spectrum-scale-cnsa)
  - [Label OpenShift worker nodes for IBM Spectrum Scale CSI driver](#label-openshift-worker-nodes-for-ibm-spectrum-scale-csi-driver)
- [Deployment steps](#deployment-steps)
  - [(STEP 1) Prepare IBM Spectrum Scale remote storage cluster and OpenShift namespaces and secrets](#step1)
    - Create GUI user for CNSA on the remote IBM Spectrum Scale storage cluster
    - Create GUI user for CSI driver on the remote IBM Spectrum Scale storage cluster
    - Apply quota and configuration settings required for CSI driver on the remote IBM Spectrum Scale storage cluster 
    - Prepare namespaces in OpenShift
    - Create secret for CNSA user credentials (remote cluster)
    - Create secrets for CSI user credentials (remote & local cluster)
    - Verify access to the remote IBM Spectrum Scale storage cluster GUI
  - [(STEP 2) Edit the config.yaml file to reflect your local environment](#step2)
    - Minimum required configuration
    - Optional configuration parameters
      - Call home (optional)
      - Hostname aliases (optional)
  - [(STEP 3) Deploy the IBM Spectrum Scale CNSA Helm Chart (*ibm-spectrum-scale*)](#step3)
  - [(STEP 4) Deploy IBM Spectrum Scale CSI driver Helm Chart (*ibm-spectrum-scale-csi*)](#step4)
- [Remove IBM Spectrum Scale CNSA and CSI deployment](#remove-ibm-spectrum-scale-cnsa-and-csi-deployment)
- [Deploy IBM Spectrum Scale CNSA and CSI driver using Helm chart templating](#deploy-ibm-spectrum-scale-cnsa-and-csi-driver-using-helm-chart-templating)
- [Example of using IBM Spectrum Scale provisioned storage](#example-of-using-ibm-spectrum-scale-provisioned-storage)
- [Additional configuration options](#additional-configuration-options)
  - Specify node selectors for IBM Spectrum Scale CNSA (optional)
  - Specify node labels for IBM Spectrum Scale CSI driver (optional)
  - Specify pod tolerations for IBM Spectrum Scale CSI driver (optional)

## Abstract

This document describes the combined deployment of

- [*IBM Spectrum Scale Container Native Storage Access* (CNSA) v5.1.0.3](https://www.ibm.com/docs/en/scalecontainernative?topic=spectrum-scale-container-native-storage-access-5103) and 
- [*IBM Spectrum Scale CSI driver* v2.1.0](https://www.ibm.com/docs/en/spectrum-scale-csi?topic=spectrum-scale-container-storage-interface-driver-210) 

using *two* Helm charts with a *single* configuration file ([*config.yaml*](config.yaml)).

The installation of the IBM Spectrum Scale® CNSA with IBM Spectrum Scale® CSI driver on Red Hat® OpenShift® requires two distinct installation steps because
a few manual steps need to be performed *after* the IBM Spectrum Scale® CNSA deployment and 
*prior* to the IBM Spectrum Scale® CSI driver deployment.

If you have already prepared all pre-installation tasks from the official IBM Documentation and meet all the requirements listed in
[Requirements](#requirements) then you can directly continue with the installation steps in [Deployment steps](#deployment-steps).


## Architecture

IBM Spectrum Scale® in containers allows the deployment of the cluster file system in a Red Hat® OpenShift® cluster. 
Using a remote mount attached file system, the IBM Spectrum Scale solution provides a persistent data store to be accessed by the applications 
via the IBM Spectrum Scale Container Storage Interface (CSI) driver using Persistent Volumes (PVs).

IBM Spectrum Scale CNSA will be running on the OpenShift cluster and be refered to as local IBM Spectrum Scale *compute* cluster.
The physical storage is provided by the remote IBM Spectrum Scale *storage* cluster 
(e.g. an [IBM Elastic Storage System](https://www.ibm.com/products/elastic-storage-system))
using a remote mount of an IBM Spectrum Scale file system.

![plot](./pics/ibm-spectrum-scale-cnsa.png)


## Requirements

To install 
[*IBM Spectrum Scale CNSA*](https://www.ibm.com/docs/en/scalecontainernative?topic=spectrum-scale-container-native-storage-access-5103) and 
[*IBM Spectrum Scale CSI driver*](https://www.ibm.com/docs/en/spectrum-scale-csi?topic=spectrum-scale-container-storage-interface-driver-210) 
with these Helm charts on Red Hat OpenShift 4.5 (or higher) the following requirements need to be met together
with the regular pre-requisites for IBM Spectrum Scale CNSA and CSI driver as described in their respective IBM Documentation:

* The official IBM Spectrum Scale CNSA v5.1.0.3 tar archive (obtainable from IBM Fix Central or IBM Passport Advantage®) 
  needs to be extracted on a local installation node with access to the OpenShift cluster (e.g. via `oc` commands).
* This Github repo needs to be cloned to the local installation node. 
* An IBM Spectrum Scale *storage* cluster with IBM Spectrum Scale version 5.1.0.1 or higher (ideally 3 nodes or more) with an IBM Spectrum Scale GUI 
  to provide an IBM Spectrum Scale file system that will be mounted as a remote file system (or as a *cross-cluster mount*) 
  in the local IBM Spectrum Scale CNSA compute cluster on the OpenShift worker nodes; Note that all nodes of the local compute and remote storage cluster need to
  be able to communicate over the IBM Spectrum Scale *daemon* network with each other (pre-requisite for a remote mount).
* A Red Hat OpenShift Container Platform cluster, version 4.5 or 4.6.6 (or higher minor version).
* A *regular* OpenShift cluster admin *user* with *cluster-admin* role is required on the OpenShift cluster (i.e. `oc whoami -t` returns a token)
  to push the IBM Spectrum Scale CNSA images to the internal OpenShift image registry. This cluster admin user can also deploy IBM Spectrum Scale CNSA/CSI.
  See the [note](#clusteradmin) below for more information on how to create such a user.
* *helm* v3 (or higher) needs to be installed on the local installation node, see [Installing Helm](https://helm.sh/docs/intro/install/)
* *podman* is required on the local installation node in order to load, tag and push the IBM Spectrum Scale CNSA images into the internal OpenShift registry
  using the provided script in `./scripts/upload_images.sh`.  
  Otherwise all IBM Spectrum Scale CNSA images would need to be pushed manually into the image registry of choice before deploying the Helm charts.
  See [IBM Spectrum Scale CNSA - Container Images](https://www.ibm.com/docs/en/scalecontainernative?topic=installation-container-images)
* Internet access is required to pull all other dependent images for IBM Spectrum Scale CNSA and CSI from their respective external image registries, e.g. quay, us.gcr.io, etc.
  See [External Container Images](https://www.ibm.com/docs/en/scalecontainernative?topic=planning-container-image-listing-spectrum-scale-container-native-storage-access)


## Repository structure

When cloning this repository you will find the following files in your local directory:
```
README.md
config.yaml           << one central configuration file with minimum required variables for the customer
helm/
 \-ibm-spectrum-scale
   |-Chart.yaml       << defines Helm chart version and provides additional info
   |-LICENSE
   |-values.yaml      << holds all configurable variables of the Helm chart / offers extended options
   |-crds/            << holds the custom resource definitions for the CNSA deployment
   |-templates/       << holds the templates of the YAML files for the CNSA deployment
 \-ibm-spectrum-scale-csi
   |-Chart.yaml       << defines Helm chart version and provides additional info
   |-LICENSE
   |-values.yaml      << holds all configurable variables of the Helm chart / offers extended options
   |-crds/            << holds the custom resource definitions for the CSI deployment
   |-templates/       << holds the templates of the YAML files for the CSI deployment
scripts/
 |- upload_images.sh  << provides a script to upload the images from the CNSA tar archive to the OpenShift internal registry
examples/
 |- ibm-spectrum-scale-sc.yaml         << storage class (SC) example for CNSA
 |- ibm-spectrum-scale-pvc.yaml        << persistent volume claim (PVC) example for CNSA
 |- ibm-spectrum-scale-test-pod.yaml   << test pod example for CNSA
```
The **config.yaml** file describes the parameters for the local environment and needs to be edited by the administrator accordingly. 
It provides a single place with a *minimum set of variables* required for the combined deployment of *IBM Spectrum Scale CNSA* and IBM Spectrum Scale CSI driver*.

The two distinct Helm charts for the IBM Spectrum Scale CNSA and CSI driver deployment are located in the *helm/* directory 
as **ibm-spectrum-scale** and **ibm-spectrum-scale-csi**, respectively.

Each of these Helm charts consists of a default **values.yaml** file that defines the available *variables* and their *default values* which are
used in the YAML templates. The YAML templates can be found in the **templates/** directory.
In contrast to the **config.yaml** file each **values.yaml** file contains additional configuration variables with their default values 
which are more specific to the individual release packages of IBM Spectrum Scale CNSA and CSI, e.g. image names and tags. 
These should not typically need to be edited by an end user for deployment. These **values.yaml** files are an inherent part of each Helm chart
and offer a great way for developers to quickly use the same Helm chart with different images and tags for development deployments without 
the need to edit individual YAML manifests manually.

The **crds/** directory stores the unchanged original *custom resource definitions* (CRDs) for the IBM Spectrum Scale CNSA and CSI driver releases 
which will not be templated by Helm. 

The **Chart.yaml** file describes the general properties of the Helm chart such as the Helm chart name, the *Helm chart version* and the *appVersion*.
The *appVersion* is used as the *default tag* for the images in the Helm chart if no other tag is explicitely defined for the container images in `values.yaml`,e.g.
**appVersion** is *v5.1.0.3* for IBM Spectrum Scale CNSA v5.1.0.3 and *v2.1.0* for IBM Spectrum Scale CSI driver v2.1.0. 


## Preinstallation tasks

Be sure to perform all pre-installation tasks for the IBM Spectrum Scale CNSA and CSI driver deployment, e.g.
* [Extracting the CNSA tar archive](https://www.ibm.com/docs/en/scalecontainernative?topic=installation-preparation)
* [Configuring Red Hat® OpenShift® Container Platform](https://www.ibm.com/docs/en/scalecontainernative?topic=installation-red-hat-openshift-container-platform-configuration)
  to increase the **PIDS_LIMIT**, add the **kernel-devel** extensions (only required on *OpenShift 4.6* and higher) 
  and increase **vmalloc kernel parameter** (the latter is only required for *Linux on System Z*)
* [Configuring IBM Spectrum Scale fileset quotas and configuration parameters for CSI](https://www.ibm.com/docs/en/scalecontainernative?topic=csi-performing-pre-installation-tasks-operator-deployment),
  e.g. parameters like `--perfileset-quota`, `--filesetdf`, `enforceFilesetQuotaOnRoot`, `controlSetxattrImmutableSELinux`.

If you stay with the defaults you only need to perform a few steps as outlined below to prepare the OpenShift cluster for the deployment of IBM Spectrum Scale CNSA and CSI driver.

Should you need to configure optional parameters like node labels and annotations for IBM Spectrum Scale CNSA and CSI you can take a look at 
the [Optional configuration parameters](#optional-configuration-parameters) section further down below.

### Upload IBM Spectrum Scale CNSA images to local image registry

After you have unpacked the IBM Spectrum Scale CNSA tar archive you need to *load*, *tag* and *push* the IBM Spectrum Scale CNSA images to
a local container image registry. 

If you have *enabled* and *exposed* the internal Red Hat OpenShift image registry in your OpenShift cluster 
(see [*Integrated OpenShift Container Platform registry*](https://docs.openshift.com/container-platform/4.5/registry/architecture-component-imageregistry.html)) 
you can conveniently push all the IBM Spectrum Scale CNSA images into this registry by using the [upload_images.sh](scripts/upload_images.sh) script 
provided with this Github repository.
Move the `upload_images.sh` into the extracted IBM Spectrum Scale CNSA tar archive, log in to the OpenShift cluster as a regular *cluster admin* user, create a project/namespace for
the IBM Spectrum Scale CNSA deployment (here we use *ibm-spectrum-scale*) and run the `upload_images.sh` script:
```
# oc new-project <ibm-spectrum-scale>
# ./upload_images.sh 
```

<a name="clusteradmin"></a>
Note: A production-ready Red Hat OpenShift cluster would have a properly configured *identity provider* and a regular *cluster-admin* user 
other than the default admin users like `kube:admin` or `system:admin` which are meant primarily as temporary accounts for the initial deployment
and do not provide a token (`oc whoami -t`) to access the internal OpenShift image registry.
The steps to create such a user include 
1. Adding an *identity provider* like *HTPasswd* to the OpenShift cluster 
(see [Configuring an HTPasswd identity provider](https://docs.openshift.com/container-platform/4.5/authentication/identity_providers/configuring-htpasswd-identity-provider.html))
and
2. Creating a regular admin user account with a *cluster-admin* role with 
```
# oc adm policy add-cluster-role-to-user cluster-admin <user-name>
```
(see  [Creating a cluster admin](https://docs.openshift.com/container-platform/4.5/authentication/using-rbac.html#creating-cluster-admin_using-rbac)).
This regular OpenShift admin user can push images to the internal OpenShift registry *and* deploy the Helm charts without the need to switch users. 

### Prepare OpenShift cluster nodes to run IBM Spectrum Scale CNSA

You need to increase the **PIDS_LIMIT** limit to a minimum of `pidsLimit: 4096` using the *Machine Config Operator* (MCO) 
on OpenShift by applying the provided YAML file in the IBM Spectrum Scale CNSA tar archive:
```
# oc create -f machineconfig/increase_pid_mco.yaml
# oc label machineconfigpool worker pid-crio=config-pid
```
Note: Executing this command will drive a rolling update across your Red Hat OpenShift Container Platform worker nodes and could take 
over 30 minutes depending on the size of the worker node pool, as the worker will be rebooted. 
You can check the update with
```
# oc get MachineConfigPool
```
Wait until the update has finished successfully.

Should you run on **OpenShift 4.6.6** (or a higher minor level) you additionally need to add **kernel-devel** extensions 
via with the Machine Config Operator by creating a YAML file as follows (here named *machineconfigoperator.yaml*)
```
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: "worker"
  name: 02-worker-kernel-devel
spec:
  config:
    ignition:
      version: 3.1.0
  extensions:
     - kernel-devel
```
and applying it 
```
# oc create -f machineconfigoperator.yaml
```
You can check the status of the update using:
```
# oc get MachineConfigPool
```
Wait until the update has finished successfully.

You can validate that the *kernel-devel* package is successfully applied by running
```
# oc get nodes -l node-role.kubernetes.io/worker \
-ojsonpath="{range .items[*]}{.metadata.name}{'\n'}" |\
xargs -I{} oc debug node/{} -T -- chroot /host sh -c "rpm -q kernel-devel"
```

### Label OpenShift worker nodes for IBM Spectrum Scale CSI driver

Using the default configuration for IBM Spectrum Scale CNSA and CSI driver
you need to label the worker nodes eligible to run IBM Spectrum Scale CSI 
with the label **scale=true** as follows:
```
# oc label nodes -l node-role.kubernetes.io/worker scale=true --overwrite=true
```


## Deployment Steps

The deployment of IBM Spectrum Scale CNSA and IBM Spectrum Scale CSI driver follows these steps:

1. Prepare IBM Spectrum Scale GUI users for CNSA and CSI and OpenShift *namespaces* and *secrets*
2. Edit the [*config.yaml*](config.yaml) file to reflect your local environment
3. Deploy the IBM Spectrum Scale CNSA Helm chart (*ibm-spectrum-scale*) and wait until the local IBM Spectrum Scale CNSA cluster is properly created and running
4. Deploy the IBM Spectrum Scale CSI driver Helm chart (*ibm-spectrum-scale-csi*)

At the heart of the Helm chart deployment is the central [*config.yaml*](config.yaml) file
which contains the configurable parameters to describe the local environment for IBM Spectrum Scale CNSA and CSI driver 
such as the image registry, names of the created secrets for the CNSA/CSI user credentials as well as 
the local compute and remote storage cluster configuration.

All these configuration parameters will automatically be applied to the YAML manifests and custom resources when deploying the
Helm charts for IBM Spectrum Scale CNSA and IBM Spectrum Scale CSI driver. The Helm charts offer a unified deployment experience 
without the need to edit various custom resources and other YAML files individually.

<a name="step1"></a>
### (STEP 1) Prepare IBM Spectrum Scale remote storage cluster and OpenShift namespaces and secrets

This step creates the required IBM Spectrum Scale CNSA and CSI driver user accounts in the IBM Spectrum Scale GUI 
on the *remote* IBM Spectrum Scale *storage* cluster. We need 
* one user account for an IBM Spectrum Scale CNSA user (here we use *cnsa_admin* with password *cnsa_PASSWORD*)
* one user account for an IBM Spectrum Scale CSI driver user (here we use *csi_admin* with password *csi_PASSWORD*).

This step also creates the *namespaces* (aka *projects*) and Kubernetes *secrets* in OpenShift
for the *IBM Spectrum Scale CNSA* and *IBM Spectrum Scale CSI driver* deployment.

The *secrets* contain the credentials for the created IBM Spectrum Scale CNSA and CSI users in the *local* and *remote* IBM Spectrum Scale GUIs.

#### Create GUI user for CNSA on the remote IBM Spectrum Scale storage cluster 

On the remote IBM Spectrum Scale storage cluster check if the GUI user group *ContainerOperator* exists by issuing the following command:
```
# /usr/lpp/mmfs/gui/cli/lsusergrp ContainerOperator
```
If the GUI user group *ContainerOperator* does not exist, create it using the following command:
```
# /usr/lpp/mmfs/gui/cli/mkusergrp ContainerOperator --role containeroperator
```
If no user for CNSA exists in the *ContainerOperator*  group
```
# /usr/lpp/mmfs/gui/cli/lsuser | grep ContainerOperator
# 
```
then create one as follows:
```
# /usr/lpp/mmfs/gui/cli/mkuser cnsa_admin -p cnsa_PASSWORD -g ContainerOperator
```
This user will later be used by *IBM Spectrum Scale CNSA* through the `cnsa-remote-gui-secret` secret.

#### Create GUI user for CSI on the remote IBM Spectrum Scale storage cluster 

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
# /usr/lpp/mmfs/gui/cli/mkuser csi_admin -p csi_PASSWORD -g CsiAdmin
```
This user will later be used by the *IBM Spectrum Scale CSI driver* through the `csi-remote-secret` secret.

#### Apply quota and configuration settings required for CSI driver on the remote IBM Spectrum Scale storage cluster 

(1) Ensure that per `--fileset-quota` on the file systems to be used by IBM Spectrum Scale CNSA and CSI driver is set to "no". 
Here we are going to use *ess3k_fs1* as the remote file system for IBM Spectrum Scale CNSA and CSI.
```
# mmlsfs ess3k_fs1 --perfileset-quota
flag                value                    description
------------------- ------------------------ -----------------------------------
 --perfileset-quota no                       Per-fileset quota enforcement
```
If it is set to "yes" you can set it to "no" with
```
# mmchfs ess3k_fs1 --noperfileset-quota
```

(2) Enable quota for all the file systems being used for fileset-based dynamic provisioning with IBM Spectrum Scale CSI driver:
```
# mmchfs ess3k_fs1 -Q yes
```
Verify that quota is enabled for the file system, here *ess3k_fs0*:
```
# mmlsfs ess3k_fs1 -Q 

flag                value                    description
------------------- ------------------------ -----------------------------------
 -Q                 user;group;fileset       Quotas accounting enabled
                    user;group;fileset       Quotas enforced
                    none                     Default quotas enabled
```

(3) Enable quota for the root user by issuing the following command:
```
# mmchconfig enforceFilesetQuotaOnRoot=yes -i
```

(4) For Red Hat OpenShift, ensure that the `controlSetxattrImmutableSELinux` parameter is set to "yes" by issuing the following command:
```
# mmchconfig controlSetxattrImmutableSELinux=yes -i
```

(5) To display the correct volume size in a container, enable `filesetdf` on the file system by using the following command:
```
# mmchfs ess3k_fs1 --filesetdf
```

#### Prepare namespaces in OpenShift

Log in to the OpenShift cluster as regular cluster admin user with a *cluster-admin* role to perform the next steps. 

You need to create two *namespaces* (aka *projects*) in OpenShift: 
* One for the *IBM Spectrum Scale CNSA* deployment, here we use **ibm-spectrum-scale** as name for the IBM Spectrum Scale CNSA namespace.
* One for the *IBM Spectrum Scale CSI driver* deployment, here we use **ibm-spectrum-scale-csi-driver** for the CSI namespace.

If not yet done, create a namespace/project for CNSA:
```
# oc new-project ibm-spectrum-scale
```
The namespace can be chosen freely. Note that we use **ibm-spectrum-scale** as name for the CNSA namespace here 
instead of *ibm-spectrum-scale-ns* which is used in the official IBM documentation.

At this time we also prepare the namespace/project for the **IBM Spectrum Scale CSI driver** in advance.
```
# oc new-project ibm-spectrum-scale-csi-driver
```
Note, that `oc new-project <my-namespace>` also switches to the newly created project/namespace right away. So you need to switch back with `oc project ibm-spectrum-scale` 
to the IBM Spectrum Scale CNSA namespace as first step of the deployment. 
Alternatively, you can also use `oc create namespace <my-namespace>` which does not switch to the created namespace.

#### Create secret for CNSA user credentials (remote cluster)

IBM Spectrum Scale CNSA requires a GUI user account on the *remote* IBM Spectrum Scale storage cluster. 
The credentials will be provided as *username* and *password* through a Kubernetes secret in the IBM Spectrum Scale CNSA namespace (here: *ibm-spectrum-scale*).

Create a Kubernetes *secret* in the CNSA namespace holding the user credentials from the CNSA GUI user on the *remote* IBM Spectrum Scale storage cluster: 
```
# oc create secret generic cnsa-remote-gui-secret  --from-literal=username='cnsa_admin' --from-literal=password='cnsa_PASSWORD' -n ibm-spectrum-scale
```

#### Create secrets for CSI user credentials (remote and local clusters)

IBM Spectrum Scale CSI driver requires a GUI user account on the *remote* IBM Spectrum Scale storage cluster and the *local* IBM Spectrum Scale CNSA compute cluster. 
The credentials will be provided as *username* and *password* through Kubernetes secrets in the IBM Spectrum Scale CSI driver namespace (here: *ibm-spectrum-scale-csi-driver*).

Create and label the Kubernetes *secret* in the CSI driver namespace holding the CSI admin user credentials  
on the *remote* IBM Spectrum Scale *storage* cluster: 
```
# oc create secret generic csi-remote-secret --from-literal=username='csi_admin' --from-literal=password='csi_PASSWORD' -n ibm-spectrum-scale-csi-driver
# oc label secret csi-remote-secret product=ibm-spectrum-scale-csi -n ibm-spectrum-scale-csi-driver 
```
At this time we plan ahead and also create the required Kubernetes *secret* holding the (yet to be created) CSI admin user credentials 
on the *local* IBM Spectrum Scale CNSA *compute* cluster in advance, i.e. before we have actually deployed IBM Spectrum Scale CNSA nor 
created the actual CSI admin user on the GUI of the local IBM Spectrum Scale CNSA cluster:
```
# oc create secret generic csi-local-secret --from-literal=username='csi_admin' --from-literal=password='csi_PASSWORD' -n ibm-spectrum-scale-csi-driver
# oc label secret csi-local-secret product=ibm-spectrum-scale-csi -n ibm-spectrum-scale-csi-driver
```
We will later use these credentials when creating the CSI admin user on the GUI of the *local* IBM Spectrum Scale CNSA compute cluster after the successful deployment.

Make sure to specify the names of these *secrets* accordingly in the [*config.yaml*](config.yaml) file in the next step.

#### Verify access to the remote IBM Spectrum Scale storage cluster GUI

Before moving on it is a good idea to verify access to the GUI of the remote IBM Spectrum Scale storage cluster by running, for example, 
```
# curl -k -u 'csi_admin:csi_PASSWORD' https://<remote storage cluster GUI host>:443/scalemgmt/v2/cluster
```
with the CSI admin user as well as the CNSA admin user credentials (from an admin node on the OpenShift cluster network).

This ensures that the user credentials are correct and that the nodes on the OpenShift network will have access to the remote IBM Spectrum Scale storage cluster.

<a name="step2"></a>
### (STEP 2) Edit the config.yaml file to reflect your local environment

The [*config.yaml*](config.yaml) file holds the *configurable parameters* for your local environment.

Edit the [*config.yaml*](config.yaml) to match the configuration of your local environment for the
*IBM Spectrum Scale CNSA* and the *IBM Spectrum Scale CSI driver* deployment.

#### Minimum required configuration

At minimum, when using the internal Red Hat OpenShift image registry to store the IBM Spectrum Scale images, you would 
need to configure the following for *IBM Spectrum Scale Container Native Storage Access* (CNSA).

First, we configure the **primaryFilesystem** that will be mounted on the local CNSA cluster from the remote IBM Spectrum Scale storage cluster and also host
the primary fileset of IBM Spectrum Scale CSI driver to store its configuration data:
```
# REQUIRED: primaryFilesystem: refers to the local file system mounted from a remote storage cluster that will also host the IBM Spectrum Scale CSI primary fileset
primaryFilesystem:
  name:           "fs1"
  mountPoint:     "/mnt/fs1"
  storageFs:      "ess_fs1"
```
with
* *name* - Local device name of the file system on the IBM Spectrum Scale CNSA cluster.
  (IMPORTANT: This local *name* must comply with Kubernetes DNS label rules and, for example, cannot contain a "_", see 
  [DNS Label Names](https://www.ibm.com/links?url=https%3A%2F%2Fkubernetes.io%2Fdocs%2Fconcepts%2Foverview%2Fworking-with-objects%2Fnames%2F%23dns-label-names)).
* *mountPoint* - Local mount point of the remote file system on OpenShift (must start with `/mnt`).
* *storageFs* - Device name of the IBM Spectrum Scale file system used on the remote IBM Spectrum Scale storage cluster (e.g. from `mmlsconfig` or
  `curl -k -u 'cnsa_admin:cnsa_PASSWORD' https://<remote storage cluster GUI host>:443/scalemgmt/v2/filesystems`.

*Note:* If you stay with *fs1* as local IBM Spectrum Scale file system name and */mnt/fs1* as local mount point for this file system on the OpenShift worker nodes
then you only need to specify the correct device name of the IBM Spectrum Scale file system on the remote IBM Spectrum Scale storage cluster (*storageFs*)
that is used for the remote mount.

Then we configure the **primaryRemoteStorageCluster** that provides the remote mount for the above file system:
```
# REQUIRED: primaryRemoteStorageCluster: refers to the remote storage cluster that will also mount the IBM Spectrum Scale CSI primary file system
primaryRemoteStorageCluster:
  gui:
    host:               "remote-scale-gui.mydomain.com"
    secretName:         "cnsa-remote-gui-secret"
    #cacert:             "cacert-storage-cluster"
    insecureSkipVerify: true
  #contactNodes: [storageCluster1node1, storageCluster1node2, storageCluster1node3]
```
with
* *host* - Hostname of the GUI endpoint on the remote IBM Spectrum Scale storage cluster.
* *secretName* - Name of the Kubernetes `secret` providing the CNSA admin user account credentials on the GUI of the remote storage cluster.
* *cacert* - Name of the ConfigMap containing the CA certificate of the remote storage cluster GUI. Uncomment if required.
  If not specified, the default OpenShift Container Platform CA or Red Hat CA bundle is used.
  See [Configure certificate authority (CA) certificates for storage cluster](https://www.ibm.com/docs/en/scalecontainernative?topic=installation-configure-certificate-authority-ca-certificates-storage-cluster)
  for more information about the available options.
* *insecureSkipVerify* - To skip TLS verification, the insecureSkipVerify option must be set to *true*. Recommended default is *false* starting with CNSA v5.1.0.3.
  Change accordingly for your environment. This [config.yaml](config.yaml) file uses "true" as default to skip TLS verification for the scope of PoCs.
* *contactNodes* (optional) - List of remote storage cluster nodes (on the IBM Spectrum Scale *damon network*) to be used as contact nodes. 
  CNSA will automatically pick 3 nodes if none are specified. Uncomment if required.

*Note:* If you stay with *cnsa-remote-gui-secret* as name for secret holding the IBM Spectrum Scale CNSA user credentials 
and accept the other defaults then you only have to specify the GUI endpoint of the remote IBM Spectrum Scale file storage cluster here (*host*).

For the consecutive deployment of the *IBM Spectrum Scale CSI driver* we also need to configure the following parameters in the **primaryCluster** section:
```
# REQUIRED: primaryCluster: local IBM Spectrum Scale CNSA cluster that will also mount the primary file system to store IBM Spectrum Scale CSI configuration data
primaryCluster:
  localClusterId:               "needs-to-be-read-after-CNSA-deployment"   
  localGuiHost:                 "ibm-spectrum-scale-gui.<replace-with-CNSA-namespace>"
  localCsiSecret:               "csi-local-secret"
  primaryRemoteClusterId:       "2303539379337927879"
  primaryRemoteCsiSecret:       "csi-remote-secret"
```
with
* *localClusterId* - Cluster-ID of the local IBM Spectrum Scale CNSA cluster 
  (leave as is - it will be provided at the time when deploying the Helm chart after IBM Spectrum Scale CNSA is up and running)
* *localGuiHost* - Internal service name of the local IBM Spectrum Scale CNSA cluster GUI. 
  Replace `<replace-with-CNSA-namespace>` with the *namespace* of the IBM Spectrum Scale CNSA deployment, 
  here, with *ibm-spectrum-scale* so it would read `ibm-spectrum-scale-gui.ibm-spectrum-scale`.
* *localCsiSecret* - Name of the Kubernetes `secret` that we created earlier for the CSI user on the GUI of the *local* IBM Spectrum Scale CNSA compute cluster.
* *primaryRemoteClusterId* - Cluster-ID of the remote IBM Spectrum Scale storage cluster that provides the primary file system for the remote mount.
* *primaryRemoteCsiSecret* - Name of the Kubernetes `secret` that we created earlier for the CSI user on the GUI of the *remote* storage cluster.

You can use *mmlscluster* or *curl* to obtain the *primaryRemoteClusterId* of the *remote* IBM Spectrum Scale storage cluster from the GUI endpoint:
```
# curl -s -k https://remote-scale-gui.mydomain.com:443/scalemgmt/v2/cluster -u "<csi-username>:<csi-password>" | grep clusterId
      "clusterId" : 2303539379337927879,
```
You can ignore the field `localClusterId: "needs-to-be-read-after-CNSA-deployment"` at this time. It can only be determined
*after* the local IBM Spectrum Scale CNSA cluster has been deployed and will be provided dynamically while deploying the CSI driver Helm chart.

*Note:* If you stay with defaults for the names of the local and remote CSI user secrets (*csi-local-secret*, *csi-remote-secret*) then you only have to fill in the 
name of the namespace where IBM Spectrum Scale CNSA is deployed (*localGuiHost*) and the cluster ID of the remote IBM Spectrum Scale storage cluster (*primaryRemoteClusterId*).

Should you decide not to use the internal OpenShift image registry for the *IBM Spectrum Scale CNSA* images
then you can specify an external registry and image pull secret in the following section of the [*config.yaml*](config.yaml) file:
```
# REQUIRED: imageRegistry as FQDN[:port] to pull the product images from (e.g. OpenShift internal registry: "image-registry.openshift-image-registry.svc:5000")
imageRegistry: "image-registry.openshift-image-registry.svc:5000"
# OPTIONAL: imageRegistryNamespace: Namespace used in the internal image registry; If set to "" the release namespace for the deployment will be used (e.g. ibm-spectrum-scale)
imageRegistryNamespace: ""
# OPTIONAL: imageRegistrySecret: This is the name of the imagePullSecret required for accessing an external image registry to pull images, e.g. created with: 
# kubectl create secret docker-registry [name] -n [namespace] --docker-server=[registry] --docker-username=[name] --docker-password=[password/token] --docker-email=[email]
# See https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/
imageRegistrySecret: ""
```
Here, the URL for the external image registry must be specified as follows: "*imageRegistry/imageRegistryNamespace*", 
e.g. `imageRegistry: my-local-registry.io:port` with `imageRegistryNamespace: ibm-spectrum-scale-cnsa` 
for "*my-local-registry.io:5000/ibm-spectrum-scale-cnsa*".

For specific information about the *IBM Spectrum Scale CNSA* configuration parameters, please refer to
[CNSA Operator - Custom Resource](https://www.ibm.com/docs/en/scalecontainernative?topic=operator-custom-resource)

For specific information about the *IBM Spectrum Scale CSI driver* configuration parameters, please refer to
[Configuring Custom Resource for CSI driver](https://www.ibm.com/docs/en/scalecontainernative?topic=driver-configuring-custom-resource-cr-csi)

#### Optional configuration parameters

##### Call home (optional)

You can also enable and configure *call home* for IBM Spectrum Scale CNSA in the following section of the 
[*config.yaml*](config.yaml) file:
```
# OPTIONAL: To enable IBM Call Home support provide the required information
callHome:
  acceptLicense: true
  companyName: "company"
  customerID: "123456-kl"
  companyEmail: "gero@email"
  countryCode: "de"
  type: production | test
  proxy:
    host: "192.1.1.1"
    port: "2345"
    secretName: "gs-secret"`
```

##### Hostname aliases (optional)

The hostnames of the remote IBM Spectrum Scale storage cluster contact nodes must be resolvable (including a *reverse* lookup) via DNS by the OpenShift nodes. 
If the IP addresses of these contact nodes cannot be resolved via DNS then the hostname and their IP addresses need to be specified in the `hostAliases` section of 
[*config.yaml*](config.yaml) file:
```
# OPTIONAL: hostAliases for environments where DNS cannot resolve the remote storage cluster.
hostAliases:
  - hostname: "my-server-1.my.domain.com"
    ip: "10.11.48.106"
  - hostname: "my-server-2.my.domain.com"
    ip: "10.11.49.98"
```

<a name="step3"></a>
### (STEP 3) Deploy the IBM Spectrum Scale CNSA Helm Chart (*ibm-spectrum-scale*)

Log in to the OpenShift cluster as regular admin user with a *cluster-admin* role, switch to the IBM Spectrum Scale CNSA namespace (here: *ibm-spectrum-scale*)
```
# oc project ibm-spectrum-scale
``` 
and install the *ibm-spectrum-scale* Helm chart with
```
# helm install ibm-spectrum-scale ./helm/ibm-spectrum-scale -f config.yaml -n ibm-spectrum-scale
```
Here we use:
* *ibm-spectrum-scale* is the release name of the Helm chart deployment (can be chosen freely),
* *helm/ibm-spectrum-scale* is the local path to the Helm chart for IBM Spectrum Scale CNSA (i.e. *ibm-spectrum-scale*),
* *config.yaml* is the configuration file which holds the parameters for the local environment (superseeds the default values in the *values.yaml* file of the Helm chart),
* *-n ibm-spectrum-scale* defines the namespace where IBM Spectrum Scale CNSA is to be deployed.

You can check the Helm chart deployment with
```
# helm list
NAME                NAMESPACE           REVISION  UPDATED                                   STATUS    CHART                     APP VERSION
ibm-spectrum-scale  ibm-spectrum-scale  1         2021-04-14 16:45:17.516316729 +0200 CEST  deployed  ibm-spectrum-scale-1.0.1  v5.1.0.3   
```

Wait for all IBM Spectrum Scale CNSA pods to come up before moving on with the next steps:
```
# oc get pods
NAME                                           READY   STATUS    RESTARTS   AGE
ibm-spectrum-scale-core-grfg2                  1/1     Running   0          114s
ibm-spectrum-scale-core-xczfn                  1/1     Running   0          114s
ibm-spectrum-scale-core-z745n                  1/1     Running   0          114s
ibm-spectrum-scale-gui-0                       9/9     Running   0          114s
ibm-spectrum-scale-operator-5d5c7799d8-lkbrn   1/1     Running   0          2m16s
ibm-spectrum-scale-pmcollector-0               2/2     Running   0          114s
ibm-spectrum-scale-pmcollector-1               2/2     Running   0          56s
```
You can check the IBM Spectrum Scale CNSA operator log with
```
# oc logs <ibm-spectrum-scale-operator-pod> -f
```
or quickly check for errors with
```
# oc logs <ibm-spectrum-scale-operator-pod> | grep -i error
```
Before moving on, verify that the local IBM Spectrum Scale CNSA cluster 
has been created successfully and that the remote file system is properly mounted with the following commands:
```
# oc exec <ibm-spectrum-scale-core-pod> -n ibm-spectrum-scale -- mmlscluster
# oc exec <ibm-spectrum-scale-core-pod> -n ibm-spectrum-scale -- mmgetstate -a
# oc exec <ibm-spectrum-scale-core-pod> -n ibm-spectrum-scale -- mmremotecluster show all
# oc exec <ibm-spectrum-scale-core-pod> -n ibm-spectrum-scale -- mmremotefs show all
# oc exec <ibm-spectrum-scale-core-pod> -n ibm-spectrum-scale -- mmlsmount all -L
```
All IBM Spectrum Scale CNSA client nodes should be active, 
the remote IBM Spectrum Scale storage cluster and file system should be configured,
and the remote file system should be mounted on all eligible nodes.   

An example output of a successful deployment would look similar to
```
# oc rsh ibm-spectrum-scale-core-grfg2

sh-4.4# mmlscluster

GPFS cluster information
========================
  GPFS cluster name:         ibm-spectrum-scale.ibm-spectrum-scale.ocp4.scale.ibm.com
  GPFS cluster id:           835838342937925076
  GPFS UID domain:           ibm-spectrum-scale.ibm-spectrum-scale.ocp4.scale.ibm.com
  Remote shell command:      /usr/bin/ssh
  Remote file copy command:  /usr/bin/scp
  Repository type:           CCR

 Node  Daemon node name         IP address  Admin node name          Designation
---------------------------------------------------------------------------------
   1   worker01.ocp4.scale.ibm.com  10.10.1.15  worker01.ocp4.scale.ibm.com  quorum-manager-perfmon
   2   worker02.ocp4.scale.ibm.com  10.10.1.16  worker02.ocp4.scale.ibm.com  quorum-manager-perfmon
   3   worker03.ocp4.scale.ibm.com  10.10.1.17  worker03.ocp4.scale.ibm.com  quorum-manager-perfmon

sh-4.4# mmgetstate -a

 Node number  Node name        GPFS state  
-------------------------------------------
       1      worker01         active
       2      worker02         active
       3      worker03         active

sh-4.4# mmremotecluster show all
Cluster name:    ess.bda.scale.ibm.com
Contact nodes:   ess-3a.bda.scale.ibm.com,ess-3b.bda.scale.ibm.com,ems.bda.scale.ibm.com
SHA digest:      8e29e5a330814b7721d00046acdaddca221dafe2b901fbe66275eaca4f620a6f
File systems:    fs1 (ess_fs1)  

sh-4.4# mmremotefs show all
Local Name  Remote Name  Cluster name           Mount Point  Mount Options  Automount  Drive  Priority
fs1         ess_fs1      ess.bda.scale.ibm.com  /mnt/fs1     rw             yes          -        0

sh-4.4# mmlsmount all -L
                                                                      
File system fs1 (ess.bda.scale.com:ess_fs1) is mounted on 7 nodes:
  10.10.1.123     ess-3b.bda            ess.bda.scale.ibm.com     
  10.10.1.122     ess-3a.bda            ess.bda.scale.ibm.com     
  10.10.1.52      ems.bda               ess.bda.scale.ibm.com     
  10.10.1.15      worker01.ocp4         ibm-spectrum-scale.ibm-spectrum-scale.ocp4.scale.ibm.com 
  10.10.1.17      worker03.ocp4         ibm-spectrum-scale.ibm-spectrum-scale.ocp4.scale.ibm.com 
  10.10.1.16      worker02.ocp4         ibm-spectrum-scale.ibm-spectrum-scale.ocp4.scale.ibm.com 
```


<a name="step4"></a>
### (STEP 4) Deploy the IBM Spectrum Scale CSI driver Helm Chart (*ibm-spectrum-scale-csi*)

(1) Stay in the *ibm-spectrum-scale* namespace of the IBM Spectrum Scale CNSA deployment to perform the next steps.

Before we can deploy the IBM Spectrum Scale CSI driver we need to create a GUI user for IBM Spectrum Scale CSI driver
on the GUI pod of the local IBM Spectrum Scale CNSA cluster that we just deployed and use the exact same credentials 
that we defined in the *csi-local-secret* earlier:
```
# oc exec -c liberty ibm-spectrum-scale-gui-0 -- /usr/lpp/mmfs/gui/cli/mkuser csi_admin -p csi_PASSWORD -g CsiAdmin
```

(2) Obtain the cluster ID of the local IBM Spectrum Scale CNSA cluster.

We set the environment variable **CLUSTERID** to the *cluster ID* of the *local* IBM Spectrum Scale CNSA cluster that we deployed in the previous step
as follows
```
# CLUSTERID=$(oc exec <ibm-spectrum-scale-core-pod> -- mmlscluster -Y | grep clusterSummary | tail -1 | cut -d':' -f8)
```
or by using
```
# CLUSTERID=$(oc exec $(oc get pods|grep "core"|tail -1|cut -d' ' -f1) -- mmlscluster -Y|grep clusterSummary|tail -1|cut -d':' -f8)
# echo $CLUSTERID
5822967484430616580
```
We will apply the environment variable **CLUSTERID** on the command line while deploying the IBM Spectrum Scale CSI driver Helm chart.

(3) Deploy the IBM Spectrum Scale CSI driver from the *ibm-spectrum-scale-csi* Helm chart.

With the environment variable **CLUSTERID** properly defined, we can now install the IBM Spectrum Scale CSI driver Helm chart 
into its own namespace , here *ibm-spectrum-scale-csi-driver*, as follows:
```
# helm install ibm-spectrum-scale-csi ./helm/ibm-spectrum-scale-csi -f config.yaml --set primaryCluster.localClusterId="$CLUSTERID" -n ibm-spectrum-scale-csi-driver
```
Here we use:
* *ibm-spectrum-scale-csi* is the release name of the Helm chart deployment (can be freely chosen),
* *./helm/ibm-spectrum-scale-csi* is the local path to the Helm chart for IBM Spectrum Scale CSI driver (i.e. *ibm-spectrum-scale-csi*)
* *config.yaml* is the configuration file which holds the variables for the local environment (overrides the default values in the *values.yaml* file in the Helm chart) 
* *--set primaryCluster.localClusterId="$CLUSTERID"* adds the cluster ID of the local CNSA cluster to the deployment of the CSI driver Helm chart 
* *-n ibm-spectrum-scale-csi-driver* defines the namespace where the IBM Spectrum Scale CSI driver is to be deployed.

You can now switch to the *ibm-spectrum-scale-csi-driver* namespace for convenience and list the Helm chart deployment:
```
# oc project ibm-spectrum-scale-csi-driver

# helm list
NAME                    NAMESPACE                       REVISION  UPDATED                                   STATUS    CHART                         APP VERSION
ibm-spectrum-scale-csi  ibm-spectrum-scale-csi-driver   1         2021-04-14 23:27:40.677408242 +0200 CEST  deployed  ibm-spectrum-scale-csi-1.0.1  v2.1.0     
```
Wait until all pods of the IBM Spectrum Scale CSI driver are running:
```
# oc get pods
NAME                                               READY   STATUS    RESTARTS   AGE
ibm-spectrum-scale-csi-attacher-0                  1/1     Running   0          34s
ibm-spectrum-scale-csi-nj7mc                       2/2     Running   0          23s
ibm-spectrum-scale-csi-operator-56955949c4-qzg55   1/1     Running   0          3m50s
ibm-spectrum-scale-csi-provisioner-0               1/1     Running   0          29s
ibm-spectrum-scale-csi-srprh                       2/2     Running   0          23s
ibm-spectrum-scale-csi-xxdv2                       2/2     Running   0          23s
```

!!! CONGRATULATIONS - DEPLOYMENT IS COMPLETED !!! 

The deployment is now completed and IBM Spectrum Scale CNSA and IBM Spectrum Scale CSI driver should be running on your OpenShift cluster.

Now you can start creating Kubernetes *storageClasses* (SCs) and *persistent volume claims* (PVCs) to provide persistent storage to your containerized applications
as described in [Example of using IBM Spectrum Scale provisioned storage](#example-of-using-ibm-spectrum-scale-provisioned-storage).

See [Using IBM Spectrum Scale Container Storage Interface driver](https://www.ibm.com/docs/en/spectrum-scale-csi?topic=200-using-spectrum-scale-container-storage-interface-driver)
for more details.


## Remove IBM Spectrum Scale CNSA and CSI deployment

To remove *IBM Spectrum Scale Container Native Storage Access* please follow instructions in
- [Cleanup IBM Spectrum Scale CNSA](https://www.ibm.com/docs/en/scalecontainernative?topic=5103-cleanup)
and 
- [Cleaning up IBM Spectrum Scale Container Storage Interface driver](https://www.ibm.com/docs/en/spectrum-scale-csi?topic=installation-cleaning-up-spectrum-scale-container-storage-interface-driver-operator-by-using-clis).

The Helm chart resources of the *IBM Spectrum Scale CNSA* deployment can be removed using:
```
# oc delete scalecluster ibm-spectrum-scale -n ibm-spectrum-scale
# helm uninstall ibm-spectrum-scale -n ibm-spectrum-scale
# oc delete crd scaleclusters.scale.ibm.com
# oc delete scc ibm-spectrum-scale-privileged
# oc delete pvc -l app=scale-pmcollector -n ibm-spectrum-scale
# oc delete pv -l app=scale-pmcollector
# oc delete sc -l app=scale-pmcollector

Note: Only delete the project and following resources 
      if you have no intention to redeploy IBM Spectrum Scale CNSA.
# oc delete project ibm-spectrum-scale
# oc debug node/<openshift_spectrum-scale_worker_node> -T -- chroot /host sh -c "rm -rf /var/mmfs; rm -rf /var/adm/ras"
# oc get nodes -ojsonpath="{range .items[*]}{.metadata.name}{'\n'}" | xargs -I{} oc annotate node {} scale.ibm.com/nodedesc-
```
with *ibm-spectrum-scale* being the Helm chart release name and *-n ibm-spectrum-scale* referring to the CNSA namespace.

The Helm chart resources of the *IBM Spectrum Scale CSI driver* deployment can be removed using:
```
# oc delete csiscaleoperators ibm-spectrum-scale-csi -n ibm-spectrum-scale-csi-driver
# helm uninstall ibm-spectrum-scale-csi -n ibm-spectrum-scale-csi-driver
# oc delete crd csiscaleoperators.csi.ibm.com
# oc delete project ibm-spectrum-scale-csi-driver
```
with *ibm-spectrum-scale-csi* being the Helm chart release name and *-n ibm-spectrum-scale-csi-driver* referring to the CSI driver namespace.


## Deploy IBM Spectrum Scale CNSA and CSI driver using Helm chart templating

By deploying IBM Spectrum Scale CNSA and IBM Spectrum Scale CSI driver as a Helm charts 
with `helm install` the deployed application has ties to Helm as a deployed *Helm chart* "release"
which offers additional (but here also *unsupported*) features after the initial deployment 
like *uninstall*, *upgrade* and *rollback* of releases.

However, these Helm charts for IBM Spectrum Scale CNSA and CSI driver are meant to assist with an initial installation 
but are not a formally supported offering. These are not supported by the IBM Spectrum Scale container native nor CSI offerings 
and are outside the scope of the IBM PMR process. 

In order to take Helm out of the picture for the deployment there is another way of using these Helm charts
without actually using Helm for deploying and managing the application as *active* Helm chart releases.

While still enjoying the convenience of a Helm chart deployment with a central [*config.yaml*](config.yaml) file
as described above we can also deploy IBM Spectrum Scale CNSA and IBM Spectrum Scale CSI driver based on the very same Helm charts
but without any dependencies on Helm for the deployed application.

By using `helm template` Helm allows to generate a deployable YAML manifest from a given Helm chart with all variables filled in.
Instead of
```
# helm install ibm-spectrum-scale ./helm/ibm-spectrum-scale -f config.yaml -n ibm-spectrum-scale
# helm install ibm-spectrum-scale-csi ./helm/ibm-spectrum-scale-csi -f config.yaml \
  --set primaryCluster.localClusterId="$CLUSTERID" -n ibm-spectrum-scale-csi-driver
```
you can simply use
```
# oc apply -f ./helm/ibm-spectrum-scale/crds/ibm_v1_scalecluster_crd.yaml 
# helm template ibm-spectrum-scale ./helm/ibm-spectrum-scale -f config.yaml -n ibm-spectrum-scale | oc apply -f -

# oc apply -f ./helm/ibm-spectrum-scale-csi/crds/csiscaleoperators.csi.ibm.com.crd.yaml
# helm template ibm-spectrum-scale-csi ./helm/ibm-spectrum-scale-csi -f config.yaml \
  --set primaryCluster.localClusterId="$CLUSTERID" -n ibm-spectrum-scale-csi-driver | oc apply -f -
```
which generates a complete YAML manifest from the Helm charts and applies it to the OpenShift cluster 
like a regular deployment of YAML manifests without any ties to Helm. As CRDs (Custom Resource Definition) are not templated
by Helm (these are the original CRD files) they need to be applied separately.

Here, Helm is only used as *template generator* to build the final YAMLs from the variables in the [*config.yaml*](config.yaml) file
and *templates* in the Helm charts. Helm itself is not used for the deployment nor for the management of the 
deployed release of the application. 

This would allow to deploy IBM Spectrum Scale CNSA and CSI driver using the ease of use and convenience of Helm charts but leaving 
no ties nor dependencies on Helm. The result is similar to a manual deployment of the individual YAML manifests.

The Helm charts above still add one additional *label* to all deployed resources but this additional label should not cause any issues:
```
helm.sh/chart: {{ include "ibm-spectrum-scale.chart" . }}
```
This additional label can also be removed on the fly for a deployment of the Helm charts with absolutely no traces left of the Helm chart:
```
# oc apply -f ./helm/ibm-spectrum-scale/crds/ibm_v1_scalecluster_crd.yaml 
# helm template ibm-spectrum-scale ./helm/ibm-spectrum-scale -f config.yaml -n ibm-spectrum-scale | grep -v 'helm.sh/chart' | oc apply -f -

# oc apply -f ./helm/ibm-spectrum-scale-csi/crds/csiscaleoperators.csi.ibm.com.crd.yaml
# helm template ibm-spectrum-scale-csi ./helm/ibm-spectrum-scale-csi -f config.yaml \
  --set primaryCluster.localClusterId="$CLUSTERID" -n ibm-spectrum-scale-csi-driver | grep -v 'helm.sh/chart' | oc apply -f -
```

## Example of using IBM Spectrum Scale provisioned storage

We also provide a set of YAML manifests in the `examples/` directory of this Github repository to quickly get started
with *dynamic provisioning* of persistent volumes (PVs) with IBM Spectrum Scale CNSA.

It can also be used for a quick sanity test after the successful deployment.

These examples comprise
* [*ibm-spectrum-scale-sc.yaml*](examples/ibm-spectrum-scale-sc.yaml): 
  a *storage class* (SC) to allow dynamic provisioning of *persistent volumes* (PVs)
* [*ibm-spectrum-scale-pvc.yaml*](examples/ibm-spectrum-scale-pvc.yaml): 
  a *persistent volume claim* (PVC) requesting a *persistent volume* (PV) from the *storage class* 
* [*ibm-spectrum-scale-test-pod.yaml*](examples/ibm-spectrum-scale-test-pod.yaml): 
  a *test pod* writing 5-second time stamps into the PV backed by IBM Spectrum Scale

The *storage class* (SC) for *dynamic provisioning* needs to be created by an OpenShift admin user.
In this example we use a storage class that provides dynamic provisioning of persistent volumes backed by *independent filesets* in IBM Spectrum Scale.

IBM Spectrum Scale CSI driver allows to use three different kinds of *storage classes* for *dynamic provisioning*:
* *light-weight* volumes using simple directories in IBM Spectrum Scale
* file-set based volumes using *independent filesets* in IBM Spectrum Scale
* file-set based volumes using *dependent filesets* in IBM Spectrum Scale

See [*IBM Spectrum Scale CSI Driver: Storage Class*](https://www.ibm.com/docs/en/spectrum-scale-csi?topic=sscsidc-storage-class#concept_akk_nkh_53b)
for more details and options.

Edit the provided storage class [*ibm-spectrum-scale-sc.yaml*](examples/ibm-spectrum-scale-sc.yaml)
and set the values of **volBackendFs** and **clusterId** accordingly to match your environment:
```
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ibm-spectrum-scale-sc
provisioner: spectrumscale.csi.ibm.com
parameters:
  volBackendFs: "<file system name on the local CNSA cluster, here: fs1>"
  clusterId: "<cluster ID of the remote storage cluster, here: 2303539379337927879>"
reclaimPolicy: Delete
```
Apply the *storage class* (SC) 
```
# oc apply -f ./examples/ibm-spectrum-scale-sc.yaml 
storageclass.storage.k8s.io/ibm-spectrum-scale-sc created

# oc get sc
NAME                          PROVISIONER                    RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
ibm-spectrum-scale-sc         spectrumscale.csi.ibm.com      Delete          Immediate              false                  2s
```
Now we can switch to a regular user profile in OpenShift, create a new namespace
```
# oc new-project test-namespace
Now using project "test-namespace" on server "https://api.ocp4.scale.com:6443".
```
and issue a request for a *persistent volume claim* (PVC) by applying [*ibm-spectrum-scale-pvc.yaml*](examples/ibm-spectrum-scale-pvc.yaml):
```
# oc apply -f ./examples/ibm-spectrum-scale-pvc.yaml
persistentvolumeclaim/ibm-spectrum-scale-pvc created

# oc get pvc
NAME                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS            AGE
ibm-spectrum-scale-pvc   Bound    pvc-87f18620-9fac-44ce-ad19-0def5f4304a1   1Gi        RWX            ibm-spectrum-scale-sc   75s
```
Here we request a PV with 1 GiB of storage capacity. Wait until the PVC is bound to a PV. 
Note that a PVC (like a pod) is bound to a *namespace* in OpenShift (unlike a PV which is not a namespaced object).

Once we see that the PVC is bound to a PV we can run the *test pod* by applying [*ibm-spectrum-scale-test-pod.yaml*](examples/ibm-spectrum-scale-test-pod.yaml): 
```
# oc apply -f ./examples/ibm-spectrum-scale-test-pod.yaml 
pod/ibm-spectrum-scale-test-pod created
```
The *test pod* will mount the PV under the local mount point */data* in the container of the created pod.
When the pod is running you can see that a time stamp is written in 5 second intervals 
to a log file *stream1.out* in the local */data* directory of the pod's container:
```
# oc get pods
NAME                          READY   STATUS    RESTARTS   AGE
ibm-spectrum-scale-test-pod   1/1     Running   0          23s

# oc rsh ibm-spectrum-scale-test-pod
/ # cat /data/stream1.out 
ibm-spectrum-scale-test-pod 20210215-12:00:29
ibm-spectrum-scale-test-pod 20210215-12:00:34
ibm-spectrum-scale-test-pod 20210215-12:00:39
ibm-spectrum-scale-test-pod 20210215-12:00:44
ibm-spectrum-scale-test-pod 20210215-12:00:49
ibm-spectrum-scale-test-pod 20210215-12:00:54
ibm-spectrum-scale-test-pod 20210215-12:00:59
ibm-spectrum-scale-test-pod 20210215-12:01:04
ibm-spectrum-scale-test-pod 20210215-12:01:09
ibm-spectrum-scale-test-pod 20210215-12:01:14
ibm-spectrum-scale-test-pod 20210215-12:01:19
```
The */data* directory in the pod's container is backed by the *pvc-87f18620-9fac-44ce-ad19-0def5f4304a1/pvc-87f18620-9fac-44ce-ad19-0def5f4304a1-data/* directory
in the IBM Spectrum Scale file system on the remote IBM Spectrum Scale storage cluster:
```
# cat /<mount point of filesystem on remote storage cluster>/pvc-87f18620-9fac-44ce-ad19-0def5f4304a1/pvc-87f18620-9fac-44ce-ad19-0def5f4304a1-data/stream1.out 
ibm-spectrum-scale-test-pod 20210215-12:00:29
ibm-spectrum-scale-test-pod 20210215-12:00:34
ibm-spectrum-scale-test-pod 20210215-12:00:39
ibm-spectrum-scale-test-pod 20210215-12:00:44
ibm-spectrum-scale-test-pod 20210215-12:00:49
ibm-spectrum-scale-test-pod 20210215-12:00:54
ibm-spectrum-scale-test-pod 20210215-12:00:59
ibm-spectrum-scale-test-pod 20210215-12:01:04
ibm-spectrum-scale-test-pod 20210215-12:01:09
ibm-spectrum-scale-test-pod 20210215-12:01:14
```
In this example *pvc-87f18620-9fac-44ce-ad19-0def5f4304a1* is created as independent fileset on the file system *ess3k_fs1* on the remote storage cluster:
```
# mmlsfileset ess3k_fs1 -L
Filesets in file system 'ess3k_fs1':
Name                            Id      RootInode  ParentId Created                      InodeSpace      MaxInodes    AllocInodes Comment
root                             0              3        -- Mon May 11 20:19:22 2020        0             15490304         500736 root fileset
pvc-87f18620-9fac-44ce-ad19-0def5f4304a1 1 524291         0 Mon Feb 15 12:56:11 2021        1                 1024           1024 Fileset created by IBM Container Storage Interface driver
spectrum-scale-csi-volume-store  2        1048579         0 Tue Feb  9 23:19:02 2021        2              1048576          52224 Fileset created by IBM Container Storage Interface driver
```
Be sure to *clean up* after this test and delete the test pod, persistent volume claim and storage class:
```
# oc delete -f ./examples/ibm-spectrum-scale-test-pod.yaml 
pod "ibm-spectrum-scale-test-pod" deleted

# oc delete -f ./examples/ibm-spectrum-scale-pvc.yaml
persistentvolumeclaim "ibm-spectrum-scale-pvc" deleted

# oc delete -f ./examples/ibm-spectrum-scale-sc.yaml 
storageclass.storage.k8s.io "ibm-spectrum-scale-sc" deleted
```
You may keep the *storage class* (SC) as an intial storage class to start with.


## Additional configuration options

### Specify node selectors for IBM Spectrum Scale CNSA (optional)

By default, IBM Spectrum Scale CNSA is deployed on all OpenShift *worker* nodes so you can skip this step if no changes are intended. 

The *default* node selector defined in the ScaleCluster custom resource leads to a deployment of IBM Spectrum Scale CNSA on all OpenShift *worker* nodes:
```
spec:
  nodeSelector:
    node-role.kubernetes.io/worker: ""
```
Regular node *labels* (in contrast to node *annotations*) can be used as *selectors* to select specific Kubernetes resources with that label, 
e.g. here we simply deploy IBM Spectrum Scale CNSA on all available OpenShift *worker* nodes which bear the regular OpenShift worker node label 
*node-role.kubernetes.io/worker* as listed below: 
```
# oc get nodes -l node-role.kubernetes.io/worker
NAME                      STATUS   ROLES    AGE     VERSION
worker01.ocp4.scale.com   Ready    worker   2d22h   v1.18.3+65bd32d
worker02.ocp4.scale.com   Ready    worker   2d22h   v1.18.3+65bd32d
worker03.ocp4.scale.com   Ready    worker   2d1h    v1.18.3+65bd32d
```
Optionally, you can select only a subset of the OpenShift worker nodes to deploy IBM Spectrum Scale CNSA on by adding labels to the nodes and the *nodeSelector* list. 
The IBM Spectrum Scale CNSA Operator will check that a node has *all* labels defined in order to deem a node eligible to deploy IBM Spectrum Scale CNSA pods.

For example, with the configuration below the IBM Spectrum Scale CNSA Operator will deploy IBM Spectrum Scale CNSA pods only on nodes with both the 
*node-role.kubernetes.io/worker* label and the *app.kubernetes.io/component: "scale"* label:
```
spec:
  nodeSelector:
    node-role.kubernetes.io/worker: ""
    app.kubernetes.io/component: "scale"
```
In the [*config.yaml*](config.yaml) file used for the Helm charts deployment you can configure these labels 
by adding additional labels in the following section:
```
# REQUIRED: nodeSelector ensures to deploy IBM Spectrum Scale CNSA pods on nodes only matching the following node labels
# The Operator will check that a node has all labels defined present in order to deploy IBM Spectrum Scale CNSA pods on this node.
# The default below deploys IBM Spectrum Scale CNSA pods on all OpenShift "worker" nodes
nodeSelector:
  node-role.kubernetes.io/worker: ""
```
See [Node selector](https://www.ibm.com/docs/en/scalecontainernative?topic=operator-selectors-labels) for more details.

Note that the default label *node-role.kubernetes.io/worker* applies to *each* worker node in an OpenShift cluster automatically 
and cannot be removed arbitrarily. This means that each node that is freshly added to the cluster will immediately join the IBM Spectrum Scale CNSA cluster 
even if this may not be wanted nor intended because the new node may be reserved for a specific purpose (e.g. infrastructure node). 
Therefore it would recommended to define an additional *customized label* for IBM Spectrum Scale CNSA so that an admin user can actively control 
(by applying or removing the label) on which nodes IBM Spectrum Scale CNSA is supposed to be running.
The nodes bearing the IBM Spectrum Scale CSI driver label (*scale: true*) would need to be a subset of the IBM Spectrum Scale CNSA nodes.

### Specify node labels for IBM Spectrum Scale CSI driver (optional)

IBM Spectrum Scale CSI driver also makes use of *node labels* to determine on which OpenShift nodes the *attacher*, *provisioner* and *plugin* resources are supposed to run.

The default (but customizable) node label used is **scale: true** which is required and designates the nodes on which IBM Spectrum Scale CSI driver resources will be running. 
These nodes must also be part of the local IBM Spectrum Scale compute cluster (here the local *IBM Spectrum Scale CNSA* cluster). 

You need to label the nodes that are selected to run IBM Spectrum Scale CSI driver as follows:
```
# oc label node <worker-node> scale=true --overwrite=true
```
This is the default label as described above and also used as default in the Helm charts.

Note that the set of nodes with IBM Spectrum Scale CSI driver labels should be identical to or a subset of all the nodes 
running IBM Spectrum Scale CNSA. The nodes with an optionally defined CSI attacher and CSI provisioner label 
need to be a subset of the nodes with an IBM Spectrum Scale CSI driver label.

Here we stay with the *default* configuration and labels for IBM Spectrum Scale CNSA (*node-role.kubernetes.io/worker: ""*) 
and IBM Spectrum Scale CSI driver (*scale: true*) and label all OpenShift *worker* nodes with **scale=true**:
```
# oc label nodes -l node-role.kubernetes.io/worker scale=true --overwrite=true

# oc get nodes -l scale=true
NAME                      STATUS   ROLES    AGE     VERSION
worker01.ocp4.scale.com   Ready    worker   2d22h   v1.18.3+65bd32d
worker02.ocp4.scale.com   Ready    worker   2d22h   v1.18.3+65bd32d
worker03.ocp4.scale.com   Ready    worker   2d1h    v1.18.3+65bd32d
```
This ensures that we can control where the IBM Spectrum Scale driver pods are running. By removing the
label from a worker node (`oc label node <nodename> scale-`) we can also remove the IBM Spectrum Scale CSI driver pods 
from the node for maintenance purposes (e.g. when *draining* a node).  

OPTIONAL: IBM Spectrum Scale CSI driver also allows to use additional node labels for the *attacher* and *provisioner* StatefulSets. 
These should be used only if there is a requirement of running these StatefulSets on very specific nodes (e.g. highly available infrastructure nodes). 
Otherwise, the use of a single label like **scale=true** for running StatefulSets and IBM Spectrum Scale CSI driver DaemonSet is strongly recommended. 
Nodes specifically marked for running StatefulSet must be a subset of the nodes marked with the *scale=true* label.

All IBM Spectrum Scale CSI driver *node labels* which are used as *nodeSelectors* can be specified in the [*config.yaml*](config.yaml) file as follows:
```
# The IBM Spectrum Scale CSI Operator will check that a node has all the labels defined below in order to deploy IBM Spectrum Scale CSI pods on this node.
# REQUIRED: csiNodeSelectorBase "scale: true" is the default node label for deploying Spectrum Scale CSI pods on a node (DEFAULT / leave as is)
csiNodeSelectorBase:
  key:    "scale"
  value:  "true"
# OPTIONAL: csiNodeSelectorProvisioner is an additional node label to run the IBM Spectrum Scale CSI Provisioner pods
# on a specifc subset of CSI nodes (highly reliable OpenShift infrastructure nodes), e.g. key: "infranode", value: "1"
# Set only if required. Otherwise set key: "" to be ignored.
csiNodeSelectorProvisioner:
  key:    ""
  value:  ""
# OPTIONAL: csiNodeSelectorAttacher is an additional node label to run the IBM Spectrum Scale CSI Attacher pods
# on a specifc subset of CSI nodes (highly reliable OpenShift infrastructure nodes), e.g. key: "infranode", value: "2"
# Set only if required. Otherwise set key: "" to be ignored.
csiNodeSelectorAttacher:
  key:    ""
  value:  ""
```

### Specify pod tolerations for IBM Spectrum Scale CSI (optional)

You can also specify Kubernetes *tolerations* in the [config.yaml](config.yaml) file that will be applied to IBM Spectrum Scale CSI driver pods. 
```
# OPTIONAL: csiTolerations is an array of Kubernetes tolerations distribued to IBM Spectrum Scale CSI pods
csiTolerations:
  - key: "key1"
    operator: "Equal"
    value: "value1"
    effect: "NoExecute"
    tolerationSeconds: 3600
  - key: "key2"
    operator: "Equal"
    value: "value1"
    effect: "NoExecute"
    tolerationSeconds: 3600
```
See [Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/) for more information.
