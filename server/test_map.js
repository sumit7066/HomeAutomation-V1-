const mongoose = require('mongoose');

const schema = new mongoose.Schema({
  relays: { type: Map, of: Boolean, default: {} }
});
const Model = mongoose.model('Test', schema);

const doc = new Model();
doc.relays.set("0", true);
doc.relays.set("1", false);

const obj = doc.toObject();
obj.relays = Object.fromEntries(doc.relays);
console.log("toObject JSON fixed:", JSON.stringify(obj));
