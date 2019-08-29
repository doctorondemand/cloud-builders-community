#!/bin/bash -xe

# Always delete instance after attempting build
function cleanup {
    # TODO: disabled for debugging
    gcloud compute instances delete ${INSTANCE_NAME} --quiet
}

# Configurable parameters
[ -z "$COMMAND" ] && echo "Need to set COMMAND" && exit 1;

USERNAME=${USERNAME:-admin}
REMOTE_WORKSPACE=${REMOTE_WORKSPACE:-/home/${USERNAME}/workspace/}
INSTANCE_NAME=${INSTANCE_NAME:-builder-$(cat /proc/sys/kernel/random/uuid)}
ZONE=${ZONE:-us-central1-f}
INSTANCE_ARGS=${INSTANCE_ARGS:---preemptible}

gcloud config set compute/zone ${ZONE}

KEYNAME=builder-key
# TODO Need to be able to detect whether a ssh key was already created
ssh-keygen -t rsa -N "" -f ${KEYNAME} -C ${USERNAME} || true
chmod 400 ${KEYNAME}*

cat > ssh-keys <<EOF
${USERNAME}:$(cat ${KEYNAME}.pub)
EOF

gcloud compute instances create \
       ${INSTANCE_ARGS} ${INSTANCE_NAME} \
       --metadata block-project-ssh-keys=TRUE \
       --metadata-from-file ssh-keys=ssh-keys

for i in $(seq 1 10); do 
  gcloud compute ssh --ssh-key-file=${KEYNAME} \
       ${USERNAME}@${INSTANCE_NAME} -- true && break
  echo "Couldn't connect to ${INSTANCE_NAME} yet (try $i/10).  Waiting 3 seconds to try again..."
  sleep 3
done

trap cleanup EXIT

date

gcloud compute scp --compress --recurse \
       $(pwd) ${USERNAME}@${INSTANCE_NAME}:${REMOTE_WORKSPACE} \
       --ssh-key-file=${KEYNAME}

date

gcloud compute ssh --ssh-key-file=${KEYNAME} \
       ${USERNAME}@${INSTANCE_NAME} -- ${COMMAND}

gcloud compute scp --compress --recurse \
       ${USERNAME}@${INSTANCE_NAME}:${REMOTE_WORKSPACE}* $(pwd) \
       --ssh-key-file=${KEYNAME}
