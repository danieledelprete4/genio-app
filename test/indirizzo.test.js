// Prove dell'indirizzo dell'app per computer: node --test test/
const test = require('node:test');
const assert = require('node:assert');
const { normalizeUrl, gemello } = require('../indirizzo');

test('tiene solo https://host', () => {
  assert.equal(normalizeUrl('genio.nexus/hub'), 'https://genio.nexus');
  assert.equal(normalizeUrl('https://www.genio.nexus/login?x=1'), 'https://www.genio.nexus');
  assert.equal(normalizeUrl('http://localhost:3000/'), 'http://localhost:3000');
  assert.equal(normalizeUrl('http://genio.nexus'), null);
  assert.equal(normalizeUrl('genio'), null);
  assert.equal(normalizeUrl(''), null);
});

test('spazi del correttore tolti', () => {
  assert.equal(normalizeUrl(' www. genio.example.it '), 'https://www.genio.example.it');
});

test('stesso Genio con o senza www', () => {
  assert.ok(gemello('https://www.genio.example.it/hub', 'https://genio.example.it'));
  assert.ok(gemello('https://genio.example.it/', 'https://www.genio.example.it'));
  assert.ok(!gemello('https://genio.example.it/', 'https://genio.example.it'));
  assert.ok(!gemello('https://www.altro.it/', 'https://genio.example.it'));
  assert.ok(!gemello('https://wwwgenio.example.it/', 'https://genio.example.it'));
  assert.ok(!gemello('http://www.genio.example.it/', 'https://genio.example.it'));
  assert.ok(!gemello('https://www.genio.example.it:8443/', 'https://genio.example.it'));
  assert.ok(!gemello('https://login.microsoftonline.com/', 'https://genio.example.it'));
  assert.ok(!gemello('https://www.genio.example.it/', null));
});
