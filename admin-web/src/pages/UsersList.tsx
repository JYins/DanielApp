import React, { useEffect, useState } from 'react';
import { collection, query, where, getDocs, doc, orderBy, serverTimestamp, writeBatch } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { db, functions } from '../lib/firebase';
import { useAuthContext } from '../components/AuthProvider';
import { CheckCircle, XCircle, ChevronDown, ChevronUp, User, MapPin, Phone, Mail, Church, Calendar, Shield } from 'lucide-react';

export default function UsersList() {
  const [users, setUsers] = useState<any[]>([]);
  const [branches, setBranches] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [expandedUserId, setExpandedUserId] = useState<string | null>(null);
  const { user: currentUserAuth, adminProfile } = useAuthContext();
  const adminAccessRole = adminProfile?.accessRole || adminProfile?.role;
  const isGlobalAdmin = ['admin', 'global_admin'].includes(adminAccessRole);
  const isRegionAdmin = adminAccessRole === 'region_admin';
  const isBranchAdmin = adminAccessRole === 'branch_admin';

  useEffect(() => {
    fetchUsers();
    fetchBranches();
  }, [adminProfile?.id]);

  const fetchUsers = async () => {
    setLoading(true);
    try {
      let usersQuery = query(collection(db, 'users'));
      if (isRegionAdmin && adminProfile?.regionId) {
        usersQuery = query(collection(db, 'users'), where('regionId', '==', adminProfile.regionId));
      } else if (isBranchAdmin && adminProfile?.branchId) {
        usersQuery = query(collection(db, 'users'), where('branchId', '==', adminProfile.branchId));
      }
      const usersSnap = await getDocs(usersQuery);
      setUsers(usersSnap.docs.map(d => ({ id: d.id, ...d.data() })));
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const fetchBranches = async () => {
    try {
      let branchesQuery = query(collection(db, 'branches'), orderBy('sortOrder', 'asc'));
      if (isRegionAdmin && adminProfile?.regionId) {
        branchesQuery = query(
          collection(db, 'branches'),
          where('regionId', '==', adminProfile.regionId),
          where('isActive', '==', true),
          orderBy('sortOrder', 'asc')
        );
      } else if (isBranchAdmin && adminProfile?.regionId) {
        branchesQuery = query(
          collection(db, 'branches'),
          where('regionId', '==', adminProfile.regionId),
          where('isActive', '==', true),
          orderBy('sortOrder', 'asc')
        );
      }
      const branchesSnap = await getDocs(branchesQuery);
      const loadedBranches = branchesSnap.docs.map(d => ({ id: d.id, ...d.data() }));
      setBranches(isBranchAdmin ? loadedBranches.filter(branch => branch.id === adminProfile?.branchId) : loadedBranches);
    } catch (err) {
      console.error('Failed to fetch branches', err);
    }
  };

  const shouldFallbackToClientBatch = (error: any) => {
    const code = error?.code || '';
    return code === 'functions/not-found' || code === 'functions/unimplemented' || code === 'not-found';
  };

  const callSetUserAccessAdmin = async (payload: any) => {
    const setUserAccessAdminFunc = httpsCallable(functions, 'setUserAccessAdmin');
    return setUserAccessAdminFunc(payload);
  };

  const toggleApproval = async (userId: string, currentStatus: boolean) => {
    const user = users.find(u => u.id === userId);
    if (!user) return;
    if (!canManageUser(user)) {
      alert("Your admin role cannot update this user.");
      return;
    }

    const nextMembershipStatus = !currentStatus ? 'active' : 'revoked';
    try {
      try {
        await callSetUserAccessAdmin({
          uid: userId,
          isApproved: !currentStatus,
          branchId: user.branchId || undefined,
          accessRole: user.accessRole || user.role || 'member',
          membershipStatus: nextMembershipStatus
        });
      } catch (callableErr: any) {
        if (!shouldFallbackToClientBatch(callableErr)) {
          throw callableErr;
        }
        const batch = writeBatch(db);
        batch.update(doc(db, 'users', userId), {
          isApproved: !currentStatus,
          approvedAt: !currentStatus ? serverTimestamp() : null,
          membershipStatus: nextMembershipStatus,
          updatedAt: serverTimestamp()
        });

        if (user.branchId) {
          batch.set(
            doc(db, 'branchMemberships', membershipId(user.branchId, userId)),
            membershipPayload(user, { membershipStatus: nextMembershipStatus }),
            { merge: true }
          );
        }

        await batch.commit();
      }
      setUsers(prev => prev.map(u => u.id === userId ? {
        ...u,
        isApproved: !currentStatus,
        membershipStatus: nextMembershipStatus
      } : u));
    } catch (err) {
      alert("Failed to update user.");
    }
  };

  const updateUserRole = async (userId: string, accessRole: string) => {
    const user = users.find(u => u.id === userId);
    if (!user) return;
    if (!canManageUser(user) || !allowedAccessRolesFor(user).includes(accessRole)) {
      alert("Your admin role cannot assign that access level.");
      return;
    }

    const role = accessRole === 'global_admin' ? 'admin' : accessRole;
    try {
      try {
        await callSetUserAccessAdmin({
          uid: userId,
          isApproved: user.isApproved === true,
          branchId: user.branchId || undefined,
          accessRole,
          membershipStatus: user.membershipStatus || (user.isApproved ? 'active' : 'pending')
        });
      } catch (callableErr: any) {
        if (!shouldFallbackToClientBatch(callableErr)) {
          throw callableErr;
        }
        const batch = writeBatch(db);
        batch.update(doc(db, 'users', userId), {
          role,
          accessRole,
          updatedAt: serverTimestamp()
        });

        if (user.branchId) {
          batch.set(
            doc(db, 'branchMemberships', membershipId(user.branchId, userId)),
            membershipPayload(user, { role, accessRole }),
            { merge: true }
          );
        }

        await batch.commit();
      }
      setUsers(prev => prev.map(u => u.id === userId ? { ...u, role, accessRole } : u));
    } catch (err) {
      alert("Failed to update user role.");
    }
  };

  const updateUserBranch = async (userId: string, branchId: string) => {
    const user = users.find(u => u.id === userId);
    const selectedBranch = branches.find(branch => branch.id === branchId);
    if (!user || !selectedBranch) return;
    if (!canManageUser(user) || !canAssignBranch(selectedBranch)) {
      alert("Your admin role cannot assign that branch.");
      return;
    }

    const branchName = selectedBranch.name?.en || selectedBranch.name?.zh || selectedBranch.name?.ko || selectedBranch.id;
    const regionName = selectedBranch.regionName?.en || selectedBranch.regionName?.zh || selectedBranch.regionName?.ko || selectedBranch.country || '';

    const payload = {
      orgId: selectedBranch.orgId || 'daniel-branch-church',
      regionId: selectedBranch.regionId || '',
      regionName,
      branchId: selectedBranch.id,
      branchName,
      churchCountry: selectedBranch.country || regionName,
      churchName: branchName,
      updatedAt: serverTimestamp()
    };

    try {
      try {
        await callSetUserAccessAdmin({
          uid: userId,
          isApproved: user.isApproved === true,
          branchId: selectedBranch.id,
          accessRole: user.accessRole || user.role || 'member',
          membershipStatus: user.membershipStatus || (user.isApproved ? 'active' : 'pending')
        });
      } catch (callableErr: any) {
        if (!shouldFallbackToClientBatch(callableErr)) {
          throw callableErr;
        }
        const batch = writeBatch(db);
        batch.update(doc(db, 'users', userId), payload);

        if (user.branchId && user.branchId !== selectedBranch.id) {
          batch.set(
            doc(db, 'branchMemberships', membershipId(user.branchId, userId)),
            membershipPayload(user, { membershipStatus: 'revoked' }),
            { merge: true }
          );
        }

        batch.set(
          doc(db, 'branchMemberships', membershipId(selectedBranch.id, userId)),
          membershipPayload(user, {
            ...payload,
            membershipStatus: user.membershipStatus || (user.isApproved ? 'active' : 'pending')
          }),
          { merge: true }
        );

        await batch.commit();
      }
      setUsers(prev => prev.map(u => u.id === userId ? { ...u, ...payload } : u));
    } catch (err) {
      alert("Failed to update user branch.");
    }
  };

  const handleDeleteUser = async (userId: string, name: string) => {
    if (!window.confirm(`Are you sure you want to completely delete user "${name}"? This will revoke their access and delete their Firebase Auth account.`)) {
      return;
    }
    
    if (currentUserAuth?.uid === userId) {
      alert("You cannot delete your own admin account.");
      return;
    }

    try {
      const deleteUserAdminFunc = httpsCallable(functions, 'deleteUserAdmin');
      await deleteUserAdminFunc({ uidToDelete: userId });
      setUsers(prev => prev.filter(u => u.id !== userId));
      alert(`User "${name}" has been completely deleted.`);
    } catch (err: any) {
      console.error('Delete User Error:', err);
      const errorMsg = err.message || "Failed to delete user.";
      alert(`Error: ${errorMsg}`);
    }
  };

  const toggleExpand = (userId: string) => {
    setExpandedUserId(prev => prev === userId ? null : userId);
  };

  const currentRole = (user: any) => user.accessRole || user.role || 'member';

  const canManageUser = (user: any) => {
    const role = currentRole(user);
    if (isGlobalAdmin) return true;
    if (['admin', 'global_admin', 'region_admin'].includes(role)) return false;
    if (isRegionAdmin) return user.regionId === adminProfile?.regionId;
    if (isBranchAdmin) return role === 'member' && user.branchId === adminProfile?.branchId;
    return false;
  };

  const canAssignBranch = (branch: any) => {
    if (isGlobalAdmin) return true;
    if (isRegionAdmin) return branch.regionId === adminProfile?.regionId;
    if (isBranchAdmin) return branch.id === adminProfile?.branchId;
    return false;
  };

  const allowedAccessRolesFor = (user: any) => {
    if (isGlobalAdmin) {
      return ['member', 'branch_admin', 'region_admin', 'global_admin'];
    }
    if (isRegionAdmin && user.regionId === adminProfile?.regionId) {
      return ['member', 'branch_admin'];
    }
    if (isBranchAdmin && user.branchId === adminProfile?.branchId) {
      return ['member'];
    }
    return [];
  };

  const canDeleteUsers = isGlobalAdmin;

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

  const membershipId = (branchId: string, userId: string) => `${branchId}_${userId}`;

  const membershipPayload = (user: any, overrides: any = {}) => {
    const branchId = overrides.branchId || user.branchId;
    return {
      id: membershipId(branchId, user.id),
      userId: user.id,
      orgId: overrides.orgId || user.orgId || 'daniel-branch-church',
      regionId: overrides.regionId || user.regionId || '',
      branchId,
      role: overrides.role || user.role || 'member',
      accessRole: overrides.accessRole || user.accessRole || user.role || 'member',
      status: overrides.membershipStatus || user.membershipStatus || (user.isApproved ? 'active' : 'pending'),
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp()
    };
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
                    <div className="text-sm text-gray-900">{user.branchName || user.churchName || '—'}</div>
                    <div className="text-xs text-gray-500">{user.regionName || user.churchCountry || ''}</div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${user.isApproved ? 'bg-green-100 text-green-800' : (user.accessRole || user.role) === 'admin' || (user.accessRole || user.role) === 'global_admin' ? 'bg-purple-100 text-purple-800' : 'bg-red-100 text-red-800'}`}>
                      {(user.accessRole || user.role) === 'admin' || (user.accessRole || user.role) === 'global_admin' ? 'Admin' : user.isApproved ? 'Approved' : 'Pending'}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium" onClick={(e) => e.stopPropagation()}>
                    {(user.accessRole || user.role) !== 'admin' && (user.accessRole || user.role) !== 'global_admin' && canManageUser(user) && (
                      <div className="flex items-center justify-end space-x-3">
                        <button
                          onClick={() => toggleApproval(user.id, user.isApproved)}
                          className={`${user.isApproved ? 'text-orange-600 hover:text-orange-900' : 'text-green-600 hover:text-green-900'} flex items-center`}
                        >
                          {user.isApproved ? <><XCircle className="h-4 w-4 mr-1" /> Revoke</> : <><CheckCircle className="h-4 w-4 mr-1" /> Approve</>}
                        </button>
                        {canDeleteUsers && (
                          <button
                            onClick={() => handleDeleteUser(user.id, user.name || user.email)}
                            className="text-red-600 hover:text-red-900 flex items-center"
                          >
                            <XCircle className="h-4 w-4 mr-1" /> Delete
                          </button>
                        )}
                      </div>
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
                            <div className="text-gray-900">{user.branchName || user.churchName || '—'} ({user.regionName || user.churchCountry || '—'})</div>
                          </div>
                        </div>
                        <div className="flex items-start space-x-2">
                          <Church className="h-4 w-4 text-amber-600 mt-0.5 flex-shrink-0" />
                          <div className="w-full">
                            <div className="text-xs font-medium text-gray-500 uppercase">Branch Assignment</div>
                            <select
                              className="mt-1 block w-full rounded-md border-gray-300 text-sm shadow-sm focus:border-amber-500 focus:ring-amber-500"
                              value={user.branchId || ''}
                              onChange={(e) => updateUserBranch(user.id, e.target.value)}
                              disabled={!canManageUser(user)}
                            >
                              <option value="" disabled>Select branch</option>
                              {branches.filter(canAssignBranch).map(branch => (
                                <option key={branch.id} value={branch.id}>
                                  {branch.name?.en || branch.name?.zh || branch.id}
                                </option>
                              ))}
                            </select>
                          </div>
                        </div>
                        <div className="flex items-start space-x-2">
                          <Shield className="h-4 w-4 text-amber-600 mt-0.5 flex-shrink-0" />
                          <div className="w-full">
                            <div className="text-xs font-medium text-gray-500 uppercase">Access Role</div>
                            <select
                              className="mt-1 block w-full rounded-md border-gray-300 text-sm shadow-sm focus:border-amber-500 focus:ring-amber-500"
                              value={user.accessRole || user.role || 'member'}
                              onChange={(e) => updateUserRole(user.id, e.target.value)}
                              disabled={!canManageUser(user)}
                            >
                              {allowedAccessRolesFor(user).map(role => (
                                <option key={role} value={role}>
                                  {role === 'global_admin' ? 'Global Admin' : role === 'region_admin' ? 'Region Admin' : role === 'branch_admin' ? 'Branch Admin' : 'Member'}
                                </option>
                              ))}
                            </select>
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
