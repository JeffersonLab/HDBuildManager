dtags = Dict("c6"=>"centos6","c7"=>"centos7","u14"=>"ubuntu14","f22"=>"fedora22")
info("Available OS tags: ",keys(dtags))
if length(ARGS) == 0
    error("Please provide Docker username as first argument.
    Specify a subset of tags by listing them as additional arguments.") end
duser = ARGS[1]
name="sim-recon"
for tag in keys(dtags); if length(ARGS) > 1 if !(tag in ARGS) continue end end
    repo = string(joinpath(duser,name),":",dtags[tag])
    run(`docker pull $repo`)
    try run(`docker rmi $name:$tag`)
    catch info("Image not available to remove (ignore previous 2 errors)") end
    run(`docker tag $repo $name:$tag`); run(`docker rmi $repo`)
end
