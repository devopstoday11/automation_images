#!/usr/bin/env bash

# This script is set as, and intended to run as the `imgts` container's
# entrypoint. It's purpose is to operate on a list of VM Images, adding
# metadata to each.  It must be executed alongside any repository's
# automation, which produces or uses GCP VM Images.

set -e

# shellcheck source=./lib_entrypoint.sh
source /usr/local/bin/lib_entrypoint.sh

req_env_var GCPJSON GCPNAME GCPPROJECT IMGNAMES BUILDID REPOREF

gcloud_init

# These must be defined by the cirrus-ci job using the container
# shellcheck disable=SC2154
ARGS="
    --update-labels=last-used=$(date +%s)
    --update-labels=build-id=$BUILDID
    --update-labels=repo-ref=$REPOREF
    --update-labels=project=$GCPPROJECT
"

# Must be defined by the cirrus-ci job using the container
# shellcheck disable=SC2154
[[ -n "$IMGNAMES" ]] || \
    die 1 "No \$IMGNAMES were specified."

# Don't allow one bad apple to ruin the whole batch
ERRIMGS=''

# It's possible for multiple simultaneous label updates to clash
CLASHMSG='Labels fingerprint either invalid or resource labels have changed'

# Must be defined by the cirrus-ci job using the container
# shellcheck disable=SC2154
for image in $IMGNAMES
do
    if ! OUTPUT=$($GCLOUD compute images update "$image" $ARGS 2>&1); then
        echo "$OUTPUT" > /dev/stderr
        if grep -iq "$CLASHMSG" <<<"$OUTPUT"; then
            # Updating the 'last-used' label is most important.
            # Assume clashing update did this for us.
            msg "Warning: Detected simultaneous label update, ignoring clash."
            continue
        fi
        msg "Detected update error for '$image'" > /dev/stderr
        ERRIMGS="$ERRIMGS $image"
    else
        echo "$OUTPUT" > /dev/stderr
    fi
done

[[ -z "$ERRIMGS" ]] || \
    die 2 "ERROR: Failed to update one or more image timestamps: $ERRIMGS"
