const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const path = require('path');

const app = express();
const corsOptions = {
  origin: process.env.CORS_ORIGIN || '*',
  credentials: true,
};
app.use(cors(corsOptions));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
// Serve static files (frontend) – production mode
if (process.env.NODE_ENV === 'production') {
  const clientBuildPath = path.join(__dirname, 'public');
  app.use(express.static(clientBuildPath));
  // All other routes -> index.html for SPA routing
  app.get('*', (req, res) => {
    res.sendFile(path.join(clientBuildPath, 'index.html'));
  });
}

// Database connection
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://ss7083024_db_user:ZLBNcrFOyaplLOuJ@ac-lwgkmdv-shard-00-00.gvifnsr.mongodb.net:27017,ac-lwgkmdv-shard-00-01.gvifnsr.mongodb.net:27017,ac-lwgkmdv-shard-00-02.gvifnsr.mongodb.net:27017/SmartHome?ssl=true&replicaSet=atlas-7caltw-shard-0&authSource=admin&retryWrites=true&w=majority&appName=Cluster0';
const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_jwt_key_12345';

if (MONGODB_URI) {
  mongoose.connect(MONGODB_URI, {
    useNewUrlParser: true,
    useUnifiedTopology: true
  }).then(() => console.log('MongoDB connected via MONGODB_URI'))
    .catch(err => console.log('MongoDB connection error:', err));
} else {
  // Use in-memory database for local testing if no URI provided
  const { MongoMemoryServer } = require('mongodb-memory-server');
  MongoMemoryServer.create().then(mongoServer => {
    mongoose.connect(mongoServer.getUri(), {
      useNewUrlParser: true,
      useUnifiedTopology: true
    }).then(() => console.log('✓ Started and connected to Local In-Memory MongoDB container'));
  });
}

// ==========================================
// MODELS
// ==========================================
const userSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  devices: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Device' }]
});

const deviceSchema = new mongoose.Schema({
  token: { type: String, required: true, unique: true },
  name: { type: String, default: 'New Device' },
  owner: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  wifiSSID: { type: String, default: '' },
  wifiPassword: { type: String, default: '' },
  relayCount: { type: Number, default: 8 },
  remoteMAC: { type: String, default: '' },
  mainMAC: { type: String, default: '' },
  status: { type: String, default: 'offline' },
  lastSeen: { type: Date, default: Date.now },
  relays: { type: Map, of: Boolean, default: {} },
  pendingCommands: { type: Map, of: Boolean, default: {} }
});

const User = mongoose.model('User', userSchema);
const Device = mongoose.model('Device', deviceSchema);

const authCodeSchema = new mongoose.Schema({
  code: { type: String, required: true },
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  clientId: String,
  expiresAt: { type: Date, default: () => Date.now() + 5 * 60000 }
});
const AuthCode = mongoose.model('AuthCode', authCodeSchema);

const refreshTokenSchema = new mongoose.Schema({
  token: { type: String, required: true },
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  clientId: String
});
const RefreshToken = mongoose.model('RefreshToken', refreshTokenSchema);

// ==========================================
// MIDDLEWARE
// ==========================================
const auth = (req, res, next) => {
  try {
    const token = req.header('Authorization').replace('Bearer ', '');
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    next();
  } catch (e) {
    res.status(401).send({ error: 'Please authenticate.' });
  }
};

// ==========================================
// USER API
// ==========================================
app.post('/api/register', async (req, res) => {
  try {
    const { name, email, password } = req.body;
    let user = await User.findOne({ email });
    if (user) return res.status(400).json({ error: 'Email already exists' });
    
    const hashedPassword = await bcrypt.hash(password, 10);
    user = new User({ name, email, password: hashedPassword });
    await user.save();
    
    const token = jwt.sign({ userId: user._id }, JWT_SECRET);
    res.status(201).json({ token, user: { id: user._id, name, email } });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    const user = await User.findOne({ email });
    if (!user) return res.status(400).json({ error: 'Invalid credentials' });
    
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) return res.status(400).json({ error: 'Invalid credentials' });
    
    const token = jwt.sign({ userId: user._id }, JWT_SECRET);
    res.json({ token, user: { id: user._id, name: user.name, email: user.email } });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/create-token', auth, async (req, res) => {
  try {
    // Generate a 16-char alphanumeric token
    const token = uuidv4().replace(/-/g, '').slice(0, 16).toUpperCase();
    const { name, wifiSSID, wifiPassword, relayCount, remoteMAC } = req.body;
    
    let parsedCount = parseInt(relayCount);
    if(isNaN(parsedCount) || parsedCount <= 0) parsedCount = 8;
    
    const device = new Device({
      token,
      name: name || 'New Device',
      owner: req.user.userId,
      wifiSSID: wifiSSID || '',
      wifiPassword: wifiPassword || '',
      relayCount: parsedCount,
      remoteMAC: remoteMAC || ''
    });
    
    // Initialize relays to false
    for (let i = 0; i < parsedCount; i++) {
      device.relays.set(String(i), false);
    }
    
    await device.save();
    
    // Log it to the terminal so the user can instantly verify it saved!
    console.log('\n--- NEW DEVICE REGISTERED ---');
    console.log(device);
    console.log('-----------------------------\n');
    
    const user = await User.findById(req.user.userId);
    user.devices.push(device._id);
    await user.save();
    
    res.status(201).json({ device });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/devices', auth, async (req, res) => {
  try {
    const user = await User.findById(req.user.userId).populate('devices');
    
    // Check offline status inline (if no sync for 30 seconds)
    const devices = user.devices.map(d => {
      const obj = d.toObject();
      if (d.relays) {
        obj.relays = Object.fromEntries(d.relays);
      }
      if (Date.now() - new Date(d.lastSeen).getTime() > 30000) {
        obj.status = 'offline';
      }
      return obj;
    });
    
    res.json({ devices });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/control', auth, async (req, res) => {
  try {
    const { deviceId, relay, state } = req.body;
    const device = await Device.findOne({ _id: deviceId, owner: req.user.userId });
    if (!device) return res.status(404).json({ error: 'Device not found' });
    
    // Add command to pending (ESP32 will pick it up)
    device.pendingCommands.set(String(relay), state);
    
    // Optimistic update of UI relays
    device.relays.set(String(relay), state);
    await device.save();
    
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Webhook control endpoint for IFTTT
app.post('/api/webhook/control', async (req, res) => {
  try {
    const { token, relay, state } = req.body;
    if (!token) return res.status(400).json({ error: 'Missing device token' });
    
    const device = await Device.findOne({ token });
    if (!device) return res.status(404).json({ error: 'Device not found' });
    
    const relayIdx = parseInt(relay);
    if (isNaN(relayIdx) || relayIdx < 0 || relayIdx >= device.relayCount) {
      return res.status(400).json({ error: 'Invalid relay index' });
    }
    
    // Parse state: can be boolean, "on"/"off", 1/0
    const turnOn = (state === true || state === 'on' || state === 1 || state === '1' || String(state).toLowerCase() === 'true');
    
    device.pendingCommands.set(String(relayIdx), turnOn);
    device.relays.set(String(relayIdx), turnOn);
    await device.save();
    
    console.log(`[IFTTT Webhook] Toggled ${device.name} Relay ${relayIdx + 1} to ${turnOn ? 'ON' : 'OFF'}`);
    res.json({ success: true, device: device.name, relay: relayIdx, state: turnOn });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/device/update-config', auth, async (req, res) => {
  try {
    const { deviceId, name } = req.body;
    const device = await Device.findOneAndUpdate(
      { _id: deviceId, owner: req.user.userId },
      { name },
      { new: true }
    );
    res.json({ device });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ==========================================
// DEVICE (ESP32) API
// ==========================================
// For device auth, the device must send its token in the headers as "Device-Token"

const deviceAuth = async (req, res, next) => {
  const token = req.header('Device-Token');
  if (!token) return res.status(401).send({ error: 'Missing device token' });
  
  const device = await Device.findOne({ token });
  if (!device) return res.status(401).send({ error: 'Invalid device token' });
  
  req.device = device;
  next();
};

app.post('/api/device/register', deviceAuth, async (req, res) => {
  try {
    const { mainMAC, relayCount } = req.body;
    req.device.mainMAC = mainMAC || req.device.mainMAC;
    // Obey the server-side relay count if it exists, otherwise accept the board's initially
    if (req.device.relayCount === undefined || req.device.relayCount === 0) {
      req.device.relayCount = relayCount || 8;
    }
    req.device.status = 'online';
    req.device.lastSeen = Date.now();
    await req.device.save();
    
    res.json({ 
      success: true, 
      message: 'Device registered', 
      remoteMAC: req.device.remoteMAC,
      relayCount: req.device.relayCount 
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/device/update', deviceAuth, async (req, res) => {
  try {
    // Expected to receive { relays: [true, false, ...] }
    const { relays } = req.body;
    
    if (relays && Array.isArray(relays)) {
      relays.forEach((state, i) => {
        req.device.relays.set(String(i), state);
      });
    }
    
    req.device.status = 'online';
    req.device.lastSeen = Date.now();
    await req.device.save();
    
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/device/commands', deviceAuth, async (req, res) => {
  try {
    const pending = {};
    let hasCommands = false;
    for (let [relay, state] of req.device.pendingCommands.entries()) {
      pending[relay] = state;
      hasCommands = true;
    }
    
    let needsSave = false;
    if (hasCommands) {
      req.device.pendingCommands = new Map();
      needsSave = true;
    }
    
    const now = Date.now();
    if (now - new Date(req.device.lastSeen).getTime() > 15000 || req.device.status !== 'online') {
      req.device.status = 'online';
      req.device.lastSeen = now;
      needsSave = true;
    }
    
    if (needsSave) {
      await req.device.save();
    }
    
    res.json({ commands: pending });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/device/config', deviceAuth, async (req, res) => {
  try {
    res.json({ 
      mainMAC: req.device.mainMAC, 
      relayCount: req.device.relayCount,
      remoteMAC: req.device.remoteMAC 
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ==========================================
// GOOGLE ASSISTANT API
// ==========================================
app.post('/api/oauth/auth-code', auth, async (req, res) => {
  try {
    const code = require('crypto').randomBytes(16).toString('hex');
    await new AuthCode({ code, userId: req.user.userId, clientId: req.body.client_id }).save();
    res.json({ code });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.post('/api/oauth/token', async (req, res) => {
  try {
    const { client_id, grant_type, code, refresh_token } = req.body;
    
    if (grant_type === 'authorization_code') {
      const authCode = await AuthCode.findOne({ code });
      if (!authCode || authCode.expiresAt < Date.now()) return res.status(400).json({error: 'invalid_grant'});
      
      const access_token = jwt.sign({ userId: authCode.userId }, JWT_SECRET, { expiresIn: '24h' });
      const new_refresh_token = require('crypto').randomBytes(32).toString('hex');
      await new RefreshToken({ token: new_refresh_token, userId: authCode.userId, clientId: client_id }).save();
      await AuthCode.deleteOne({ _id: authCode._id });
      
      return res.json({ token_type: 'Bearer', access_token, refresh_token: new_refresh_token, expires_in: 86400 });
    } else if (grant_type === 'refresh_token') {
      const tokenDoc = await RefreshToken.findOne({ token: refresh_token });
      if (!tokenDoc) return res.status(400).json({error: 'invalid_grant'});
      
      const access_token = jwt.sign({ userId: tokenDoc.userId }, JWT_SECRET, { expiresIn: '24h' });
      return res.json({ token_type: 'Bearer', access_token, expires_in: 86400 });
    }
    res.status(400).json({error: 'unsupported_grant_type'});
  } catch(err) { res.status(500).json({error: 'server_error'}); }
});

app.post('/api/fulfillment', async (req, res) => {
  try {
    const token = (req.header('Authorization') || '').replace('Bearer ', '');
    if (!token) return res.status(401).send();
    let decoded;
    try { decoded = jwt.verify(token, JWT_SECRET); } catch(e) { return res.status(401).send(); }
    
    const userId = decoded.userId;
    const { requestId, inputs } = req.body;
    const intent = inputs[0].intent;
    
    if (intent === 'action.devices.SYNC') {
      const user = await User.findById(userId).populate('devices');
      const devices = user.devices.flatMap(d => {
        let googleDevices = [];
        for(let i=0; i<d.relayCount; i++) {
            googleDevices.push({
                id: `${d._id}_${i}`,
                type: 'action.devices.types.SWITCH',
                traits: ['action.devices.traits.OnOff'],
                name: {
                    defaultNames: [`Relay ${i+1}`],
                    name: `${d.name} Relay ${i+1}`,
                    nicknames: [`${d.name} ${i+1}`]
                },
                willReportState: false,
                deviceInfo: { manufacturer: 'DIY', model: 'ESP32 Relay', hwVersion: '1.0' }
            });
        }
        return googleDevices;
      });
      return res.json({ requestId, payload: { agentUserId: userId, devices } });
    } 
    
    else if (intent === 'action.devices.QUERY') {
      const payloadDevices = inputs[0].payload.devices;
      const devicesResult = {};
      for (let reqDevice of payloadDevices) {
        const [deviceId, relayIdx] = reqDevice.id.split('_');
        const device = await Device.findOne({ _id: deviceId, owner: userId });
        if(device) {
           const state = device.relays.get(relayIdx) || false;
           const isOnline = Date.now() - new Date(device.lastSeen).getTime() <= 30000 && device.status === 'online';
           devicesResult[reqDevice.id] = { online: isOnline, status: 'SUCCESS', on: state };
        } else {
           devicesResult[reqDevice.id] = { online: false, status: 'ERROR_OFFLINE' };
        }
      }
      return res.json({ requestId, payload: { devices: devicesResult } });
    }
    
    else if (intent === 'action.devices.EXECUTE') {
      const commands = inputs[0].payload.commands;
      const commandResult = [];
      for (let command of commands) {
        for (let execution of command.execution) {
          if (execution.command === 'action.devices.commands.OnOff') {
            const turnOn = execution.params.on;
            for (let reqDevice of command.devices) {
                const [deviceId, relayIdx] = reqDevice.id.split('_');
                const device = await Device.findOne({ _id: deviceId, owner: userId });
                if (device) {
                    device.pendingCommands.set(relayIdx, turnOn);
                    device.relays.set(relayIdx, turnOn);
                    await device.save();
                    commandResult.push({
                        ids: [reqDevice.id],
                        status: 'SUCCESS',
                        states: { on: turnOn, online: true }
                    });
                }
            }
          }
        }
      }
      return res.json({ requestId, payload: { commands: commandResult } });
    }
    
    else if (intent === 'action.devices.DISCONNECT') {
      await RefreshToken.deleteMany({ userId });
      return res.json({});
    }
  } catch(err) {
    console.log("Fulfillment error:", err);
    res.status(500).json({error: err.message});
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
