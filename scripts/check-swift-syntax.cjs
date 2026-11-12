// Optional Windows syntax check. This does not type-check Apple SDK calls.
// npm install --prefix .validation --no-save --ignore-scripts web-tree-sitter@0.20.8 tree-sitter-wasms@0.1.13
const fs = require('node:fs');
const path = require('node:path');
const Parser = require('../.validation/node_modules/web-tree-sitter');
function files(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    const name = path.join(directory, entry.name);
    return entry.isDirectory() ? files(name) : name.endsWith('.swift') ? [name] : [];
  });
}
(async () => {
  await Parser.init();
  const language = await Parser.Language.load(path.resolve('.validation/node_modules/tree-sitter-wasms/out/tree-sitter-swift.wasm'));
  const parser = new Parser();
  parser.setLanguage(language);
  let errors = 0;
  for (const file of [...files('Sources'), ...files('Tests'), 'Package.swift']) {
    const tree = parser.parse(fs.readFileSync(file, 'utf8'));
    function walk(node) {
      if (node.type === 'ERROR' || node.isMissing()) {
        console.error(`${file}:${node.startPosition.row + 1}:${node.startPosition.column + 1}: ${node.type}: ${node.text.slice(0, 100)}`);
        errors++;
      }
      for (const child of node.children) walk(child);
    }
    walk(tree.rootNode);
    tree.delete();
  }
  console.log(`Swift syntax scan: ${errors} parser errors (not an Xcode build).`);
  process.exitCode = errors ? 1 : 0;
})().catch(error => { console.error(error); process.exitCode = 1; });
