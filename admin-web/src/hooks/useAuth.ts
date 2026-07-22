import { useState, useEffect } from 'react';
import { auth, db } from '../lib/firebase';
import { onAuthStateChanged, User } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';

export function useAuth() {
  const [user, setUser] = useState<User | null>(null);
  const [isAdmin, setIsAdmin] = useState<boolean>(false);
  const [adminProfile, setAdminProfile] = useState<any | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      setUser(user);
      if (user) {
        // Check if user has admin role in Firestore
        try {
          const userDoc = await getDoc(doc(db, 'users', user.uid));
          const userData = userDoc.data();
          const accessRole = userData?.accessRole || userData?.role;
          if (userDoc.exists() && userData?.isApproved === true && ['admin', 'global_admin', 'region_admin', 'branch_admin'].includes(accessRole)) {
            setIsAdmin(true);
            setAdminProfile({ id: userDoc.id, ...userData, accessRole });
          } else {
            setIsAdmin(false);
            setAdminProfile(null);
          }
        } catch (error) {
          console.error("Error fetching user role:", error);
          setIsAdmin(false);
          setAdminProfile(null);
        }
      } else {
        setIsAdmin(false);
        setAdminProfile(null);
      }
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  return { user, isAdmin, adminProfile, loading };
}
