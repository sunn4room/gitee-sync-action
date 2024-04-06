#!/bin/sh -l
# shellcheck disable=SC2015

TEMPFILE="$(mktemp)"

parse_repo() {
	if printf '%s' "$1" | grep -Eq '^[^/]+/[^/]+$'; then
		printf '%s\n' "$1"
	else
		PAGE=0
		while true; do
			PAGE=$((PAGE + 1))
			URL="https://gitee.com/api/v5/orgs/$1/repos?type=all&per_page=100&page=$PAGE"
			curl -s --retry 5 "${URL}" >"$TEMPFILE" || {
				RETURN_CODE=1
				printf '::error::%s\n' "failed to fetch data from ${URL}" >&2
				break
			}
			COUNT=0
			for ITEM in $(jq -r '.[].full_name' "${TEMPFILE}"); do
				printf '%s\n' "$ITEM"
				COUNT=$((COUNT + 1))
			done
			if test "${COUNT}" -lt "100"; then
				break
			fi
		done
	fi
}

mirror_repo() {
	printf '%s\n' "[$1]"
	GITEE_REPO="https://${INPUT_USERNAME}:${INPUT_PASSWORD}@gitee.com/$1.git"
	URL="https://gitee.com/api/v5/repos/$1"
	curl -s "https://gitee.com/api/v5/repos/$1"
	curl -s --retry 5 "${URL}" >"$TEMPFILE" || {
		RETURN_CODE=1
		printf '::error::%s\n' "failed to fetch data from ${URL}" >&2
		return
	}
	SOURCE_REPO="$(jq -r '.description' "${TEMPFILE}")"
	expr "$SOURCE_REPO" : "https://" >/dev/null || {
		RETURN_CODE=1
		printf '::error::%s\n' "source not found for ${GITEE_REPO}" >&2
		return
	}
	TEMPDIR="$(mktemp -d)"
	cd "${TEMPDIR}" || true
	git init >/dev/null
	git remote add source "$SOURCE_REPO" >/dev/null
	git fetch --all >/dev/null 2>&1 && printf 'pull done\n' || {
		RETURN_CODE=1
		printf '::error::%s\n' "failed to pull data from ${SOURCE_REPO}" >&2
		return
	}
	git branch -a | grep remotes | grep -v HEAD | awk '{print $1}' | while IFS= read -r BRANCH; do
		git branch --track "${BRANCH##*/}" "$BRANCH" >/dev/null
	done
	git remote add gitee "$GITEE_REPO" >/dev/null
	git push --all --force gitee >/dev/null 2>&1 && git push --tags --force gitee >/dev/null 2>&1 && printf 'push done\n' || {
		RETURN_CODE=1
		printf '::error::%s\n' "failed to push data to ${GITEE_REPO}" >&2
		return
	}
	rm -rf "${TEMPDIR}"
}

# main
RETURN_CODE=0
git config --global init.defaultBranch main >/dev/null
for LINE in $(printf '%s' "$INPUT_REPOSITORIES"); do
	for REPO in $(parse_repo "$LINE"); do
		mirror_repo "${REPO}"
	done
done

rm "$TEMPFILE"
exit $RETURN_CODE
