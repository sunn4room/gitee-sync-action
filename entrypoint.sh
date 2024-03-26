#!/bin/sh -l
# shellcheck disable=SC2015
# shellcheck disable=SC2164

parse_repo() {
	if expr "$1" : '[^/]*/[^/]*$' >/dev/null; then
		printf '%s\n' "$1"
	else
		COUNT=0
		while true; do
			COUNT=$((COUNT + 1))
			OUTPUT="$(curl -s "https://gitee.com/api/v5/orgs/$1/repos?type=all&per_page=100&page=$COUNT" | jq -r .[].full_name)"
			printf '%s\n' "$OUTPUT"
			if test "$(printf '%s' "$OUTPUT" | wc -l)" -lt "100"; then
				break
			fi
		done
	fi
}

mirror_repo() {
	printf '%s\n' "[$1]"
	GITEE_REPO="https://${INPUT_USERNAME}:${INPUT_PASSWORD}@gitee.com/$1.git"
	SOURCE_REPO="$(curl -s "https://gitee.com/api/v5/repos/$1" | jq -r .description)"
	expr "$SOURCE_REPO" : "https://" >/dev/null || {
		RETURN_CODE=1
		printf '::error::%s\n' "source not found" && return
	}
	cd "$(mktemp -d)"
	git init >/dev/null
	git remote add source "$SOURCE_REPO" >/dev/null
	git fetch --all >/dev/null 2>&1 && printf 'pull done\n' || {
		RETURN_CODE=1
		printf '::error::pull failed\n' && return
	}
	git branch -a | grep remotes | grep -v HEAD | awk '{print $1}' | while IFS= read -r BRANCH; do
		git branch --track "${BRANCH##*/}" "$BRANCH" >/dev/null
	done
	git remote add gitee "$GITEE_REPO" >/dev/null
	git push --all --force gitee >/dev/null 2>&1 && git push --tags --force gitee >/dev/null 2>&1 && printf 'push done\n' || {
		RETURN_CODE=1
		printf '::error::push failed\n' && return
	}
}

# main
RETURN_CODE=0
git config --global init.defaultBranch main >/dev/null
printf '%s' "$INPUT_REPOSITORIES" | while IFS= read -r LINE; do
	parse_repo "$LINE" | while IFS= read -r REPO; do
		mirror_repo "${REPO}"
	done
done

exit $RETURN_CODE
