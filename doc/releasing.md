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
   sed -i "" "s/\"version\": \".*\"/\"version\": \"$RELEASE_VERSION\"/" library/oh-package.json5
   sed -i "" "s/export const VERSION = \".*\";/export const VERSION = \"$RELEASE_VERSION\";/" library/Index.ets
    ```
4. Tag the release and push to GitHub.
   ```shell
   git commit -am "Prepare for release $RELEASE_VERSION"
   git tag -a $RELEASE_VERSION -m "Version $RELEASE_VERSION"
   git push && git push --tags
   ```

5. Publish pub
   ```shell
   # 编译
   hvigorw --mode module -p product=default -p module=library@default assembleHar --analyze=normal --parallel --incremental --daemon
   
   # 发布
   ohpm publish library/build/default/outputs/default/library.har
   ```