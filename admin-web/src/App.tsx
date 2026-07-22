import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './components/AuthProvider';
import { useAuthContext } from './components/AuthProvider';
import { ProtectedRoute } from './components/ProtectedRoute';
import Layout from './components/Layout';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import UsersList from './pages/UsersList';
import BranchesList from './pages/BranchesList';
import NewslettersList from './pages/NewslettersList';
import ResourcesList from './pages/ResourcesList';
import BranchAccess from './pages/BranchAccess';

function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<Login />} />
          
          <Route
            path="/"
            element={
              <ProtectedRoute>
                <Layout />
              </ProtectedRoute>
            }
          >
            <Route index element={<Dashboard />} />
            <Route path="users" element={<UsersList />} />
            <Route path="branches" element={<GlobalAdminOnly><BranchesList /></GlobalAdminOnly>} />
            <Route path="newsletters" element={<NewslettersList />} />
            <Route path="resources" element={<GlobalAdminOnly><ResourcesList /></GlobalAdminOnly>} />
            <Route path="branch-access" element={<BranchScopedAdmin><BranchAccess /></BranchScopedAdmin>} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}

function BranchScopedAdmin({ children }: { children: React.ReactNode }) {
  const { adminProfile } = useAuthContext();
  const accessRole = adminProfile?.accessRole || adminProfile?.role;
  if (!['admin', 'global_admin', 'region_admin', 'branch_admin'].includes(accessRole)) {
    return <Navigate to="/" replace />;
  }
  return <>{children}</>;
}

function GlobalAdminOnly({ children }: { children: React.ReactNode }) {
  const { adminProfile } = useAuthContext();
  const accessRole = adminProfile?.accessRole || adminProfile?.role;
  if (!['admin', 'global_admin'].includes(accessRole)) {
    return <Navigate to="/" replace />;
  }

  return <>{children}</>;
}

export default App;
