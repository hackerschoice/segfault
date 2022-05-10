all:
	make -C guest
	make -C host
	make -C encfs
