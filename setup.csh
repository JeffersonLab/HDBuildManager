# tcsh: Get julia binary and put it in PATH
#       Make alias for running hdpm.jl
# usage: source setup.csh
echo "Hall-D Package Manager setup"
set ARGS=($_)
if ("$ARGS" != "") then
    set HDPM_PATH="`dirname ${ARGS[2]}`"
    set HDPM_PATH="`cd $HDPM_PATH; pwd`"
else
    set cwd=`pwd`
    if ( `basename ${cwd}` != "hdpm" || ! -e setup.csh ) then
        echo "ERROR: Non-interactive usage requires the following commands:"
        echo "cd <path_to_hdpm>; source setup.csh"
        exit 1
    endif
endif
echo "Run 'hdpm' to see available commands."
alias hdpm "julia $HDPM_PATH/src/hdpm.jl"
setenv JULIA_LOAD_PATH $HDPM_PATH/src
set uname=`uname`
if ($uname == "Linux") then
    set JLPATH=/group/halld/Software/ExternalPackages/julia-latest/bin
    if ( -e ${JLPATH}/julia ) then
        echo "You appear to be on the JLab CUE; Will try to use group installation of julia."
        echo $PATH | grep -q $JLPATH
        if ( $? != 0 ) then
            echo "Putting julia in your PATH."
            setenv PATH ${JLPATH}:$PATH; goto end
        else
            echo "You already have julia in your PATH."; goto end
        endif
    endif
endif
set VER=0.4.6
set JLPATH=$HDPM_PATH/pkgs/julia-$VER/bin
if ( -e ${JLPATH}/julia ) then
    echo "julia-$VER directory already exists; nothing to download."
    echo $PATH | grep -q $JLPATH
    if ( $? != 0 ) then
        echo "Putting julia in your PATH."
        setenv PATH ${JLPATH}:$PATH; goto end
    else
        echo "You already have julia in your PATH."; goto end
    endif
endif
echo "Downloading julia-$VER."
if ($uname == "Linux") then
    curl -OL https://julialang.s3.amazonaws.com/bin/linux/x64/0.4/julia-$VER-linux-x86_64.tar.gz
    mkdir -p $HDPM_PATH/pkgs/julia-$VER
    tar -xzf julia-$VER-linux-x86_64.tar.gz -C $HDPM_PATH/pkgs/julia-$VER --strip-components=1
    rm -f julia-$VER-linux-x86_64.tar.gz
endif
if ($uname == "Darwin") then
    curl -OL https://s3.amazonaws.com/julialang/bin/osx/x64/0.4/julia-$VER-osx10.7+.dmg
    hdiutil attach -quiet julia-$VER-osx10.7+.dmg
    mkdir -p $HDPM_PATH/pkgs
    cp -pr /Volumes/Julia/Julia-$VER.app/Contents/Resources/julia $HDPM_PATH/pkgs/julia-$VER
    hdiutil detach -quiet /Volumes/Julia
    rm -f $HDPM_PATH/pkgs/julia-$VER/etc/julia/juliarc.jl
    rm -f julia-$VER-osx10.7+.dmg
endif
if ( -e ${JLPATH}/julia ) then
    echo "Putting julia in your PATH."
    setenv PATH ${JLPATH}:$PATH; goto end
else
    echo "julia download failed: Source this setup script to try again."
    echo "If the problem persists, please check your internet connection."
    exit 1
endif
end:
    echo "Good to go!"
