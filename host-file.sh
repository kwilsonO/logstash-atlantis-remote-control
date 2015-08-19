for f in /Users/kwilson/tstflt-alias/*; do
	echo "Copying ${f}"
	filename=$(basename "$f")
	scp "$f" "root@$(cat ${f}):/root/${filename}"
done
