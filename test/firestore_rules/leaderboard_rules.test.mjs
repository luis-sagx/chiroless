import assert from 'node:assert/strict';
import { before, beforeEach, test } from 'node:test';
import { readFile } from 'node:fs/promises';

// Standalone local REST checks: no Firebase CLI, credentials, SDK, or production.
// Start the Firestore emulator on 127.0.0.1:8185 with demo-chiroless first.
const host = 'http://127.0.0.1:8185';
const project = 'demo-chiroless';
const database = `projects/${project}/databases/(default)`;
const documents = `${database}/documents`;
const profile = (uid = 'alice') => `users/${uid}/leaderboard/profile`;
const entry = (uid = 'alice', month = '2026-10') => `leaderboardMonths/${month}/entries/${uid}`;
const value = (v) => {
  if (typeof v === 'string') return { stringValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return { doubleValue: Number.isFinite(v) ? v : String(v) };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(value) } };
  throw new Error('Unsupported local test value');
};
const fields = (data) => Object.fromEntries(Object.entries(data).map(([k, v]) => [k, value(v)]));
const token = (uid) => {
  const now = Math.floor(Date.now() / 1000);
  const encode = (v) => Buffer.from(JSON.stringify(v)).toString('base64url');
  return `${encode({ alg: 'none', typ: 'JWT' })}.${encode({
    sub: uid, user_id: uid, aud: project, iss: `https://securetoken.google.com/${project}`,
    iat: now, exp: now + 3600, auth_time: now,
    firebase: { sign_in_provider: 'custom', identities: {} },
  })}.`;
};
async function request(path, { uid, admin = false, method = 'GET', body } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (admin || uid) headers.Authorization = `Bearer ${admin ? 'owner' : token(uid)}`;
  const response = await fetch(`${host}/${path}`, {
    method, headers, body: body ? JSON.stringify(body) : undefined,
    signal: AbortSignal.timeout(15000),
  });
  const text = await response.text();
  let data;
  try { data = JSON.parse(text); } catch { data = text; }
  return { status: response.status, data };
}
const write = (path, data, timestamp = false) => ({
  update: { name: `${documents}/${path}`, fields: fields(data) },
  ...(timestamp ? { updateTransforms: [{ fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' }] } : {}),
});
const commit = (writes, uid = 'alice') => request(`v1/${documents}:commit`, {
  method: 'POST', uid, body: { writes },
});
const prefs = (enabled = true, alias = 'Alicia') => ({ enabled, alias, publishedMonths: ['2026-10'] });
const score = (savingsPercent = 35, alias = 'Alicia') => ({ alias, savingsPercent });
const allow = (r) => assert.equal(r.status, 200, JSON.stringify(r.data));
const deny = (r) => assert.equal(r.status, 403, JSON.stringify(r.data));
async function seed(path, data) {
  allow(await request(`v1/${documents}/${path}`, { admin: true, method: 'PATCH', body: { fields: fields(data) } }));
}

before(async () => {
  const rulesPath = process.env.LOCAL_FIRESTORE_RULES || 'firestore.rules';
  const content = await readFile(rulesPath, 'utf8');
  const r = await request(`emulator/v1/projects/${project}:securityRules`, {
    admin: true, method: 'PUT', body: { rules: { files: [{ name: 'firestore.rules', content }] } },
  });
  allow(r);
  assert.equal((r.data.issues || []).filter((i) => i.severity === 'ERROR').length, 0, JSON.stringify(r.data));
});
beforeEach(async () => {
  allow(await request(`emulator/v1/${database}/documents`, { method: 'DELETE', admin: true }));
  await seed(profile(), prefs());
});

test('owner publishes finite savings with a server timestamp after opting in', async () => {
  allow(await commit([write(entry(), score(), true)]));
  const r = await request(`v1/${documents}/${entry()}`, { uid: 'alice' });
  allow(r);
  assert.equal(r.data.fields.savingsPercent.doubleValue, 35);
  assert.ok(r.data.fields.updatedAt.timestampValue);
});

test('signed-in participants can read the shared ranking; anonymous users cannot', async () => {
  await seed(entry(), score());
  allow(await request(`v1/${documents}/${entry()}`, { uid: 'bob' }));
  deny(await request(`v1/${documents}/${entry()}`));
  allow(await request(`v1/${documents}/leaderboardMonths/2026-10/entries`, { uid: 'bob' }));
  deny(await request(`v1/${documents}/leaderboardMonths/2026-10/entries`));
});

test('another user cannot create, update, or delete the owner projection', async () => {
  deny(await commit([write(entry(), score(), true)], 'bob'));
  await seed(entry(), score());
  deny(await commit([write(entry(), score(40), true)], 'bob'));
  deny(await commit([{ delete: `${documents}/${entry()}` }], 'bob'));
});

test('negative percentages and 100 are truthful valid boundary scores', async () => {
  for (const percent of [-10000, 0, 100]) allow(await commit([write(entry(), score(percent), true)]));
});

test('NaN, infinities, values above 100, and strings are rejected', async () => {
  for (const percent of [NaN, Infinity, -Infinity, 100.01, '35']) {
    deny(await commit([write(entry(), score(percent), true)]));
  }
});

test('extra private fields, missing required fields, and malformed aliases are rejected', async () => {
  deny(await commit([write(entry(), { ...score(), income: 1000 }, true)]));
  deny(await commit([write(entry(), { alias: 'Alicia' }, true)]));
  deny(await commit([write(entry(), score(35, ''), true)]));
  deny(await commit([write(entry(), score(35, 'x'.repeat(25)), true)]));
  deny(await commit([write(entry(), score(35, 'Different alias'), true)]));
});

test('client timestamps and invalid month keys cannot be published', async () => {
  const r = write(entry(), score());
  r.update.fields.updatedAt = { timestampValue: '2026-10-01T00:00:00Z' };
  deny(await commit([r]));
  for (const month of ['2026-00', '2026-13', 'October', '2026-1']) {
    deny(await commit([write(entry('alice', month), score(), true)]));
  }
});

test('same-batch opt-in and publishing use the post-commit profile', async () => {
  await seed(profile(), prefs(false, ''));
  allow(await commit([write(profile(), prefs()), write(entry(), score(), true)]));
});

test('withdrawal blocks late publication and owner can delete after opting out', async () => {
  allow(await commit([write(entry(), score(), true)]));
  allow(await commit([write(profile(), prefs(false))]));
  deny(await commit([write(entry(), score(45), true)]));
  allow(await commit([{ delete: `${documents}/${entry()}` }]));
});

test('same-batch disable plus publish is denied atomically; disable plus delete is allowed', async () => {
  allow(await commit([write(entry(), score(), true)]));
  deny(await commit([write(profile(), prefs(false)), write(entry(), score(45), true)]));
  const r = await request(`v1/${documents}/${profile()}`, { uid: 'alice' });
  allow(r);
  assert.equal(r.data.fields.enabled.booleanValue, true);
  allow(await commit([write(profile(), prefs(false)), { delete: `${documents}/${entry()}` }]));
});

test('participation preferences stay private and schema-validated', async () => {
  allow(await request(`v1/${documents}/${profile()}`, { uid: 'alice' }));
  deny(await request(`v1/${documents}/${profile()}`, { uid: 'bob' }));
  deny(await request(`v1/${documents}/${profile()}`));
  deny(await commit([write(profile(), prefs())], 'bob'));
  deny(await commit([write(profile(), { ...prefs(), income: 1000 })]));
  deny(await commit([write(profile(), prefs(true, 'x'))]));
  deny(await commit([write('users/alice/leaderboard/other', prefs())]));
});

test('public ranking access does not expose user documents or financial collections', async () => {
  for (const path of ['users/alice', 'expenses/e', 'incomes/i', 'budgets/b', 'achievements/a', 'metrics/m', 'recurringTransactions/r']) {
    await seed(path, { userId: 'alice', amount: 1000 });
    allow(await request(`v1/${documents}/${path}`, { uid: 'alice' }));
    deny(await request(`v1/${documents}/${path}`, { uid: 'bob' }));
    deny(await request(`v1/${documents}/${path}`));
  }
});
