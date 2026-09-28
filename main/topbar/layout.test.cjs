const {test} = require('node:test');
const assert = require('node:assert/strict');
const {parse} = require('./Layout.js');
const base = () => ({version:1,left:[],center:[{id:'clock'}],right:[],centerAnchor:'clock'});
const read = c => parse(JSON.stringify(c));
test('normalizes optional fields and omits disabled entries', () => {
 const c=base();c.left=[{id:'example',enabled:false}];
 assert.deepEqual(read(c).center,[{id:'clock',reveal:'always',settings:{}}]);assert.deepEqual(read(c).left,[]);
});
test('rejects unsafe paths, duplicates, and malformed settings', () => {
 for (const entry of [{id:'../escape'},{id:'clock'},{id:'example',settings:[]},{id:'example',enabled:'false'},{id:'example',reveal:'click'}]) {
  const c=base();c.right=[entry];assert.throws(()=>read(c));
 }
});
test('requires anchor in an always-visible center slot', () => {
 const c=base();c.center[0].reveal='hover';assert.throws(()=>read(c));
 c.centerAnchor='missing';assert.throws(()=>read(c));
 delete c.centerAnchor;assert.equal(read(c).centerAnchor,'');
});
test('rejects invalid JSON and unsupported schema', () => {
 assert.throws(()=>parse('{'));assert.throws(()=>read({...base(),version:2}));assert.throws(()=>read({...base(),left:{}}));
});
