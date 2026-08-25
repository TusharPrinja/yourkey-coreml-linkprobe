/**
 * with-coreml-llm.js (v3) — the package AND the bridge into the app target.
 * The pods wall stands (twice proven); we compile where the package lives.
 */
const { withXcodeProject, withDangerousMod } = require('expo/config-plugins');
const fs = require('fs');
const path = require('path');

const PKG_URL = 'https://github.com/TusharPrinja/CoreML-LLM';
const PKG_BRANCH = 'main';
const PKG_PRODUCT = 'CoreMLLLM';
const BRIDGE = 'YKCoreMLBridge.swift';

module.exports = function withCoreMLLLM(config) {
  // 1. Copy the bridge source into the generated app directory.
  config = withDangerousMod(config, ['ios', (cfg) => {
    const appName = cfg.modRequest.projectName;
    const src = path.join(cfg.modRequest.projectRoot, 'native', BRIDGE);
    const dst = path.join(cfg.modRequest.platformProjectRoot, appName, BRIDGE);
    fs.copyFileSync(src, dst);
    return cfg;
  }]);

  // 2. Package reference + product on the app target, and the bridge file
  //    into the target's Sources phase. Idempotent on rerun.
  return withXcodeProject(config, (cfg) => {
    const project = cfg.modResults;
    const objects = project.hash.project.objects;
    const appName = cfg.modRequest.projectName;

    if (!JSON.stringify(project.hash).includes(PKG_URL)) {
      const refUuid = project.generateUuid();
      const depUuid = project.generateUuid();
      objects.XCRemoteSwiftPackageReference = objects.XCRemoteSwiftPackageReference || {};
      objects.XCRemoteSwiftPackageReference[refUuid] = {
        isa: 'XCRemoteSwiftPackageReference',
        repositoryURL: `"${PKG_URL}"`,
        requirement: { kind: 'branch', branch: PKG_BRANCH },
      };
      objects.XCSwiftPackageProductDependency = objects.XCSwiftPackageProductDependency || {};
      objects.XCSwiftPackageProductDependency[depUuid] = {
        isa: 'XCSwiftPackageProductDependency',
        package: refUuid,
        productName: PKG_PRODUCT,
      };
      const firstProjectKey = Object.keys(objects.PBXProject).find((k) => !k.endsWith('_comment'));
      const pbxProject = objects.PBXProject[firstProjectKey];
      pbxProject.packageReferences = pbxProject.packageReferences || [];
      pbxProject.packageReferences.push({ value: refUuid, comment: `XCRemoteSwiftPackageReference "${PKG_PRODUCT}"` });
      const targetKey = project.getFirstTarget().uuid;
      const target = objects.PBXNativeTarget[targetKey];
      target.packageProductDependencies = target.packageProductDependencies || [];
      target.packageProductDependencies.push({ value: depUuid, comment: PKG_PRODUCT });
    }

    if (!JSON.stringify(project.hash).includes(BRIDGE)) {
      const fileRef = project.generateUuid();
      const buildFile = project.generateUuid();
      objects.PBXFileReference[fileRef] = {
        isa: 'PBXFileReference',
        lastKnownFileType: 'sourcecode.swift',
        // App-relative path on the MAIN group: resolves correctly no matter
        // how the template names its inner groups (the v3 lesson — a named
        // group search missed, and the file resolved to ios/ instead).
        path: `${appName}/${BRIDGE}`,
        sourceTree: '"<group>"',
      };
      objects.PBXFileReference[`${fileRef}_comment`] = BRIDGE;
      objects.PBXBuildFile[buildFile] = { isa: 'PBXBuildFile', fileRef, fileRef_comment: BRIDGE };
      objects.PBXBuildFile[`${buildFile}_comment`] = `${BRIDGE} in Sources`;
      const mainGroupId = project.getFirstProject().firstProject.mainGroup;
      const mainGroup = objects.PBXGroup[mainGroupId];
      mainGroup.children = mainGroup.children || [];
      mainGroup.children.push({ value: fileRef, comment: BRIDGE });
      const targetKey = project.getFirstTarget().uuid;
      const target = objects.PBXNativeTarget[targetKey];
      for (const ph of target.buildPhases ?? []) {
        const phase = objects.PBXSourcesBuildPhase[ph.value];
        if (phase) {
          phase.files = phase.files || [];
          phase.files.push({ value: buildFile, comment: `${BRIDGE} in Sources` });
          break;
        }
      }
    }
    return cfg;
  });
};
