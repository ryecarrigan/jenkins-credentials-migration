#!/usr/bin/env bash
#BASE_URL
#JENKINS_USER_ID
#JENKINS_API_TOKEN
SOURCE_CONTROLLER="alpha"
DESTINATION_CONTROLLER="beta"

# Get jenkins-cli
JENKINS_CLI_JAR="${PWD}/jenkins-cli.jar"
if [[ ! -f "${JENKINS_CLI_JAR}" ]]; then
  curl -sSo ${JENKINS_CLI_JAR} ${BASE_URL}/cjoc/jnlpJars/jenkins-cli.jar
fi

# Export system credentials from the source controller (and store them encoded)
SYSTEM_DOMAIN="system::system::jenkins"
SYSTEM_CREDENTIALS="${SYSTEM_DOMAIN}.xml"
echo "Retrieving source controller credentials"
curl -Ss \
    -u "${JENKINS_USER_ID}:${JENKINS_API_TOKEN}" \
    --data-urlencode "script=$(<system.groovy); return null" \
    -X POST \
    "${BASE_URL}/${SOURCE_CONTROLLER}/scriptText" > "${SYSTEM_CREDENTIALS}"
echo "Importing credentials in destination controller"
if ! java -jar jenkins-cli.jar -webSocket \
      -auth "${JENKINS_USER_ID}:${JENKINS_API_TOKEN}" \
      -s "${BASE_URL}/${DESTINATION_CONTROLLER}" import-credentials-as-xml system::system::jenkins < "${SYSTEM_CREDENTIALS}"
then
  exit
fi

# List all folders from the source controller
FOLDERS=$(curl -Ss \
    -u "${JENKINS_USER_ID}:${JENKINS_API_TOKEN}" \
    --data-urlencode "script=Jenkins.instanceOrNull.getAllItems(com.cloudbees.hudson.plugins.folder.Folder.class).each {println it.fullName }; return null" \
    -X POST \
    "${BASE_URL}/${SOURCE_CONTROLLER}/scriptText")

for folder in ${FOLDERS}; do
  # Get the config.xml from the source folder
  echo "Retrieving source folder configuration"
  CONFIG_XML="${folder}.xml"

  java -jar jenkins-cli.jar -webSocket \
      -auth "${JENKINS_USER_ID}:${JENKINS_API_TOKEN}" \
      -s "${BASE_URL}/${SOURCE_CONTROLLER}" get-job "$folder" > "${CONFIG_XML}"

  # Create the folder on the destination controller
  echo "Creating copy of folder '$folder' in destination"
  if ! java -jar jenkins-cli.jar -webSocket \
      -auth "${JENKINS_USER_ID}:${JENKINS_API_TOKEN}" \
      -s "${BASE_URL}/${DESTINATION_CONTROLLER}" create-job "$folder" < "${CONFIG_XML}"
  then
    # If creation fails, then attempt updating the item
    echo "Updating existing folder '$folder' in destination"
    if ! java -jar jenkins-cli.jar -webSocket \
      -auth "${JENKINS_USER_ID}:${JENKINS_API_TOKEN}" \
      -s "${BASE_URL}/${DESTINATION_CONTROLLER}" update-job "$folder" < "${CONFIG_XML}"
    then
      exit
    fi
  fi
done

for folder in ${FOLDERS}; do
  # Get the credentials from the source folder
  FOLDER_DOMAIN="folder::item::${folder}"
  FOLDER_CREDENTIALS="${FOLDER_DOMAIN}.xml"
  echo "Retrieving source folder credentials"
  curl -Ss \
    -u "${JENKINS_USER_ID}:${JENKINS_API_TOKEN}" \
    --data-urlencode "script=def folderName=\"${folder}\";$(<folder.groovy); return null" \
    -X POST \
    "${BASE_URL}/${SOURCE_CONTROLLER}/scriptText" > "${FOLDER_CREDENTIALS}"

  echo "Importing credentials in destination folder"
  if ! java -jar jenkins-cli.jar -webSocket \
      -auth "${JENKINS_USER_ID}:${JENKINS_API_TOKEN}" \
      -s "${BASE_URL}/${DESTINATION_CONTROLLER}" import-credentials-as-xml "${FOLDER_DOMAIN}" < "${FOLDER_CREDENTIALS}"
  then
    exit
  fi
done
