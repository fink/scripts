SOURCES = \
	Install\ Fink.tool

# The tarball
dist: InstallFink.tgz

InstallFink.tgz: $(SOURCES)
	mkdir InstallFink
	cp -pR $(SOURCES) InstallFink/
	@COPYFILE_DISABLE=1 tar -czf InstallFink.tgz InstallFink
	rm -fr InstallFink

clean:
	rm -f *.tgz
