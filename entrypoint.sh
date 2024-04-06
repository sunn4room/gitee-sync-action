#!/bin/sh -l
# shellcheck disable=SC2015
# shellcheck disable=SC2164

TEMPFILE="$(mktemp)"

parse_repo() {
	if printf '%s' "$1" | grep -Eq '^[^/]+/[^/]+$'; then
		printf '%s\n' "$1"
	else
		PAGE=0
		while true; do
			PAGE=$((PAGE + 1))
			URL="https://gitee.com/api/v5/orgs/$1/repos?type=all&per_page=100&page=$PAGE"
			if ! curl -s --retry 5 "${URL}" >"$TEMPFILE"; then
				RETURN_CODE=1
				printf '::error::%s\n' "failed to fetch data from ${URL}" >&2
				break
			fi
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
	GITEE_REPO="https://${INPUT_USERNAME}:${INPUT_PASSWORD}@gitee.com/$1.git"
	URL="https://gitee.com/api/v5/repos/$1"
	if curl -s --retry 5 "${URL}" >"$TEMPFILE"; then
		SOURCE_REPO="$(jq -r '.description' "${TEMPFILE}")"
	else
		RETURN_CODE=1
		printf '::error::[%s] %s\n' "$1" "failed to fetch info" >&2
		return
	fi
	if expr "$SOURCE_REPO" : "https://" >/dev/null; then
		printf '[%s] %s\n' "$1" "$SOURCE_REPO"
	else
		RETURN_CODE=1
		printf '::error::[%s] %s\n' "$1" "source not found in info" >&2
		return
	fi
	TEMPDIR="$(mktemp -d)"
	cd "${TEMPDIR}"
	git init >/dev/null
	git remote add source "$SOURCE_REPO" >/dev/null
	if git fetch --all >/dev/null 2>&1; then
		printf '[%s] %s\n' "$1" "pull done"
	else
		RETURN_CODE=1
		printf '::error::[%s] %s\n' "$1" "failed to pull from source" >&2
		return
	fi
	git branch -a | grep remotes | grep -v HEAD | awk '{print $1}' | while IFS= read -r BRANCH; do
		git branch --track "${BRANCH##*/}" "$BRANCH" >/dev/null
	done
	git remote add gitee "$GITEE_REPO" >/dev/null
	if git push --all --force gitee >/dev/null 2>&1 && git push --tags --force gitee >/dev/null 2>&1; then
		printf '[%s] %s\n' "$1" "push done"
	else
		RETURN_CODE=1
		printf '::error::[%s] %s\n' "$1" "failed to push data to gitee" >&2
		return
	fi
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
