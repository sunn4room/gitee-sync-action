#!/bin/sh -l

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
	if ! expr "$SOURCE_REPO" : "https://" >/dev/null; then
		printf '::error::%s\n' "source repo not found" && return
	fi
	TMPDIR="$(mktemp -d)"
	cd "$TMPDIR" || true
	git init >/dev/null
	git remote add source "$SOURCE_REPO" >/dev/null
	git fetch --all >/dev/null 2>&1 \
		&& printf 'pull done\n' \
		|| printf '::error::pull failed\n' && return
	for BRANCH in $(git branch -a | grep remotes | grep -v HEAD); do
		git branch --track "${BRANCH##*/}" "$BRANCH" >/dev/null
	done
	git remote add gitee "$GITEE_REPO" >/dev/null
	git push --all --force gitee >/dev/null 2>&1 \
		&& git push --tags --force gitee >/dev/null 2>&1 \
		&& printf 'push done\n' \
		|| printf '::error::push failed\n' && return
}

# main
git config --global init.defaultBranch main >/dev/null
printf '%s' "$INPUT_REPOSITORIES" | while IFS= read -r LINE; do
	parse_repo "$LINE" | while IFS= read -r REPO; do
		mirror_repo "${REPO}"
	done
done

exit 0
