Releasing
=========

Cutting a Release
-----------------

1. Update `library/CHANGELOG.md`.
   > Fix:
   > New: new api, feature, etc.
   > Update: bump dependencies
   > Breaking change. change class to enum.
2. Set versions:

    ```shell
   export RELEASE_VERSION=$(awk -F '[][]' '/\[/{print $2; exit}'  library/CHANGELOG.md) \
   && echo "RELEASE_VERSION=$RELEASE_VERSION"
    ```
3. Update versions:
   ```shell
   bash scripts/publish-package.sh prepare-version "$RELEASE_VERSION"
    ```
4. Tag the release and push to GitHub.
   ```shell
   git commit -am "release $RELEASE_VERSION"
   git tag -a $RELEASE_VERSION -m "Version $RELEASE_VERSION"
   git push && git push --tags
   ```

5. Publish pub
   ```shell
   bash scripts/publish-package.sh publish "$RELEASE_VERSION"
   ```

Publishing a Prerelease
-----------------------

Use semantic prerelease versions for test packages, for example `0.2.0-alpha.1`.

1. Prepare the prerelease version locally:
   ```shell
   export PRERELEASE_VERSION=0.2.0-alpha.1
   bash scripts/publish-package.sh prepare-version "$PRERELEASE_VERSION"
   ```
2. Build and publish the test package:
   ```shell
   bash scripts/publish-package.sh publish "$PRERELEASE_VERSION"
   ```
3. Or trigger the GitHub Actions workflow `Publish Prerelease Package` and pass `0.2.0-alpha.1`.

Notes
-----

- `scripts/publish-package.sh` validates that the package name follows the ArkTS scoped naming style, such as `@shengwang/whiteboard`.
- Test packages and stable packages share the same ArkTS package name. They are distinguished by the semantic version suffix, for example `0.2.0-alpha.1`.
- The GitHub Actions workflow expects a self-hosted runner with HarmonyOS build tools installed, plus `HVIGORW_BIN` and `OHPM_BIN` secrets that point to the actual command paths.
