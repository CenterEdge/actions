# CenterEdge Actions

Common GitHub Actions reused by CenterEdge repositories.

## Using

`centeredge/actions/<system-directory>/<action-directory>@<version-tag>`

`centeredge/actions/dotnet/nuget-version@v1`

## List of actions

- `centeredge/actions/dotnet/nuget-version` Calculates NuGet package versions from release tags and run metadatauploads the test report

## Versioning & Releases

Versioning these actions are done with tags, all versions should start with `v`, for example `v1.0.0`

- This should be done via Releases
- Any updates that only patch these actions, such as using a new version of a outside action, like `actions/checkout@v3` to `actions/checkout@v4` for example, should warrant a patch version bump - `@v1.0.1`
- Any non-breaking changes should warrant a minor version bump - `@v1.1.0`
- Any breaking changes should warrant a major version bump - `@v2.0.0`
- We have a workflow in this repository triggered by releases, which will update the major tag based on the release tag - so there's a new release `v1.0.5`, the `update-tag.yaml` workflow will update the `@v1` major version tag automatically

## Notes

- Try not to use outside actions, and if it's needed be sure to use the git tag for that action, not @master or @main
