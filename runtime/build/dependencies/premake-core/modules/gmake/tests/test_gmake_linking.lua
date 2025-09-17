--
-- test_gmake_linking.lua
-- Validate the link step generation for makefiles.
-- (c) 2016-2017 Jess Perkins, Blizzard Entertainment and the Premake project
--

	local suite = test.declare("gmake_linking")

	local p = premake
	local gmake = p.modules.gmake
	local cpp = gmake.cpp

	local project = p.project


--
-- Setup and teardown
--

	local wks, prj

	function suite.setup()
		_OS = "linux"
		wks, prj = test.createWorkspace()
	end

	local function prepare(calls)
		local cfg = test.getconfig(prj, "Debug")
		local toolset = p.tools.gcc
		p.callArray(calls, cfg, toolset)
	end


--
-- Check link command for a shared C++ library.
--

	function suite.links_onCppSharedLib()
		kind "SharedLib"
		prepare { cpp.ldFlags, cpp.linkCmd }
		test.capture [[
ALL_LDFLAGS += $(LDFLAGS) -shared -Wl,-soname=libMyProject.so -s
LINKCMD = $(CXX) -o "$@" $(OBJECTS) $(RESOURCES) $(ALL_LDFLAGS) $(LIBS)
		]]
	end

	function suite.links_onMacOSXCppSharedLib()
		_OS = "macosx"
		kind "SharedLib"
		prepare { cpp.ldFlags, cpp.linkCmd }
		test.capture [[
ALL_LDFLAGS += $(LDFLAGS) -dynamiclib -Wl,-install_name,@rpath/libMyProject.dylib -Wl,-x
LINKCMD = $(CXX) -o "$@" $(OBJECTS) $(RESOURCES) $(ALL_LDFLAGS) $(LIBS)
		]]
	end

--
-- Check link command for a shared C library.
--

	function suite.links_onCSharedLib()
		language "C"
		kind "SharedLib"
		prepare { cpp.ldFlags, cpp.linkCmd }
		test.capture [[
ALL_LDFLAGS += $(LDFLAGS) -shared -Wl,-soname=libMyProject.so -s
LINKCMD = $(CC) -o "$@" $(OBJECTS) $(RESOURCES) $(ALL_LDFLAGS) $(LIBS)
		]]
	end


--
-- Check link command for a static library.
--

	function suite.links_onStaticLib()
		kind "StaticLib"
		prepare { cpp.ldFlags, cpp.linkCmd }
		test.capture [[
ALL_LDFLAGS += $(LDFLAGS) -s
LINKCMD = $(AR) -rcs "$@" $(OBJECTS)
		]]
	end


--
-- Check link command for the Utility kind.
--
-- Utility projects should only run custom commands, and perform no linking.
--

	function suite.links_onUtility()
		kind "Utility"
		prepare { cpp.linkCmd }
		test.capture [[
LINKCMD =
		]]
	end


--
-- Check link command for a Mac OS X universal static library.
--

	function suite.links_onMacUniversalStaticLib()
		architecture "universal"
		kind "StaticLib"
		prepare { cpp.ldFlags, cpp.linkCmd }
		test.capture [[
ALL_LDFLAGS += $(LDFLAGS) -s
LINKCMD = libtool -o "$@" $(OBJECTS)
		]]
	end


--
-- Check a linking to a sibling static library.
--

	function suite.links_onSiblingStaticLib()
		links "MyProject2"

		test.createproject(wks)
		kind "StaticLib"
		location "build"

		prepare { cpp.ldFlags, cpp.libs, cpp.ldDeps }
		test.capture [[
ALL_LDFLAGS += $(LDFLAGS) -s
LIBS += build/bin/Debug/libMyProject2.a
LDDEPS += build/bin/Debug/libMyProject2.a
		]]
	end


--
-- Check a linking to a sibling shared library.
--

	function suite.links_onSiblingSharedLib()
		links "MyProject2"

		test.createproject(wks)
		kind "SharedLib"
		location "build"

		prepare { cpp.ldFlags, cpp.libs, cpp.ldDeps }
		test.capture [[
ALL_LDFLAGS += $(LDFLAGS) -Wl,-rpath,'$$ORIGIN/../../build/bin/Debug' -s
LIBS += build/bin/Debug/libMyProject2.so
LDDEPS += build/bin/Debug/libMyProject2.so
		]]
	end

--
-- Check a linking to a sibling shared library using -l and -L.
--

    function suite.links_onSiblingSharedLibRelativeLinks()
        links "MyProject2"
        flags { "RelativeLinks" }

        test.createproject(wks)
        kind "SharedLib"
        location "build"

        prepare { cpp.ldFlags, cpp.libs, cpp.ldDeps }
        test.capture [[
ALL_LDFLAGS += $(LDFLAGS) -Lbuild/bin/Debug -Wl,-rpath,'$$ORIGIN/../../build/bin/Debug' -s
LIBS += -lMyProject2
LDDEPS += build/bin/Debug/libMyProject2.so
        ]]
    end

    function suite.links_onMacOSXSiblingSharedLib()
    	_OS = "macosx"
        links "MyProject2"
		flags { "RelativeLinks" }

        test.createproject(wks)
        kind "SharedLib"
        location "build"

        prepare { cpp.ldFlags, cpp.libs, cpp.ldDeps }
        test.capture [[
ALL_LDFLAGS += $(LDFLAGS) -Lbuild/bin/Debug -Wl,-rpath,'@loader_path/../../build/bin/Debug' -Wl,-x
LIBS += -lMyProject2
LDDEPS += build/bin/Debug/libMyProject2.dylib
        ]]
    end

--
-- Check a linking multiple siblings.
--

	function suite.links_onMultipleSiblingStaticLib()
		links "MyProject2"
		links "MyProject3"

		test.createproject(wks)
		kind "StaticLib"
		location "build"

		test.createproject(wks)
		kind "StaticLib"
		location "build"

		prepare { cpp.ldFlags, cpp.libs, cpp.ldDeps }
		test.capture [[
ALL_LDFLAGS += $(LDFLAGS) -s
LIBS += build/bin/Debug/libMyProject2.a build/bin/Debug/libMyProject3.a
LDDEPS += build/bin/Debug/libMyProject2.a build/bin/Debug/libMyProject3.a
		]]
	end

--
-- Check a linking multiple siblings with link groups enabled.
--

	function suite.links_onSiblingStaticLibWithLinkGroups()
		links "MyProject2"
		links "MyProject3"
		linkgroups "On"

		test.createproject(wks)
		kind "StaticLib"
		location "build"

		test.createproject(wks)
		kind "StaticLib"
		location "build"

		prepare { cpp.ldFlags, cpp.libs, cpp.ldDeps }
		test.capture [[
ALL_LDFLAGS += $(LDFLAGS) -s
LIBS += -Wl,--start-group build/bin/Debug/libMyProject2.a build/bin/Debug/libMyProject3.a -Wl,--end-group
LDDEPS += build/bin/Debug/libMyProject2.a build/bin/Debug/libMyProject3.a
		]]
	end

--
-- When referencing an external library via a path, the directory
-- should be added to the library search paths, and the library
-- itself included via an -l flag.
--

	function suite.onExternalLibraryWithPath()
		location "MyProject"
		links { "libs/SomeLib" }
		prepare { cpp.ldFlags, cpp.libs }
		test.capture [[
ALL_LDFLAGS += $(LDFLAGS) -L../libs -s
LIBS += -lSomeLib
		]]
	end



--
-- When referencing an external library with a period in the
-- file name make sure it appears correctly in  the LIBS
-- directive. Currently the period and everything after it
-- is stripped
--

	function suite.onExternalLibraryWithPathAndVersion()
		location "MyProject"
		links { "libs/SomeLib-1.1" }
		prepare { cpp.libs }
		test.capture [[
LIBS += -lSomeLib-1.1
		]]
	end
