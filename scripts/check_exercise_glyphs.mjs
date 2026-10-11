import fs from "node:fs";

const serviceSource = fs.readFileSync("jianshengjily/Services/WorkoutService.swift", "utf8");
const glyphSource = fs.readFileSync("jianshengjily/Views/ExerciseGlyphView.swift", "utf8");

const exerciseListMatch = serviceSource.match(
  /static let defaultExercises = \[([\s\S]*?)\n    \]/,
);
const exactMappingMatch = glyphSource.match(
  /switch name \{([\s\S]*?)\n\s*default:/,
);

if (!exerciseListMatch || !exactMappingMatch) {
  throw new Error("无法读取默认动作或动作图标映射。请检查源码结构是否变化。");
}

const officialNames = [...exerciseListMatch[1].matchAll(/"([^"]+)"/g)].map(
  (match) => match[1].toLowerCase(),
);
const mappingLines = exactMappingMatch[1]
  .split("\n")
  .filter((line) => line.trimStart().startsWith("case "));
const mappedNames = mappingLines.flatMap((line) =>
  [...line.matchAll(/"([^"]+)"/g)].map((match) => match[1].toLowerCase()),
);
const mappingEntries = [
  ...exactMappingMatch[1].matchAll(
    /case "([^"]+)":\s*self\.init\(\s*kind:\s*\.([A-Za-z]+),\s*equipment:\s*\.([A-Za-z]+)(?:,\s*variant:\s*\.([A-Za-z]+))?\s*\)/g,
  ),
].map((match) => ({
  name: match[1].toLowerCase(),
  kind: match[2],
  equipment: match[3],
  variant: match[4] ?? "standard",
}));

const officialSet = new Set(officialNames);
const mappedSet = new Set(mappedNames);
const missingNames = officialNames.filter((name) => !mappedSet.has(name));
const duplicateNames = mappedNames.filter(
  (name, index) => mappedNames.indexOf(name) !== index,
);
const unexpectedNames = mappedNames.filter((name) => !officialSet.has(name));

if (missingNames.length || duplicateNames.length || unexpectedNames.length) {
  const details = [
    missingNames.length ? `缺少映射：${missingNames.join("、")}` : null,
    duplicateNames.length ? `重复映射：${[...new Set(duplicateNames)].join("、")}` : null,
    unexpectedNames.length ? `非官方映射：${unexpectedNames.join("、")}` : null,
  ].filter(Boolean);
  throw new Error(details.join("\n"));
}

if (mappingEntries.length !== mappedNames.length) {
  throw new Error(
    `有 ${mappedNames.length - mappingEntries.length} 个动作没有可验证的 kind + equipment + variant 图标配置。`,
  );
}

const mappedKinds = new Set(mappingEntries.map((entry) => entry.kind));

if (mappedKinds.size < 35) {
  throw new Error(`动作姿势种类不足：当前仅 ${mappedKinds.size} 种。`);
}

const entriesByProfile = new Map();
for (const entry of mappingEntries) {
  const profile = `${entry.kind}:${entry.equipment}:${entry.variant}`;
  entriesByProfile.set(profile, [...(entriesByProfile.get(profile) ?? []), entry.name]);
}

const duplicateProfiles = [...entriesByProfile.entries()].filter(
  ([, names]) => names.length > 1,
);
if (duplicateProfiles.length) {
  const details = duplicateProfiles
    .map(([profile, names]) => `${profile}：${names.join("、")}`)
    .join("\n");
  throw new Error(`官方动作存在重复视觉配置：\n${details}`);
}

console.log(
  `Exercise glyph coverage passed: ${officialSet.size} official exercises, ${mappedKinds.size} pose kinds, ${entriesByProfile.size} unique visual profiles.`,
);
