#!/usr/bin/env node
// ==============================================================================
// erd.mjs — Genera los diagramas ER (Mermaid) a partir de prisma/schema.prisma.
//
// Arquitectura del DW: modelo CONSTELACIÓN (bus).
//   - 3 data mart por área de negocio, separados por esquema:
//       dm_comercial      -> Comercial (ventas, membresías, renovaciones, avisos)
//       dm_entrenamiento  -> Entrenamiento (asistencias, objetivos, evaluaciones)
//       dm_atencion       -> Atención (reclamos)
//   - Dimensiones CONFORMADAS compartidas por los 3: esquema `dim`.
//
// Salida: docs/ERD.md con
//   1. Vista general (constelación completa)
//   2. Una estrella por data mart (sus hechos + solo las dims conformadas que usa)
//   3. Matriz bus (hecho -> dimensiones conformadas)
//
// No usa Chromium ni mermaid-cli: la salida es texto Mermaid, que se renderiza
// nativamente en VS Code (Markdown/Mermaid) y en GitHub.
//
// La base NO define FOREIGN KEY (las relaciones son lógicas, por convención
// sk_*). Por eso, además de las relaciones reales que Prisma detecte, se
// INFIEREN: cada columna sk_x (o sk_x_algo) de un hecho apunta a la dimensión
// cuyo PK es sk_x.
//
// Uso:  node scripts/erd.mjs
// ==============================================================================
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import internals from '@prisma/internals';

const { getDMMF } = internals;

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');

// Uso:
//   node scripts/erd.mjs                                  -> esquema completo (constelación)
//   node scripts/erd.mjs <schema.prisma> <salida.md>      -> un data mart puntual
const schemaPath = resolve(root, process.argv[2] ?? 'prisma/schema.prisma');
const outPath = resolve(root, process.argv[3] ?? 'docs/ERD.md');

const schema = readFileSync(schemaPath, 'utf8');
const dmmf = await getDMMF({ datamodel: schema });
const models = dmmf.datamodel.models;

if (models.length === 0) {
  console.error(
    'ERROR: prisma/schema.prisma no tiene modelos. Ejecutá primero:\n' +
      '  npx prisma db pull --schema prisma/schema.prisma',
  );
  process.exit(1);
}

const MART_LABELS = {
  dm_comercial: 'Comercial — ventas y membresías',
  dm_entrenamiento: 'Entrenamiento',
  dm_atencion: 'Atención y reclamos',
};

// --- helpers -----------------------------------------------------------------

const typeMap = {
  Int: 'int',
  BigInt: 'bigint',
  String: 'string',
  Boolean: 'boolean',
  DateTime: 'datetime',
  Float: 'float',
  Decimal: 'decimal',
  Json: 'json',
  Bytes: 'bytes',
  Unsupported: 'unsupported',
};
const mapType = (t) => typeMap[t] ?? String(t).toLowerCase();

const schemaOf = (model) => {
  if (model.schema) return model.schema;
  const re = new RegExp(
    String.raw`model\s+${model.name}\s*\{[\s\S]*?@@schema\("([^"]+)"\)`,
  );
  const m = schema.match(re);
  return m ? m[1] : 'dbo';
};

const dims = models
  .filter((m) => schemaOf(m) === 'dim')
  .map((m) => {
    const pk = m.fields.find((f) => f.isId && f.kind !== 'object');
    return pk ? { model: m.name, pk: pk.name } : null;
  })
  .filter(Boolean);

// Relaciones de un hecho hacia las dimensiones conformadas.
const edgesOf = (model) => {
  const edges = [];
  const seen = new Set();
  const realPairs = new Set();
  const push = (from, to, label) => {
    const id = `${from}|${to}|${label}`;
    if (seen.has(id)) return;
    seen.add(id);
    edges.push({ from, to, label });
  };

  // 1) Relaciones reales (existen si el DW define FOREIGN KEY).
  for (const f of model.fields) {
    if (f.kind !== 'object') continue;
    if (!f.relationFromFields || f.relationFromFields.length === 0) continue;
    // Etiqueta legible: la columna FK (no el nombre interno de la relación Prisma).
    push(model.name, f.type, f.relationFromFields.join(', '));
    realPairs.add(`${model.name}|${f.type}`);
  }
  // 2) Relaciones lógicas inferidas por convención sk_*.
  //    Solo se usan para pares hecho->dimensión que NO tengan ya FK real.
  if (!model.name.startsWith('Dim')) {
    for (const f of model.fields) {
      if (f.kind === 'object') continue;
      const dim = dims.find((d) => f.name === d.pk || f.name.startsWith(`${d.pk}_`));
      if (!dim) continue;
      if (realPairs.has(`${model.name}|${dim.model}`)) continue;
      push(model.name, dim.model, f.name);
    }
  }
  return edges;
};

const renderEntity = (model) => {
  const lines = [`  ${model.name} {`];
  for (const f of model.fields.filter((x) => x.kind !== 'object')) {
    let key = '';
    if (f.isId) key = ' PK';
    else if (f.isUnique) key = ' UK';
    lines.push(`    ${mapType(f.type)} ${f.name}${key}`);
  }
  lines.push('  }');
  return lines;
};

const renderDiagram = (entityNames, edges) => {
  const byName = new Map(models.map((m) => [m.name, m]));
  const lines = ['```mermaid', 'erDiagram'];
  for (const name of entityNames) lines.push(...renderEntity(byName.get(name)));
  for (const e of edges) lines.push(`  ${e.from} }o--|| ${e.to} : "${e.label}"`);
  lines.push('```');
  return lines.join('\n');
};

// --- construir el documento --------------------------------------------------

const factsBySchema = {};
for (const m of models) {
  const s = schemaOf(m);
  if (s.startsWith('dm_')) (factsBySchema[s] ??= []).push(m.name);
}
const martSchemas = Object.keys(factsBySchema).sort();

const hasRealFk = models.some((m) =>
  m.fields.some(
    (f) => f.kind === 'object' && f.relationFromFields && f.relationFromFields.length > 0,
  ),
);

const singleMart = martSchemas.length === 1 ? martSchemas[0] : null;
const schemaRel = relative(root, schemaPath);
const allDims = dims.map((d) => d.model);

const out = [];
out.push(singleMart ? `# ERD — Data Mart: ${singleMart}` : '# ERD — Esquema BI_VIP_CENTER_FIT');
out.push('');
out.push(`> Generado automáticamente por \`scripts/erd.mjs\` desde \`${schemaRel}\`.`);
out.push(`> Modelos: ${models.length}. \`PK\` = clave primaria, \`UK\` = clave única.`);
out.push('>');
if (singleMart) {
  out.push(`> **Data Mart \`${singleMart}\`**: una **estrella** (sus hechos) más las`);
  out.push('> **dimensiones conformadas** del esquema `dim` que comparte con el resto de la constelación.');
} else {
  out.push('> **Arquitectura: Data Warehouse en constelación.** El modelo tiene 3 data mart por área');
  out.push('> de negocio, cada uno una **estrella**, que **comparten las dimensiones conformadas** del');
}
out.push(
  hasRealFk
    ? '> Las relaciones provienen de las **FOREIGN KEY** declaradas en el DW.'
    : '> Las relaciones se infieren por convención `sk_*` (la base no define FK).',
);
out.push('');

// 1. Constelación completa (solo en el esquema completo).
if (!singleMart) {
  const allEdges = models.flatMap((m) => edgesOf(m));
  out.push('## Vista general (constelación)');
  out.push('');
  out.push(renderDiagram(models.map((m) => m.name), allEdges));
  out.push('');
}

// 2. Una estrella por data mart (o la única, si el esquema es de un mart).
for (const s of martSchemas) {
  const label = MART_LABELS[s] ?? s;
  const factNames = factsBySchema[s];
  const edges = factNames.flatMap((n) => edgesOf(models.find((m) => m.name === n)));
  const dimsUsed = allDims.filter((d) => edges.some((e) => e.to === d));
  out.push(`## ${singleMart ? 'Estrella' : 'Data Mart'}: ${label}`);
  out.push('');
  out.push(`\`esquema: ${s}\``);
  out.push('');
  out.push(renderDiagram([...factNames, ...dimsUsed], edges));
  out.push('');
}

// 3. Matriz bus (hecho -> dimensiones conformadas).
out.push('## Matriz bus (hecho → dimensiones conformadas)');
out.push('');
out.push(`| Data mart | Hecho | Dimensiones |`);
out.push('| --- | --- | --- |');
for (const s of martSchemas) {
  for (const fact of factsBySchema[s]) {
    const edges = edgesOf(models.find((m) => m.name === fact));
    const used = allDims.filter((d) => edges.some((e) => e.to === d));
    out.push(`| ${MART_LABELS[s] ?? s} | ${fact} | ${used.join(', ') || '—'} |`);
  }
}
out.push('');

mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, `${out.join('\n')}\n`, 'utf8');

console.log(
  `ERD escrito en ${outPath} (${models.length} modelos, ${martSchemas.length} data mart)`,
);
