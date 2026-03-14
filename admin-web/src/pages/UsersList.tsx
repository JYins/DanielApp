import React, { useEffect, useState } from 'react';
import { collection, query, getDocs, updateDoc, doc } from 'firebase/firestore';
import { db } from '../lib/firebase';
import { CheckCircle, XCircle, ChevronDown, ChevronUp, User, MapPin, Phone, Mail, Church, Calendar, Shield } from 'lucide-react';

export default function UsersList() {
  const [users, setUsers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [expandedUserId, setExpandedUserId] = useState<string | null>(null);

  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    setLoading(true);
    try {
      const usersQuery = query(collection(db, 'users'));
      const usersSnap = await getDocs(usersQuery);
      setUsers(usersSnap.docs.map(d => ({ id: d.id, ...d.data() })));
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const toggleApproval = async (userId: string, currentStatus: boolean) => {
    try {
      await updateDoc(doc(db, 'users', userId), {
        isApproved: !currentStatus,
        approvedAt: !currentStatus ? new Date() : null,
        updatedAt: new Date()
      });
      setUsers(prev => prev.map(u => u.id === userId ? { ...u, isApproved: !currentStatus } : u));
    } catch (err) {
      alert("Failed to update user.");
    }
  };

  const toggleExpand = (userId: string) => {
    setExpandedUserId(prev => prev === userId ? null : userId);
  };

  const formatDate = (dateValue: any) => {
    if (!dateValue) return '—';
    // Handle Firestore Timestamp
    if (dateValue.toDate) return dateValue.toDate().toLocaleDateString();
    // Handle regular Date or string
    if (dateValue instanceof Date) return dateValue.toLocaleDateString();
    if (typeof dateValue === 'string') return new Date(dateValue).toLocaleDateString();
    // Handle seconds-based timestamp
    if (dateValue.seconds) return new Date(dateValue.seconds * 1000).toLocaleDateString();
    return '—';
  };

  const genderLabel = (gender: string) => {
    if (gender === 'brother') return '弟兄 Brother';
    if (gender === 'sister') return '姊妹 Sister';
    return gender || '—';
  };

  if (loading) return <div className="p-8">Loading users...</div>;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">User Management</h1>
        <span className="text-sm text-gray-500">{users.length} users total</span>
      </div>

      <div className="bg-white shadow rounded-lg overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase w-8"></th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Name</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Email</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Church</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Actions</th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {users.map((user) => (
              <React.Fragment key={user.id}>
                {/* Main Row */}
                <tr
                  className={`cursor-pointer hover:bg-gray-50 transition-colors ${expandedUserId === user.id ? 'bg-amber-50' : ''}`}
                  onClick={() => toggleExpand(user.id)}
                >
                  <td className="px-6 py-4">
                    {expandedUserId === user.id
                      ? <ChevronUp className="h-4 w-4 text-gray-400" />
                      : <ChevronDown className="h-4 w-4 text-gray-400" />
                    }
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm font-medium text-gray-900">{user.name || user.displayName || '—'}</div>
                    <div className="text-xs text-gray-500">{genderLabel(user.gender)}</div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{user.email}</td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm text-gray-900">{user.churchName || '—'}</div>
                    <div className="text-xs text-gray-500">{user.churchCountry || ''}</div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${user.isApproved ? 'bg-green-100 text-green-800' : user.role === 'admin' ? 'bg-purple-100 text-purple-800' : 'bg-red-100 text-red-800'}`}>
                      {user.role === 'admin' ? 'Admin' : user.isApproved ? 'Approved' : 'Pending'}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium" onClick={(e) => e.stopPropagation()}>
                    {user.role !== 'admin' && (
                      <button
                        onClick={() => toggleApproval(user.id, user.isApproved)}
                        className={`${user.isApproved ? 'text-red-600 hover:text-red-900' : 'text-green-600 hover:text-green-900'} flex items-center justify-end w-full`}
                      >
                        {user.isApproved ? <><XCircle className="h-4 w-4 mr-1" /> Revoke</> : <><CheckCircle className="h-4 w-4 mr-1" /> Approve</>}
                      </button>
                    )}
                  </td>
                </tr>

                {/* Expandable Details Row */}
                {expandedUserId === user.id && (
                  <tr className="bg-amber-50">
                    <td colSpan={6} className="px-6 py-4">
                      <div className="grid grid-cols-2 md:grid-cols-3 gap-4 text-sm">
                        <div className="flex items-start space-x-2">
                          <User className="h-4 w-4 text-amber-600 mt-0.5 flex-shrink-0" />
                          <div>
                            <div className="text-xs font-medium text-gray-500 uppercase">Gender</div>
                            <div className="text-gray-900">{genderLabel(user.gender)}</div>
                          </div>
                        </div>
                        <div className="flex items-start space-x-2">
                          <Calendar className="h-4 w-4 text-amber-600 mt-0.5 flex-shrink-0" />
                          <div>
                            <div className="text-xs font-medium text-gray-500 uppercase">Birth Date</div>
                            <div className="text-gray-900">{formatDate(user.birthDate)}</div>
                          </div>
                        </div>
                        <div className="flex items-start space-x-2">
                          <Phone className="h-4 w-4 text-amber-600 mt-0.5 flex-shrink-0" />
                          <div>
                            <div className="text-xs font-medium text-gray-500 uppercase">Phone</div>
                            <div className="text-gray-900">{user.phoneNumber || '—'}</div>
                          </div>
                        </div>
                        <div className="flex items-start space-x-2">
                          <MapPin className="h-4 w-4 text-amber-600 mt-0.5 flex-shrink-0" />
                          <div>
                            <div className="text-xs font-medium text-gray-500 uppercase">Address</div>
                            <div className="text-gray-900">{user.address || '—'}</div>
                          </div>
                        </div>
                        <div className="flex items-start space-x-2">
                          <Church className="h-4 w-4 text-amber-600 mt-0.5 flex-shrink-0" />
                          <div>
                            <div className="text-xs font-medium text-gray-500 uppercase">Church</div>
                            <div className="text-gray-900">{user.churchName || '—'} ({user.churchCountry || '—'})</div>
                          </div>
                        </div>
                        <div className="flex items-start space-x-2">
                          <Calendar className="h-4 w-4 text-amber-600 mt-0.5 flex-shrink-0" />
                          <div>
                            <div className="text-xs font-medium text-gray-500 uppercase">Salvation Date</div>
                            <div className="text-gray-900">{formatDate(user.salvationDate)}</div>
                          </div>
                        </div>
                        <div className="flex items-start space-x-2">
                          <Shield className="h-4 w-4 text-amber-600 mt-0.5 flex-shrink-0" />
                          <div>
                            <div className="text-xs font-medium text-gray-500 uppercase">Ministry / Department</div>
                            <div className="text-gray-900">{user.ministryDepartment || '—'}</div>
                          </div>
                        </div>
                        <div className="flex items-start space-x-2">
                          <User className="h-4 w-4 text-amber-600 mt-0.5 flex-shrink-0" />
                          <div>
                            <div className="text-xs font-medium text-gray-500 uppercase">Confirmation Person</div>
                            <div className="text-gray-900 font-semibold">{user.confirmationPerson || '—'}</div>
                          </div>
                        </div>
                        <div className="flex items-start space-x-2">
                          <Calendar className="h-4 w-4 text-amber-600 mt-0.5 flex-shrink-0" />
                          <div>
                            <div className="text-xs font-medium text-gray-500 uppercase">Registered</div>
                            <div className="text-gray-900">{formatDate(user.createdAt)}</div>
                          </div>
                        </div>
                      </div>
                    </td>
                  </tr>
                )}
              </React.Fragment>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
