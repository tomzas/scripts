#!/usr/bin/env bash

# Copyright (c) 2018 Tomasz Jakubowski

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

function printUsageAndExit()
{
	echo "bootstrap.sh [OPTIONS]"
	echo
	echo "OPTIONS:"
	echo "-h or --help - Print help and usage message"
	echo "--gtest_root PATH - GTest install root path"
	echo "--gtest_clone PATH - Clone GTest to current project directory"
	echo "--ninja - Build the project with ninja build"

	exit $1
}

unset GTEST_ROOT

GTEST_CLONE_PATH="https://github.com/google/googletest.git"

while [[ $# -gt 0 ]]; do
key="$1"

case $key in
	-h|--help)
	printUsageAndExit 0
	shift # past argument
	;;
	--gtest_root)
	GTEST_ROOT="$2"
	shift # past argument
	shift # past value
	;;
	--gtest_clone)
	GTEST_CLONE_PATH="$2"
	shift # past argument
	shift # past value
	;;
	--ninja)
	USE_NINJA=True
	shift # past argument
	;;
	*)
	echo "Unknown option: $key"
	echo
	printUsageAndExit 1
	shift # past argument
	;;
esac
done

if [ ! -z "$(ls)" ]; then
    echo "Current directory not empty! Aborting."
    exit 1
fi

if [[ -v GTEST_ROOT ]]; then
	echo "Using $GTEST_ROOT"
	export GTEST_ROOT=$GTEST_ROOT
else
	echo "Setting up and building GTest"

	git clone $GTEST_CLONE_PATH
	cd googletest
	mkdir build
	cd build
	if [ $USE_NINJA ]; then
		cmake -GNinja -DCMAKE_INSTALL_PREFIX=installdir ..
	else
		cmake -DCMAKE_INSTALL_PREFIX=installdir ..
	fi
	cmake --build . --target install

	export GTEST_ROOT=$(pwd)/installdir

	cd ../..
fi

cat > test.cpp << EOF
#include <gtest/gtest.h>

TEST(Test, test)
{
    EXPECT_TRUE(true);
}
EOF

cat > CMakeLists.txt << EOF
cmake_minimum_required(VERSION 3.10)

project(main LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(GTest REQUIRED)
enable_testing()
add_executable(tests test.cpp)
target_link_libraries(tests GTest::GTest GTest::Main)

if(CMAKE_CXX_COMPILER_ID MATCHES "Clang|AppleClang|GNU")
    target_compile_options(tests PRIVATE -Wall -Wextra -Wunreachable-code -Wpedantic)
endif()
if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    target_compile_options(tests PRIVATE -Wweak-vtables -Wexit-time-destructors
										 -Wglobal-constructors -Wmissing-noreturn)
endif()

add_test(NAME simple-run COMMAND $<TARGET_FILE:tests>)
EOF

mkdir build
cd build
if [ $USE_NINJA ]; then
	cmake -GNinja ..
else
	cmake ..
fi
cmake --build .
./tests

echo
echo 'To build again in another terminal export GTEST_ROOT:'
echo 'export GTEST_ROOT='$GTEST_ROOT
echo