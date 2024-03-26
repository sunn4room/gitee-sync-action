#!/bin/sh -l

parse_repo() {
	if expr "$1" : '[^/]*/[^/]*$' >/dev/null; then
		printf '%s\n' "$1"
	else
		COUNT=0
		while true; do
			COUNT=$(($COUNT + 1))
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
	GITEE_REPO="https://gitee.com/$1.git"
	printf '%s\n' "$GITEE_REPO"
	SOURCE_REPO="$(curl -s "https://gitee.com/api/v5/repos/$1" | jq -r .description)"
	printf '%s\n' "$SOURCE_REPO"
}

# main
printf '%s' "$INPUT_REPOSITORIES" | while IFS= read -r LINE; do
	parse_repo "$LINE" | while IFS= read -r REPO; do
		mirror_repo "${REPO}"
	done
done

exit 0
