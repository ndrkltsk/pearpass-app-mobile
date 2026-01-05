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
exports.withSplashScreenAndroid = void 0;
const config_plugins_1 = require("@expo/config-plugins");
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const DARK_BACKGROUND_COLOR = '#232323';
const withSplashScreenAndroid = (config) => {
    return (0, config_plugins_1.withDangerousMod)(config, ['android', async (cfg) => {
            const packageName = cfg.android?.package || 'com.pears.pass';
            const packagePath = packageName.replace(/\./g, '/');
            const templateDir = path.join(__dirname, '../../templates/android');
            const androidDir = cfg.modRequest.platformProjectRoot;
            // Copy Kotlin files
            const javaDir = path.join(androidDir, 'app/src/main/java', packagePath);
            await fs.promises.mkdir(javaDir, { recursive: true });
            const kotlinFiles = ['CustomSplashScreenModule.kt', 'CustomSplashScreenPackage.kt'];
            for (const file of kotlinFiles) {
                const srcPath = path.join(templateDir, file);
                const destPath = path.join(javaDir, file);
                let content = await fs.promises.readFile(srcPath, 'utf-8');
                // Replace package declarations
                content = content.replace(/^package com\.noxtton\.pearpass$/gm, `package ${packageName}`);
                content = content.replace(/^package com\.pears\.pass$/gm, `package ${packageName}`);
                // Replace imports
                content = content.replace(/import com\.noxtton\.pearpass\./g, `import ${packageName}.`);
                content = content.replace(/import com\.pears\.pass\./g, `import ${packageName}.`);
                await fs.promises.writeFile(destPath, content);
            }
            // Copy layout file
            const layoutDir = path.join(androidDir, 'app/src/main/res/layout');
            await fs.promises.mkdir(layoutDir, { recursive: true });
            const layoutSrc = path.join(templateDir, 'layout', 'custom_splash_screen_layout.xml');
            const layoutDest = path.join(layoutDir, 'custom_splash_screen_layout.xml');
            if (fs.existsSync(layoutSrc)) {
                await fs.promises.copyFile(layoutSrc, layoutDest);
            }
            // Copy custom_splash_screen.png drawable
            const drawableDir = path.join(androidDir, 'app/src/main/res/drawable');
            await fs.promises.mkdir(drawableDir, { recursive: true });
            const drawableSrc = path.join(templateDir, 'drawable', 'custom_splash_screen.png');
            const drawableDest = path.join(drawableDir, 'custom_splash_screen.png');
            if (fs.existsSync(drawableSrc)) {
                await fs.promises.copyFile(drawableSrc, drawableDest);
            }
            // Fix colors.xml to use dark background colors
            const colorsPath = path.join(androidDir, 'app/src/main/res/values/colors.xml');
            if (fs.existsSync(colorsPath)) {
                let colorsContent = await fs.promises.readFile(colorsPath, 'utf-8');
                // Fix splashscreen_background color
                colorsContent = colorsContent.replace(/<color name="splashscreen_background">#[0-9A-Fa-f]+<\/color>/, `<color name="splashscreen_background">${DARK_BACKGROUND_COLOR}</color>`);
                // Fix colorPrimaryDark color
                colorsContent = colorsContent.replace(/<color name="colorPrimaryDark">#[0-9A-Fa-f]+<\/color>/, `<color name="colorPrimaryDark">${DARK_BACKGROUND_COLOR}</color>`);
                // Add splash_background color if it doesn't exist
                if (!colorsContent.includes('name="splash_background"')) {
                    colorsContent = colorsContent.replace('</resources>', `  <color name="splash_background">${DARK_BACKGROUND_COLOR}</color>\n</resources>`);
                }
                else {
                    colorsContent = colorsContent.replace(/<color name="splash_background">#[0-9A-Fa-f]+<\/color>/, `<color name="splash_background">${DARK_BACKGROUND_COLOR}</color>`);
                }
                await fs.promises.writeFile(colorsPath, colorsContent);
            }
            // Fix styles.xml to use dark status bar color
            const stylesPath = path.join(androidDir, 'app/src/main/res/values/styles.xml');
            if (fs.existsSync(stylesPath)) {
                let stylesContent = await fs.promises.readFile(stylesPath, 'utf-8');
                // Fix statusBarColor
                stylesContent = stylesContent.replace(/<item name="android:statusBarColor">#[0-9A-Fa-f]+<\/item>/, `<item name="android:statusBarColor">${DARK_BACKGROUND_COLOR}</item>`);
                await fs.promises.writeFile(stylesPath, stylesContent);
            }
            return cfg;
        }]);
};
exports.withSplashScreenAndroid = withSplashScreenAndroid;
