#!/usr/bin/env node

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import process from "node:process";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.dirname(scriptDirectory);
const appDirectory = path.join(repositoryRoot, "jianshengjily");
const localizablePath = path.join(appDirectory, "Localizable.xcstrings");
const infoPlistPath = path.join(appDirectory, "InfoPlist.xcstrings");
const hanPattern = /[\u3400-\u9fff]/u;

function fail(message) {
  console.error(`Localization check failed: ${message}`);
  process.exit(1);
}

function run(command, commandArguments) {
  const result = spawnSync(command, commandArguments, {
    cwd: repositoryRoot,
    encoding: "utf8",
  });
  if (result.status !== 0) {
    fail(`${command} ${commandArguments.join(" ")}\n${result.stderr || result.stdout}`);
  }
  return result.stdout.trim();
}

function localizedValues(localization) {
  if (!localization || typeof localization !== "object") {
    return [];
  }
  if (localization.stringUnit) {
    return [localization.stringUnit.value];
  }
  return Object.values(localization).flatMap(localizedValues);
}

function swiftFiles(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      return swiftFiles(entryPath);
    }
    return entry.name.endsWith(".swift") ? [entryPath] : [];
  });
}

run("node", ["scripts/generate_localization_catalog.mjs", "--check"]);

const catalog = JSON.parse(fs.readFileSync(localizablePath, "utf8"));
const infoCatalog = JSON.parse(fs.readFileSync(infoPlistPath, "utf8"));
if (catalog.sourceLanguage !== "zh-Hans" || infoCatalog.sourceLanguage !== "zh-Hans") {
  fail("string catalogs must use zh-Hans as the source language");
}

const catalogKeys = new Set(Object.keys(catalog.strings));
for (const [key, entry] of Object.entries(catalog.strings)) {
  const englishValues = localizedValues(entry.localizations?.["en-US"]);
  if (englishValues.length === 0) {
    fail(`missing en-US translation for ${JSON.stringify(key)}`);
  }
  for (const value of englishValues) {
    if (hanPattern.test(value)) {
      fail(`en-US translation still contains Han characters: ${JSON.stringify(key)} -> ${JSON.stringify(value)}`);
    }
  }
}

const swiftStringPattern = /"((?:\\.|[^"\\])*)"/g;
const l10nCallPattern = /L10n\.(?:string|format|count)\(\s*"([^"]+)"/g;
for (const file of swiftFiles(appDirectory)) {
  const source = fs.readFileSync(file, "utf8");
  for (const match of source.matchAll(l10nCallPattern)) {
    if (!catalogKeys.has(match[1])) {
      fail(`missing catalog entry for L10n key ${JSON.stringify(match[1])} in ${path.relative(repositoryRoot, file)}`);
    }
  }
  for (const match of source.matchAll(swiftStringPattern)) {
    const value = match[1];
    const isFormatFallback = value.includes("%1$");
    if (hanPattern.test(value) && !value.includes("\\(") && !isFormatFallback && !catalogKeys.has(value)) {
      fail(`missing catalog entry for Chinese string ${JSON.stringify(value)} in ${path.relative(repositoryRoot, file)}`);
    }
  }
}

const displayName = infoCatalog.strings?.CFBundleDisplayName?.localizations;
if (localizedValues(displayName?.["zh-Hans"])[0] !== "力迹"
    || localizedValues(displayName?.["en-US"])[0] !== "Liji") {
  fail("CFBundleDisplayName must be 力迹 for zh-Hans and the reversible Liji romanization for en-US");
}

const outputDirectory = fs.mkdtempSync(path.join(os.tmpdir(), "jianshengjily-localization-"));
try {
  const localizableOutput = path.join(outputDirectory, "localizable");
  const infoOutput = path.join(outputDirectory, "info");
  fs.mkdirSync(localizableOutput);
  fs.mkdirSync(infoOutput);
  run("xcrun", ["xcstringstool", "compile", localizablePath, "--output-directory", localizableOutput]);
  run("xcrun", ["xcstringstool", "compile", infoPlistPath, "--output-directory", infoOutput]);

  const englishStrings = path.join(localizableOutput, "en-US.lproj", "Localizable.strings");
  const chineseStrings = path.join(localizableOutput, "zh-Hans.lproj", "Localizable.strings");
  const englishInfo = path.join(infoOutput, "en-US.lproj", "InfoPlist.strings");
  const chineseInfo = path.join(infoOutput, "zh-Hans.lproj", "InfoPlist.strings");
  for (const compiledFile of [englishStrings, chineseStrings, englishInfo, chineseInfo]) {
    if (!fs.existsSync(compiledFile)) {
      fail(`compiled localization is missing: ${compiledFile}`);
    }
  }

  const runtimeAssertions = new Map([
    ["开始训练", "Start Workout"],
    ["卧推", "Bench Press"],
    ["全身入门", "Full-Body Starter"],
    ["三分化基础", "Basic 3-Day Split"],
    ["恢复购买", "Restore Purchases"],
    ["由 力迹 生成", "Made with Liji"],
  ]);
  for (const [key, expected] of runtimeAssertions) {
    const actual = run("plutil", ["-extract", key, "raw", englishStrings]);
    if (actual !== expected) {
      fail(`compiled en-US value for ${JSON.stringify(key)} is ${JSON.stringify(actual)}, expected ${JSON.stringify(expected)}`);
    }
  }
} finally {
  fs.rmSync(outputDirectory, { recursive: true, force: true });
}

console.log(`Localization checks passed (${catalogKeys.size} entries, zh-Hans + en-US).`);
