import { ConfigPlugin, withDangerousMod } from '@expo/config-plugins';
import * as fs from 'fs';
import * as path from 'path';

const DARK_BACKGROUND_COLOR = '#232323';

export const withSplashScreenAndroid: ConfigPlugin = (config) => {
  return withDangerousMod(config, ['android', async (cfg) => {
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
      content = content.replace(
        /^package com\.noxtton\.pearpass$/gm,
        `package ${packageName}`
      );
      content = content.replace(
        /^package com\.pears\.pass$/gm,
        `package ${packageName}`
      );

      // Replace imports
      content = content.replace(
        /import com\.noxtton\.pearpass\./g,
        `import ${packageName}.`
      );
      content = content.replace(
        /import com\.pears\.pass\./g,
        `import ${packageName}.`
      );

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
      colorsContent = colorsContent.replace(
        /<color name="splashscreen_background">#[0-9A-Fa-f]+<\/color>/,
        `<color name="splashscreen_background">${DARK_BACKGROUND_COLOR}</color>`
      );

      // Fix colorPrimaryDark color
      colorsContent = colorsContent.replace(
        /<color name="colorPrimaryDark">#[0-9A-Fa-f]+<\/color>/,
        `<color name="colorPrimaryDark">${DARK_BACKGROUND_COLOR}</color>`
      );

      // Add splash_background color if it doesn't exist
      if (!colorsContent.includes('name="splash_background"')) {
        colorsContent = colorsContent.replace(
          '</resources>',
          `  <color name="splash_background">${DARK_BACKGROUND_COLOR}</color>\n</resources>`
        );
      } else {
        colorsContent = colorsContent.replace(
          /<color name="splash_background">#[0-9A-Fa-f]+<\/color>/,
          `<color name="splash_background">${DARK_BACKGROUND_COLOR}</color>`
        );
      }

      await fs.promises.writeFile(colorsPath, colorsContent);
    }

    // Fix styles.xml to use dark status bar color
    const stylesPath = path.join(androidDir, 'app/src/main/res/values/styles.xml');
    if (fs.existsSync(stylesPath)) {
      let stylesContent = await fs.promises.readFile(stylesPath, 'utf-8');

      // Fix statusBarColor
      stylesContent = stylesContent.replace(
        /<item name="android:statusBarColor">#[0-9A-Fa-f]+<\/item>/,
        `<item name="android:statusBarColor">${DARK_BACKGROUND_COLOR}</item>`
      );

      await fs.promises.writeFile(stylesPath, stylesContent);
    }

    return cfg;
  }]);
};
