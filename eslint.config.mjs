import js from "@eslint/js";
import globals from "globals";
import pluginReact from "eslint-plugin-react";
import { defineConfig } from "eslint/config";

export default defineConfig([
    {
        files: ["**/*.{js,mjs,cjs,jsx}"], // solo JS y JSX
        ignores: ["test.js", "node_modules/**"], // ignorar test.js y node_modules
        plugins: { react: pluginReact },
        settings: {
            react: { version: "detect" },
        },
        languageOptions: { globals: { ...globals.browser, ...globals.node } },
        rules: {},
    },
    js.configs.recommended,
]);
