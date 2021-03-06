#!/usr/bin/env bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# A shell script to build the PROX VM image using diskimage-builder
#
usage() {
    echo "Usage: $0 [-v]"
    echo "   -v    verify only (build but do not push to google storage)"
    exit 1
}

# Takes only 1 optional argument
if [ $# -gt 1 ]; then
   usage
fi
verify_only=0

if [ $# -eq 1 ]; then
   if [ $1 = "-v" ]; then
        verify_only=1
    else
        usage
    fi
fi
set -e

# Artifact URL
gs_url=artifacts.opnfv.org/samplevnf/images

# image version number
__version__=0.01
image_name=rapid-$__version__

# if image exists skip building
echo "Checking if image exists in google storage..."
if  command -v gsutil >/dev/null; then
    if gsutil -q stat gs://$gs_url/$image_name.qcow2; then
        echo "Image already exists at http://$gs_url/$image_name.qcow2"
        echo "Build is skipped"
        exit 0
    fi
    echo "Image does not exist in google storage, starting build..."
    echo
else
    echo "Cannot check image availability in OPNFV artifact repository (gsutil not available)"
fi

# check if image is already built locally
if [ -f $image_name.qcow2 ]; then
    echo "Image $image_name.qcow2 already exists locally"
else

    # install diskimage-builder
    if [ -d dib-venv ]; then
        . dib-venv/bin/activate
    else
        virtualenv dib-venv
        . dib-venv/bin/activate
        pip install diskimage-builder
    fi
    # Add rapid elements directory to the DIB elements path
    export ELEMENTS_PATH=`pwd`/elements
    # canned user/password for direct login
    export DIB_DEV_USER_USERNAME=prox
    export DIB_DEV_USER_PASSWORD=prox
    export DIB_DEV_USER_PWDLESS_SUDO=Y
    # Set the data sources to have ConfigDrive only
    export DIB_CLOUD_INIT_DATASOURCES="Ec2, ConfigDrive, OpenStack"
    # Use ELRepo to have latest kernel
    export DIB_USE_ELREPO_KERNEL=True
    echo "Building $image_name.qcow2..."
    time disk-image-create -o $image_name centos7 cloud-init rapid vm
fi

ls -l $image_name.qcow2


if [ $verify_only -eq 1 ]; then
    echo "Image verification SUCCESS"
    echo "NO upload to google storage (-v)"
else
    if command -v gsutil >/dev/null; then
        echo "Uploading $image_name.qcow2..."
        gsutil cp $image_name.qcow2 gs://$gs_url/$image_name.qcow2
        echo "You can access to image at http://$gs_url/$image_name.qcow2"
    else
        echo "Cannot upload new image to the OPNFV artifact repository (gsutil not available)"
        exit 1
    fi
fi
