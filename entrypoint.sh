#!/bin/sh -l

parse_repo() {
	if expr "$1" : '^[^/]*/[^/]*$' >/dev/null; then
		echo "$1"
	else
		echo "$1/111"
		echo "$1/222"
	fi
}

printf "$INPUT_REPOSITORIES" | while IFS= read -r LINE; do
	parse_repo "$LINE" | while IFS= read -r REPO; do
		echo "::info::$REPO"
	done
done

exit 0
