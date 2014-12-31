BIN=${HOME}/bin/nw

nw: nw.d
	dmd *.d -ofnw
	mv nw ${BIN}
	sudo chown root:root ${BIN}
	sudo chmod 4755 ${BIN}
