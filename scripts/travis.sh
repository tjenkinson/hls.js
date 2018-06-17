#!/bin/bash
# https://docs.travis-ci.com/user/customizing-the-build/#Implementing-Complex-Build-Steps
set -ev

npm install

if [ "${TRAVIS_MODE}" = "build" ]; then
  npm run lint
  npm run build
elif [ "${TRAVIS_MODE}" = "unitTests" ]; then
	npm run test:unit
elif [ "${TRAVIS_MODE}" = "funcTests" ]; then
	npm run build
	n=0
	maxRetries=1
	until [ $n -ge ${maxRetries} ]
	do
		if [ $n -gt 0 ]; then
			echo "Retrying... Attempt: $((n+1))"
			delay=$((n*60))
			echo "Waiting ${delay} seconds..."
			sleep $delay
		fi
		npm run test:func && break
		n=$[$n+1]
	done
	if [ ${n} = ${maxRetries} ]; then
		exit 1
	fi
elif [ "${TRAVIS_MODE}" = "release" ] || [ "${TRAVIS_MODE}" = "releaseCanary" ]; then
  # update the version
  # make sure everything is fetched https://github.com/travis-ci/travis-ci/issues/3412
  git fetch --unshallow
  node ./scripts/set-package-version.js
  if [[ $(node ./scripts/check-already-published.js) = "not published" ]]; then
    npm run lint
    npm run build
    npm run test:unit
    # write the token to config
    # see https://docs.npmjs.com/private-modules/ci-server-config
    echo "//registry.npmjs.org/:_authToken=${NPM_TOKEN}" >> .npmrc
    if [ "${TRAVIS_MODE}" = "releaseCanary" ]; then
      # npm publish --tag canary
      echo "Published canary."
      curl https://purge.jsdelivr.net/npm/hls.js@canary
      echo "Cleared jsdelivr cache."
    elif [ "${TRAVIS_MODE}" = "release" ]; then
      # npm publish
      echo "Published."
    fi
  else
    echo "Already published."
  fi
else
	echo "Unknown travis mode: ${TRAVIS_MODE}" 1>&2
	exit 1
fi
