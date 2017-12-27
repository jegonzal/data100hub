#!/bin/bash
set -euo pipefail

# This script is used by travis to trigger deployments or builds

# .travis.yml:
# - AZ_LOCATION
# - CLUSTER_ADMIN
# - DOCKER_PASSWORD (secure)
# - DOCKER_USERNAME (secure)
# - HUB_COURSE
# - SUBSCRIPTION_PREFIX
# travis project settings:
# - encrypted_56228062df6f_key (created by 'travis encrypt-file')
# - encrypted_56228062df6f_iv  (created by 'travis encrypt-file')

CLUSTER="${HUB_COURSE}-${TRAVIS_BRANCH}"

function build {
	echo "Starting build..."
	PUSH=''

	if [[ ${TRAVIS_PULL_REQUEST} == 'false' ]]; then
		PUSH='--push'
		# Assume we have secrets!
		docker login -u $DOCKER_USERNAME -p "$DOCKER_PASSWORD"
	fi

	# Attempt to improve relability of pip installs:
	# https://github.com/travis-ci/travis-ci/issues/2389
	sudo sysctl net.ipv4.tcp_ecn=0

	echo ./deploy.py build --commit-range ${TRAVIS_COMMIT_RANGE} ${PUSH}
	./deploy.py build --commit-range ${TRAVIS_COMMIT_RANGE} ${PUSH}
}

function deploy {
	echo "Starting deploy..."
	REPO="https://github.com/${TRAVIS_REPO_SLUG}"
    CHECKOUT_DIR="/tmp/${TRAVIS_BUILD_NUMBER}"
    COMMIT="${TRAVIS_COMMIT}"
	MASTER_HOST="${HUB_COURSE}-${TRAVIS_BRANCH}.${AZ_LOCATION}.cloudapp.azure.com"
    SSHKEY="${CHECKOUT_DIR}/hub/secrets/id_${TRAVIS_BRANCH}"
    KUBECONFIG="${CHECKOUT_DIR}/hub/secrets/kc-${TRAVIS_BRANCH}.${AZ_LOCATION}.json"

	# Encrypted variables are only set when we are not a PR
	# https://docs.travis-ci.com/user/pull-requests/#Pull-Requests-and-Security-Restrictions
	echo "Fetching git-crypt key..."
	openssl aes-256-cbc \
		-K $encrypted_56228062df6f_key \
		-iv $encrypted_56228062df6f_iv \
		-in git-crypt.key.enc -out ./git-crypt.key -d

	chmod 0400 git-crypt.key

	git-crypt unlock git-crypt.key

	az account set -s ${SUBSCRIPTION_PREFIX}-${TRAVIS_BRANCH}

	echo ./deploy.py deploy ${TRAVIS_BRANCH}
	./deploy.py deploy ${TRAVIS_BRANCH}

	echo "Done!"
}

# main
case $1 in
	build)  build ;;
	deploy) deploy ;;
esac