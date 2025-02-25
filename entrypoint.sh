#!/bin/sh

timestamp() {
  date +"%s" # current time
}

set -e
set -x

if [ -z "$INPUT_SOURCE_FOLDER" ]
then
  echo "Source folder must be defined"
  return -1
fi

if [ $INPUT_DESTINATION_HEAD_BRANCH == "main" ] || [ $INPUT_DESTINATION_HEAD_BRANCH == "master" ]
then
  echo "Destination head branch cannot be 'main' nor 'master'"
  return -1
fi

if [ -z "$INPUT_PULL_REQUEST_REVIEWERS" ]
then
  PULL_REQUEST_REVIEWERS=$INPUT_PULL_REQUEST_REVIEWERS
else
  PULL_REQUEST_REVIEWERS='-r '$INPUT_PULL_REQUEST_REVIEWERS
fi

CLONE_DIR=$(mktemp -d)

echo "Setting git variables"
export GITHUB_TOKEN=$API_TOKEN_GITHUB
git config --global user.email "$INPUT_USER_EMAIL"
git config --global user.name "$INPUT_USER_NAME"

# Fix for the unsafe repo error: https://github.com/repo-sync/pull-request/issues/84
git config --global --add safe.directory /github/workspace

echo "Cloning destination git repository"
git clone "https://$API_TOKEN_GITHUB@github.com/$INPUT_DESTINATION_REPO.git" "$CLONE_DIR"

echo "Copying contents to git repo"
rm -rf $CLONE_DIR/$INPUT_DESTINATION_FOLDER/
mkdir -p $CLONE_DIR/$INPUT_DESTINATION_FOLDER/
cp -R $INPUT_SOURCE_FOLDER "$CLONE_DIR/$INPUT_DESTINATION_FOLDER/"
rm -rf $CLONE_DIR/$INPUT_DESTINATION_FOLDER/.git
rm -rf $CLONE_DIR/$INPUT_DESTINATION_FOLDER/.gitignore
cd "$CLONE_DIR"

INPUT_DESTINATION_HEAD_BRANCH="${INPUT_DESTINATION_HEAD_BRANCH}@$(timestamp)"
echo "New branch name: ${INPUT_DESTINATION_HEAD_BRANCH}"
git checkout -b "$INPUT_DESTINATION_HEAD_BRANCH"

echo "Adding git commit"
git add .
if git status | grep -q "Changes to be committed"
then
  git commit --message "Update from https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"
  echo "Pushing git commit"
  git push -u origin HEAD:$INPUT_DESTINATION_HEAD_BRANCH
  echo "Creating a pull request"
  gh pr create \
    --title "[Auto PR] $INPUT_DESTINATION_HEAD_BRANCH" \
    --body "Update from https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA" \
    --base $INPUT_DESTINATION_BASE_BRANCH \
    --head $INPUT_DESTINATION_HEAD_BRANCH \
    $PULL_REQUEST_REVIEWERS
else
  echo "No changes detected"
fi
