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
import WordCardsList from './pages/WordCardsList';
import NewslettersList from './pages/NewslettersList';
import PraiseList from './pages/PraiseList';
import ResourcesList from './pages/ResourcesList';

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
            <Route path="wordcards" element={<GlobalAdminOnly><WordCardsList /></GlobalAdminOnly>} />
            <Route path="newsletters" element={<GlobalAdminOnly><NewslettersList /></GlobalAdminOnly>} />
            <Route path="resources" element={<GlobalAdminOnly><ResourcesList /></GlobalAdminOnly>} />
            <Route path="praise" element={<GlobalAdminOnly><PraiseList /></GlobalAdminOnly>} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
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
