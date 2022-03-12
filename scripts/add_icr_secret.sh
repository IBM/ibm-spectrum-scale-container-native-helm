#!/usr/bin/bash
## -------------------------------------------------
##  Adding IBM Cloud Container Registry Entitlement 
## -------------------------------------------------
##  G.Schmidt                            2022-03-10
## -------------------------------------------------
## Usage: ./add_icr_secret.sh
## -------------------------------------------------

## TEMPORARY FILES
TEMP_FILE1="cnsa_icr_authority_temp1.json"
TEMP_FILE2="cnsa_icr_authority_temp2.json"

## MAIN
echo 
echo "## -----------------------------------------------"
echo "## IBM Cloud Container Registry (ICR) entitlement "
echo "## -----------------------------------------------"
echo "##"

## ABORT IF TEMPORARY FILES ALREADY EXIST
if [ -f $TEMP_FILE1 ] || [ -f $TEMP_FILE2 ]
then
  echo "## File exists. Please manually remove any of these files:"
  echo "## $TEMP_FILE1 and $TEMP_FILE2 "
  echo 
  exit 2
fi

## CHECK IF jq RPM PACKAGE IS INSTALLED (RHEL8 and higher)
if ! rpm -q --quiet jq
then
  echo "## The jq package is required but not installed. Please install jq with"
  echo "## yum install jq"
  echo
  exit 3
fi

## CHECK ACCESS TO TARGET OPENSHIFT CLUSTER (ADMIN ROLE REQUIRED)
if ! oc get secret/pull-secret -n openshift-config > /dev/null
then
  echo "## You don't seem to have admin access to the target OpenShift cluster"
  echo "## where CNSA is to be installed! Please make sure you can access"
  echo "## the target OpenShift cluster as admin with the oc command."
  echo
  exit 4
fi

## ASK FOR IBM CLOUD CONTAINER REGISTRY (ICR) ENTITLEMENT KEY
read -s -p "## Please enter your IBM Cloud Container Registry (ICR) entitlement key (leave empty to quit): "  MYANSWER1
echo

if [[ "$MYANSWER1" == "" ]]
then
  echo
  echo "PROGRAM ABORTED!"
  echo
  exit 5
fi

### DISPLAY TARGET OPENSHIFT CLUSTER TO CONFIRM LATER
echo "##"
echo "## Target OpenShift cluster (output limited to 10 lines):"
oc get nodes | tail -10
echo "##"

### WRITING IBM CLOUD CONTAINER REGISTRY (ICR) CREDENTIALS TO TEMPORARY FILE
echo "## Writing temporary entitlement file..."
echo "{
  \"auth\": \"$(echo -n cp:${MYANSWER1} | base64 -w0)\",
  \"username\": \"cp\",
  \"password\": \"${MYANSWER1}\"
}" > $TEMP_FILE1

### ADDING IBM CLOUD CONTAINER REGISTRY (ICR) CREDENTIALS TO OPENSHIFT GLOBAL PULL SECRETS
echo "##"
echo "## Reading the current OpenShift global pull secrets..."
oc get secret/pull-secret -n openshift-config -ojson | jq -r '.data[".dockerconfigjson"]' | base64 -d - | jq '.[]."cp.icr.io" += input' - $TEMP_FILE1 > $TEMP_FILE2
RETURN_CODE=$?
rm -f $TEMP_FILE1
if [ $RETURN_CODE = 0 ]
then
  echo "##"
  echo "## Will be adding your IBM Cloud Container Registry (ICR) entitlement as follows:"
  grep -A3 "cp.icr.io" $TEMP_FILE2
  echo "##"
  read -p "## Enter yes to continue and apply the ICR entitlement to the target OpenShift cluster shown above (leave empty to quit): "  MYANSWER2
  echo
  if [[ "$MYANSWER2" != "yes" ]]
  then
    echo
    echo "PROGRAM ABORTED!"
    echo
    rm -f $TEMP_FILE2
    exit 6
  fi
  echo "##"
  echo "## Applying your IBM Cloud Container Registry (ICR) entitlement to the target OpenShift cluster..."
  oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=$TEMP_FILE2
  RETURN_CODE=$?
  if [ $RETURN_CODE != 0 ]
  then
    echo "## ERROR: Something went wrong!" 
    echo "##        Could not apply your IBM Cloud Container Registry (ICR) entitlement to the target OpenShift cluster"
    echo
    rm -f $TEMP_FILE2
    exit 10
  fi
  rm -f $TEMP_FILE2
  sleep 10
  echo "## Your new OpenShift global pull secrets:"
  oc get secret/pull-secret -n openshift-config -ojson | jq -r '.data[".dockerconfigjson"]' | base64 -d - | jq
  echo "##"
  echo "## Finished...The updated global pull secret is now rolled out to all the nodes in the OpenShift cluster..."
fi

exit 0
