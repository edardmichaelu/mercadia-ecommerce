import js from "@eslint/js";
import globals from "globals";
import tseslint from "typescript-eslint";
import pluginReact from "eslint-plugin-react";
import { defineConfig } from "eslint/config";

export default defineConfig([
    // Reglas base de JS
    js.configs.recommended,

    // Reglas de TypeScript
    ...tseslint.configs.recommended,

    // Configuración para React
    {
        files: ["**/*.{js,mjs,cjs,ts,mts,cts,jsx,tsx}"],
        plugins: {
            react: pluginReact,
        },
        settings: {
            react: {
                version: "detect", // 👈 Detecta automáticamente la versión de React
            },
        },
        languageOptions: {
            globals: {
                ...globals.browser,
                ...globals.node,
            },
        },
        rules: {
            // Puedes agregar reglas personalizadas aquí si lo deseas
        },
    },
]);
