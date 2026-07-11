import React, { useState, useEffect } from 'react';
import { useAuth, AuthProvider } from './AuthContext';

const Dashboard = () => {
  const { user, tenantId, logout, api } = useAuth();
  const [products, setProducts] = useState([]);
  const [productName, setProductName] = useState('');
  const [selectedFile, setSelectedFile] = useState(null);
  const [analyticsStatus, setAnalyticsStatus] = useState('');

  const fetchProducts = async () => {
    try {
      // In production, Nginx or EKS Ingress paths route this to the Django app
      const res = await api.get('/api/catalog/products/');
      setProducts(res.data);
    } catch (err) {
      alert('Error fetching products. Ensure tenant context is set.');
    }
  };

  useEffect(() => {
    fetchProducts();
  }, []);

  const handleCreateProduct = async (e) => {
    e.preventDefault();
    if (!productName || !selectedFile) return;

    const formData = new FormData();
    formData.append('name', productName);
    formData.append('image', selectedFile);
    formData.append('category', '1'); // Mocking category PK for this exercise

    try {
      await api.post('/api/catalog/products/', formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
      });
      setProductName('');
      setSelectedFile(null);
      fetchProducts();
    } catch (err) {
      alert('Write failed: Unauthorized or bad payload context.');
    }
  };

  const triggerAnalytics = async () => {
    try {
      setAnalyticsStatus('Queuing...');
      // Routes internally down to the Flask worker triggers
      const res = await api.post('/api/v1/analytics/report', { report_type: 'sales' });
      setAnalyticsStatus(`Job Spawned: ${res.data.task_id}`);
    } catch (err) {
      setAnalyticsStatus('Failed to spawn worker job.');
    }
  };

  return (
    <div style={{ padding: '2rem' }}>
      <h2>Tenant System Workspace: {tenantId} (User: {user.username})</h2>
      <button onClick={logout}>Terminate Session</button>
      <hr />
      
      <h3>Add New Product (Requires Active Session)</h3>
      <form onSubmit={handleCreateProduct}>
        <input type="text" placeholder="Product Name" value={productName} onChange={e => setProductName(e.target.value)} />
        <input type="file" onChange={e => setSelectedFile(target.files[0])} />
        <button type="submit">Upload & Save to Cluster</button>
      </form>

      <h3>Tenant Product Catalog (Public View)</h3>
      <ul>
        {products.map(p => (
          <li key={p.id}>{p.name} - <a href={p.image} target="_blank" rel="noreferrer">View Secure Asset Link</a></li>
        ))}
      </ul>
      <hr />

      <h3>Asynchronous Processing Engine</h3>
      <button onClick={triggerAnalytics}>Compile Heavy Analytics Report</button>
      <p>Engine Feedback: <strong>{analyticsStatus}</strong></p>
    </div>
  );
};

const AuthScreen = () => {
  const { login, register } = useAuth();
  const [isRegistering, setIsRegistering] = useState(false);
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [tenantId, setTenantId] = useState('');
  const [feedback, setFeedback] = useState({ message: '', isError: false });

  const handleSubmit = async (e) => {
    e.preventDefault();
    setFeedback({ message: '', isError: false });

    if (isRegistering) {
      const res = await register(username, password, tenantId);
      if (res.success) {
        setFeedback({ message: 'Registration complete! Proceeding to login state.', isError: false });
        setIsRegistering(false);
        setPassword('');
      } else {
        setFeedback({ message: res.error, isError: true });
      }
    } else {
      const res = await login(username, password, tenantId);
      if (!res.success) {
        setFeedback({ message: res.error, isError: true });
      }
    }
  };

  return (
    <div style={{ maxWidth: '400px', margin: '5rem auto', padding: '2rem', border: '1px solid #ddd', borderRadius: '4px' }}>
      <h2>{isRegistering ? 'Create Corporate Account' : 'Enterprise Portal Access'}</h2>
      
      {feedback.message && (
        <p style={{ color: feedback.isError ? 'red' : 'green', fontWeight: 'bold' }}>
          {feedback.message}
        </p>
      )}

      <form onSubmit={handleSubmit}>
        <div style={{ marginBottom: '1rem' }}>
          <label style={{ display: 'block', marginBottom: '0.5rem' }}>Tenant ID Scope</label>
          <input type="text" value={tenantId} onChange={e => setTenantId(e.target.value)} style={{ width: '100%', padding: '0.5rem' }} required />
        </div>
        <div style={{ marginBottom: '1rem' }}>
          <label style={{ display: 'block', marginBottom: '0.5rem' }}>Username</label>
          <input type="text" value={username} onChange={e => setUsername(e.target.value)} style={{ width: '100%', padding: '0.5rem' }} required />
        </div>
        <div style={{ marginBottom: '1rem' }}>
          <label style={{ display: 'block', marginBottom: '0.5rem' }}>Password</label>
          <input type="password" value={password} onChange={e => setPassword(e.target.value)} style={{ width: '100%', padding: '0.5rem' }} required />
        </div>
        
        <button type="submit" style={{ width: '100%', padding: '0.75rem', background: '#0070f3', color: 'white', border: 'none', cursor: 'pointer' }}>
          {isRegistering ? 'Initialize Identity' : 'Establish Verification'}
        </button>
      </form>

      <button 
        onClick={() => { setIsRegistering(!isRegistering); setFeedback({ message: '', isError: false }); }} 
        style={{ marginTop: '1rem', background: 'none', border: 'none', color: '#0070f3', cursor: 'pointer', textDecoration: 'underline' }}
      >
        {isRegistering ? 'Already have an identity? Sign In' : 'Need a multi-tenant identity? Register here'}
      </button>
    </div>
  );
};

// Ensure AppContent renders AuthScreen instead of LoginScreen:
const AppContent = () => {
  const { token } = useAuth();
  return token ? <Dashboard /> : <AuthScreen />;
};

export default function App() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  );
}