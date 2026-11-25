#!/usr/bin/env python3
"""Génère Slide.xcodeproj à partir des fichiers présents."""

import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "Slide"
TESTS = ROOT / "SlideTests"
PROJ = ROOT / "Slide.xcodeproj"


def uid(seed: str) -> str:
    return hashlib.sha1(seed.encode()).hexdigest()[:24].upper()


def q(value: str) -> str:
    if value.isalnum() or set(value) <= set("._/-") and " " not in value and not value.startswith("$"):
        if any(ch in value for ch in " /"):
            return f'"{value}"'
        return value
    return f'"{value}"'


def collect(folder: Path):
    files = []
    catalogs = []
    for path in sorted(folder.rglob("*")):
        if any(parent.suffix == ".xcassets" for parent in path.parents):
            continue
        if path.is_dir() and path.suffix == ".xcassets":
            catalogs.append(path.relative_to(folder))
            continue
        if path.is_file() and path.name != ".DS_Store":
            files.append(path.relative_to(folder))
    return files + catalogs


def file_type(rel: Path) -> str:
    name = rel.name
    if name.endswith(".swift"):
        return "sourcecode.swift"
    if name.endswith(".plist"):
        return "text.plist.xml"
    if name.endswith(".xcprivacy"):
        return "text.plist.xml"
    if name.endswith(".xcassets"):
        return "folder.assetcatalog"
    if name.endswith(".xcstrings"):
        return "text.json.xcstrings"
    return "text"


app_files = collect(APP)
test_files = collect(TESTS)

# Stable IDs
file_refs = {}
build_files = {}
for rel in app_files:
    file_refs[("app", str(rel))] = uid(f"fileref-app-{rel}")
    if rel.suffix == ".swift":
        build_files[("app", str(rel))] = uid(f"build-app-{rel}")
    elif rel.name.endswith(".xcassets") or rel.name.endswith(".xcprivacy") or rel.name.endswith(".xcstrings"):
        build_files[("app", str(rel))] = uid(f"build-res-{rel}")
for rel in test_files:
    file_refs[("test", str(rel))] = uid(f"fileref-test-{rel}")
    if rel.suffix == ".swift":
        build_files[("test", str(rel))] = uid(f"build-test-{rel}")

app_product = uid("product-app")
test_product = uid("product-test")
app_target = uid("target-app")
test_target = uid("target-test")
app_sources = uid("phase-app-sources")
app_resources = uid("phase-app-resources")
app_frameworks = uid("phase-app-frameworks")
test_sources = uid("phase-test-sources")
test_frameworks = uid("phase-test-frameworks")
project_id = uid("project")
main_group = uid("group-main")
products_group = uid("group-products")
app_group = uid("group-app")
test_group = uid("group-test")
proxy = uid("proxy")
dependency = uid("dependency")
app_debug = uid("cfg-app-debug")
app_release = uid("cfg-app-release")
test_debug = uid("cfg-test-debug")
test_release = uid("cfg-test-release")
proj_debug = uid("cfg-proj-debug")
proj_release = uid("cfg-proj-release")
app_cfg_list = uid("list-app")
test_cfg_list = uid("list-test")
proj_cfg_list = uid("list-proj")
widget_target = uid("target-widget")
widget_product = uid("product-widget")
widget_sources = uid("phase-widget-sources")
widget_frameworks = uid("phase-widget-frameworks")
widget_embed = uid("phase-embed")
widget_embed_file = uid("build-embed-widget")
widget_proxy = uid("proxy-widget")
widget_dep = uid("dep-widget")
widget_group = uid("group-widget")
widget_file_swift = uid("fileref-widget-swift")
widget_file_plist = uid("fileref-widget-plist")
widget_build_swift = uid("build-widget-swift")
widget_build_attr = uid("build-widget-attr")
widget_cfg_list = uid("list-widget")
widget_debug = uid("cfg-widget-debug")
widget_release = uid("cfg-widget-release")
attr_ref = file_refs[("app", "Activity/SlideActivityAttributes.swift")]

# Directory groups inside the app, so Xcode shows folders.
dir_groups = {Path("."): app_group}
for rel in app_files:
    parent = rel.parent
    while parent != Path("."):
        if parent not in dir_groups:
            dir_groups[parent] = uid(f"group-dir-{parent}")
        parent = parent.parent

lines = []
w = lines.append
w("// !$*UTF8*$!")
w("{")
w("\tarchiveVersion = 1;")
w("\tclasses = {};")
w("\tobjectVersion = 56;")
w("\tobjects = {")
w("")
w("/* Begin PBXBuildFile section */")
for key in sorted(build_files, key=lambda item: item[1]):
    w(f"\t\t{build_files[key]} /* {Path(key[1]).name} */ = {{isa = PBXBuildFile; fileRef = {file_refs[key]} /* {Path(key[1]).name} */; }};")
w("/* End PBXBuildFile section */")
w("")
w("/* Begin PBXContainerItemProxy section */")
w(f"\t\t{proxy} /* PBXContainerItemProxy */ = {{")
w("\t\t\tisa = PBXContainerItemProxy;")
w(f"\t\t\tcontainerPortal = {project_id} /* Project object */;")
w("\t\t\tproxyType = 1;")
w(f"\t\t\tremoteGlobalIDString = {app_target};")
w("\t\t\tremoteInfo = Slide;")
w("\t\t};")
w("/* End PBXContainerItemProxy section */")
w("")
w("/* Begin PBXFileReference section */")
w(f"\t\t{app_product} /* Slide.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Slide.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
w(f"\t\t{test_product} /* SlideTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = SlideTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
for rel in app_files:
    ref = file_refs[("app", str(rel))]
    kind = file_type(rel)
    name = rel.name
    w(f"\t\t{ref} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {kind}; path = {q(name)}; sourceTree = \"<group>\"; }};")
for rel in test_files:
    ref = file_refs[("test", str(rel))]
    w(f"\t\t{ref} /* {rel.name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(rel.name)}; sourceTree = \"<group>\"; }};")
w("/* End PBXFileReference section */")
w("")


def children_of(base: Path):
    kids = []
    subdirs = sorted({rel.parent for rel in app_files if rel.parent != base and rel.parent.parent == base})
    # direct files
    direct = sorted((rel for rel in app_files if rel.parent == base), key=lambda p: p.name)
    for sub in subdirs:
        kids.append((dir_groups[sub], sub.name, "group"))
    for rel in direct:
        kids.append((file_refs[("app", str(rel))], rel.name, "file"))
    return kids


w("/* Begin PBXGroup section */")
w(f"\t\t{main_group} = {{")
w("\t\t\tisa = PBXGroup;")
w("\t\t\tchildren = (")
w(f"\t\t\t\t{app_group} /* Slide */,")
w(f"\t\t\t\t{widget_group} /* SlideActivity */,")
w(f"\t\t\t\t{test_group} /* SlideTests */,")
w(f"\t\t\t\t{products_group} /* Products */,")
w("\t\t\t);")
w("\t\t\tsourceTree = \"<group>\";")
w("\t\t};")
w(f"\t\t{products_group} /* Products */ = {{")
w("\t\t\tisa = PBXGroup;")
w("\t\t\tchildren = (")
w(f"\t\t\t\t{app_product} /* Slide.app */,")
w(f"\t\t\t\t{widget_product} /* SlideActivity.appex */,")
w(f"\t\t\t\t{test_product} /* SlideTests.xctest */,")
w("\t\t\t);")
w("\t\t\tname = Products;")
w("\t\t\tsourceTree = \"<group>\";")
w("\t\t};")

# App root group and nested groups
all_dirs = sorted(dir_groups, key=lambda p: (len(p.parts), str(p)))
for directory in all_dirs:
    gid = dir_groups[directory]
    kids = children_of(directory)
    name = "Slide" if directory == Path(".") else directory.name
    w(f"\t\t{gid} /* {name} */ = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    for kid_id, kid_name, _kind in kids:
        w(f"\t\t\t\t{kid_id} /* {kid_name} */,")
    w("\t\t\t);")
    if directory == Path("."):
        w("\t\t\tpath = Slide;")
    else:
        w(f"\t\t\tpath = {q(directory.name)};")
    w("\t\t\tsourceTree = \"<group>\";")
    w("\t\t};")

w(f"\t\t{test_group} /* SlideTests */ = {{")
w("\t\t\tisa = PBXGroup;")
w("\t\t\tchildren = (")
for rel in test_files:
    w(f"\t\t\t\t{file_refs[('test', str(rel))]} /* {rel.name} */,")
w("\t\t\t);")
w("\t\t\tpath = SlideTests;")
w("\t\t\tsourceTree = \"<group>\";")
w("\t\t};")
w("/* End PBXGroup section */")
w("")

w("/* Begin PBXFrameworksBuildPhase section */")
for phase, name in ((app_frameworks, "Slide"), (test_frameworks, "SlideTests")):
    w(f"\t\t{phase} /* Frameworks */ = {{")
    w("\t\t\tisa = PBXFrameworksBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w("\t\t\tfiles = (")
    w("\t\t\t);")
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")
w("/* End PBXFrameworksBuildPhase section */")
w("")

w("/* Begin PBXNativeTarget section */")
w(f"\t\t{app_target} /* Slide */ = {{")
w("\t\t\tisa = PBXNativeTarget;")
w(f"\t\t\tbuildConfigurationList = {app_cfg_list} /* Build configuration list for PBXNativeTarget \"Slide\" */;")
w("\t\t\tbuildPhases = (")
w(f"\t\t\t\t{app_sources} /* Sources */,")
w(f"\t\t\t\t{app_frameworks} /* Frameworks */,")
w(f"\t\t\t\t{app_resources} /* Resources */,")
w(f"\t\t\t\t{widget_embed} /* Embed Foundation Extensions */,")
w("\t\t\t);")
w("\t\t\tbuildRules = (")
w("\t\t\t);")
w("\t\t\tdependencies = (")
w(f"\t\t\t\t{widget_dep} /* PBXTargetDependency */,")
w("\t\t\t);")
w("\t\t\tname = Slide;")
w("\t\t\tproductName = Slide;")
w(f"\t\t\tproductReference = {app_product} /* Slide.app */;")
w("\t\t\tproductType = \"com.apple.product-type.application\";")
w("\t\t};")
w(f"\t\t{test_target} /* SlideTests */ = {{")
w("\t\t\tisa = PBXNativeTarget;")
w(f"\t\t\tbuildConfigurationList = {test_cfg_list} /* Build configuration list for PBXNativeTarget \"SlideTests\" */;")
w("\t\t\tbuildPhases = (")
w(f"\t\t\t\t{test_sources} /* Sources */,")
w(f"\t\t\t\t{test_frameworks} /* Frameworks */,")
w("\t\t\t);")
w("\t\t\tbuildRules = (")
w("\t\t\t);")
w("\t\t\tdependencies = (")
w(f"\t\t\t\t{dependency} /* PBXTargetDependency */,")
w("\t\t\t);")
w("\t\t\tname = SlideTests;")
w("\t\t\tproductName = SlideTests;")
w(f"\t\t\tproductReference = {test_product} /* SlideTests.xctest */;")
w("\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";")
w("\t\t};")
w("/* End PBXNativeTarget section */")
w("")

w("/* Begin PBXProject section */")
w(f"\t\t{project_id} /* Project object */ = {{")
w("\t\t\tisa = PBXProject;")
w("\t\t\tattributes = {")
w("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
w("\t\t\t\tLastUpgradeCheck = 1600;")
w("\t\t\t\tTargetAttributes = {")
w(f"\t\t\t\t\t{app_target} = {{")
w("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
w("\t\t\t\t\t};")
w(f"\t\t\t\t\t{test_target} = {{")
w("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
w("\t\t\t\t\t\tTestTargetID = " + app_target + ";")
w("\t\t\t\t\t};")
w("\t\t\t\t};")
w("\t\t\t};")
w(f"\t\t\tbuildConfigurationList = {proj_cfg_list} /* Build configuration list for PBXProject \"Slide\" */;")
w("\t\t\tdevelopmentRegion = en;")
w("\t\t\thasScannedForEncodings = 0;")
w("\t\t\tknownRegions = (")
w("\t\t\t\ten,")
w("\t\t\t\tfr,")
w("\t\t\t\tBase,")
w("\t\t\t);")
w(f"\t\t\tmainGroup = {main_group};")
w("\t\t\tminimizedProjectReferenceProxies = 1;")
w(f"\t\t\tproductRefGroup = {products_group} /* Products */;")
w("\t\t\tprojectDirPath = \"\";")
w("\t\t\tprojectRoot = \"\";")
w("\t\t\ttargets = (")
w(f"\t\t\t\t{app_target} /* Slide */,")
w(f"\t\t\t\t{widget_target} /* SlideActivity */,")
w(f"\t\t\t\t{test_target} /* SlideTests */,")
w("\t\t\t);")
w("\t\t};")
w("/* End PBXProject section */")
w("")

w("/* Begin PBXResourcesBuildPhase section */")
w(f"\t\t{app_resources} /* Resources */ = {{")
w("\t\t\tisa = PBXResourcesBuildPhase;")
w("\t\t\tbuildActionMask = 2147483647;")
w("\t\t\tfiles = (")
for rel in app_files:
    key = ("app", str(rel))
    if rel.name.endswith(".xcassets") or rel.name.endswith(".xcprivacy") or rel.name.endswith(".xcstrings"):
        w(f"\t\t\t\t{build_files[key]} /* {rel.name} */,")
w("\t\t\t);")
w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w("\t\t};")
w("/* End PBXResourcesBuildPhase section */")
w("")

w("/* Begin PBXSourcesBuildPhase section */")
w(f"\t\t{app_sources} /* Sources */ = {{")
w("\t\t\tisa = PBXSourcesBuildPhase;")
w("\t\t\tbuildActionMask = 2147483647;")
w("\t\t\tfiles = (")
for rel in app_files:
    if rel.suffix == ".swift":
        w(f"\t\t\t\t{build_files[('app', str(rel))]} /* {rel.name} */,")
w("\t\t\t);")
w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w("\t\t};")
w(f"\t\t{test_sources} /* Sources */ = {{")
w("\t\t\tisa = PBXSourcesBuildPhase;")
w("\t\t\tbuildActionMask = 2147483647;")
w("\t\t\tfiles = (")
for rel in test_files:
    if rel.suffix == ".swift":
        w(f"\t\t\t\t{build_files[('test', str(rel))]} /* {rel.name} */,")
w("\t\t\t);")
w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w("\t\t};")
w("/* End PBXSourcesBuildPhase section */")
w("")

w("/* Begin PBXTargetDependency section */")
w(f"\t\t{dependency} /* PBXTargetDependency */ = {{")
w("\t\t\tisa = PBXTargetDependency;")
w(f"\t\t\ttarget = {app_target} /* Slide */;")
w(f"\t\t\ttargetProxy = {proxy} /* PBXContainerItemProxy */;")
w("\t\t};")
w("/* End PBXTargetDependency section */")
w("")

common_target = """
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Slide/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = ch.geneve.slide.ski;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = iphoneos;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
"""

test_common = """
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
					"@loader_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = ch.geneve.slide.ski.tests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = iphoneos;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Slide.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Slide";
"""

proj_common_debug = """
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
"""

proj_common_release = """
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				MTL_ENABLE_DEBUG_INFO = NO;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				VALIDATE_PRODUCT = YES;
"""

w("/* Begin XCBuildConfiguration section */")


def config(cid, name, settings, extra=""):
    w(f"\t\t{cid} /* {name} */ = {{")
    w("\t\t\tisa = XCBuildConfiguration;")
    w("\t\t\tbuildSettings = {")
    for line in settings.strip("\n").splitlines():
        w("\t\t\t" + line)
    if extra:
        for line in extra.strip("\n").splitlines():
            w("\t\t\t" + line)
    w("\t\t\t};")
    w(f"\t\t\tname = {name};")
    w("\t\t};")


config(proj_debug, "Debug", proj_common_debug)
config(proj_release, "Release", proj_common_release)
config(app_debug, "Debug", common_target)
config(app_release, "Release", common_target)
config(test_debug, "Debug", test_common, 'SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG SLIDE_HOSTED_TESTS $(inherited)";')
config(test_release, "Release", test_common, 'SWIFT_ACTIVE_COMPILATION_CONDITIONS = "SLIDE_HOSTED_TESTS $(inherited)";')
w("/* End XCBuildConfiguration section */")
w("")

w("/* Begin XCConfigurationList section */")
w(f"\t\t{proj_cfg_list} /* Build configuration list for PBXProject \"Slide\" */ = {{")
w("\t\t\tisa = XCConfigurationList;")
w("\t\t\tbuildConfigurations = (")
w(f"\t\t\t\t{proj_debug} /* Debug */,")
w(f"\t\t\t\t{proj_release} /* Release */,")
w("\t\t\t);")
w("\t\t\tdefaultConfigurationIsVisible = 0;")
w("\t\t\tdefaultConfigurationName = Release;")
w("\t\t};")
w(f"\t\t{app_cfg_list} /* Build configuration list for PBXNativeTarget \"Slide\" */ = {{")
w("\t\t\tisa = XCConfigurationList;")
w("\t\t\tbuildConfigurations = (")
w(f"\t\t\t\t{app_debug} /* Debug */,")
w(f"\t\t\t\t{app_release} /* Release */,")
w("\t\t\t);")
w("\t\t\tdefaultConfigurationIsVisible = 0;")
w("\t\t\tdefaultConfigurationName = Release;")
w("\t\t};")
w(f"\t\t{test_cfg_list} /* Build configuration list for PBXNativeTarget \"SlideTests\" */ = {{")
w("\t\t\tisa = XCConfigurationList;")
w("\t\t\tbuildConfigurations = (")
w(f"\t\t\t\t{test_debug} /* Debug */,")
w(f"\t\t\t\t{test_release} /* Release */,")
w("\t\t\t);")
w("\t\t\tdefaultConfigurationIsVisible = 0;")
w("\t\t\tdefaultConfigurationName = Release;")
w("\t\t};")
w(f"\t\t{widget_cfg_list} /* Build configuration list for PBXNativeTarget \"SlideActivity\" */ = {{")
w("\t\t\tisa = XCConfigurationList;")
w("\t\t\tbuildConfigurations = (")
w(f"\t\t\t\t{widget_debug} /* Debug */,")
w(f"\t\t\t\t{widget_release} /* Release */,")
w("\t\t\t);")
w("\t\t\tdefaultConfigurationIsVisible = 0;")
w("\t\t\tdefaultConfigurationName = Release;")
w("\t\t};")
w("/* End XCConfigurationList section */")
w("")
w("/* Begin widget extension */")
w(f"\t\t{widget_product} /* SlideActivity.appex */ = {{isa = PBXFileReference; explicitFileType = \"wrapper.app-extension\"; includeInIndex = 0; path = SlideActivity.appex; sourceTree = BUILT_PRODUCTS_DIR; }};")
w(f"\t\t{widget_file_swift} /* SlideActivityWidget.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SlideActivityWidget.swift; sourceTree = \"<group>\"; }};")
w(f"\t\t{widget_file_plist} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};")
w(f"\t\t{widget_build_swift} /* SlideActivityWidget.swift */ = {{isa = PBXBuildFile; fileRef = {widget_file_swift}; }};")
w(f"\t\t{widget_build_attr} /* SlideActivityAttributes.swift */ = {{isa = PBXBuildFile; fileRef = {attr_ref}; }};")
w(f"\t\t{widget_embed_file} /* SlideActivity.appex in Embed */ = {{isa = PBXBuildFile; fileRef = {widget_product}; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};")
w(f"\t\t{widget_group} /* SlideActivity */ = {{")
w("\t\t\tisa = PBXGroup;")
w("\t\t\tchildren = (")
w(f"\t\t\t\t{widget_file_swift} /* SlideActivityWidget.swift */,")
w(f"\t\t\t\t{widget_file_plist} /* Info.plist */,")
w("\t\t\t);")
w("\t\t\tpath = SlideActivity;")
w("\t\t\tsourceTree = \"<group>\";")
w("\t\t};")
w(f"\t\t{widget_sources} /* Sources */ = {{")
w("\t\t\tisa = PBXSourcesBuildPhase;")
w("\t\t\tbuildActionMask = 2147483647;")
w("\t\t\tfiles = (")
w(f"\t\t\t\t{widget_build_swift} /* SlideActivityWidget.swift */,")
w(f"\t\t\t\t{widget_build_attr} /* SlideActivityAttributes.swift */,")
w("\t\t\t);")
w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w("\t\t};")
w(f"\t\t{widget_frameworks} /* Frameworks */ = {{")
w("\t\t\tisa = PBXFrameworksBuildPhase;")
w("\t\t\tbuildActionMask = 2147483647;")
w("\t\t\tfiles = (")
w("\t\t\t);")
w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w("\t\t};")
w(f"\t\t{widget_embed} /* Embed Foundation Extensions */ = {{")
w("\t\t\tisa = PBXCopyFilesBuildPhase;")
w("\t\t\tbuildActionMask = 2147483647;")
w("\t\t\tdstPath = \"\";")
w("\t\t\tdstSubfolderSpec = 13;")
w("\t\t\tfiles = (")
w(f"\t\t\t\t{widget_embed_file} /* SlideActivity.appex */,")
w("\t\t\t);")
w("\t\t\tname = \"Embed Foundation Extensions\";")
w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w("\t\t};")
w(f"\t\t{widget_proxy} /* PBXContainerItemProxy */ = {{")
w("\t\t\tisa = PBXContainerItemProxy;")
w(f"\t\t\tcontainerPortal = {project_id} /* Project object */;")
w("\t\t\tproxyType = 1;")
w(f"\t\t\tremoteGlobalIDString = {widget_target};")
w("\t\t\tremoteInfo = SlideActivity;")
w("\t\t};")
w(f"\t\t{widget_dep} /* PBXTargetDependency */ = {{")
w("\t\t\tisa = PBXTargetDependency;")
w(f"\t\t\ttarget = {widget_target} /* SlideActivity */;")
w(f"\t\t\ttargetProxy = {widget_proxy} /* PBXContainerItemProxy */;")
w("\t\t};")
w(f"\t\t{widget_target} /* SlideActivity */ = {{")
w("\t\t\tisa = PBXNativeTarget;")
w(f"\t\t\tbuildConfigurationList = {widget_cfg_list};")
w("\t\t\tbuildPhases = (")
w(f"\t\t\t\t{widget_sources} /* Sources */,")
w(f"\t\t\t\t{widget_frameworks} /* Frameworks */,")
w("\t\t\t);")
w("\t\t\tbuildRules = (")
w("\t\t\t);")
w("\t\t\tdependencies = (")
w("\t\t\t);")
w("\t\t\tname = SlideActivity;")
w("\t\t\tproductName = SlideActivity;")
w(f"\t\t\tproductReference = {widget_product};")
w("\t\t\tproductType = \"com.apple.product-type.app-extension\";")
w("\t\t};")
widget_settings = """
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = SlideActivity/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
					"@executable_path/../../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = ch.geneve.slide.ski.liveactivity;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = iphoneos;
				SKIP_INSTALL = YES;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
"""
config(widget_debug, "Debug", widget_settings)
config(widget_release, "Release", widget_settings)
w("/* End widget extension */")
w("\t};")
w(f"\trootObject = {project_id} /* Project object */;")
w("}")
w("")

out = PROJ / "project.pbxproj"
out.parent.mkdir(parents=True, exist_ok=True)
text = "\n".join(lines)
out.write_text(text)

scheme_dir = PROJ / "xcshareddata" / "xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{app_target}"
               BuildableName = "Slide.app"
               BlueprintName = "Slide"
               ReferencedContainer = "container:Slide.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{test_target}"
               BuildableName = "SlideTests.xctest"
               BlueprintName = "SlideTests"
               ReferencedContainer = "container:Slide.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_target}"
            BuildableName = "Slide.app"
            BlueprintName = "Slide"
            ReferencedContainer = "container:Slide.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_target}"
            BuildableName = "Slide.app"
            BlueprintName = "Slide"
            ReferencedContainer = "container:Slide.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
(scheme_dir / "Slide.xcscheme").write_text(scheme)
workspace = PROJ / "project.xcworkspace"
workspace.mkdir(parents=True, exist_ok=True)
(workspace / "contents.xcworkspacedata").write_text(
    """<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
"""
)
print(f"wrote {out} ({len(app_files)} app files, {len(test_files)} test files)")
