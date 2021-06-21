###!/usr/bin/bash
### -------------------------------------------------------------------
### Upload IBM Spectrum Scale Container Native Storage Access 
### Container Images into the internal Red Hat OpenShift Image Registry
### -------------------------------------------------------------------
### ./upload_images.sh                                            v0.04
### -------------------------------------------------------------------
###  G.Schmidt                                               2021-04-12
### -------------------------------------------------------------------

###
### VARIABLES
###

CNSA_IMAGES="ibm-spectrum-scale-core ibm-spectrum-scale-core-operator ibm-spectrum-scale-gui ibm-spectrum-scale-monitor ibm-spectrum-scale-pmcollector"
CNSA_TAG="v5.1.0.3"
CNSA_FTYPE="tar"

IMAGE_PATH="."
REGISTRY_USER=""
REGISTRY_TOKEN=""

###
### FUNCTIONS
###

# Print a message and exit
function err_exit()
{
  echo "ERROR: $@" >&2
  exit 1
}

function get_confirmation()
{
  echo "------------------------[CONFIRMATION REQUIRED]------------------------"
  echo "$@"
  MYANSWER=""
  read -p "Please enter 'yes' to continue (all other input aborts script execution): " MYANSWER
  echo "-----------------------------------------------------------------------"
  [[ "$MYANSWER" != "yes" ]] && return 1
  return 0
}

##
## CHECK PREREQUISITES
##

# CHECK IF PODMAN IS AVAILABLE
if ! which podman >/dev/null 2>&1
then
  err_exit "The podman command is either not installed or not in the local path. Please install podman or adjust the local path to run the podman command."
fi

# CHECK IF WE ARE LOGGED IN TO OPENSHIFT AS USER WITH TOKEN
if ! which oc >/dev/null 2>&1
then
  err_exit "The oc command line tool is either not installed or not in the local path. Please install oc or adjust the local path to run the oc command line tool."
fi
if ! oc get nodes -o wide >/dev/null 2>&1
then
  err_exit "The OpenShift command line tool (oc) does not seem to be connected to an actual OpenShift target cluster. Please login to an OpenShift target cluster."
fi
if ! REGISTRY_USER="$(oc whoami)" 
then
  err_exit "You do not seem to be connected to or logged in to an OpenShift cluster. Please log in with a regular admin account that has upload access to the internal OpenShift image registry."
fi
if ! REGISTRY_TOKEN="$(oc whoami -t)"
then
  err_exit "An account token for OpenShift user $REGISTRY_USER could not be retrieved. Please log in as a regular admin user (with token / oc whoami -t) and access to the internal OpenShift image registry."
fi

# CHECK IF ALL IMAGE FILES ARE PRESENT
for i in $CNSA_IMAGES
do
  FILE="${IMAGE_PATH}/${i}-${CNSA_TAG}.${CNSA_FTYPE}"
  [ -f "$FILE" ] || err_exit "CNSA image file $FILE not found!"
done

##
## MAIN
##

echo "------------------------------------------------------------------------------------------------------------"
echo "### UPLOADING IBM Spectrum Scale Container Native Storage Access $CNSA_TAG images ### $(date) ###"
echo "------------------------------------------------------------------------------------------------------------"

# LOAD IMAGE FILE TO LOCAL IMAGE REPOSITORY
for i in $CNSA_IMAGES
do
  FILE="${IMAGE_PATH}/${i}-${CNSA_TAG}.${CNSA_FTYPE}"
  echo "## Loading CNSA image from file $FILE"
  podman load -q -i "${FILE}" "localhost/${i}:${CNSA_TAG}" 
done

# CONFIRM TARGET NAMESPACE
TGT_NAMESPACE=$(oc project | cut -d'"' -f2)
echo "## Preparing to push CNSA images to internal OpenShift image registry for namespace <${TGT_NAMESPACE}>"
if ! get_confirmation "Please confirm that this is the correct namespace <${TGT_NAMESPACE}> where IBM Spectrum Scale Container Native Storage Access will be deployed?"
then
  err_exit "Upload of IBM Spectrum Scale Container Native Storage Access $CNSA_TAG images aborted by user. Be sure to be logged into the IBM CNSA target project/namespace."
fi

# GET DEFAULT ROUTE FOR INTERNAL IMAGE REGISTRY
if ! REGHOST="$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')"
then
  err_exit "Could not obtain the default route for the internal OpenShift registry. Please ensure to expose the internal registry!"
fi

# LOGIN TO INTERNAL IMAGE REGISTRY
if ! echo $REGISTRY_TOKEN | podman login -u $REGISTRY_USER --password-stdin --tls-verify=false $REGHOST
then
  err_exit "Could not login as $REGISTRY_USER to the internal OpenShift registry at $REGHOST."
fi

# PUSH IMAGE FILES TO IMAGE REPOSITORY
for i in $CNSA_IMAGES
do
  IMAGE="${i}:${CNSA_TAG}"
  echo "## Pushing CNSA image $IMAGE to internal OpenShift image registry for namespace <${TGT_NAMESPACE}>"
  podman tag localhost/$IMAGE ${REGHOST}/${TGT_NAMESPACE}/$IMAGE
  if ! podman push ${REGHOST}/${TGT_NAMESPACE}/$IMAGE --tls-verify=false
  then
    err_exit "Could not push image $IMAGE to  as $REGISTRY_USER to the internal OpenShift registry at $REGHOST. Please check if the user has push access to the registry"
  fi
done

# LIST PUSHED IMAGE FILES IN IMAGE REPOSITORY
oc get is
for i in $CNSA_IMAGES
do
  echo "---"
  if ! oc get is $i -o yaml | egrep "name:|dockerImageRepository:|tag"
  then
    echo "WARNING: IBM Spectrum Scale Container Native Storage Access image $i is missing in OpenShift image registry!"
  fi
done

echo "-------------------------------------------------------------------------"
echo "### ALL TASKS COMPLETED SUCCESSFULLY ### $(date) ###"
echo "-------------------------------------------------------------------------"
