module Packages
# organize package information
home = pwd()
export Package,name,version,url,path,cmds,is_external,get_packages,get_package,gettop,osrelease,gettag,select_template,show_settings
export get_unpack_file,mk_cd,get_template_ids,get_pkg_names,get_deps,tagged_deps,git_version,check_deps,mk_template,install_dirname
export versions_from_xml,rm_regex,input,hz
immutable Package
    name::ASCIIString
    version::ASCIIString
    url::ASCIIString
    path::ASCIIString
    cmds::Array{ASCIIString,1}
    deps::ASCIIString
end
name(a::Package) = a.name
version(a::Package) = a.version
url(a::Package) = a.url
path(a::Package) = a.path
cmds(a::Package) = a.cmds
deps(a::Package) = a.deps
is_external(a::Package) = length(cmds(a)) == 0
#
function write_id(id)
    fid = open("settings/id.txt","w"); println(fid,id); close(fid)
end
#
function select_template(id="master")
    run(`rm -rf settings`)
    if id in ["master","home-dev","jlab-dev"] run(`cp -pr templates/$id settings`)
    else run(`cp -pr templates/settings-$id settings`) end
    write_id(id)
end
#
function get_template_ids()
    if !ispath("settings") run(`cp -pr templates/master settings`)
        write_id("master") end
    list = Array(ASCIIString,0)
    push!(list,"master","home-dev","jlab-dev")
    for dir in readdir("templates")
        if contains(dir,"settings") push!(list,split(dir,"settings-")[2]) end
    end
    list
end
function disable_cmds()
    run(`mv settings/commands.txt settings/commands.txt.old`)
    file = Dict("cmds-old"=>open("settings/commands.txt.old"),"cmds"=>open("settings/commands.txt","w"))
    for line in readlines(file["cmds-old"])
        println(file["cmds"],string("#",chomp(line)))
    end
    for (k,v) in file close(v) end
    rm("settings/commands.txt.old")
end
function rm_regex(regex,path=pwd())
    if ispath(path)
        for item in filter(regex,readdir(path))
            run(`rm -rf $path/$item`)
        end
    end
end
function mk_template(id)
    if id in ["master","home-dev","jlab-dev"] error("'$id' id is reserved. Use another name.\n") end
    if ispath("templates/settings-$id") ts = readchomp(`date "+%Y-%m-%d_%H:%M:%S"`)
        info("Renaming older template with same id to '$id-$ts'.")
        run(`mv templates/settings-$id templates/settings-$id-$ts`) end
    if id == "dist"
        top = gettop()
        if !ispath("$top/.dist") error("'$top/.dist' does not exist. Use 'hdpm fetch-dist' to fetch the latest distribution.\n")
        elseif ispath("$top/.dist/settings") run(`cp -p settings/top.txt top.txt.tmp`)
            run(`rm -rf settings`); run(`cp -pr $top/.dist/settings settings`); run(`mv top.txt.tmp settings/top.txt`) end
    end
    if id == "jlab" || id == "dist" disable_cmds()
        info("Saving '$id' template. All build commands are disabled.") end
    write_settings(id)
    rm_regex(r".+\.txt~$","settings")
    run(`cp -pr settings templates/settings-$id`)
    write_id(id)
end
#
function mk_cd(path)
    mkpath(path); cd(path)
end
function input(prompt)
    print(prompt); chomp(readline())
end
function check_for_settings()
    if !ispath("settings")
        error("Please select a 'build template'.
        \t Use 'hdpm select <id>'.
        \t ids: ",join(get_template_ids(),", "),"\n") end
end
function gettop()
    check_for_settings()
    top = string(pwd(),"/pkgs")
    custom_top = readdlm("settings/top.txt",ASCIIString,use_mmap=false)
    if size(custom_top,1) != 1 || size(custom_top,2) != 2 error("'top.txt' has wrong number of rows or columns.") end
    if custom_top[1,1] != "default"
        top = custom_top[1,1]
        if !isabspath(top) top = string(pwd(),"/pkgs/",top) end
    end
    top
end
#
osrelease() = readchomp(`perl src/osrelease.pl`)
#
function gettag()
    tag = ""
    custom_tag = readdlm("settings/top.txt",ASCIIString,use_mmap=false)
    if size(custom_tag,1) != 1 || size(custom_tag,2) != 2 error("'top.txt' has wrong number of rows or columns.") end
    if custom_tag[1,2] != "default" tag = custom_tag[1,2] end
    tag
end
install_dirname() = (gettag() == "") ? osrelease() : string("build-",gettag())
get_pkg_names() = ["xerces-c","cernlib","root","amptools","geant4","evio","ccdb","jana","hdds","sim-recon"]
hz(a::ASCIIString) = println(repeat(a,80))
jlab_top() = string("/group/halld/Software/builds/",osrelease())
#
function major_minor(ver)
    for v in split(ver,"-")
        if contains(v,".") return split(v,".")[1],split(v,".")[2] end
    end
    "0","0"
end
function get_packages(id="")
    check_for_settings()
    vers = readdlm("settings/versions.txt",ASCIIString,use_mmap=false)
    urls = readdlm("settings/urls.txt",ASCIIString,use_mmap=false)
    paths = readdlm("settings/paths.txt",ASCIIString,use_mmap=false)
    pkg_names = get_pkg_names()
    @assert(vers[:,1] == pkg_names,string("'versions.txt' has wrong number of packages, names, or order.\nNeeds to match: ",join(pkg_names,", "),".\n"))
    @assert(urls[:,1] == pkg_names,string("'urls.txt' has wrong number of packages, names, or order.\nNeeds to match: ",join(pkg_names,", "),".\n"))
    @assert(paths[:,1] == pkg_names,string("'paths.txt' has wrong number of packages, names, or order.\nNeeds to match: ",join(pkg_names,", "),".\n"))
    #
    commands = [[] []]
    try
        commands = readdlm("settings/commands.txt",ASCIIString,use_mmap=false)
    catch
        info("All builds are disabled.")
    end
    tmp_cmds = Dict{ASCIIString,Array{ASCIIString,1}}()
    cmds = Dict{ASCIIString,Array{ASCIIString,1}}()
    for name in get_pkg_names()
        tmp_cmds[name] = Array(ASCIIString,0)
        cmds[name] = Array(ASCIIString,0)
    end
    for i=1:size(commands,1)
        push!(tmp_cmds[commands[i,1]],commands[i,2])
    end
    mydeps = Dict(
        "xerces-c" => "",
        "cernlib" => "",
        "root" => "",
        "amptools" => "root",
        "geant4" => "",
        "evio" => "",
        "ccdb" => "",
        "jana" => "xerces-c,root,ccdb",
        "hdds" => "xerces-c",
        "sim-recon" => "xerces-c,cernlib,root,evio,ccdb,jana,hdds")
    @osx_only mydeps["sim-recon"] = "xerces-c,root,evio,ccdb,jana,hdds"
    jsep = Dict("xerces-c"=>"-","cernlib"=>"","root"=>"_","amptools"=>"_","geant4"=>"-","evio"=>"-","ccdb"=>"_","jana"=>"_","hdds"=>"-","sim-recon"=>"-")
    pkgs = Array(Package,0)
    for i=1:size(paths,1)
        name = paths[i,1]
        path = paths[i,2]; path = replace(path,"[OS]",osrelease())
        path = (vers[i,2] != "latest") ? replace(path,"[VER]",vers[i,2]) : replace(replace(path,"-[VER]",""),"_[VER]","")
        url = urls[i,2]
        if name == "evio"
            evio_major_minor = join(major_minor(vers[i,2]),".")
            if !contains(url,evio_major_minor) url = replace(url,r"4.[0-9]",evio_major_minor) end
        end
        url = replace(url,"[VER]",vers[i,2])
        if !isabspath(path) && path != "NA"
            path = joinpath(gettop(),path)
        end
        if vers[i,2] == "NA" url = "NA"; path = "NA" end
        core = ["xerces-c","root","evio","ccdb","jana","hdds","sim-recon"]
        if path == "NA" && name in core
            error("Core packages cannot be disabled. Replace 'NA' with a valid path in 'paths.txt'.
            core: ",join(core,", "),"\n") end
        for cmd in tmp_cmds[name]; if path == "NA" continue end
            push!(cmds[name],replace(cmd,"[PATH]",path))
        end
        if id == "jlab"
            assert(length(cmds[name]) == 0)
            jpath = joinpath(jlab_top(),name,string(name,jsep[name],vers[i,2]))
            if ispath(jpath) path = jpath end
            if name == "cernlib" && ispath(joinpath(jlab_top(),name)) path = joinpath(jlab_top(),name) end
        end
        if id == "dist"
            assert(length(cmds[name]) == 0)
            dpath = joinpath(gettop(),".dist",basename(path))
            if ispath(dpath) path = dpath end
        end
        @osx_only begin
            if name == "xerces-c" && contains(path,"/.dist/xerces-c")
                assert(length(cmds[name]) == 0)
                dpath = joinpath("/usr/local/Cellar/xerces-c",vers[i,2])
                if ispath(dpath) path = dpath end
            end
        end
        if length(cmds[name]) > 0 path = joinpath(gettop(),basename(path)) end
        if (name == "hdds" || name == "sim-recon") && vers[i,2] != "latest"
            vmm = major_minor(vers[i,2])
            url_alt = "https://github.com/JeffersonLab/$name/archive/$name-$(vers[i,2]).tar.gz"
            if name == "hdds"
                if parse(Int,vmm[1]) <= 3 && parse(Int,vmm[2]) <= 2 || parse(Int,vmm[1]) <= 2 url = url_alt end
            elseif name == "sim-recon"
                if parse(Int,vmm[1]) <= 1 && parse(Int,vmm[2]) <= 3 || parse(Int,vmm[1]) == 0 || contains(vers[i,2],"dc") url = url_alt end
            end
        end
        if vers[i,2] == "latest" && contains(url,"https://github.com/JeffersonLab/$name/archive/")
            url = "https://github.com/JeffersonLab/$name" end
        if name == "jana" && vers[i,2] == "latest" url = "https://phys12svn.jlab.org/repos/JANA" end
        push!(pkgs,Package(name,vers[i,2],url,path,cmds[name],mydeps[name]))
    end
    pkgs
end
function write_settings(id)
    mkdir("settings-tmp")
    run(`cp -p settings/top.txt settings-tmp`); run(`cp -p settings/commands.txt settings-tmp`)
    file = Dict("vers"=>open("settings-tmp/versions.txt","w"),"urls"=>open("settings-tmp/urls.txt","w"),"paths"=>open("settings-tmp/paths.txt","w"))
    w = 10
    for pkg in get_packages(id)
        println(file["vers"],rpad(name(pkg),w," "),version(pkg))
        if version(pkg) != "NA"
            PATH = contains(path(pkg),gettop()) && !contains(path(pkg),"/.dist/") ? replace(basename(path(pkg)),version(pkg),"[VER]") : replace(replace(path(pkg),osrelease(),"[OS]"),version(pkg),"[VER]")
            if contains(PATH,"/.dist/") PATH = joinpath(".dist",basename(PATH)) end
            println(file["urls"],rpad(name(pkg),w," "),replace(url(pkg),version(pkg),"[VER]"))
            println(file["paths"],rpad(name(pkg),w," "),PATH)
        else
            println(file["urls"],rpad(name(pkg),w," "),"NA")
            println(file["paths"],rpad(name(pkg),w," "),"NA")
        end
    end
    for (k,v) in file close(v) end
    run(`rm -rf settings`); run(`mv settings-tmp settings`)
end
function get_package(a::ASCIIString)
    cd(home)
    for pkg in get_packages()
        if name(pkg) == a return pkg end
    end
end # use git hash for git-repo. packages
git_version(a) = ispath(joinpath(path(a),".git")) ? begin dir = pwd(); cd(path(a)); ver = readchomp(`git log -1 --format="%h"`); cd(dir); ver end : version(a)
function get_deps(arguments)
    mydeps = Array(ASCIIString,0)
    for pkg_name in arguments
        pkg_name = convert(ASCIIString,pkg_name)
        for dep in split(deps(get_package(pkg_name)),",")
            dep = convert(ASCIIString,dep)
            if dep != ""  push!(mydeps,dep) end
        end
    end
    unique(mydeps)
end
function tagged_deps(a)
    mydeps = Array(ASCIIString,0)
    for dep in split(deps(a),",")
        dep = convert(ASCIIString,dep)
        if dep == "" continue end
        push!(mydeps,string(dep,"-",git_version(get_package(dep))))
    end
    if length(mydeps) == 0 push!(mydeps,"none listed") end
    string("\"",join(mydeps,","),"\"")
end
function get_unpack_file(URL,PATH="")
    file = basename(URL); info("Downloading $file")
    if contains(URL,"https://") || contains(URL,"http://") run(`curl -OL $URL`)
    else run(`cp -p $URL .`) end
    if PATH != ""
        mkpath(PATH); if readchomp(pipeline(`tar tf $file`,`head`))[1] != '.' ncomp = 1 else ncomp = 2 end
        run(`tar xf $file -C $PATH --strip-components=$ncomp`)
    else
        run(`tar xf $file`)
    end
    rm(file)
end
function show_settings(;col=:all,sep=2)
    check_for_settings()
    if sep <= 1 sep = 1; info("Using min. column spacing of ",string(sep)," spaces.") end
    if sep >= 24 sep = 24; info("Using max. column spacing of ",string(sep)," spaces.") end
    hz("="); print(Base.text_colors[:bold])
    println("Current build settings")
    try
        println("ID:  ",readchomp("settings/id.txt"))
    catch
        println("ID:  ","id file not found; This will not affect build.")
    end
    println("TOP: ",gettop())
    println("TAG: ",gettag()); hz("-")
    sizes = Dict(:name=>0,:version=>0)
    for pkg in get_packages()
        for s in [:name,:version]
            sizes[s] = max(sizes[s],length(pkg.(s)))
        end
    end
    w1 = sizes[:name] + sep; w2 = sizes[:version] + sep
    for k in [:name,:version,:path]; if col != :all && !(k in [:name,col]) continue end
        if k != :path print(rpad(k,sizes[k]+sep," "))
        else print(k) end
    end
    for k in [:url,:cmds,:deps]; if col == :all || k != col continue end
        print(k)
    end
    println(); hz("-"); print(Base.text_colors[:normal])
    for pkg in get_packages()
        p = replace(path(pkg),string(gettop(),"/"),"")
        if col==:all
            println(rpad(name(pkg),w1," "),rpad(git_version(pkg),w2," "),p)
        elseif col==:version
            println(rpad(name(pkg),w1," "),git_version(pkg))
        elseif col==:url
            println(rpad(name(pkg),w1," "),url(pkg))
        elseif col==:path
            println(rpad(name(pkg),w1," "),p)
        elseif col==:deps
            println(rpad(name(pkg),w1," "),replace(deps(pkg),",",", "))
        elseif col==:cmds
            for cmd in cmds(pkg)
                println(rpad(name(pkg),w1," "),replace(cmd,string(gettop(),"/"),""))
            end
        end
    end
    hz("=")
end
function check_deps(pkg)
    @linux_only begin LDD = `ldd`; OE = `so` end
    @osx_only begin LDD = `otool -L`; OE = `dylib` end
    install_dir = is_external(get_package("hdds")) ? osrelease() : install_dirname()
    test_cmds = Dict(
        "xerces-c" => `$LDD $(path(get_package("xerces-c")))/lib/libxerces-c.$OE`,
        "cernlib" => `ls -lh $(path(get_package("cernlib")))/$(version(get_package("cernlib")))/lib/libgeant321.a`,
        "root" => `root -b -q -l`,
        "evio" => `evio2xml`,
        "ccdb" => `ccdb`,
        "jana" => `jana`,
        "hdds" => pipeline(`$LDD $(path(get_package("hdds")))/$install_dir/lib/libhdds.so`,`grep libxerces-c`),
        "sim-recon" => `hd_root`)
    for dep in get_deps([name(pkg)])
        if !success(test_cmds[dep])
            error("$dep does not appear to be installed. Please check path
            if using external installation, or test it manually.\n")
        end
    end # check version compatibility of deps
    if name(pkg) == "sim-recon"
        shlibs = ["xerces-c","root","ccdb"]
        users = ["amptools","jana","hdds"]
        pkgs = get_packages()
        for pkg_shlib in pkgs; if !(name(pkg_shlib) in shlibs) continue end
            name_ver = string(name(pkg_shlib),"-",version(pkg_shlib))
            for pkg_ld in pkgs; if !(name(pkg_ld) in users) continue end
                user_name_ver = string(name(pkg_ld),"-",version(pkg_ld))
                if !contains(deps(pkg_ld),name(pkg_shlib)) continue end
                p0 = path(pkg_ld)
                if contains(p0,jlab_top()) || !ispath(p0) continue end
                p = (name(pkg_ld)=="amptools") ?  p0 : joinpath(p0,osrelease())
                if contains(osrelease(),"RHEL") && contains(p0,"/.dist/") p = replace(p,"RHEL","CentOS") end
                if contains(osrelease(),"LinuxMint17") && contains(p0,"/.dist/") p = replace(p,r"LinuxMint17.[1-4]","Ubuntu14.04") end
                record = split(readall("$p/success.hdpm"))[end]
                if !contains(record,name_ver) error("$name_ver is incompatible with $user_name_ver.\n$user_name_ver depends on $record.\nRebuild $user_name_ver against $name_ver, or use required $(name(pkg_shlib)) version.\n") end
            end
        end
    end
end
function versions_from_xml(path="https://halldweb.jlab.org/dist/version.xml")
    check_for_settings()
    file = path; wasurl = false
    if contains(path,"https://") || contains(path,"http://")
        wasurl = true
        println(); info("Downloading $file")
        file = basename(path)
        run(`curl -OL $path`)
    end
    println()
    if !ispath(jlab_top()) info("Browse version xml files at https://halldweb.jlab.org/dist") end
    if ispath(jlab_top()) info("Browse version xml files at /group/halld/www/halldweb/html/dist
Problems? Try ",joinpath(jlab_top(),"version.xml")) end
    if !ispath(file) error(file," does not exist!\n") end
    if !contains(file,".xml") error(file," does not appear to be an xml file!\n") end
    d = readdlm(file,use_mmap=false)
    a = Dict{ASCIIString,ASCIIString}()
    for i=1:size(d,1)
        a[replace(replace(d[i,2],"name=",""),"\"","")] = replace(replace(replace(d[i,3],"version=",""),"/>",""),"\"","")
    end
    a["amptools"] = "NA"; a["geant4"] = "NA"
    vers = readdlm("settings/versions.txt",ASCIIString,use_mmap=false)
    output = open("settings/versions.txt","w")
    for i=1:size(vers,1)
        for (k,v) in a
            if vers[i,1] == k println(output,rpad(k,10," "),v) end
        end
        if !haskey(a,"evio") && vers[i,1] == "evio" println(output,rpad("evio",10," "),vers[i,2]) end
     end
     close(output)
     if wasurl rm(file) end
end
#
end
