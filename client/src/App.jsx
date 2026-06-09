import React, { useState, useEffect, useCallback } from 'react';

const API_URL = 'https://homeautomation-v1.onrender.com/api';

export default function App() {
  const [token, setToken] = useState(localStorage.getItem('token'));
  const [user, setUser] = useState(JSON.parse(localStorage.getItem('user')) || null);
  const [toast, setToast] = useState({ show: false, message: '', error: false });
  const [oauthParams, setOauthParams] = useState(null);

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    if (params.get('client_id') && params.get('redirect_uri') && params.get('response_type') === 'code') {
      setOauthParams({
        client_id: params.get('client_id'),
        redirect_uri: params.get('redirect_uri'),
        state: params.get('state')
      });
    }
  }, []);

  const showToast = (message, error = false) => {
    setToast({ show: true, message, error });
    setTimeout(() => setToast({ show: false, message: '', error: false }), 3000);
  };

  const handleAuthSuccess = (data) => {
    setToken(data.token);
    setUser(data.user);
    localStorage.setItem('token', data.token);
    localStorage.setItem('user', JSON.stringify(data.user));
    showToast(`Welcome, ${data.user.name}!`);
  };

  const logout = () => {
    setToken(null);
    setUser(null);
    localStorage.removeItem('token');
    localStorage.removeItem('user');
  };

  return (
    <>
      <nav className="glass" style={{ margin: '1rem 2rem' }}>
        <div className="logo">
          <i className="fa-solid fa-house-signal"></i> SmartHome
        </div>
        {token && user && (
          <div id="nav-actions">
            <span style={{ marginRight: '15px', fontWeight: 500 }}>Hi, {user.name}</span>
            <button className="btn btn-outline" onClick={logout}>
              <i className="fa-solid fa-sign-out-alt"></i> Logout
            </button>
          </div>
        )}
      </nav>

      <div className="container">
        {!token ? (
          <AuthPage onAuth={handleAuthSuccess} showToast={showToast} />
        ) : oauthParams ? (
          <OAuthScreen token={token} params={oauthParams} showToast={showToast} />
        ) : (
          <Dashboard token={token} onLogout={logout} showToast={showToast} />
        )}
      </div>

      <div id="toast" className={`toast ${toast.show ? 'toast-show' : ''} ${toast.error ? 'toast-error' : ''}`}>
        {toast.message}
      </div>
    </>
  );
}

function AuthPage({ onAuth, showToast }) {
  const [isLogin, setIsLogin] = useState(true);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!email || !password || (!isLogin && !name)) {
      return showToast('Please fill all required fields', true);
    }
    try {
      const endpoint = isLogin ? '/login' : '/register';
      const body = isLogin ? { email, password } : { name, email, password };
      const res = await fetch(`${API_URL}${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body)
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Authenication failed');
      onAuth(data);
    } catch (err) {
      showToast(err.message, true);
    }
  };

  return (
    <div className="glass auth-container">
      <h2>{isLogin ? 'Welcome Back' : 'Create Account'}</h2>
      <form onSubmit={handleSubmit}>
        {!isLogin && (
          <div className="form-group">
            <label>Full Name</label>
            <input type="text" value={name} onChange={e => setName(e.target.value)} required />
          </div>
        )}
        <div className="form-group">
          <label>Email</label>
          <input type="email" value={email} onChange={e => setEmail(e.target.value)} required />
        </div>
        <div className="form-group">
          <label>Password</label>
          <input type="password" value={password} onChange={e => setPassword(e.target.value)} required />
        </div>
        <button type="submit" className="btn btn-primary" style={{ width: '100%' }}>
          {isLogin ? 'Log In' : 'Sign Up'}
        </button>
      </form>
      <div className="switch-auth" onClick={() => setIsLogin(!isLogin)}>
        {isLogin ? "Don't have an account? Sign up" : 'Already have an account? Log in'}
      </div>
    </div>
  );
}

function Dashboard({ token, onLogout, showToast }) {
  const [devices, setDevices] = useState([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);

  const fetchDevices = useCallback(async () => {
    try {
      const res = await fetch(`${API_URL}/devices`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error);
      setDevices(data.devices || []);
    } catch (err) {
      if (err.message.includes('authenticate')) onLogout();
    } finally {
      setLoading(false);
    }
  }, [token, onLogout]);

  useEffect(() => {
    fetchDevices();
    const interval = setInterval(fetchDevices, 3000);
    return () => clearInterval(interval);
  }, [fetchDevices]);

  const toggleRelay = async (deviceId, relay, state) => {
    // Optimistic UI update
    setDevices(prev => prev.map(d => {
      if (d._id === deviceId) {
        return { ...d, relays: { ...d.relays, [relay]: state } };
      }
      return d;
    }));

    try {
      const res = await fetch(`${API_URL}/control`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ deviceId, relay, state })
      });
      if (!res.ok) throw new Error('Failed to update relay');
    } catch (err) {
      showToast(err.message, true);
      fetchDevices(); // Revert
    }
  };

  return (
    <>
      <div className="dashboard-header">
        <div>
          <h1>My Devices</h1>
          <p style={{ color: 'var(--text-muted)', marginTop: '5px' }}>Manage your smart home network</p>
        </div>
        <button className="btn btn-primary" onClick={() => setModalOpen(true)}>
          <i className="fa-solid fa-plus"></i> Add Device
        </button>
      </div>

      {loading && <div className="loader" style={{ display: 'block' }}></div>}

      {!loading && devices.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '4rem', color: 'var(--text-muted)' }}>
          <i className="fa-solid fa-microchip" style={{ fontSize: '4rem', marginBottom: '1rem', opacity: 0.5 }}></i>
          <h3>No devices found</h3>
          <p>Click the 'Add Device' button to connect your first ESP32 board.</p>
        </div>
      ) : (
        <div className="devices-grid">
          {devices.map(device => (
             <DeviceCard key={device._id} device={device} onToggle={toggleRelay} />
          ))}
        </div>
      )}

      {modalOpen && (
        <AddDeviceModal 
          token={token} 
          onClose={() => setModalOpen(false)} 
          onSuccess={() => { fetchDevices(); showToast('Device added successfully!'); }}
          showToast={showToast} 
        />
      )}
    </>
  );
}

function DeviceCard({ device, onToggle }) {
  const isOnline = device.status === 'online';
  const relayCount = device.relayCount || 8;
  const relays = [];
  
  for (let i = 0; i < relayCount; i++) {
    const state = device.relays?.[i] || false;
    relays.push(
      <div key={i} className="relay-item">
        <div className="relay-info">
          <span className="relay-name">Relay {i + 1}</span>
          <span className="relay-state">{state ? 'ON' : 'OFF'}</span>
        </div>
        <label className="switch">
          <input 
            type="checkbox" 
            checked={state} 
            disabled={!isOnline}
            onChange={(e) => onToggle(device._id, i, e.target.checked)}
          />
          <span className="slider"></span>
        </label>
      </div>
    );
  }

  return (
    <div className="device-card glass">
      <div className="device-header">
        <div>
          <h3 style={{ marginBottom: '5px' }}>{device.name}</h3>
          <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', fontFamily: 'monospace' }}>
            ID: {device.token.substring(0,8)}...
          </div>
        </div>
        <div>
          {isOnline ? (
            <span className="status-badge status-online"><i className="fa-solid fa-wifi"></i> Online</span>
          ) : (
            <span className="status-badge status-offline"><i className="fa-solid fa-wifi-slash" style={{ opacity: 0.6 }}></i> Offline</span>
          )}
        </div>
      </div>
      <div className="relay-grid">
        {relays}
      </div>
    </div>
  );
}

function AddDeviceModal({ token, onClose, onSuccess, showToast }) {
  const [step, setStep] = useState(1);
  const [deviceToken, setDeviceToken] = useState('');
  
  const [name, setName] = useState('');
  const [ssid, setSsid] = useState('');
  const [password, setPassword] = useState('');
  const [rmac, setRmac] = useState('');
  const [rcount, setRcount] = useState(8);

  const generateToken = async () => {
    if (!name) return showToast('Device Name is required', true);
    try {
      const res = await fetch(`${API_URL}/create-token`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ name, wifiSSID: ssid, wifiPassword: password, relayCount: rcount, remoteMAC: rmac })
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error);
      
      setDeviceToken(data.device.token);
      setStep(2);
      onSuccess();
    } catch (err) {
      showToast(err.message, true);
    }
  };

  const copyToken = () => {
    navigator.clipboard.writeText(deviceToken);
    showToast('Token copied to clipboard!');
  };

  return (
    <div className="modal" onClick={onClose}>
      <div className="glass modal-content" onClick={e => e.stopPropagation()}>
        <span className="close-btn" onClick={onClose}>&times;</span>
        <h2 style={{ marginBottom: '1.5rem' }}>Add New Device</h2>
        
        {step === 1 ? (
          <div>
            <div className="form-group">
              <label>Device Name (e.g. Living Room)</label>
              <input type="text" value={name} onChange={e => setName(e.target.value)} placeholder="Living Room Relays" required />
            </div>
            <div className="form-group">
              <label>WiFi SSID</label>
              <input type="text" value={ssid} onChange={e => setSsid(e.target.value)} placeholder="Home Network Name" />
            </div>
            <div className="form-group">
              <label>WiFi Password</label>
              <input type="text" value={password} onChange={e => setPassword(e.target.value)} placeholder="Network Password" />
            </div>
            <div className="form-group">
              <label>Remote MAC Address (Optional)</label>
              <input type="text" value={rmac} onChange={e => setRmac(e.target.value)} placeholder="XX:XX:XX:XX:XX:XX" />
            </div>
            <div className="form-group">
              <label>Relay Count</label>
              <input type="number" min="1" max="16" value={rcount} onChange={e => setRcount(parseInt(e.target.value) || 8)} />
            </div>
            <button type="button" className="btn btn-primary" onClick={generateToken} style={{ width: '100%' }}>Generate Token</button>
          </div>
        ) : (
          <div style={{ textAlign: 'center' }}>
            <i className="fa-solid fa-check-circle" style={{ color: 'var(--success)', fontSize: '3rem', marginBottom: '1rem' }}></i>
            <h3>Device Added Successfully!</h3>
            <p style={{ marginTop: '1rem', color: 'var(--text-muted)' }}>Enter this token in your ESP32 configuration portal:</p>
            
            <div className="token-display">{deviceToken}</div>
            
            <button className="btn btn-outline" onClick={copyToken} style={{ marginTop: '1.5rem', width: '100%' }}>
              <i className="fa-regular fa-copy"></i> Copy Token
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

function OAuthScreen({ token, params, showToast }) {
  const [loading, setLoading] = useState(false);

  const authorize = async () => {
    setLoading(true);
    try {
      const res = await fetch(`${API_URL}/oauth/auth-code`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ client_id: params.client_id })
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error);
      
      const redirectUrl = new URL(params.redirect_uri);
      redirectUrl.searchParams.append('code', data.code);
      redirectUrl.searchParams.append('state', params.state);
      window.location.href = redirectUrl.toString();
    } catch (err) {
      showToast(err.message, true);
      setLoading(false);
    }
  };

  return (
    <div className="glass auth-container">
      <h2>Link to Google Home</h2>
      <p style={{ color: 'var(--text-muted)', marginBottom: '2rem' }}>
        Google Assistant wants to access your Smart Home devices.
      </p>
      <button className="btn btn-primary" onClick={authorize} disabled={loading} style={{ width: '100%' }}>
        {loading ? 'Linking...' : 'Authorize'}
      </button>
    </div>
  );
}
