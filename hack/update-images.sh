#!/bin/bash

set -e

update_upstream_mce_images() {
  local value_file="$1"
  local new_tag="$2"

  if [[ ! -f "$value_file" ]]; then
    echo "YAML file not found: $value_file"
    return 1
  fi

  # Get all keys under images.overrides
  keys=$(yq e '.images.overrides | keys | .[]' "$value_file")

  for key in $keys; do
    CURRENT=$(yq e ".images.overrides.${key}" "$value_file")
    if [[ "$CURRENT" == "null" ]]; then
      echo "Key not found: $key"
      continue
    fi

    IMG_NAME="${CURRENT%%:*}"
    NEW_VALUE="${IMG_NAME}:${new_tag}"

    yq e -i ".images.overrides.${key} = \"${NEW_VALUE}\"" "$value_file"
  done

  echo "All image tags updated to '$new_tag' in $value_file"
}

update_policy_images() {
  local value_file="$1"
  local new_tag="$2"

  if [[ ! -f "$value_file" ]]; then
    echo "YAML file not found: $value_file"
    return 1
  fi

  # Get all keys under images.overrides
  keys=$(yq e '.global.imageOverrides | keys | .[]' "$value_file")

  for key in $keys; do
    CURRENT=$(yq e ".global.imageOverrides.${key}" "$value_file")
    if [[ "$CURRENT" == "null" ]]; then
      echo "Key not found: $key"
      continue
    fi

    IMG_NAME="${CURRENT%%:*}"
    NEW_VALUE="${IMG_NAME}:${new_tag}"

    yq e -i ".global.imageOverrides.${key} = \"${NEW_VALUE}\"" "$value_file"
  done

  echo "All image tags updated to '$new_tag' in $value_file"
}


get_images_json() {
  local name="$1"
  local image="$2"
  local image_json_file="$3"
  echo "## Pull the image $image."
  podman pull --arch amd64 $image

  echo "## Create a temporary container $name."
  if podman container exists $name; then
    podman rm -f $name
  fi

  podman create --arch amd64 --name $name $image

  echo "## Copy the contents out of the container to a local directory."
  podman cp $name:/extras/$image_json_file ./

  echo "Remove the temporary container $name."
  podman rm $name
}

update_downstream_mce_images(){
  local values_file=$1
  local image_json_file=$2

  keys=$(yq e '.images.overrides | keys | .[]' "$values_file")

  for key in $keys; do
      current_image=$(yq e ".images.overrides.${key}" "$values_file")
      if [[ "$current_image" == "null" ]]; then
          echo "Error: Key not found: $key"
          exit 1
      fi

      image_name=$(jq -r '.[] | select(."image-key" == "'"$key"'") | ."image-name"' $image_json_file)
      if [[ -z "$image_name" ]]; then
          echo "Error: No image found in the image for key: $key"
          exit 1
      fi
      image_digest=$(jq -r '.[] | select(."image-key" == "'"$key"'") | ."image-digest"' $image_json_file)
      if [[ -z "$image_digest" ]]; then
          echo "Error: No image digest in the image for key: $key"
          exit 1
      fi

      yq e -i ".images.overrides.${key} = \"${image_name}@${image_digest}\"" "$values_file"
      echo "### Update the image $key tags updated to ${image_name}@${image_digest} in $values_file"
  done

}

update_downstream_acm_images(){
  local values_file=$1
  local image_json_file=$2

  keys=$(yq e '.global.imageOverrides | keys | .[]' "$values_file")

  for key in $keys; do
      current_image=$(yq e ".global.imageOverrides.${key}" "$values_file")
      if [[ "$current_image" == "null" ]]; then
          echo "Error: Key not found: $key"
          exit 1
      fi

      image_name=$(jq -r '.[] | select(."image-key" == "'"$key"'") | ."image-name"' $image_json_file)
      if [[ -z "$image_name" ]]; then
          echo "Error: No image found in the image for key: $key"
          exit 1
      fi
      image_digest=$(jq -r '.[] | select(."image-key" == "'"$key"'") | ."image-digest"' $image_json_file)
      if [[ -z "$image_digest" ]]; then
          echo "Error: No image digest in the image for key: $key"
          exit 1
      fi

      yq e -i ".global.imageOverrides.${key} = \"${image_name}@${image_digest}\"" "$values_file"
      echo "### Update the image $key tags updated to ${image_name}@${image_digest} in $values_file"
  done

}

# Check required environment variables
if [[ -z "${MCE_VERSION:-}" ]]; then
  echo "Error: MCE_VERSION environment variable must be set."
  exit 1
fi

# Validate MCE_VERSION format (must be a.b.c, where a, b, c are numbers(e.g., 2.14.3).)
if ! [[ "$MCE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: MCE_VERSION must be in the format a.b.c (e.g., 2.14.3)."
  exit 1
fi

echo "MCE version is $MCE_VERSION"

# Check required environment variables
if [[ -z "${ACM_VERSION:-}" ]]; then
  echo "Error: ACM_VERSION environment variable must be set."
  exit 1
fi

# Validate ACM_VERSION format (must be a.b.c, where a, b, c are numbers(e.g., 2.14.3).)
if ! [[ "$ACM_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: ACM_VERSION must be in the format a.b.c (e.g., 2.14.3)."
  exit 1
fi

echo "ACM version is $ACM_VERSION"

# update the upstream images
# upstream_tag=$(curl -s -X GET "https://quay.io/api/v1/repository/stolostron/acm-custom-registry/tag/?limit=10" | jq -r ".tags | .[] | select(.name | startswith(\"$ACM_VERSION\")) | .name" | head -n 1)

# if [[ -z "$upstream_tag" ]]; then
#   echo "Error: No tag found for ACM_VERSION '${ACM_VERSION}'"
#   exit 1
# fi

if [[ -z "${ACM_UPSTREAM_TAG:-}" ]]; then
  echo "Error: ACM_UPSTREAM_TAG environment variable must be set."
  exit 1
fi
echo "The latest upstream image tag is $ACM_UPSTREAM_TAG, update the values.yaml"
update_upstream_mce_images "./test/configuration/mce-values.yaml" "$ACM_UPSTREAM_TAG"
update_policy_images "./test/configuration/policy-values.yaml" "$ACM_UPSTREAM_TAG"


# update the downstream images
get_images_json "mce-operater-bundle" $MCE_OPERATOR_BUNDLE_IMAGE $MCE_VERSION.json
mv $MCE_VERSION.json mce-$MCE_VERSION.json
get_images_json "acm-operater-bundle" $ACM_OPERATOR_BUNDLE_IMAGE $ACM_VERSION.json
mv $ACM_VERSION.json acm-$ACM_VERSION.json

update_downstream_mce_images "./test/configuration/mce-ds-values.yaml" mce-$MCE_VERSION.json
update_downstream_acm_images "./test/configuration/policy-ds-values.yaml" acm-$ACM_VERSION.json

rm mce-$MCE_VERSION.json
rm acm-$ACM_VERSION.json

echo "!!! update completely!!! "
