use "json"

primitive LocalGitProjectRepo
  fun tag createBundle(bundle: Bundle, dep: JsonObject box): BundleDep? =>
    _BundleDepLocalGit(bundle, dep)

class _BundleDepLocalGit
  let bundle: Bundle
  let info: JsonObject box
  let package_name: String
  let local_path: String
  let git_tag: (String | None)
  new create(b: Bundle, i: JsonObject box)? =>
    bundle       = b
    info         = i
    local_path   = try info.data("local-path") as String
                   else bundle.log("No 'local-path' key in dep: " + info.string()); error
                   end
    package_name = try _SubdirNameGenerator(local_path)
                   else bundle.log("Something went wrong generating dir name "); error
                   end
    bundle.log(package_name)
    git_tag      = try info.data("tag") as String
                   else None
                   end
    bundle.log(package_name)

  fun root_path(): String => ".deps/"+package_name
  fun packages_path(): String => root_path()

  fun ref fetch()? =>
    Shell("git clone "+local_path+" "+root_path())
    _checkout_tag()

  fun _checkout_tag() ? =>
    if git_tag isnt None then
      Shell("cd " + root_path() + " && git checkout " + (git_tag as String))
    end