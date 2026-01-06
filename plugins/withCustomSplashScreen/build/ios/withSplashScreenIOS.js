"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.withSplashScreenIOS = void 0;
const config_plugins_1 = require("@expo/config-plugins");
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
async function copyDirectory(src, dest) {
    await fs.promises.mkdir(dest, { recursive: true });
    const entries = await fs.promises.readdir(src, { withFileTypes: true });
    for (const entry of entries) {
        const srcPath = path.join(src, entry.name);
        const destPath = path.join(dest, entry.name);
        if (entry.isDirectory()) {
            await copyDirectory(srcPath, destPath);
        }
        else {
            await fs.promises.copyFile(srcPath, destPath);
        }
    }
}
// Intercept Expo's splash storyboard mod - set skipWriting flag and copy our file instead
const withCustomSplashStoryboard = (config) => {
    return (0, config_plugins_1.withMod)(config, {
        platform: 'ios',
        mod: 'splashScreenStoryboard',
        action: async (cfg) => {
            const templateDir = path.join(__dirname, '../../templates/ios');
            const storyboardSrc = path.join(templateDir, 'SplashScreen.storyboard');
            const projectName = cfg.modRequest.projectName || cfg.name || 'PearPass';
            const storyboardDest = path.join(cfg.modRequest.platformProjectRoot, projectName, 'SplashScreen.storyboard');
            // Copy our storyboard directly
            if (fs.existsSync(storyboardSrc)) {
                await fs.promises.copyFile(storyboardSrc, storyboardDest);
            }
            // Tell Expo's base mod to skip writing by marking it handled
            cfg.modResults = null;
            cfg.modRequest.introspect = true;
            return cfg;
        },
    });
};
// Copy splash screen assets (images, colorsets)
const withSplashScreenAssets = (config) => {
    return (0, config_plugins_1.withDangerousMod)(config, ['ios', async (cfg) => {
            const templateDir = path.join(__dirname, '../../templates/ios');
            const iosDir = cfg.modRequest.platformProjectRoot;
            const projectName = cfg.modRequest.projectName || cfg.name || 'PearPass';
            const projectDir = path.join(iosDir, projectName);
            const imagesDir = path.join(projectDir, 'Images.xcassets');
            // Copy SplashImage.imageset (full-screen splash image)
            const splashImageSrc = path.join(templateDir, 'SplashImage.imageset');
            const splashImageDest = path.join(imagesDir, 'SplashImage.imageset');
            if (fs.existsSync(splashImageSrc)) {
                await copyDirectory(splashImageSrc, splashImageDest);
            }
            // Copy SplashScreenBackground.colorset
            const splashBgSrc = path.join(templateDir, 'SplashScreenBackground.colorset');
            const splashBgDest = path.join(imagesDir, 'SplashScreenBackground.colorset');
            if (fs.existsSync(splashBgSrc)) {
                await copyDirectory(splashBgSrc, splashBgDest);
            }
            return cfg;
        }]);
};
const withSplashScreenIOS = (config) => {
    // Intercept and handle storyboard ourselves
    config = withCustomSplashStoryboard(config);
    // Copy the image assets
    config = withSplashScreenAssets(config);
    return config;
};
exports.withSplashScreenIOS = withSplashScreenIOS;
