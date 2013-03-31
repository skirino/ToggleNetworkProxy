BIN=/home/skirino/bin/nw

nw: nw.d
	dmd nw.d
	mv nw ${BIN}
	sudo chown root:root ${BIN}
	sudo chmod 4755 ${BIN}
