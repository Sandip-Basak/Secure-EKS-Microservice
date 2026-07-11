import React, { createContext, useState, useContext } from 'react';
import axios from 'axios';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [token, setToken] = useState(null);
  const [tenantId, setTenantId] = useState('');
  const [user, setUser] = useState(null);

  // Configure an Axios instance that respects our secure, relative routing
  const api = axios.create({
    baseURL: '/' // Routed relatively to prevent CORS and infrastructure leakage
  });

  // Interceptor to inject identity and tenancy context on every request
  api.interceptors.request.use((config) => {
    if (token) {
      config.headers['Authorization'] = `Bearer ${token}`;
    }
    if (tenantId) {
      config.headers['X-Tenant-ID'] = tenantId;
    }
    return config, (error) => Promise.reject(error);
  });

  const login = async (username, password, targetTenant) => {
    try {
      // Hits our Node.js Gateway via Nginx reverse-proxy routing
      const response = await api.post('/api/auth/login', {
        username,
        password,
        tenantId: targetTenant
      });

      const { token: receivedToken } = response.data;

      // Store token safely in volatile RAM state, NOT localStorage
      setToken(receivedToken);
      setTenantId(targetTenant);
      setUser({ username });
      return { success: true };
    } catch (error) {
      return {
        success: false,
        error: error.response?.data?.error || 'Authentication failed'
      };
    }
  };

  const logout = () => {
    setToken(null);
    setTenantId('');
    setUser(null);
  };

  const register = async (username, password, targetTenant) => {
    try {
      await api.post('/api/auth/register', {
        username,
        password,
        tenantId: targetTenant
      });
      return { success: true };
    } catch (error) {
      return {
        success: false,
        error: error.response?.data?.error || 'Registration failed. Check constraints.'
      };
    }
  };

  return (
    <AuthContext.Provider value={{ token, tenantId, user, login, logout, register, api }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => useContext(AuthContext);