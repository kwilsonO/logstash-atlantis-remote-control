HOSTDIR="/Users/kwilson/work/ooyala/ELK/atlantis-logstash-repos/logstash-atlantis-remote-control/hosts"

for f in $HOSTDIR/*; do
	echo "Copying ${f}"
	echo "Remote: $(cat ${f})"
	filename=$(basename "$f")
	scp "${f}" "root@$(cat ${f}):/root/atlantis-analytics"
	ssh "root@$(cat ${f})" "cd /root/atlantis-analytics; echo '${filename}' > localname; mv ${filename} address"
done
