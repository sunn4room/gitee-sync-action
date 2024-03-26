#!/bin/sh -l

parse_repo() {
	if expr "$1" : '[^/]*/[^/]*$' >/dev/null; then
		echo "$1"
	else
		COUNT=0
		echo "$1"
		while true; do
			COUNT="$(("$COUNT" + 1))"
			OUTPUT="$(curl -s "https://gitee.com/api/v5/orgs/$1/repos?type=all&per_page=100&page=$COUNT" | jq -r .[].full_name)"
			printf '%s' "$OUTPUT"
			if test "$(printf '%s' "$OUTPUT" | wc -l)" -lt "100"; then
				break
			fi
		done
	fi
}

printf '%s' "$INPUT_REPOSITORIES" | while IFS= read -r LINE; do
	parse_repo "$LINE" | while IFS= read -r REPO; do
		echo "[${REPO}]"
	done
done

exit 0
