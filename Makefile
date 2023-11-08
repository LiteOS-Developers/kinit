build:
	@mkdir -p $(TARGET)/sbin
	@cp $(SRC)/src/init.lua $(TARGET)/sbin/
	@cp $(SRC)/src/init.lua.attr $(TARGET)/sbin/
