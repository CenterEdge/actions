# dotnet/nuget-version

Uses tags and GitHub run information to calculate a NuGet package version, which can be used in other steps of a workflow.

## Methodology

- If the run is triggered by a release tag, the version will be the tag name with any matching `tag-prefix` pattern removed from the start. The script automatically adds a leading `^` to the pattern. For example, if the tag is `V1.0.0` and the pattern is `[vV]`, the version will be `1.0.0`.
- Support prerelease tags as well, so if the tag is `v1.0.0-beta`, the version will be `1.0.0-beta`.
- If the run is not triggered by a release tag, the version will be an `alpha` prerelease version, such as `0.1.0-alpha.234`. The alpha version is based on the GitHub run number.
  - If the most recent release tag on the default branch is a stable version, the alpha version will be based on the next patch version. For example, if the most recent release tag is `v1.0.0`, the alpha version will be `1.0.1-alpha.234`.
  - If the most recent release tag is a prerelease version, the alpha version reuse the same version number. For example, if the most recent release tag is `v1.0.0-beta.5`, the alpha version will be `1.0.0-alpha.234`.

## Inputs

- `tag-prefix` (optional): Regular expression pattern matched against the start of release tags. The script prepends `^` automatically, so the pattern is always start-anchored. For example, to match both `v` and `V` you can use `[vV]`, and for tags like `release/v1.0.0` you can use `release/v`.

## Outputs

- `version`: The calculated NuGet package version based on the release tag and run metadata.
- `is-release`: A boolean `true` when the current run is associated with a release tag, or `false` otherwise (such as a PR or branch build).
