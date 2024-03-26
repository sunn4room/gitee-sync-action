#!/bin/sh -l

echo -n "$INPUT_REPOSITORIES" | while IFS= read -r REPO; do
	echo "$REPO"
done

exit 0
